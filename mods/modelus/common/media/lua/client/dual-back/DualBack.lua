require "Hotbar/ISHotbar"
require "Hotbar/ISHotbarAttachDefinition"
require "dual-back/DualBackPolicy"
require "dual-back/DualBackLocations"
require "dual-back/DualBackModels"

ModelusDualBack = ModelusDualBack or {}
local DualBack = ModelusDualBack
local Policy = ModelusDualBackPolicy
local installedKey = "_modelusDualBackInstalled"
local definition

function DualBack.ensureSlotDefinition()
    for _, existing in ipairs(ISHotbarAttachDefinition) do
        if existing.type == Policy.SLOT_TYPE then
            definition = existing
            return existing
        end
    end
    definition = Policy.buildSlotDefinition()
    ISHotbarAttachDefinition[#ISHotbarAttachDefinition + 1] = definition
    return definition
end

local function maximumNumericIndex(list)
    local maximum = 0
    for index in pairs(list) do
        if type(index) == "number" and index > maximum and index == math.floor(index) then
            maximum = index
        end
    end
    return maximum
end

function DualBack.ensureSlotPresent(hotbar)
    local slotIndex = hotbar:getThisSlotIndex(Policy.SLOT_TYPE)
    if slotIndex then return false end
    local slotDef = DualBack.ensureSlotDefinition()
    hotbar.availableSlot[maximumNumericIndex(hotbar.availableSlot) + 1] = {
        slotType = Policy.SLOT_TYPE,
        name = Policy.SLOT_NAME,
        def = slotDef
    }
    hotbar:savePosition()
    return true
end

local function hasBackBag(character)
    local wornItems = character:getWornItems()
    for index = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(index)
        if item and not character:isHandItem(item)
                and item:getAttachmentReplacement() == "Bag" then
            return true
        end
    end
    return false
end

function DualBack.syncAttachmentNames(character)
    local changed = ModelusDualBackLocations.setAttachmentNames(hasBackBag(character))
    if changed then character:resetModelNextFrame() end
    return changed
end

function DualBack.ensureVisuals(character)
    if not character then return false end
    local locationsChanged = ModelusDualBackLocations.register()
    local modelsCreated = ModelusDualBackModels.register()
    locationsChanged = ModelusDualBackLocations.setAttachmentNames(hasBackBag(character)) or locationsChanged
    local changed = modelsCreated or locationsChanged
    if changed then character:resetModelNextFrame() end
    return changed
end

function DualBack.install()
    if ISHotbar[installedKey] then return false end
    ISHotbar[installedKey] = true
    DualBack.ensureSlotDefinition()

    local originalLoadPosition = ISHotbar.loadPosition
    ISHotbar.loadPosition = function(self, ...)
        DualBack.ensureSlotDefinition()
        DualBack.ensureVisuals(self.chr)
        local result = originalLoadPosition(self, ...)
        DualBack.ensureSlotPresent(self)
        return result
    end

    local originalHaveThisSlot = ISHotbar.haveThisSlot
    ISHotbar.haveThisSlot = function(self, slotType, list, ...)
        if slotType == Policy.SLOT_TYPE and list ~= nil then return true end
        return originalHaveThisSlot(self, slotType, list, ...)
    end

    local originalRefresh = ISHotbar.refresh
    ISHotbar.refresh = function(self, ...)
        DualBack.ensureVisuals(self.chr)
        local result = originalRefresh(self, ...)
        return result
    end
    return true
end

DualBack.install()

if not ISHotbar._modelusDualBackEventsInstalled then
    ISHotbar._modelusDualBackEventsInstalled = true
    Events.OnGameBoot.Add(function()
        ModelusDualBackLocations.register()
        ModelusDualBackModels.register()
    end)
    Events.OnGameStart.Add(function()
        local character = getSpecificPlayer(0)
        if character then DualBack.ensureVisuals(character) end
    end)
end

return DualBack
