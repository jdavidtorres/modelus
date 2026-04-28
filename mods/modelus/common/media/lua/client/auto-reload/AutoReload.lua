-- AutoReload.lua
-- Chains unload/reload timed actions on a reloadable firearm or magazine to
-- train the player's Reloading skill.  Stops when ammo is exhausted, the
-- player reaches max Reloading level, or any external event interrupts the
-- action queue.
-- Hook: additive monkey-patches on ISInventoryPaneContextMenu and ISTimedAction
--       lifecycle methods.
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
AutoReload.OPTIONS = AutoReload.OPTIONS or {}
AutoReload.OPTIONS.MaxReloadingLevel = AutoReload.OPTIONS.MaxReloadingLevel or 10

-- Single session flag — true while a self-chaining loop is in flight.
AutoReload.actionStarted = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Reserved hook: return false here to exclude specific modded firearms.
function AutoReload.isFirearmManaged(--[[weapon]])
    return true
end

--- Reserved hook: return false here to exclude specific modded magazines.
function AutoReload.isMagazineManaged(--[[magazine]])
    return true
end

--- Guard: true when it is safe to queue the next iteration.
local function canTrain(player)
    if player:getPerkLevel(Perks.Reloading) >= AutoReload.OPTIONS.MaxReloadingLevel then
        logDebug("canTrain: Reloading skill at max — stopping")
        return false
    end
    if player:isStrafing() or player:isAttacking() then
        logDebug("canTrain: player is strafing/attacking — aborting iteration")
        return false
    end
    return true
end

--- Equip the weapon into the primary hand if it is not already equipped there.
local function ensureWeaponEquipped(player, weapon)
    if not player:isEquipped(weapon) then
        logDebug("ensureWeaponEquipped: equipping " .. tostring(weapon:getType()))
        ISInventoryPaneContextMenu.equipWeapon(weapon, true, false, player:getPlayerNum())
    end
end

--- Transfer matching ammo from any sub-inventory into the player's main inventory
--- so that the reload action can find it.
local function ensureAmmoInMainInventory(player, item)
    ISInventoryPaneContextMenu.transferBullets(
        player,
        item:getAmmoType(),
        item:getCurrentAmmoCount(),
        item:getMaxAmmo()
    )
end

--- Return the first stack of ammo matching `ammoType` anywhere on the player.
local function getAmmoItem(player, ammoType)
    return player:getInventory():getFirstTypeRecurse(ammoType)
end

-- ---------------------------------------------------------------------------
-- Stop
-- ---------------------------------------------------------------------------

--- Clear the session flag.  Called by cleanup patches and internally when the
--- loop detects no further work is possible.
function AutoReload.stop()
    if not AutoReload.actionStarted then
        logDebug("stop: called while not started — ignoring")
        return
    end
    logDebug("stop: clearing session flag")
    AutoReload.actionStarted = false
end

-- ---------------------------------------------------------------------------
-- Loop entry points
-- ---------------------------------------------------------------------------

--- Queue the next unload or reload action for a direct-ammo firearm.
--- Re-entered from the patched perform() hooks to create the self-chaining loop.
function AutoReload.trainFirearm(player, weapon)
    if not player or not weapon then
        logDebug("trainFirearm: nil player or weapon — aborting")
        if AutoReload.actionStarted then AutoReload.stop() end
        return
    end

    logDebug("trainFirearm: player=" .. tostring(player) .. " weapon=" .. tostring(weapon:getType()))

    if not canTrain(player) then
        if AutoReload.actionStarted then AutoReload.stop() end
        return
    end

    local ammoType = weapon:getAmmoType()
    if not ammoType then
        logDebug("trainFirearm: weapon has no direct ammo type — aborting")
        if AutoReload.actionStarted then AutoReload.stop() end
        return
    end

    local queued = false

    if weapon:getCurrentAmmoCount() > 0 then
        -- Weapon has rounds loaded — unload first to generate XP.
        ensureWeaponEquipped(player, weapon)
        logDebug("trainFirearm: queuing ISUnloadBulletsFromFirearm")
        ISTimedActionQueue.add(ISUnloadBulletsFromFirearm:new(player, weapon))
        queued = true
    else
        -- Weapon is empty — attempt to reload.
        local ammoItem = getAmmoItem(player, ammoType)
        if ammoItem then
            ensureAmmoInMainInventory(player, weapon)
            ensureWeaponEquipped(player, weapon)
            logDebug("trainFirearm: queuing ISReloadWeaponAction")
            ISTimedActionQueue.add(ISReloadWeaponAction:new(player, weapon))
            queued = true
        else
            logDebug("trainFirearm: no ammo available — stopping loop")
        end
    end

    if queued and not AutoReload.actionStarted then
        logDebug("trainFirearm: session started")
        AutoReload.actionStarted = true
    elseif not queued and AutoReload.actionStarted then
        AutoReload.stop()
    end
