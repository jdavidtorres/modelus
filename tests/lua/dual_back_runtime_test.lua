local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local policy = {
    SLOT_TYPE = "ModelusBack2", SLOT_NAME = "Back 2",
    buildSlotDefinition = function()
        return { type = "ModelusBack2", name = "Back 2", attachments = { Rifle = "ModelusBack2Rifle" } }
    end
}
local attachments = { { type = "Back", name = "Back", attachments = { Rifle = "Rifle On Back" } } }
local Hotbar = {}
function Hotbar:getThisSlotIndex(slotType)
    for index, slot in pairs(self.availableSlot) do if slot.slotType == slotType then return index end end
end
function Hotbar:savePosition() self.saved = {}; for i, slot in pairs(self.availableSlot) do self.saved[i] = slot.slotType end end
function Hotbar:loadPosition()
    self.availableSlot = {
        { slotType = "Back", name = "Back" },
        { slotType = "SmallBeltLeft", name = "Left" },
        { slotType = "SmallBeltRight", name = "Right" }
    }
end
function Hotbar:haveThisSlot(slotType, list)
    for _, slot in pairs(list or self.availableSlot) do if slot.slotType == slotType then return true end end
    return false
end
function Hotbar:refresh() self.originalRefresh = true end
local boneChanged = false
local currentBagState = false
local locations = { setAttachmentNames = function(hasBag)
    local changed = boneChanged or currentBagState ~= hasBag
    boneChanged = false
    currentBagState = hasBag
    return changed
end }
function locations.register() return false end
local models = { register = function() return false end }
local character = { resets = 0, worn = {} }
function character:getWornItems()
    return { size = function() return #self.worn end, getItemByIndex = function(_, index) return self.worn[index + 1] end }
end
function character:isHandItem(item) return item.inHand == true end
function character:wornItemsForTest(items) self.worn = items end
function character:resetModelNextFrame() self.resets = self.resets + 1 end
local callbacks = { OnGameBoot = {}, OnGameStart = {} }
for _, event in pairs(callbacks) do function event.Add(callback) event[#event + 1] = callback end end
local env = {
    require = function() end,
    ModelusDualBackPolicy = policy,
    ModelusDualBackLocations = locations,
    ModelusDualBackModels = models,
    ISHotbar = Hotbar,
    ISHotbarAttachDefinition = attachments,
    Events = callbacks,
    getSpecificPlayer = function() return nil end,
    ipairs = ipairs, pairs = pairs, type = type, math = math,
    print = function() end
}
setmetatable(env, { __index = _G })
local chunk = assert(loadfile("mods/modelus/common/media/lua/client/dual-back/DualBack.lua"))
setfenv(chunk, env)
local module = chunk()
expect(#attachments == 2 and attachments[2].type == "ModelusBack2", "slot definition registered once")
local hotbar = { availableSlot = {}, chr = character }
setmetatable(hotbar, { __index = Hotbar })
hotbar:loadPosition()
expect(hotbar.availableSlot[1].slotType == "Back" and hotbar.availableSlot[2].slotType == "SmallBeltLeft"
    and hotbar.availableSlot[3].slotType == "SmallBeltRight", "existing saved indices unchanged")
expect(hotbar.availableSlot[4].slotType == "ModelusBack2" and hotbar.saved[4] == "ModelusBack2", "new slot appended and persisted")
hotbar:loadPosition()
expect(hotbar.availableSlot[4].slotType == "ModelusBack2" and hotbar.availableSlot[5] == nil, "reload does not duplicate slot")
expect(hotbar:haveThisSlot("ModelusBack2", {}), "custom slot survives refresh pruning")
expect(not hotbar:haveThisSlot("SmallBeltLeft", {}), "other types retain native check")
hotbar:refresh()
expect(hotbar.originalRefresh, "native refresh still called")
boneChanged = true
module.syncAttachmentNames(character)
expect(character.resets == 1, "model reset on changed attachment mapping")
local bag = { getAttachmentReplacement = function() return "Bag" end }
character:wornItemsForTest({ bag })
expect(module.ensureVisuals(character), "worn bag mapping change requests visuals refresh")
expect(character.resets == 2, "worn bag mapping resets model once")
local handBag = { inHand = true, getAttachmentReplacement = function() return "Bag" end }
character:wornItemsForTest({ handBag })
expect(module.ensureVisuals(character), "bag held in hand restores no-bag anchors")
expect(not module.ensureVisuals(character), "held bag does not trigger repeated anchor changes")
expect(#callbacks.OnGameBoot == 1 and #callbacks.OnGameStart == 1, "visual lifecycle callbacks registered once")
local repeatedChunk = assert(loadfile("mods/modelus/common/media/lua/client/dual-back/DualBack.lua"))
setfenv(repeatedChunk, env)
repeatedChunk()
expect(#attachments == 2 and #callbacks.OnGameBoot == 1 and #callbacks.OnGameStart == 1,
    "reloading module does not duplicate definition, wrappers or lifecycle callbacks")
return assertions
