local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local function readFile(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

local function findVanillaLuaDir()
    local configured = os.getenv("MODELUS_VANILLA_LUA_DIR")
    if configured then
        assert(readFile(configured .. "/client/Hotbar/ISHotbar.lua"),
            "MODELUS_VANILLA_LUA_DIR is set but ISHotbar.lua was not found there")
        return configured
    end
    local candidates = {
        "/mnt/d/SteamLibrary/steamapps/common/ProjectZomboid/media/lua",
        "/mnt/c/Program Files (x86)/Project Zomboid/media/lua",
        "C:/Program Files (x86)/Project Zomboid/media/lua"
    }
    for _, candidate in ipairs(candidates) do
        if readFile(candidate .. "/client/Hotbar/ISHotbar.lua") then return candidate end
    end
    return nil
end

local luaDir = findVanillaLuaDir()
if not luaDir then
    print("SKIP tests/lua/dual_back_vanilla_hotbar_test.lua (Project Zomboid Lua directory not found)")
    return 0
end

local scriptPath = luaDir:gsub("/media/lua/?$", "/media/scripts/generated/models_characters.txt")
local modelSource = assert(readFile(scriptPath), "models_characters.txt not found beside vanilla Lua directory")

local function blockFor(source, pattern)
    local startAt, openAt = source:find(pattern)
    assert(startAt, "missing model/attachment block " .. pattern)
    openAt = assert(source:find("{", openAt + 1), "missing block opener " .. pattern)
    local depth = 0
    for index = openAt, #source do
        local char = source:sub(index, index)
        if char == "{" then depth = depth + 1 end
        if char == "}" then
            depth = depth - 1
            if depth == 0 then return source:sub(openAt + 1, index - 1) end
        end
    end
    error("unterminated model/attachment block " .. pattern)
end

local function parseVector(block, key)
    local value = assert(block:match(key .. "%s*=%s*([^,]+),"), "missing " .. key .. " in model attachment")
    local x, y, z = value:match("%s*([%+%-%.%d]+)%s+([%+%-%.%d]+)%s+([%+%-%.%d]+)%s*")
    assert(x and y and z, "invalid " .. key .. " vector " .. value)
    return tonumber(x), tonumber(y), tonumber(z)
end

local env = {}
setmetatable(env, { __index = _G })
env._G = env
env.require = function() end
env.UIFont = { Small = 1 }
env.getTextManager = function() return { getFontHeight = function() return 10 end } end
env.Events = {
    OnGameStart = { Add = function() end },
    OnGameBoot = { Add = function() end }
}
env.ISPanelJoypad = {
    derive = function(_, name)
        local class = { __name = name }
        class.__index = class
        return class
    end
}
local testTable = {}
for key, value in pairs(table) do testTable[key] = value end
testTable.wipe = function(value) for key in pairs(value) do value[key] = nil end end
env.table = testTable
env.isClient = function() return false end
env.AttachedLocations = { getGroup = function() return locationsGroup end }

local function loadInto(path)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    setfenv(chunk, env)
    return chunk()
end

local attachDefinitions = loadInto(luaDir .. "/client/Hotbar/ISHotbarAttachDefinition.lua")
loadInto(luaDir .. "/client/Hotbar/ISHotbar.lua")
local nativeHaveThisSlot = env.ISHotbar.haveThisSlot

local policy = loadInto("mods/modelus/common/media/lua/shared/dual-back/DualBackPolicy.lua")
local locationData = {}
locationsGroup = {}
function locationsGroup:getOrCreateLocation(id)
    if not locationData[id] then
        local location = { attachmentName = nil }
        function location:getAttachmentName() return self.attachmentName end
        function location:setAttachmentName(name) self.attachmentName = name end
        locationData[id] = location
    end
    return locationData[id]
end
loadInto("mods/modelus/common/media/lua/shared/dual-back/DualBackLocations.lua")

local function vector(x, y, z)
    local value = { vx = x, vy = y, vz = z }
    function value:x() return self.vx end
    function value:y() return self.vy end
    function value:z() return self.vz end
    function value:set(nx, ny, nz) self.vx, self.vy, self.vz = nx, ny, nz; return self end
    return value
end

local function modelAttachment(id, bone, offset, rotate, scale)
    local value = { id = id, bone = bone, offset = offset, rotate = rotate, scale = scale or 1 }
    function value:getBone() return self.bone end
    function value:setBone(name) self.bone = name end
    function value:getOffset() return self.offset end
    function value:getRotate() return self.rotate end
    function value:getScale() return self.scale end
    function value:setScale(newScale) self.scale = newScale end
    return value
end

local scripts = {}
for _, bodyName in ipairs({ "Base.MaleBody", "Base.FemaleBody" }) do
    local body = bodyName:match("%.(.+)$")
    local modelBlock = blockFor(modelSource, "model%s+" .. body .. "%s*")
    local script = { attachments = {}, fullType = bodyName }
    function script:getAttachmentById(id) return self.attachments[id] end
    function script:addAttachment(value) self.attachments[value.id] = value; return value end
    function script:getFullType() return self.fullType end
    for _, attachmentType in ipairs(policy.ATTACHMENT_TYPES) do
        local sources = policy.SOURCE_ANCHORS[attachmentType]
        for _, variant in ipairs({ "normal", "bag" }) do
            local sourceId = sources[variant]
            if not script.attachments[sourceId] then
                local attachmentBlock = blockFor(modelBlock, "attachment%s+" .. sourceId .. "%s*")
                local x, y, z = parseVector(attachmentBlock, "offset")
                local rx, ry, rz = parseVector(attachmentBlock, "rotate")
                local bone = assert(attachmentBlock:match("bone%s*=%s*([^,]+),"), "missing attachment bone")
                script.attachments[sourceId] = modelAttachment(sourceId, bone:match("%S+"),
                    vector(x, y, z), vector(rx, ry, rz))
            end
        end
    end
    scripts[bodyName] = script
end
env.ModelAttachment = { new = function(id) return modelAttachment(id, nil, vector(0, 0, 0), vector(0, 0, 0)) end }
env.getScriptManager = function()
    return { getModelScript = function(_, fullType) return scripts[fullType] end }
end

loadInto("mods/modelus/common/media/lua/client/dual-back/DualBackModels.lua")
loadInto("mods/modelus/common/media/lua/client/dual-back/DualBack.lua")
local policy = env.ModelusDualBackPolicy
local locations = env.ModelusDualBackLocations

local function javaList(items)
    return {
        size = function() return #items end,
        get = function(_, index) return items[index + 1] end,
        getItemByIndex = function(_, index) return items[index + 1] end
    }
end

local function makeItem(attachmentType, slotIndex, slotType, modelId)
    local item = {
        attachmentType = attachmentType, slotIndex = slotIndex or -1,
        slotType = slotType, modelId = modelId, broken = false
    }
    function item:getAttachmentType() return self.attachmentType end
    function item:getAttachedSlot() return self.slotIndex end
    function item:setAttachedSlot(value) self.slotIndex = value end
    function item:getAttachedSlotType() return self.slotType end
    function item:setAttachedSlotType(value) self.slotType = value end
    function item:getAttachedToModel() return self.modelId end
    function item:setAttachedToModel(value) self.modelId = value end
    function item:getAttachmentReplacement() return nil end
    function item:getAttachmentsProvided() return nil end
    function item:getTexture() return nil end
    function item:isBroken() return self.broken end
    return item
end

local function makeCharacter(inventoryItems, wornItems, handItems)
    local attached = {}
    local modData = { hotbar = { [1] = "Back", [2] = "SmallBeltLeft", [3] = "SmallBeltRight" } }
    local inventory = {
        getItems = function() return javaList(inventoryItems) end,
        contains = function(_, item)
            for _, candidate in ipairs(inventoryItems) do if candidate == item then return true end end
            return false
        end
    }
    local character = { attached = attached, modData = modData, wornItems = wornItems or {}, handItems = handItems or {}, inventory = inventory }
    function character:getModData() return self.modData end
    function character:transmitModData() self.transmitted = true end
    function character:getInventory() return self.inventory end
    function character:getWornItems() return javaList(self.wornItems) end
    function character:isHandItem(item) return self.handItems[item] == true end
    function character:setAttachedItem(locationId, item) self.attached[locationId] = item end
    function character:removeAttachedItem(item)
        for locationId, attachedItem in pairs(self.attached) do
            if attachedItem == item then self.attached[locationId] = nil end
        end
    end
    function character:resetModelNextFrame() self.resetCount = (self.resetCount or 0) + 1 end
    function character:SetVariable() end
    return character
end

local function makeHotbar(character, saved)
    if saved then character.modData.hotbar = saved end
    local hotbar = setmetatable({
        chr = character, character = character, availableSlot = {}, attachedItems = {},
        slotWidth = 60, slotHeight = 60, slotPad = 2, margins = 2,
        setWidth = function(self, value) self.width = value end
    }, env.ISHotbar)
    hotbar:loadPosition()
    return hotbar
end

local function slotTypes(hotbar)
    local result = {}
    for index, slot in pairs(hotbar.availableSlot) do result[index] = slot.slotType end
    return result
end

local legacyCharacter = makeCharacter({}, {}, {})
local legacyHotbar = makeHotbar(legacyCharacter)
local legacyTypes = slotTypes(legacyHotbar)
expect(legacyTypes[1] == "Back" and legacyTypes[2] == "SmallBeltLeft"
    and legacyTypes[3] == "SmallBeltRight" and legacyTypes[4] == "ModelusBack2",
    "real loadPosition preserves old slot indices and appends Back 2")
expect(legacyCharacter.modData.hotbar[4] == "ModelusBack2", "real savePosition persists appended slot")
local roundtrip = makeHotbar(legacyCharacter)
expect(roundtrip.availableSlot[4].slotType == "ModelusBack2" and roundtrip.availableSlot[5] == nil,
    "real loadPosition restores Back 2 without duplication")

local function testRefresh(hasBag, useNativePrune, bagInHand)
    local first = makeItem("Rifle", 1, "Back", "Rifle On Back")
    local second = makeItem("Rifle", 2, "ModelusBack2", "ModelusBack2Rifle")
    local bag = {
        getAttachmentReplacement = function() return "Bag" end,
        getAttachmentsProvided = function() return nil end
    }
    local worn = hasBag and { bag } or {}
    local character = makeCharacter({ first, second }, worn, bagInHand and { [bag] = true } or {})
    local hotbar = makeHotbar(character, { [1] = "Back", [2] = "ModelusBack2" })
    hotbar.attachedItems = { [1] = first, [2] = second }
    if useNativePrune then hotbar.haveThisSlot = nativeHaveThisSlot end
    hotbar:refresh()
    return character, hotbar, first, second, bag
end

local character, hotbar, first, second = testRefresh(false, false)
expect(hotbar:getThisSlotIndex("ModelusBack2") ~= nil, "real refresh retains Back 2 through membership wrapper")
expect(character.attached.ModelusBack2Rifle == second and character.attached["Rifle On Back"] == first,
    "real refresh attaches equal-type rifles to distinct attachment locations")
expect(second.slotIndex == 2 and second.slotType == "ModelusBack2", "real attachItem preserves Back 2 item identity")
expect(character.attached[first.modelId] == first and first.modelId ~= second.modelId, "both equal-type items remain attached")
expect(locations.locationIds.Rifle == "ModelusBack2Rifle", "second rifle uses its stable custom location")

local bagCharacter, bagHotbar, bagFirst, bagSecond = testRefresh(true, false)
expect(bagCharacter.attached["Rifle On Back with Bag"] == bagFirst, "vanilla Back uses its bag replacement")
expect(bagCharacter.attached.ModelusBack2Rifle == bagSecond, "Back 2 keeps its unique location with a bag")
expect(locationsGroup:getOrCreateLocation(locations.locationIds.Rifle):getAttachmentName()
    == policy.anchorName("Rifle", true), "worn bag switches Back 2 to its bag anchor")

bagCharacter.wornItems = {}
bagHotbar:refresh()
expect(bagCharacter.attached["Rifle On Back"] == bagFirst
    and bagCharacter.attached.ModelusBack2Rifle == bagSecond, "real refresh toggles both items back to no-bag locations")
expect(locationsGroup:getOrCreateLocation(locations.locationIds.Rifle):getAttachmentName()
    == policy.anchorName("Rifle", false), "removing worn bag restores Back 2 normal anchor")

local noBagCharacter, _, noBagFirst, noBagSecond = testRefresh(false, false)
expect(noBagCharacter.attached["Rifle On Back"] == noBagFirst
    and noBagCharacter.attached.ModelusBack2Rifle == noBagSecond, "removing bag restores both normal locations")
expect(locationsGroup:getOrCreateLocation(locations.locationIds.Rifle):getAttachmentName()
    == policy.anchorName("Rifle", false), "removing bag restores Back 2 normal anchor")

local heldBagCharacter = testRefresh(true, false, true)
expect(heldBagCharacter.attached["Rifle On Back"] ~= nil,
    "vanilla ignores replacement from a bag held in the hand")
expect(locationsGroup:getOrCreateLocation(locations.locationIds.Rifle):getAttachmentName()
    == policy.anchorName("Rifle", false), "Modelus ignores a bag held in the hand")

local canaryCharacter, canaryHotbar = testRefresh(false, true)
expect(canaryHotbar:getThisSlotIndex("ModelusBack2") == nil, "native membership canary prunes Back 2 without Modelus wrapper")
expect(canaryCharacter.attached.ModelusBack2Rifle == nil, "native prune canary detaches Back 2 item")
expect(next(canaryCharacter.attached) ~= nil, "canary preserves vanilla Back attachment")

local models = env.ModelusDualBackModels
for _, bodyName in ipairs({ "Base.MaleBody", "Base.FemaleBody" }) do
    for _, attachmentType in ipairs(policy.ATTACHMENT_TYPES) do
        for _, variant in ipairs({ "normal", "bag" }) do
            local source = scripts[bodyName]:getAttachmentById(policy.SOURCE_ANCHORS[attachmentType][variant])
            local target = scripts[bodyName]:getAttachmentById(policy.ANCHOR_IDS[attachmentType][variant])
            expect(target:getOffset():x() == source:getOffset():x()
                and target:getOffset():y() == source:getOffset():y() - policy.LATERAL_OFFSET
                and target:getOffset():z() == source:getOffset():z(), "real model source transformed on outward Y")
        end
    end
end

return assertions
