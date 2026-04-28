-- FreeHotwiring.lua
-- Temporarily grants the Burglar trait while the player is seated as driver in
-- a valid vehicle, so the vanilla hotwire radial option becomes available for
-- everyone. The temporary trait is removed when no longer needed.
-- Hook: additive patch on ISVehicleMenu.showRadialMenu + cleanup events.
-- Scope: client only.

local _LOG_PREFIX = "[Modelus][FreeHotwiring]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

FreeHotwiring = FreeHotwiring or {}
FreeHotwiring.MOD_DATA_KEY = "modelusFreeHotwiringTempBurglar"

local function hasVehicleKey(playerObj, vehicle)
    return playerObj:getInventory():haveThisKeyId(vehicle:getKeyId())
end

local function canOfferHotwire(playerObj, vehicle)
    if not playerObj or not vehicle then return false end
    if not vehicle:isDriver(playerObj) then return false end
    if vehicle:isHotwired() or vehicle:isEngineRunning() then return false end
    if vehicle:isKeysInIgnition() then return false end
    if hasVehicleKey(playerObj, vehicle) then return false end
    return true
end

local function hasBurglarTrait(playerObj)
    return playerObj:getTraits():contains("Burglar")
end

function FreeHotwiring.grantTempTrait(playerObj)
    if hasBurglarTrait(playerObj) then
        return
    end

    playerObj:getTraits():add("Burglar")
    playerObj:getModData()[FreeHotwiring.MOD_DATA_KEY] = true
    SyncXp(playerObj)
    logDebug("temporary Burglar trait granted")
end

function FreeHotwiring.removeTempTrait(playerObj)
    if not playerObj or not playerObj:getModData()[FreeHotwiring.MOD_DATA_KEY] then
        return
    end

    local profession = playerObj:getDescriptor() and playerObj:getDescriptor():getProfession()
    if profession ~= "burglar" and hasBurglarTrait(playerObj) then
        playerObj:getTraits():remove("Burglar")
        SyncXp(playerObj)
        logDebug("temporary Burglar trait removed")
    end

    playerObj:getModData()[FreeHotwiring.MOD_DATA_KEY] = nil
end

local genuineShowRadialMenu = ISVehicleMenu.showRadialMenu

function ISVehicleMenu.showRadialMenu(playerObj)
    genuineShowRadialMenu(playerObj)

    local vehicle = playerObj and playerObj:getVehicle()
    if not canOfferHotwire(playerObj, vehicle) then
        return
    end

    local radialMenu = getPlayerRadialMenu(playerObj:getPlayerNum())
    local hotwireText = getText("ContextMenu_VehicleHotwire")

    if radialMenu and radialMenu.slices then
        for _, slice in ipairs(radialMenu.slices) do
            if slice.text == hotwireText then
                return
            end
        end
    end

    FreeHotwiring.grantTempTrait(playerObj)
    genuineShowRadialMenu(playerObj)
end

local function onExitVehicle(playerObj)
    FreeHotwiring.removeTempTrait(playerObj)
end

local function onGameStart()
    local playerObj = getPlayer()
    if playerObj then
        FreeHotwiring.removeTempTrait(playerObj)
    end
end

Events.OnExitVehicle.Add(onExitVehicle)
Events.OnGameStart.Add(onGameStart)