end

--- Queue the next unload or load action for a magazine item.
function AutoReload.trainMagazine(player, magazine)
    if not player or not magazine then
        logDebug("trainMagazine: nil player or magazine — aborting")
        if AutoReload.actionStarted then AutoReload.stop() end
        return
    end

    logDebug("trainMagazine: magazine=" .. tostring(magazine:getType()))

    if not canTrain(player) then
        if AutoReload.actionStarted then AutoReload.stop() end
        return
    end

    local ammoType = magazine:getAmmoType()
    if not ammoType then
        logDebug("trainMagazine: magazine has no ammo type — aborting")
        if AutoReload.actionStarted then AutoReload.stop() end
        return
    end

    local queued = false

    if magazine:getCurrentAmmoCount() > 0 then
        -- Magazine has rounds — unload to generate XP.
        logDebug("trainMagazine: queuing ISUnloadBulletsFromMagazine")
        ISTimedActionQueue.add(ISUnloadBulletsFromMagazine:new(player, magazine))
        queued = true
    else
        local ammoItem = getAmmoItem(player, ammoType)
        if ammoItem then
            logDebug("trainMagazine: queuing ISLoadBulletsInMagazine")
            ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(player, magazine))
            queued = true
        else
            logDebug("trainMagazine: no ammo available — stopping loop")
        end
    end

    if queued and not AutoReload.actionStarted then
        logDebug("trainMagazine: session started")
        AutoReload.actionStarted = true
    elseif not queued and AutoReload.actionStarted then
        AutoReload.stop()
    end
end

-- ---------------------------------------------------------------------------
-- Context-menu patches
-- ---------------------------------------------------------------------------

-- Firearm direct-ammo menu (doBulletMenu)
local _genuineDoBulletMenu = ISInventoryPaneContextMenu.doBulletMenu
ISInventoryPaneContextMenu.doBulletMenu = function(playerObj, weapon, context)
    _genuineDoBulletMenu(playerObj, weapon, context)

    -- Guard: below max level, weapon is managed, weapon uses direct ammo.
    if playerObj:getPerkLevel(Perks.Reloading) >= AutoReload.OPTIONS.MaxReloadingLevel then return end
    if not AutoReload.isFirearmManaged(weapon) then return end
    local ammoType = weapon:getAmmoType()
    if not ammoType then return end

    local option = context:addOption(
        getText("ContextMenu_AutoReload"),
        playerObj,
        AutoReload.trainFirearm,
        weapon
    )

    -- Grey out when there is nothing to unload and nothing to reload.
    if weapon:getCurrentAmmoCount() == 0 and
       not getAmmoItem(playerObj, ammoType) then
        option.notAvailable = true
    end

    logDebug("doBulletMenu: option added for " .. tostring(weapon:getType()))
end

-- Magazine menu (doMagazineMenu) — may not exist in all B42 builds.
if ISInventoryPaneContextMenu.doMagazineMenu then
    local _genuineDoMagazineMenu = ISInventoryPaneContextMenu.doMagazineMenu
    ISInventoryPaneContextMenu.doMagazineMenu = function(playerObj, magazine, context)
        _genuineDoMagazineMenu(playerObj, magazine, context)

        if playerObj:getPerkLevel(Perks.Reloading) >= AutoReload.OPTIONS.MaxReloadingLevel then return end
        if not AutoReload.isMagazineManaged(magazine) then return end
        local ammoType = magazine:getAmmoType()
        if not ammoType then return end

        local option = context:addOption(
            getText("ContextMenu_AutoReload"),
            playerObj,
            AutoReload.trainMagazine,
            magazine
        )

        if magazine:getCurrentAmmoCount() == 0 and
           not getAmmoItem(playerObj, ammoType) then
            option.notAvailable = true
        end

        logDebug("doMagazineMenu: option added for " .. tostring(magazine:getType()))
    end
