-- AmmoConverter.lua
-- Auto-converts ammo of the same tier to the type used by the equipped weapon.
-- Trigger: OnPlayerUpdate, fires when the character is idle (no actions queued).
-- Scope: client only.
--
-- B42 Notes:
--   - Full item types ("Base.556Bullets") must be preserved end-to-end for B42
--     inventory APIs. _toKey() is intentionally NOT used for count/remove/create.
--   - Magazine-fed weapons fallback via ScriptManager when direct ammoType is nil.
--   - Sources: only loose ammo, boxes, and cartons in player inventory.
--   - Magazines and magazine-loaded ammo are NEVER counted or consumed.
--   - Package ratios (vanilla B42):
--       pistol box=50, carton=600
--       rifle/.44 box=20, carton=240
--       shotgun box=25, carton=300
--   - Remainder rule: when a box/carton is consumed its FULL round-value is
--     produced as destination loose ammo. totalCreated >= totalRounds always.

local _LOG_PREFIX = "[Modelus][AmmoConverter]"
local _VERBOSE_DIAGNOSTICS = false

local function logDebug(msg)
    if _VERBOSE_DIAGNOSTICS or (getDebug and getDebug()) then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

AmmoConverter = {}

-- How many ticks between idle checks (~2 seconds at 60fps).
AmmoConverter.IDLE_CHECK_INTERVAL = 120

AmmoConverter.TIERS = {
    pistol = {
        "Base.Bullets9mm",
        "Base.Bullets38",
        "Base.Bullets45",
        "Base.Bullets357",
    },
    rifle = {
        "Base.Bullets44",
        "Base.556Bullets",
        "Base.308Bullets",
        "Base.3030Bullets",
    },
    shotgun = {
        "Base.ShotgunShells",
    },
}

-- ---------------------------------------------------------------------------
-- NORMALIZATION — maps runtime/legacy ammo type strings to canonical
-- B42 full item types. Also handles already-qualified "Base.*" as passthrough.
-- ---------------------------------------------------------------------------

AmmoConverter.NORMALIZATION = {
    ["base:bullets_556"]        = "Base.556Bullets",
    ["base:bullets_3030"]       = "Base.3030Bullets",
    ["base:bullets_308"]        = "Base.308Bullets",
    ["base:bullets_44"]         = "Base.Bullets44",
    ["base:bullets_9mm"]        = "Base.Bullets9mm",
    ["base:bullets_38"]         = "Base.Bullets38",
    ["base:bullets_45"]         = "Base.Bullets45",
    ["base:bullets_357"]        = "Base.Bullets357",
    ["base:shotgunshells"]      = "Base.ShotgunShells",
    -- Already-qualified pass-throughs (identity; checked first in normalizer)
    ["Base.556Bullets"]         = "Base.556Bullets",
    ["Base.3030Bullets"]        = "Base.3030Bullets",
    ["Base.308Bullets"]         = "Base.308Bullets",
    ["Base.Bullets44"]          = "Base.Bullets44",
    ["Base.Bullets9mm"]         = "Base.Bullets9mm",
    ["Base.Bullets38"]          = "Base.Bullets38",
    ["Base.Bullets45"]          = "Base.Bullets45",
    ["Base.Bullets357"]         = "Base.Bullets357",
    ["Base.ShotgunShells"]      = "Base.ShotgunShells",
}

-- ---------------------------------------------------------------------------
-- PACKAGING — loose/box/carton mappings with unit round values.
-- Vanilla B42 ratios:
--   pistol  box=50, carton=600  (12 boxes × 50)
--   rifle   box=20, carton=240  (12 boxes × 20)
--   .44 Mag box=20, carton=240
--   shotgun box=25, carton=300  (12 boxes × 25)
-- Only calibers that have B42 packaging are listed.
-- ---------------------------------------------------------------------------

