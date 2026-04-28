-- AutoReload.lua
-- Automatically reloads the player's equipped weapon when its ammo count
-- reaches zero.  Ammo is searched recursively across all sub-containers in
-- the player's inventory.  No user interaction is required.
-- Hook: OnPlayerUpdate event (polling) + guard against re-entry via flag.
-- Scope: client only.

local _LOG_PREFIX = "[Modelus][AutoReload]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

-- ---------------------------------------------------------------------------
-- Module table
-- ---------------------------------------------------------------------------

AutoReload = AutoReload or {}

-- True while a reload action queued by this module is in flight.
AutoReload.reloading = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Return the first stack of ammo matching `ammoType` anywhere on the player,
--- including all bags and sub-containers (recursive search).
local function getAmmoItem(player, ammoType)
    return player:getInventory():getFirstTypeRecurse(ammoType)
end

--- True when the action queue is empty and the player is not performing
--- any action (safe to enqueue a new timed action).
local function isQueueIdle(player)
    return ISTimedActionQueue.isQueued(player, nil) == false
       and not player:getTimedActionQueue():isEmpty() == false
end

-- ---------------------------------------------------------------------------
-- Core trigger
-- ---------------------------------------------------------------------------

--- Called each update tick.  Detects an equipped weapon with 0 ammo and
--- queues ISReloadWeaponAction once.  Clears the flag when the weapon is
--- no longer empty.
local function onPlayerUpdate(player)
    -- Only handle the local player (splitscreen: player num 0).
    if player:getPlayerNum() ~= 0 then return end

    local weapon = player:getPrimaryHandItem()

    -- Weapon must exist, be a firearm, and accept direct ammo (not mag-only).
    if not weapon then
        AutoReload.reloading = false
        return
    end

    local ammoType = weapon:getAmmoType()
    if not ammoType then
        AutoReload.reloading = false
        return
    end

    local currentAmmo = weapon:getCurrentAmmoCount()

    -- If weapon is loaded again, clear flag so next empty will trigger again.
    if currentAmmo > 0 then
        AutoReload.reloading = false
        return
    end

    -- Weapon is empty — skip if we already queued a reload.
    if AutoReload.reloading then return end

    -- Skip if action queue is busy (player doing something else).
    if not player:getTimedActionQueue():isEmpty() then
        logDebug("onPlayerUpdate: queue busy — skipping")
        return
    end

    -- Skip if player is in combat stance actions.
    if player:isAttacking() or player:isStrafing() then
        logDebug("onPlayerUpdate: player attacking/strafing — skipping")
        return
    end

    -- Search for ammo recursively across entire inventory.
    local ammoItem = getAmmoItem(player, ammoType)
    if not ammoItem then
        logDebug("onPlayerUpdate: weapon empty, no ammo found anywhere — doing nothing")
        return
    end

    logDebug("onPlayerUpdate: weapon empty, ammo found — queuing ISReloadWeaponAction")
    AutoReload.reloading = true
    ISTimedActionQueue.add(ISReloadWeaponAction:new(player, weapon))
end

-- ---------------------------------------------------------------------------
-- Event registration
-- ---------------------------------------------------------------------------

Events.OnPlayerUpdate.Add(onPlayerUpdate)
