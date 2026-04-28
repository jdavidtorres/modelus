-- CasualReloading.lua
-- Makes magazine-fed ranged weapons reload in a casual way by disabling their
-- magazine requirement on the equipped item instance and enabling bulk bullet
-- insertion.
-- Hook: OnGameStart + additive wrap of ISEquipWeaponAction.new.
-- Scope: client only.

local _LOG_PREFIX = "[Modelus][CasualReloading]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

CasualReloading = CasualReloading or {}

local function isSupportedWeapon(item)
    return item
        and item.IsWeapon
        and item:IsWeapon()
        and item.isRanged
        and item:isRanged()
        and item.getMagazineType
        and item:getMagazineType() ~= nil
end

function CasualReloading.applyToWeapon(item)
    if not isSupportedWeapon(item) then
        return
    end

    item:setMagazineType(nil)
    item:setInsertAllBulletsReload(true)

    logDebug("casual reload enabled for " .. tostring(item:getType()))
end

local function onGameStart()
    local playerObj = getPlayer()
    if not playerObj then
        return
    end

    CasualReloading.applyToWeapon(playerObj:getPrimaryHandItem())
    CasualReloading.applyToWeapon(playerObj:getSecondaryHandItem())
end

local _originalEquipWeaponActionNew = ISEquipWeaponAction.new

function ISEquipWeaponAction:new(character, item, time, primary, twoHands)
    local action = _originalEquipWeaponActionNew(self, character, item, time, primary, twoHands)
    CasualReloading.applyToWeapon(item)
    return action
end

Events.OnGameStart.Add(onGameStart)