end

-- ---------------------------------------------------------------------------
-- Action lifecycle patches — perform() chains the loop; stop() cleans up.
-- Each block is pcall-guarded so a missing action class fails gracefully.
-- ---------------------------------------------------------------------------

-- ISUnloadBulletsFromFirearm
if ISUnloadBulletsFromFirearm then
    local _genuineUnloadFirearmStop = ISUnloadBulletsFromFirearm.stop
    function ISUnloadBulletsFromFirearm:stop()
        _genuineUnloadFirearmStop(self)
        if AutoReload.actionStarted then
            logDebug("ISUnloadBulletsFromFirearm:stop → AutoReload.stop")
            AutoReload.stop()
        end
    end

    local _genuineUnloadFirearmPerform = ISUnloadBulletsFromFirearm.perform
    function ISUnloadBulletsFromFirearm:perform()
        _genuineUnloadFirearmPerform(self)
        if AutoReload.actionStarted then
            logDebug("ISUnloadBulletsFromFirearm:perform → trainFirearm")
            AutoReload.trainFirearm(self.character, self.gun)
        end
    end
end

-- ISReloadWeaponAction
if ISReloadWeaponAction then
    local _genuineReloadStop = ISReloadWeaponAction.stop
    function ISReloadWeaponAction:stop()
        _genuineReloadStop(self)
        if AutoReload.actionStarted then
            logDebug("ISReloadWeaponAction:stop → AutoReload.stop")
            AutoReload.stop()
        end
    end

    local _genuineReloadPerform = ISReloadWeaponAction.perform
    function ISReloadWeaponAction:perform()
        _genuineReloadPerform(self)
        if AutoReload.actionStarted then
            logDebug("ISReloadWeaponAction:perform → trainFirearm")
            AutoReload.trainFirearm(self.character, self.gun)
        end
    end
end

-- ISUnloadBulletsFromMagazine
if ISUnloadBulletsFromMagazine then
    local _genuineUnloadMagStop = ISUnloadBulletsFromMagazine.stop
    function ISUnloadBulletsFromMagazine:stop()
        _genuineUnloadMagStop(self)
        if AutoReload.actionStarted then
            logDebug("ISUnloadBulletsFromMagazine:stop → AutoReload.stop")
            AutoReload.stop()
        end
    end

    local _genuineUnloadMagPerform = ISUnloadBulletsFromMagazine.perform
    function ISUnloadBulletsFromMagazine:perform()
        _genuineUnloadMagPerform(self)
        if AutoReload.actionStarted then
            logDebug("ISUnloadBulletsFromMagazine:perform → trainMagazine")
            AutoReload.trainMagazine(self.character, self.magazine)
        end
    end
end

-- ISLoadBulletsInMagazine
if ISLoadBulletsInMagazine then
    local _genuineLoadMagStop = ISLoadBulletsInMagazine.stop
    function ISLoadBulletsInMagazine:stop()
        _genuineLoadMagStop(self)
        if AutoReload.actionStarted then
            logDebug("ISLoadBulletsInMagazine:stop → AutoReload.stop")
            AutoReload.stop()
        end
    end

    local _genuineLoadMagPerform = ISLoadBulletsInMagazine.perform
    function ISLoadBulletsInMagazine:perform()
        _genuineLoadMagPerform(self)
        if AutoReload.actionStarted then
            logDebug("ISLoadBulletsInMagazine:perform → trainMagazine")
            AutoReload.trainMagazine(self.character, self.magazine)
        end
    end
end

-- ---------------------------------------------------------------------------
-- ISTimedActionQueue:clearQueue — ensure session flag is cleared on any flush.
-- ---------------------------------------------------------------------------

local _genuineClearQueue = ISTimedActionQueue.clearQueue
function ISTimedActionQueue:clearQueue()
    _genuineClearQueue(self)
    if AutoReload.actionStarted then
        logDebug("ISTimedActionQueue:clearQueue → AutoReload.stop")
        AutoReload.stop()
    end
end
