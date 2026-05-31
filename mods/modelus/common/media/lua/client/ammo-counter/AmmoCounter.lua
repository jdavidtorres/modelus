-- AmmoCounter.lua
-- Client-only HUD overlay that displays ammo state near the cursor while aiming a ranged weapon.
-- Read-only: never mutates game state, never creates, removes, or transfers items.
-- Hook: Events.OnRenderTick
-- Scope: client only.

local _LOG_PREFIX = "[Modelus][AmmoCounter]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

-- ---------------------------------------------------------------------------
-- Module table (local scope — no global leak)
-- ---------------------------------------------------------------------------

local AmmoCounter = {
    cache = {
        reserveCount = 0,
        ammoType     = nil,
        lastTick     = 0,
    },
    config = {
        throttleTicks = 30,
        offsetX       = 15,
        offsetY       = 15,
    },
}

-- Internal frame counter incremented each OnRenderTick call; drives throttle cadence.
AmmoCounter._frameCount = 0

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Returns true when the local player exists, is alive, is currently aiming,
--- and has a ranged weapon in their primary hand.
function AmmoCounter.isAimingRanged(player)
    if not player then return false end

    local okDead, dead = pcall(function() return player:isDead() end)
    if okDead and dead then return false end

    local okAim, aiming = pcall(function() return player:isAiming() end)
    if not okAim or not aiming then return false end

    local okWep, weapon = pcall(function() return player:getPrimaryHandItem() end)
    if not okWep or not weapon then return false end

    local okRanged, isRanged = pcall(function()
        return instanceof(weapon, "HandWeapon") and weapon:isRanged()
    end)
    return okRanged and isRanged == true
end

--- Resolves the full ammo state for the player's primary hand item.
--- Returns a state table:
---   { current, max, ammoType, isJammed, isChambered }
--- Returns nil if the item cannot be resolved or is not a ranged weapon.
function AmmoCounter.resolveWeaponState(player)
    if not player then return nil end

    local okWep, weapon = pcall(function() return player:getPrimaryHandItem() end)
    if not okWep or not weapon then return nil end

    local okRanged, isRanged = pcall(function()
        return instanceof(weapon, "HandWeapon") and weapon:isRanged()
    end)
    if not okRanged or not isRanged then return nil end

    local state = {}

    local okCur, current = pcall(function() return weapon:getCurrentAmmoCount() end)
    state.current = okCur and current or 0

    local okMax, maxAmmo = pcall(function()
        return weapon.getMaxAmmo and weapon:getMaxAmmo() or 0
    end)
    state.max = okMax and maxAmmo or 0

    local okType, ammoType = pcall(function() return weapon:getAmmoType() end)
    state.ammoType = okType and ammoType or nil

    local okJam, isJammed = pcall(function()
        return weapon.isJammed and weapon:isJammed() or false
    end)
    state.isJammed = okJam and isJammed == true

    local okChamber, isChambered = pcall(function()
        return weapon.isRoundChambered and weapon:isRoundChambered() or false
    end)
    state.isChambered = okChamber and isChambered == true

    return state
end

--- Returns the cached or freshly scanned count of reserve ammo of the given
--- type in the player's full inventory (including nested bags).
--- Refreshes the cache at most once every throttleTicks frames.
function AmmoCounter.getReserve(player, ammoType)
    if not player or not ammoType then return 0 end

    -- Return the cached value when the throttle has not expired and ammo type matches.
    if AmmoCounter.cache.ammoType == ammoType
            and (AmmoCounter._frameCount - AmmoCounter.cache.lastTick)
                    < AmmoCounter.config.throttleTicks then
        return AmmoCounter.cache.reserveCount
    end

    -- Strip namespace prefix so the inventory lookup key matches PZ internals
    -- e.g. "Base.Bullets9mm" → "Bullets9mm"
    local ammoKey = tostring(ammoType)
    local dot = ammoKey:find("%.")
    if dot then ammoKey = ammoKey:sub(dot + 1) end

    local count = 0
    local okInv, inv = pcall(function() return player:getInventory() end)
    if okInv and inv then
        local okCount, n = pcall(function() return inv:getCountTypeRecurse(ammoKey) end)
        if okCount and type(n) == "number" then
            count = n
        end
    end

    -- Update throttle cache.
    AmmoCounter.cache.reserveCount = count
    AmmoCounter.cache.ammoType     = ammoType
    AmmoCounter.cache.lastTick     = AmmoCounter._frameCount

    logDebug("reserve scan: " .. tostring(ammoType) .. " = " .. tostring(count))
    return count
end

-- ---------------------------------------------------------------------------
-- Text formatting
-- ---------------------------------------------------------------------------

--- Formats the ammo display string from the resolved weapon state and reserve count.
--- Warning states take priority: jammed → "JAMMED"; empty/not-ready → "EMPTY".
--- Normal state → "current / max + reserve" (reserve omitted when zero).
local function formatAmmoText(state, reserve)
    if state.isJammed then
        return "JAMMED"
    end
    if state.current == 0 and not state.isChambered then
        return "EMPTY"
    end
    local text = tostring(state.current) .. " / " .. tostring(state.max)
    if reserve and reserve > 0 then
        text = text .. " + " .. tostring(reserve)
    end
    return text
end

-- ---------------------------------------------------------------------------
-- Render hook
-- ---------------------------------------------------------------------------

--- Called every render frame. Evaluates whether the local player is aiming a
--- ranged weapon; if so, resolves ammo state and draws a summary near the cursor.
--- All PZ API calls are guarded with pcall. Exits silently on any resolution failure.
function AmmoCounter.OnRenderTick()
    AmmoCounter._frameCount = AmmoCounter._frameCount + 1

    local okPlayer, player = pcall(function()
        return getSpecificPlayer and getSpecificPlayer(0)
    end)
    if not okPlayer or not player then return end

    if not AmmoCounter.isAimingRanged(player) then return end

    local state = AmmoCounter.resolveWeaponState(player)
    if not state then return end

    local reserve = 0
    if state.ammoType then
        reserve = AmmoCounter.getReserve(player, state.ammoType)
    end

    local text = formatAmmoText(state, reserve)

    -- Resolve cursor position; bail out silently if unavailable.
    local okMx, mx = pcall(function() return getMouseX() end)
    local okMy, my = pcall(function() return getMouseY() end)
    if not okMx or not okMy then return end

    local x = mx + AmmoCounter.config.offsetX
    local y = my + AmmoCounter.config.offsetY

    -- Lazy-initialize the cached TextDrawObject (avoids per-frame allocation).
    -- Configure default color once; ReadString uses flag -1 to apply object-state colors.
    if not AmmoCounter._textObj then
        AmmoCounter._textObj = TextDrawObject.new()
        AmmoCounter._textObj:setDefaultColors(1, 1, 1, 0.9)
    end
    -- Queue the ammo text to the render pipeline via the supported batched draw path.
    pcall(function()
        AmmoCounter._textObj:ReadString(UIFont.Small, text, -1)
        AmmoCounter._textObj:AddBatchedDraw(x, y, true)
    end)
end

-- ---------------------------------------------------------------------------
-- Event registration
-- ---------------------------------------------------------------------------

Events.OnRenderTick.Add(AmmoCounter.OnRenderTick)
logDebug("AmmoCounter module loaded")
