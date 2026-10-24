local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local events = {}
events.OnPlayerUpdate = { Add = function(callback) events.OnPlayerUpdate.callback = callback end }
events.OnGameStart = { Add = function(callback) events.OnGameStart.callback = callback end }
local queueBusy = false
local queued = {}
local transferred = {}
local mainInventory

local base = {}
function base:derive(name)
    return setmetatable({ __index = self, __name = name }, { __index = self })
end
function base:new(character, donor, target)
    return setmetatable({ character = character, drainable = donor, intoItem = target,
        fromStart = donor:getCurrentUsesFloat(), intoStart = target:getCurrentUsesFloat(),
        fromTarget = 0, intoTarget = 1, maxTime = 90 }, { __index = self })
end
function base:start() self.parentStarted = true end
function base:stop() self.parentStopped = true end
function base:perform() self.parentPerformed = true end
function base:forceStop() self:stop() end

local function item(fullType, quantity, useDelta)
    local value = { fullType = fullType, quantity = quantity, useDelta = useDelta, mergeable = true }
    function value:getFullType() return self.fullType end
    function value:getCurrentUsesFloat() return self.quantity end
    function value:getUseDelta() return self.useDelta end
    function value:canConsolidate() return self.mergeable end
    function value:getFluidContainer() return nil end
    function value:isWaterSource() return false end
    function value:getPrimaryHandItem() error("not an item method") end
    function value:getCondition() error("condition must not be read") end
    return value
end

local function container(items)
    local value = { items = items or {} }
    function value:getItems()
        local list = self.items
        return { size = function() return #list end, get = function(_, index) return list[index + 1] end }
    end
    function value:contains(target)
        for _, candidate in ipairs(self.items) do if candidate == target then return true end end
        return false
    end
    return value
end

local bagInventory = container()
local bag = { inventory = bagInventory }
function bag:getInventory() return self.inventory end
local donor = item("Base.Thread", 0.25, 0.01)
local target = item("Base.Thread", 0.65, 0.01)
bagInventory.items = { donor, target }
mainInventory = container({ bag })
local player = {
    getInventory = function() return mainInventory end,
    getPlayerNum = function() return 0 end,
    isDead = function() return false end,
    isMoving = function() return false end,
    isAttacking = function() return false end,
    isStrafing = function() return false end,
    getVehicle = function() return nil end,
    getPrimaryHandItem = function() return nil end,
    getSecondaryHandItem = function() return nil end
}

local environment
environment = {
    Events = events,
    ISConsolidateDrainable = base,
    ISTimedActionQueue = {
        isPlayerDoingAction = function() return queueBusy end,
        add = function(action) queued[#queued + 1] = action; queueBusy = true end
    },
    ISInventoryPaneContextMenu = {
        transferIfNeeded = function(_, value)
            transferred[#transferred + 1] = value
            for index, held in ipairs(bagInventory.items) do
                if held == value then
                    table.remove(bagInventory.items, index)
                    mainInventory.items[#mainInventory.items + 1] = value
                    break
                end
            end
            queueBusy = true
        end
    },
    instanceof = function(value, className)
        if className == "InventoryContainer" then return value == bag end
        if className == "DrainableComboItem" then return value == donor or value == target end
        if className == "Food" then return false end
        return false
    end,
    print = function() end,
    require = function(name)
        if name == "auto-consolidate/ConsolidationPolicy" then
            local policyEnvironment = { math = math, tostring = tostring, type = type }
            setmetatable(policyEnvironment, { __index = _G })
            local policyChunk = assert(loadfile("mods/modelus/common/media/lua/shared/auto-consolidate/ConsolidationPolicy.lua"))
            setfenv(policyChunk, policyEnvironment)
            local policy = policyChunk()
            environment.ModelusConsolidationPolicy = policy
            return policy
        end
        return true
    end,
    math = math,
    tostring = tostring,
    pcall = pcall,
    error = error,
    table = table,
    assert = assert
}
setmetatable(environment, { __index = _G })
local moduleChunk = assert(loadfile("mods/modelus/common/media/lua/client/auto-consolidate/AutoConsolidate.lua"))
setfenv(moduleChunk, environment)
local auto = moduleChunk()

local entries = auto.collectEntries(player)
expect(#entries == 2, "recursive bag scan finds both items once")
local pairDonor, pairTarget = environment.ModelusConsolidationPolicy.choosePair(entries)
expect(pairDonor.item == donor and pairTarget.item == target, "policy selects expected items")

expect(auto.queuePair(player, donor, target), "pair queues")
expect(#transferred == 2 and #queued == 0, "only chosen nested items are transferred first")
expect(not auto.queuePair(player, donor, target), "second operation is refused while pending")
queueBusy = false
auto.onPlayerUpdate(player)
expect(#queued == 1 and auto.pending.phase == "consolidating", "consolidation waits until transfers finish")

local action = queued[1]
donor.quantity = 0.3
target.quantity = 0.6
action:start()
expect(action.fromStart == 0.3 and action.intoStart == 0.6, "action refreshes quantities at start")
donor.quantity = 0
target.quantity = 1
expect(action:isValid(), "started action remains valid at empty/full endpoints")
action:stop()
expect(auto.pending == nil and action.parentStopped, "cancel clears pending state via vanilla stop")
expect(donor.quantity == 0 and target.quantity == 1, "cancel does not restore content")

return assertions