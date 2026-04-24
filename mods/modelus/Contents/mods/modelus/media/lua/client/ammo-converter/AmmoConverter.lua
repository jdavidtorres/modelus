-- AmmoConverter.lua
-- Auto-converts ammo of the same tier to the type used by the equipped weapon.
-- Trigger: OnPlayerUpdate, fires when the character is idle (no actions queued).
-- Scope: client only.

local _LOG_PREFIX = "[Modelus][AmmoConverter]"

local function logDebug(msg)
    if getDebug and getDebug() then
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
}

-- ---------------------------------------------------------------------------
-- Internal: reverse lookup tables — built once at load time.
-- _typeToTier : "Base.Bullets9mm" → "pistol"
-- _tierPeers  : "Base.Bullets9mm" → { "Base.Bullets38", "Base.Bullets45", ... }
-- ---------------------------------------------------------------------------

AmmoConverter._typeToTier  = {}
AmmoConverter._tierPeers   = {}
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
-- Helpers
-- ---------------------------------------------------------------------------

-- Returns the inventory key from a full type ("Base.Bullets9mm" → "Bullets9mm").
local function _toKey(fullType)
    return fullType:match("%.(.+)$") or fullType
end

-- Resolves the full type from a weapon's AmmoType object.
-- getItemKey() may return "Bullets9mm" or "Base.Bullets9mm" depending on the engine version.
local function _resolveWeaponAmmoFullType(ammoTypeObj)
    local key = ammoTypeObj:getItemKey()
    -- Already qualified?
    if key:find("%.") then
        return key
    end
    -- Prefix with default module.
    return "Base." .. key
end

-- ---------------------------------------------------------------------------
-- Conversion logic
-- ---------------------------------------------------------------------------

--- Converts `amount` of `srcType` to `dstType` in the player's inventory, atomically.
function AmmoConverter.doConvert(player, srcType, dstType, amount)
    if not player then
        logDebug("doConvert: nil player — aborting")
        return
    end

    local inventory = player:getInventory()
    local srcKey    = _toKey(srcType)

    -- Pre-validate stock before touching anything.
    local stock = inventory:getItemCountRecurse(srcKey)
    if stock < amount then
        logDebug(
            "doConvert: insufficient stock for " .. srcType ..
            " (need " .. amount .. ", have " .. stock .. ") — aborting"
        )
        return
    end

    -- Phase 1: create all destination items locally. Abort if any fail.
    local created = {}
    for _ = 1, amount do
        local newItem = InventoryItemFactory.CreateItem(dstType)
        if not newItem then
            logDebug("doConvert: CreateItem failed for " .. dstType .. " — aborting, no inventory change")
            return
        end
        created[#created + 1] = newItem
    end

    -- Phase 2: atomic swap — remove source then add destination.
    local toRemove = inventory:getSomeType(srcKey, amount)
    for i = 0, toRemove:size() - 1 do
        inventory:Remove(toRemove:get(i))
    end
    for _, item in ipairs(created) do
        inventory:AddItem(item)
    end

    logDebug(
        "doConvert: " .. amount .. "x " .. srcType .. " → " .. dstType
    )
end

-- ---------------------------------------------------------------------------
-- Idle check
-- ---------------------------------------------------------------------------

--- Runs when the player is confirmed idle. Detects the equipped weapon's ammo
--- type and converts all other ammo of the same tier to that type.
function AmmoConverter.onIdleCheck(player)
    -- Guard: player must not be performing any action.
    if ISTimedActionQueue.isPlayerDoingAction(player) then return end

    -- Guard: must have a ranged HandWeapon in primary hand with a direct ammo type.
    local weapon = player:getPrimaryHandItem()
    if not weapon then return end
    if not instanceof(weapon, "HandWeapon") then return end
    if not weapon:isRanged() then return end

    local ammoTypeObj = weapon:getAmmoType()
    if not ammoTypeObj then
        -- Magazine-based weapon — out of scope in v1.
        return
    end

    local weaponAmmoFullType = _resolveWeaponAmmoFullType(ammoTypeObj)

    -- Guard: weapon ammo type must be in our conversion tiers.
    if not AmmoConverter._typeToTier[weaponAmmoFullType] then
        logDebug("onIdleCheck: ammo type not in TIERS: " .. weaponAmmoFullType)
        return
    end

    local peers     = AmmoConverter._tierPeers[weaponAmmoFullType]
    local inventory = player:getInventory()

    logDebug("onIdleCheck: weapon uses " .. weaponAmmoFullType .. ", checking peers")

    for _, srcType in ipairs(peers) do
        local srcKey = _toKey(srcType)
        local stock  = inventory:getItemCountRecurse(srcKey)
        if stock > 0 then
            AmmoConverter.doConvert(player, srcType, weaponAmmoFullType, stock)
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
