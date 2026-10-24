require "dual-back/DualBackPolicy"

ModelusDualBackLocations = ModelusDualBackLocations or {}
local Locations = ModelusDualBackLocations
local Policy = ModelusDualBackPolicy
local hasBackBag = false

local function ensureGroup()
    return AttachedLocations.getGroup("Human")
end

function Locations.register()
    local target = ensureGroup()
    if not target then return false end
    for _, attachmentType in ipairs(Policy.ATTACHMENT_TYPES) do
        target:getOrCreateLocation(Policy.locationId(attachmentType))
    end
    return Locations.setAttachmentNames(hasBackBag)
end

function Locations.setAttachmentNames(bagWorn)
    hasBackBag = bagWorn == true
    local target = ensureGroup()
    if not target then return false end
    local changed = false
    for _, attachmentType in ipairs(Policy.ATTACHMENT_TYPES) do
        local location = target:getOrCreateLocation(Policy.locationId(attachmentType))
        local anchorName = Policy.anchorName(attachmentType, hasBackBag)
        if location:getAttachmentName() ~= anchorName then
            location:setAttachmentName(anchorName)
            changed = true
        end
    end
    return changed
end

Locations.locationIds = Policy.LOCATION_IDS
Locations.register()

return Locations