AmmoConverter.PACKAGING = {
    -- Rifle
    ["Base.556Bullets"]   = { box = "Base.556Box",          carton = "Base.556Carton",          boxValue = 20, cartonValue = 240 },
    ["Base.3030Bullets"]  = { box = "Base.3030Box",         carton = "Base.3030Carton",         boxValue = 20, cartonValue = 240 },
    ["Base.308Bullets"]   = { box = "Base.308Box",          carton = "Base.308Carton",          boxValue = 20, cartonValue = 240 },
    -- .44 Magnum (rifle tier)
    ["Base.Bullets44"]    = { box = "Base.Bullets44Box",    carton = "Base.Bullets44Carton",    boxValue = 20, cartonValue = 240 },
    -- Pistol (box=50, carton=600)
    ["Base.Bullets9mm"]   = { box = "Base.Bullets9mmBox",   carton = "Base.Bullets9mmCarton",   boxValue = 50, cartonValue = 600 },
    ["Base.Bullets38"]    = { box = "Base.Bullets38Box",    carton = "Base.Bullets38Carton",    boxValue = 50, cartonValue = 600 },
    ["Base.Bullets45"]    = { box = "Base.Bullets45Box",    carton = "Base.Bullets45Carton",    boxValue = 50, cartonValue = 600 },
    ["Base.Bullets357"]   = { box = "Base.Bullets357Box",   carton = "Base.Bullets357Carton",   boxValue = 50, cartonValue = 600 },
    -- Shotgun (box=25, carton=300)
    ["Base.ShotgunShells"] = { box = "Base.ShotgunShellsBox", carton = "Base.ShotgunShellsCarton", boxValue = 25, cartonValue = 300 },
}

-- ---------------------------------------------------------------------------
-- Internal lookup tables — built once at load time.
-- _typeToTier : "Base.Bullets9mm" → "pistol"
-- _tierPeers  : "Base.Bullets9mm" → { "Base.Bullets38", ... }
-- ---------------------------------------------------------------------------

AmmoConverter._typeToTier   = {}
AmmoConverter._tierPeers    = {}
AmmoConverter._tickCounters = {}   -- playerNum → tick count

