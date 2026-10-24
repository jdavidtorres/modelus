local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local function list(values)
    return {
        size = function() return #values end,
        get = function(_, index) return values[index + 1] end
    }
end
local events = {}
events.OnFillInventoryObjectContextMenu = {
    Add = function(fn) events.OnFillInventoryObjectContextMenu.callback = fn end
}
events.OnPlayerUpdate = { Add = function(fn) events.OnPlayerUpdate.callback = fn end }
local queued = {}
local queueBusy = false
local queue = { add = function(action) queued[#queued + 1] = action end,
    isPlayerDoingAction = function() return queueBusy end }
local transfer = {}
function transfer:derive() local class = {}; class.__index = class; setmetatable(class, { __index = self }); return class end
function transfer:isValid() return true end
function transfer:new(character, item, source, destination)
    return setmetatable({ character = character, item = item, source = source, destination = destination }, self)
end
local inventory = { items = {}, room = true, allowed = true }
function inventory:isItemAllowed() return self.allowed end
function inventory:hasRoomFor() return self.room end
function inventory:contains(item)
    for _, current in ipairs(self.items) do if current == item then return true end end
    return false
end
local player = { modData = {}, inventory = inventory, playerNum = 0 }
function player:getModData() return self.modData end
function player:getInventory() return self.inventory end
function player:getPlayerNum() return self.playerNum end
function player:isDead() return self.dead == true end
function player:isGhostMode() return false end
function player:getVehicle() return self.vehicle end
function player:isPlayerMoving() return self.moving == true end
function player:isAttacking() return self.attacking == true end
function player:isStrafing() return self.strafing == true end
local function item(fullType, flags)
    flags = flags or {}
    local value = { fullType = fullType, flags = flags }
    function value:getFullType() return self.fullType end
    function value:getContainer() return self.container end
    function value:isInPlayerInventory() return self.flags.owned == true end
    function value:isEquipped() return false end
    function value:isUnwanted() return self.flags.unwanted == true end
    function value:isBroken() return self.flags.broken == true end
    function value:isRotten() return self.flags.rotten == true end
    return value
end
local function source(items, options)
    options = options or {}
    local result = { items = items, options = options }
    function result:getItems() return list(self.items) end
    function result:isInCharacterInventory() return self.options.owned == true end
    function result:getOutermostContainer() return self.options.outer end
    function result:isRemoveItemAllowed(value) return value.flags.removable ~= false end
    return result
end
local external = { marker = true }
local loot = source({})
local containerSources = { loot }
local contextMenu = { getContainers = function() return list(containerSources) end }
local contextPage = { refreshBackpacks = function() end }
local selectedItem
local contextIdentification = { getSelectedItem = function() return selectedItem end }
local policyEnv = setmetatable({}, { __index = _G })
local policyChunk = assert(loadfile("mods/modelus/common/media/lua/shared/auto-loot/AutoLootPolicy.lua"))
setfenv(policyChunk, policyEnv)
policyChunk()
local environment = {
    require = function() end,
    ModelusAutoLootPolicy = policyEnv.ModelusAutoLootPolicy,
    Events = events,
    ISInventoryTransferAction = transfer,
    ISTimedActionQueue = queue,
    ISInventoryPaneContextMenu = contextMenu,
    ModelusItemIdentification = contextIdentification,
    instanceof = function(value, className)
        return className == "Food" and value.flags.isFood == true
            or className == "InventoryItem" and value.fullType ~= nil
    end,
    getText = function(key) return key end,
    getSpecificPlayer = function() return player end,
    getPlayerLoot = function() return contextPage end,
    print = function() end,
    ipairs = ipairs, pairs = pairs, type = type, tostring = tostring, tonumber = tonumber,
    string = string, table = table, math = math, pcall = pcall, assert = assert,
    setmetatable = setmetatable, rawget = rawget, rawset = rawset
}
setmetatable(environment, { __index = _G })
local chunk = assert(loadfile("mods/modelus/common/media/lua/client/auto-loot/AutoLoot.lua"))
setfenv(chunk, environment)
chunk()
local auto = environment.ModelusAutoLoot

player.modData.modelusAutoLootAllowlist = "Base.Apple"
expect(auto.isTypeAllowed(player, "Base.Apple"), "existing saved allowlist remains readable")
expect(auto.toggleTypeAllowed(player, "Base.WaterBottle"), "toggle enables type")
expect(player.modData.modelusAutoLootAllowlist == "Base.Apple|Base.WaterBottle", "toggle stores sorted pipe list")
local previous = player.modData.modelusAutoLootAllowlist
expect(not auto.toggleTypeAllowed(player, "Base.Bad|Type") and player.modData.modelusAutoLootAllowlist == previous,
    "invalid type does not modify saved allowlist")
expect(not auto.toggleTypeAllowed(player, "Base.Apple") and not auto.isTypeAllowed(player, "Base.Apple"),
    "toggle removes and persists selection")

player.modData.modelusAutoLootAllowlist = "Base.Apple"
local allowed = item("Base.Apple")
selectedItem = allowed
local option
local checked
local context = {
    addOption = function(_, label, _, callback)
        option = { name = label, callback = callback }
        return option
    end,
    setOptionChecked = function(_, _, value) checked = value end
}
events.OnFillInventoryObjectContextMenu.callback(0, context, { allowed })
expect(option and option.name == "ContextMenu_ModelusAutoLootStop Base.Apple" and checked == true,
    "context menu shows selected type and persisted checked state")
option.callback()
expect(player.modData.modelusAutoLootAllowlist == "", "context menu callback toggles saved type")
selectedItem = nil

player.modData.modelusAutoLootAllowlist = "Base.Apple"
local rotten = item("Base.Apple", { isFood = true, rotten = true })
local denied = item("Base.Apple", { unwanted = true })
local broken = item("Base.Apple", { broken = true })
local own = item("Base.Apple", { owned = true })
loot.items = { allowed, allowed, rotten, denied, broken, own, item("Base.Pear") }
local candidates = auto.selectCandidates(player, loot)
expect(#candidates == 1 and candidates[1] == allowed, "runtime filters and identity-deduplicates candidates")
allowed.container = loot
expect(auto.canCollect(player, allowed), "eligible item passes revalidation")
player.modData.modelusAutoLootAllowlist = ""
expect(not auto.canCollect(player, allowed), "action revalidation reloads saved allowlist")
player.modData.modelusAutoLootAllowlist = "Base.Apple"
local ownBag = source({ allowed }, { outer = inventory })
allowed.container = ownBag
expect(not auto.canCollect(player, allowed) and #auto.selectCandidates(player, ownBag) == 0,
    "items in player-owned bags are excluded")
allowed.container = loot
inventory.room = false
expect(not auto.canCollect(player, allowed), "destination capacity is checked")
inventory.room = true
loot.options = { owned = true }
expect(#auto.selectCandidates(player, loot) == 0, "player-owned containers are excluded")
loot.options = {}
for _, state in ipairs({ "dead", "vehicle", "moving", "attacking", "strafing" }) do
    if state == "vehicle" then player.vehicle = {} else player[state] = true end
    expect(#auto.selectCandidates(player, loot) == 0, "unavailable player state blocks collection: " .. state)
    if state == "vehicle" then player.vehicle = nil else player[state] = false end
end

local nextAllowed = item("Base.Apple")
local secondLoot = source({ nextAllowed })
nextAllowed.container = secondLoot
loot.items = { allowed }
containerSources = { loot, secondLoot }
auto._ticks = auto.POLL_INTERVAL - 1
events.OnPlayerUpdate.callback(player)
expect(#queued == 1, "only one native transfer is queued at the polling interval")
expect(queued[1].item == allowed and queued[1].source == loot and queued[1].destination == inventory,
    "first eligible source is transferred to player inventory")
expect(auto.canCollect(player, allowed), "queued transfer still passes fresh validity check")
return assertions