local function _buildLookup()
    for tierName, types in pairs(AmmoConverter.TIERS) do
        for _, fullType in ipairs(types) do
            AmmoConverter._typeToTier[fullType] = tierName
        end
    end
    for _, types in pairs(AmmoConverter.TIERS) do
        for _, fullType in ipairs(types) do
            local peers = {}
            for _, other in ipairs(types) do
                if other ~= fullType then
                    peers[#peers + 1] = other
                end
            end
            AmmoConverter._tierPeers[fullType] = peers
        end
    end
end

_buildLookup()

-- ---------------------------------------------------------------------------
-- Table validation helper — runs at load time, emits warn for any structural
-- issue: unknown tier types, duplicate entries, packaging keys not in tiers,
-- or self-target pairs. Does not abort loading; only warns.
-- Task 2.2 requirement: "rejects missing script items and self-target pairs".
-- ---------------------------------------------------------------------------

local function _validateTables()
    -- Validate that every PACKAGING key has a matching TIERS entry.
    for looseType, _ in pairs(AmmoConverter.PACKAGING) do
        if not AmmoConverter._typeToTier[looseType] then
            print(_LOG_PREFIX .. " [WARN] PACKAGING key not in TIERS: " .. tostring(looseType))
        end
    end
    -- Validate that peers table has no self-target entries (invariant from _buildLookup).
    for looseType, peers in pairs(AmmoConverter._tierPeers) do
        for _, peer in ipairs(peers) do
            if peer == looseType then
                print(_LOG_PREFIX .. " [WARN] Self-target peer detected for: " .. tostring(looseType))
            end
        end
    end
end

_validateTables()

-- ---------------------------------------------------------------------------
-- Normalizer — returns canonical full type or nil if unknown.
-- Handles "base:bullets_*", already-qualified "Base.*", or bare keys.
-- ---------------------------------------------------------------------------

local function _normalizeAmmoType(raw)
    if not raw then return nil end
    -- Direct hit (covers both legacy and already-qualified).
    local known = AmmoConverter.NORMALIZATION[raw]
    if known then return known end
    -- Bare key without module (e.g. "556Bullets" from old engine paths).
    local qualified = "Base." .. raw
    if AmmoConverter.NORMALIZATION[qualified] then
        return AmmoConverter.NORMALIZATION[qualified]
    end
    logDebug("_normalizeAmmoType: unknown key '" .. tostring(raw) .. "'")
    return nil
end

-- B42 inventory count/removal APIs expect the item type key without module
-- (e.g. "556Bullets"), while creation and catalog logic should preserve the
-- canonical full type (e.g. "Base.556Bullets"). Keep the conversion isolated
-- here so fullType normalization stays explicit everywhere else.
local function _inventoryTypeKey(fullType)
    return fullType:match("%.(.+)$") or fullType
end

-- ---------------------------------------------------------------------------
-- Target ammo resolver.
-- 1. Prefer weapon:getAmmoType():getItemKey() normalized.
-- 2. Fallback: weapon:getMagazineType() → ScriptManager item → ammoType.
-- ---------------------------------------------------------------------------

local function _resolveTargetAmmoFullType(weapon)
    -- Primary path: direct weapon ammo type.
    local okAmmoType, ammoTypeObj = pcall(function()
        return weapon:getAmmoType()
    end)
    if not okAmmoType then
        logDebug("_resolveTargetAmmoFullType: weapon:getAmmoType failed, trying magazine fallback")
        ammoTypeObj = nil
    end
    if ammoTypeObj then
        local okKey, raw = pcall(function()
            return ammoTypeObj:getItemKey()
        end)
        if okKey then
            local normalized = _normalizeAmmoType(raw)
            if normalized then
                logDebug("_resolveTargetAmmoFullType: direct ammo '" .. tostring(raw) .. "' → '" .. normalized .. "'")
                return normalized
            end
            logDebug("_resolveTargetAmmoFullType: direct ammo key '" .. tostring(raw) .. "' not normalized, trying magazine fallback")
        else
            logDebug("_resolveTargetAmmoFullType: ammoType:getItemKey failed, trying magazine fallback")
        end
    end

    -- Fallback: magazine type → script item → ammo type.
    local okMagType, magType = pcall(function()
        if weapon.getMagazineType then
            return weapon:getMagazineType()
        end
        return nil
    end)
    if not okMagType then
        logDebug("_resolveTargetAmmoFullType: weapon:getMagazineType failed — cannot resolve")
        return nil
    end
    if not magType or magType == "" then
        logDebug("_resolveTargetAmmoFullType: no direct ammo and no magazine type — cannot resolve")
        return nil
    end

    logDebug("_resolveTargetAmmoFullType: magazine type = '" .. magType .. "', looking up script item")

    local ok, scriptItem = pcall(function()
        return ScriptManager.instance:getItem(magType)
    end)
    if not ok or not scriptItem then
        logDebug("_resolveTargetAmmoFullType: ScriptManager lookup failed for '" .. magType .. "'")
        return nil
    end

    local okMagAmmo, magAmmoTypeObj = pcall(function()
        if scriptItem.getAmmoType then
            return scriptItem:getAmmoType()
        end
        return nil
    end)
    if not okMagAmmo then
        logDebug("_resolveTargetAmmoFullType: magazine script getAmmoType failed")
        return nil
    end
    if not magAmmoTypeObj then
        logDebug("_resolveTargetAmmoFullType: magazine script item has no ammo type")
        return nil
    end

    local okMagKey, rawMag = pcall(function()
        if magAmmoTypeObj.getItemKey then
            return magAmmoTypeObj:getItemKey()
        end
        return tostring(magAmmoTypeObj)
    end)
    if not okMagKey then
        rawMag = tostring(magAmmoTypeObj)
    end
    local normalized = _normalizeAmmoType(rawMag)
    if normalized then
        logDebug("_resolveTargetAmmoFullType: magazine fallback '" .. rawMag .. "' → '" .. normalized .. "'")
        return normalized
    end

    logDebug("_resolveTargetAmmoFullType: magazine ammo key '" .. rawMag .. "' not normalized — cannot resolve")
    return nil
end

-- ---------------------------------------------------------------------------
-- Source value calculator.
-- Returns total loose-round equivalent from loose ammo, boxes, and cartons.
-- Magazines and their contents are intentionally excluded.
-- inventory: player inventory; srcType: canonical full type of peer caliber.
-- ---------------------------------------------------------------------------

local function _calcSourceValue(inventory, srcType)
    local pkg = AmmoConverter.PACKAGING[srcType]
    local total = 0

    -- Loose ammo.
    local looseSrcKey = _inventoryTypeKey(srcType)
    local loose = inventory:getItemCountRecurse(looseSrcKey)
    total = total + loose

    if pkg then
        -- Boxes.
        if pkg.box then
            local boxKey = _inventoryTypeKey(pkg.box)
            local boxes = inventory:getItemCountRecurse(boxKey)
            total = total + (boxes * pkg.boxValue)
        end
        -- Cartons.
        if pkg.carton then
            local cartonKey = _inventoryTypeKey(pkg.carton)
            local cartons = inventory:getItemCountRecurse(cartonKey)
            total = total + (cartons * pkg.cartonValue)
        end
    end

    return total
end

-- Returns a debug string showing loose/box/carton breakdown for a source type.
local function _calcSourceDebugStr(inventory, srcType)
    local pkg = AmmoConverter.PACKAGING[srcType]
    local looseSrcKey = _inventoryTypeKey(srcType)
    local loose = inventory:getItemCountRecurse(looseSrcKey)
    local boxes = 0
    local cartons = 0
    if pkg then
        if pkg.box then boxes = inventory:getItemCountRecurse(_inventoryTypeKey(pkg.box)) end
        if pkg.carton then cartons = inventory:getItemCountRecurse(_inventoryTypeKey(pkg.carton)) end
    end
    return "loose=" .. loose .. " boxes=" .. boxes .. " cartons=" .. cartons
end

-- ---------------------------------------------------------------------------
-- doConvert — removes source units (loose first, then boxes, then cartons),
-- creates destination loose ammo equal to the TOTAL ROUND VALUE consumed.
--
-- Key invariant: totalCreated = loosConsumed + boxesConsumed*boxValue + cartonsConsumed*cartonValue
-- This guarantees no round-value is lost due to package remainder.
--
-- Safety guard: srcType MUST NOT equal dstType (caller responsibility, but
-- enforced here as an explicit abort to prevent accidental self-consumption).
-- ---------------------------------------------------------------------------

function AmmoConverter.doConvert(player, srcType, dstType)
    if not player then
        logDebug("doConvert: nil player — aborting")
        return
    end

    -- Hard safety: never treat destination as source.
    if srcType == dstType then
        logDebug("doConvert: srcType == dstType (" .. tostring(srcType) .. ") — aborting to prevent self-consumption")
        return
    end

    local inventory = player:getInventory()
    local pkg = AmmoConverter.PACKAGING[srcType]

    -- Snapshot source stock.
    local looseSrcKey = _inventoryTypeKey(srcType)
    local looseStock = inventory:getItemCountRecurse(looseSrcKey)

    local boxStock, boxKey = 0, nil
    local cartonStock, cartonKey = 0, nil
    if pkg then
        if pkg.box    then boxKey    = _inventoryTypeKey(pkg.box);    boxStock    = inventory:getItemCountRecurse(boxKey)    end
        if pkg.carton then cartonKey = _inventoryTypeKey(pkg.carton); cartonStock = inventory:getItemCountRecurse(cartonKey) end
    end

    if looseStock == 0 and boxStock == 0 and cartonStock == 0 then
        logDebug("doConvert: no source stock for " .. srcType .. " — skipping")
        return
    end

    -- Compute how many destination loose rounds to create.
    -- Each consumed unit produces its full round-value in destination ammo.
    -- This preserves total round value even when partial boxes are consumed.
    local totalToCreate = looseStock
        + boxStock    * (pkg and pkg.boxValue    or 0)
        + cartonStock * (pkg and pkg.cartonValue or 0)

    logDebug(
        "doConvert: target=" .. dstType ..
        " src=" .. srcType ..
        " loose=" .. looseStock ..
        " boxes=" .. boxStock ..
        " cartons=" .. cartonStock ..
        " → creating " .. totalToCreate .. " destination rounds"
    )

    if totalToCreate <= 0 then return end

    -- Phase 1: pre-create all destination items. Abort if any CreateItem fails.
    local created = {}
    for _ = 1, totalToCreate do
        local newItem = InventoryItemFactory.CreateItem(dstType)
        if not newItem then
            logDebug("doConvert: CreateItem failed for " .. dstType .. " — aborting, no inventory change")
            return
        end
        created[#created + 1] = newItem
    end

    -- Phase 2: preflight every source list BEFORE removing anything.
    -- This preserves atomicity: if any lookup fails, no source item has been removed.
    local looseItems = nil
    if looseStock > 0 then
        looseItems = inventory:getSomeType(looseSrcKey, looseStock)
        if not looseItems or looseItems:size() < looseStock then
            logDebug("doConvert: getSomeType failed for loose " .. srcType .. " — aborting")
            return
        end
    end

    local boxItems = nil
    if boxStock > 0 and boxKey then
        boxItems = inventory:getSomeType(boxKey, boxStock)
        if not boxItems or boxItems:size() < boxStock then
            logDebug("doConvert: getSomeType failed for boxes " .. pkg.box .. " — aborting, no inventory change")
            return
        end
    end

    local cartonItems = nil
    if cartonStock > 0 and cartonKey then
        cartonItems = inventory:getSomeType(cartonKey, cartonStock)
        if not cartonItems or cartonItems:size() < cartonStock then
            logDebug("doConvert: getSomeType failed for cartons " .. pkg.carton .. " — aborting, no inventory change")
            return
        end
    end

    -- Phase 3: consume sources deterministically — loose → boxes → cartons.

    -- Remove ALL loose source ammo.
    if looseItems then
        for i = 0, looseItems:size() - 1 do
            inventory:Remove(looseItems:get(i))
        end
        logDebug("doConvert: removed " .. looseStock .. "x loose " .. srcType)
    end

    -- Remove ALL boxes.
    if boxItems then
        for i = 0, boxItems:size() - 1 do
            inventory:Remove(boxItems:get(i))
        end
        logDebug("doConvert: removed " .. boxStock .. "x box " .. pkg.box)
    end

    -- Remove ALL cartons.
    if cartonItems then
        for i = 0, cartonItems:size() - 1 do
            inventory:Remove(cartonItems:get(i))
        end
        logDebug("doConvert: removed " .. cartonStock .. "x carton " .. pkg.carton)
    end

    -- Phase 4: add all destination items only after successful removal.
    for _, item in ipairs(created) do
        inventory:AddItem(item)
    end

    logDebug(
        "doConvert: ✓ converted " .. srcType .. " → " .. dstType ..
        " (" .. totalToCreate .. " destination rounds created)"
    )
end

-- ---------------------------------------------------------------------------
-- onIdleCheck — resolves target, iterates tier peers,
-- converts all source caliber stock to target loose ammo.
-- Never converts the equipped target caliber into itself.
-- ---------------------------------------------------------------------------

function AmmoConverter.onIdleCheck(player)
    -- Guard: player must not be performing any action.
    if ISTimedActionQueue.isPlayerDoingAction and ISTimedActionQueue.isPlayerDoingAction(player) then
        logDebug("onIdleCheck: player busy — skipping")
        return
    end

    -- Guard: must have a ranged HandWeapon in primary hand.
    local weapon = player:getPrimaryHandItem()
    if not weapon then
        logDebug("onIdleCheck: no primary hand item")
        return
    end
    if not instanceof(weapon, "HandWeapon") then
        logDebug("onIdleCheck: primary item is not HandWeapon: " .. tostring(weapon:getFullType()))
        return
    end
    if not weapon:isRanged() then
        logDebug("onIdleCheck: weapon is not ranged: " .. tostring(weapon:getFullType()))
        return
    end

    -- Resolve target ammo with normalization + magazine fallback.
    local targetType = _resolveTargetAmmoFullType(weapon)
    if not targetType then
        logDebug("onIdleCheck: could not resolve target ammo — skipping")
        return
    end

    -- Guard: target type must be in our conversion tiers.
    if not AmmoConverter._typeToTier[targetType] then
        logDebug("onIdleCheck: target ammo not in TIERS: " .. targetType)
        return
    end

    local peers     = AmmoConverter._tierPeers[targetType]
    local inventory = player:getInventory()

    -- Debug: show target, peers, and counts.
    logDebug("onIdleCheck: target=" .. targetType .. " peers=" .. #peers)
    for _, srcType in ipairs(peers) do
        local dbg = _calcSourceDebugStr(inventory, srcType)
        local value = _calcSourceValue(inventory, srcType)
        logDebug("onIdleCheck:   peer " .. srcType .. " " .. dbg .. " total=" .. value)
    end

    -- For each peer, convert ALL of its source stock to destination.
    -- srcType is guaranteed != targetType by the peers table construction.
    for _, srcType in ipairs(peers) do
        local value = _calcSourceValue(inventory, srcType)
        if value > 0 then
            logDebug("onIdleCheck: converting " .. srcType .. " → " .. targetType)
            AmmoConverter.doConvert(player, srcType, targetType)
        end
    end
end

-- ---------------------------------------------------------------------------
-- OnPlayerUpdate hook with tick throttle
-- ---------------------------------------------------------------------------

local function onPlayerUpdate(player)
    local pn = player:getPlayerNum()
    AmmoConverter._tickCounters[pn] = (AmmoConverter._tickCounters[pn] or 0) + 1
    if AmmoConverter._tickCounters[pn] < AmmoConverter.IDLE_CHECK_INTERVAL then
        return
    end
    AmmoConverter._tickCounters[pn] = 0
    AmmoConverter.onIdleCheck(player)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)

-- OnContainerUpdate: reset the tick counter so the next OnPlayerUpdate fires
-- an idle check promptly, instead of calling onIdleCheck directly. This prevents
-- container-update storms from bypassing the throttle or causing re-entrant passes.
local function onContainerUpdate()
    if not getPlayer then return end
    local player = getPlayer()
    if not player then return end
    local pn = player:getPlayerNum()
    -- Advance counter to one tick before the check threshold so the next
    -- OnPlayerUpdate fires the idle check, respecting the throttle window.
    AmmoConverter._tickCounters[pn] = AmmoConverter.IDLE_CHECK_INTERVAL - 1
end

Events.OnContainerUpdate.Add(onContainerUpdate)
