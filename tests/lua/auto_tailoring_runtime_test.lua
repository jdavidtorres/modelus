local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local events = {}
events.OnPlayerUpdate = { Add = function(callback) events.OnPlayerUpdate.callback = callback end }
events.OnGameStart = { Add = function(callback) events.OnGameStart.callback = callback end }

local function list(values)
    return {
        size = function() return #values end,
        get = function(_, index) return values[index + 1] end,
        getItemByIndex = function(_, index) return values[index + 1] end
    }
end

local function derive(parent)
    local class = {}
    class.__index = class
    setmetatable(class, { __index = parent })
    return class
end

local inventory = { items = {} }
function inventory:getItems() return list(self.items) end
function inventory:contains(item)
    for index = 1, #self.items do if self.items[index] == item then return true end end
    return false
end
function inventory:addItem(item)
    self.items[#self.items + 1] = item
    item.container = self
end
function inventory:Remove(item)
    for index = 1, #self.items do
        if self.items[index] == item then
            table.remove(self.items, index)
            item.container = nil
            return
        end
    end
end

local queue = { queue = {} }
local queueBusy = false
local function removeQueued(action)
    for index = 1, #queue.queue do
        if queue.queue[index] == action then
            table.remove(queue.queue, index)
            break
        end
    end
    queueBusy = #queue.queue > 0
end

local patchStates = setmetatable({}, { __mode = "k" })
local function makePatch(state)
    local patch = {}
    patchStates[patch] = state
    function patch:getFabricType() return patchStates[self].fabricType end
    function patch:getScratchDefense() return patchStates[self].scratch end
    function patch:getBiteDefense() return patchStates[self].bite end
    return setmetatable(patch, { __index = function(_, key)
        if key == "hasHole" or key == "conditionGain" or key == "neckProtectionModifier" then
            error("unexposed game field must not be read: " .. key)
        end
    end })
end

local TimedAction = {}
TimedAction.__index = TimedAction
function TimedAction:derive() return derive(self) end
function TimedAction:new(character)
    return setmetatable({ character = character, maxTime = 10 }, self)
end
function TimedAction:isValidStart() return true end
function TimedAction:isValid() return true end
function TimedAction:start() self.started = true end
function TimedAction:complete() return true end
function TimedAction:stop() removeQueued(self) end
function TimedAction:perform() removeQueued(self) end
function TimedAction:forceCancel() removeQueued(self) end

local ISRemovePatch = derive(TimedAction)
function ISRemovePatch:new(player, clothing, part, needle)
    return setmetatable({ character = player, clothing = clothing, part = part, needle = needle }, self)
end
function ISRemovePatch:isValid()
    return inventory:contains(self.clothing) and inventory:contains(self.needle)
        and self.clothing:getPatchType(self.part) ~= nil
end
function ISRemovePatch:start() self.started = true end
function ISRemovePatch:complete()
    local patch = self.clothing:getPatchType(self.part)
    local state = patchStates[patch]
    self.clothing.patch = nil
    if state.hasHole then
        self.clothing.hole = true
        self.clothing.condition = self.clothing.condition - state.conditionGain
    end
    return true
end
function ISRemovePatch:stop() TimedAction.stop(self) end
function ISRemovePatch:perform() TimedAction.perform(self) end

local ISRepairClothing = derive(TimedAction)
function ISRepairClothing:new(player, clothing, part, fabric, thread, needle)
    return setmetatable({ character = player, clothing = clothing, part = part,
        fabric = fabric, thread = thread, needle = needle }, self)
end
function ISRepairClothing:isValid()
    return inventory:contains(self.clothing) and inventory:contains(self.fabric)
        and inventory:contains(self.thread) and inventory:contains(self.needle)
        and self.clothing:getPatchType(self.part) == nil
end
function ISRepairClothing:start() self.started = true end
function ISRepairClothing:complete()
    if self.clothing:canFullyRestore(self.character, self.part, self.fabric) then
        self.clothing.hole = false
        self.clothing.condition = math.min(self.clothing.conditionMax,
            self.clothing.condition + self.clothing.conditionLossPerHole)
    else
        local isHole = self.clothing.hole
        self.clothing.hole = false
        self.clothing.patch = makePatch({ hasHole = isHole, scratch = self.fabric.scratch,
            bite = self.fabric.bite, fabricType = self.fabric.fabricType,
            conditionGain = isHole and self.clothing.conditionLossPerHole or 0 })
        if isHole then
            self.clothing.condition = math.min(self.clothing.conditionMax,
                self.clothing.condition + self.clothing.conditionLossPerHole)
        end
    end
    inventory:Remove(self.fabric)
    self.thread.uses = self.thread.uses - 1
    return true
end
function ISRepairClothing:stop() TimedAction.stop(self) end
function ISRepairClothing:perform() TimedAction.perform(self) end

local bagInventory = { items = {} }
setmetatable(bagInventory, { __index = inventory })
local bag = { inventory = bagInventory }
function bag:getInventory() return self.inventory end
function bag:getFullType() return "Base.TestBag" end
function bag:getType() return "TestBag" end
function bag:hasTag() return false end

local function makeItem(fullType, itemType, options)
    options = options or {}
    local item = { fullType = fullType, itemType = itemType or fullType:match("[^%.]+$"),
        fabricType = options.fabricType, scratch = options.scratch or 0, bite = options.bite or 0,
        uses = options.uses or 0, condition = 10, tags = options.tags or {} }
    function item:getFullType() return self.fullType end
    function item:getType() return self.itemType end
    function item:getFabricType() return self.fabricType end
    function item:getCurrentUses() return self.uses end
    function item:hasTag(tag) return self.tags[tag] == true end
    function item:getID() return self end
    function item:getContainer() return self.container end
    return item
end

local function makeClothing(options)
    options = options or {}
    local part = { toString = function() return "Torso_Upper" end }
    local clothing = makeItem("Base.TestJacket", "TestJacket", { fabricType = options.fabricType or "Cotton" })
    clothing.condition = options.condition or 50
    clothing.conditionMax = 100
    clothing.conditionLossPerHole = options.conditionLossPerHole or 10
    clothing.hole = options.hole == true
    clothing.patch = options.patch and makePatch(options.patch) or nil
    clothing.parts = { part }
    function clothing:getCoveredParts() return list(self.parts) end
    function clothing:getVisual()
        return { getHole = function() return self.hole and 1 or 0 end }
    end
    function clothing:getPatchType() return self.patch end
    function clothing:getFabricType() return self.fabricType end
    function clothing:getDefForPart(_, isBite)
        if self.hole then return 0 end
        local base = isBite and 4 or 8
        if self.patch then
            local state = patchStates[self.patch]
            if state.hasHole then return isBite and state.bite or state.scratch end
            return base + (isBite and state.bite or state.scratch)
        end
        return base
    end
    function clothing:getCondition() return self.condition end
    function clothing:getCondLossPerHole() return self.conditionLossPerHole end
    function clothing:canFullyRestore(_, _, fabric)
        return self.hole and self.tailoring >= 8 and fabric.fabricType == self.fabricType
    end
    clothing.tailoring = options.tailoring or 0
    return clothing, part
end

local player = {}
function player:getPlayerNum() return 0 end
function player:isDead() return false end
function player:isAsleep() return false end
function player:isMoving() return false end
function player:isAttacking() return false end
function player:isStrafing() return false end
function player:isAiming() return false end
function player:getVehicle() return nil end
function player:isDraggingCorpse() return false end
function player:getInventory() return inventory end
function player:getWornItems() return list(self.worn or {}) end
function player:getPerkLevel() return self.tailoring or 0 end

local function getTimedQueue() return queue end
local function addAction(action)
    queue.queue[#queue.queue + 1] = action
    queueBusy = true
end
local environment
environment = {
    Events = events,
    ISRemovePatch = ISRemovePatch,
    ISRepairClothing = ISRepairClothing,
    ISTimedActionQueue = {
        add = addAction,
        addAfter = function(previous, action)
            for index = 1, #queue.queue do
                if queue.queue[index] == previous then
                    table.insert(queue.queue, index + 1, action)
                    return queue, action
                end
            end
            return nil
        end,
        hasAction = function(action)
            for index = 1, #queue.queue do if queue.queue[index] == action then return true end end
            return false
        end,
        getTimedActionQueue = getTimedQueue,
        isPlayerDoingAction = function() return queueBusy end
    },
    ISInventoryPaneContextMenu = {
        transferIfNeeded = function(_, item)
            local source = item.container
            if source then source:Remove(item) end
            inventory:addItem(item)
            local transfer = setmetatable({ character = player, item = item }, derive(TimedAction))
            addAction(transfer)
        end
    },
    luautils = {
        haveToBeTransfered = function(_, item) return item.container ~= inventory end
    },
    Clothing = {
        getScratchDefenseFromItem = function(_, fabric) return fabric.scratch end,
        getBiteDefenseFromItem = function(_, fabric) return fabric.bite end
    },
    ItemTag = { THREAD = "thread", SEWING_NEEDLE = "needle" },
    instanceof = function(item, className)
        if className == "InventoryContainer" then return item == bag end
        if className == "Clothing" then return item and item.fullType == "Base.TestJacket" end
        if className == "DrainableComboItem" then return item and item.isDrainable == true end
        return false
    end,
    print = function() end,
    require = function(name)
        if name == "auto-tailoring/TailoringPolicy" then
            local policyEnvironment = { math = math, type = type }
            setmetatable(policyEnvironment, { __index = _G })
            local policyChunk = assert(loadfile("mods/modelus/common/media/lua/shared/auto-tailoring/TailoringPolicy.lua"))
            setfenv(policyChunk, policyEnvironment)
            local policy = policyChunk()
            environment.ModelusTailoringPolicy = policy
            return policy
        end
        return true
    end,
    table = table,
    math = math,
    pcall = pcall,
    tostring = tostring,
    assert = assert
}
setmetatable(environment, { __index = _G })

local function reset()
    inventory.items = { bag }
    bagInventory.items = {}
    queue.queue = {}
    queueBusy = false
    player.worn = {}
    player.tailoring = 0
end

local function fabric(fullType, fabricType, scratch, bite)
    return makeItem(fullType, fullType:match("[^%.]+$"), { fabricType = fabricType, scratch = scratch, bite = bite })
end

local function thread(uses, itemType)
    local fullType = "Base." .. (itemType or "Thread")
    local value = makeItem(fullType, itemType or "Thread", { uses = uses, tags = { thread = true } })
    value.isDrainable = true
    function value:UseAndSync() self.uses = self.uses - 1 end
    return value
end

local function runQueue()
    local guard = 0
    while #queue.queue > 0 do
        guard = guard + 1
        assert(guard < 30, "timed-action queue did not drain")
        local action = queue.queue[1]
        if action.isValidStart then assert(action:isValidStart(), "queued action start validation failed") end
        if action.start then action:start() end
        if action.isValid then assert(action:isValid(), "running action validation failed") end
        if action.complete then assert(action:complete() ~= false, "action completion validation failed") end
        if action.perform then action:perform() else removeQueued(action) end
    end
end

local moduleChunk = assert(loadfile("mods/modelus/common/media/lua/client/auto-tailoring/AutoTailoring.lua"))
setfenv(moduleChunk, environment)
local auto = moduleChunk()

local reserveMaterials = {
    materials = { ["Base.RippedSheets"] = {
        fabric("Base.RippedSheets", "Cotton", 5, 0),
        fabric("Base.RippedSheets", "Cotton", 5, 0)
    } },
    threads = { thread(1), thread(1) },
    needles = { makeItem("Base.Needle_Bone", "Needle_Bone", { tags = { needle = true } }) }
}
local splitReservation = auto.reserveResources(reserveMaterials, "Base.RippedSheets", 2)
expect(splitReservation and splitReservation.materials[1] ~= splitReservation.materials[2],
    "two-strip reservations use distinct fabric objects")
expect(splitReservation.threads[1] ~= splitReservation.threads[2],
    "two thread uses may be reserved across partially used spools")

reset()
local worn, part = makeClothing({ hole = true })
local outerLayer = makeClothing({ hole = true })
local reserve = makeClothing({ hole = true })
player.worn = { worn, outerLayer }
inventory:addItem(worn)
inventory:addItem(outerLayer)
inventory:addItem(reserve)
local leather = fabric("Base.LeatherStrips", "Leather", 20, 10)
local sewingThread = thread(2, "FishingLine")
local needle = makeItem("Base.Needle_Bone", "Needle_Bone", { tags = { needle = true } })
bagInventory.addItem = inventory.addItem
bagInventory.Remove = inventory.Remove
bagInventory:addItem(leather)
bagInventory:addItem(sewingThread)
bagInventory:addItem(needle)
local targets = auto.collectTargets(player)
expect(#targets == 2 and targets[1].clothing == worn and targets[2].clothing == outerLayer,
    "all worn layers are targeted while carried reserve clothing is excluded")
local resources = auto.collectResources(player)
local candidates = auto.buildCandidates(player, targets, resources)
expect(#candidates == 2 and candidates[1].fabric == leather, "clean carried material becomes candidates for worn layers")
auto.ticks = auto.POLL_INTERVAL - 1
auto.onPlayerUpdate(player)
expect(auto.pending ~= nil, "eligible worn hole queues a job")
runQueue()
expect(worn.hole == false and worn.patch ~= nil, "native repair action patches the worn hole")
expect(reserve.hole == true and reserve.patch == nil, "unworn reserve clothing remains untouched")
expect(sewingThread.uses == 1 and leather.container == nil, "one patch consumes one strip and one thread use")
expect(auto.pending == nil and not auto.suspended, "completed repair clears pending state")

reset()
local upgradePatch = { hasHole = true, scratch = 2, bite = 1, fabricType = "Cotton", conditionGain = 2 }
local upgradeClothing, upgradePart = makeClothing({ fabricType = "Cotton", patch = upgradePatch,
    condition = 50, conditionLossPerHole = 10, tailoring = 8 })
player.worn = { upgradeClothing }
inventory:addItem(upgradeClothing)
local cottonOne = fabric("Base.RippedSheets", "Cotton", 5, 2)
local cottonTwo = fabric("Base.RippedSheets", "Cotton", 5, 2)
local upgradeThread = thread(2)
local upgradeNeedle = makeItem("Base.Needle", "Needle")
bagInventory:addItem(cottonOne)
bagInventory:addItem(cottonTwo)
bagInventory:addItem(upgradeThread)
bagInventory:addItem(upgradeNeedle)
targets = auto.collectTargets(player)
resources = auto.collectResources(player)
candidates = auto.buildCandidates(player, targets, resources)
expect(#candidates == 1 and candidates[1].secondFabric == cottonTwo,
    "matching-material patch upgrade reserves two distinct strips")
auto.ticks = auto.POLL_INTERVAL - 1
auto.onPlayerUpdate(player)
runQueue()
expect(upgradeClothing.patch ~= nil and not upgradeClothing.hole,
    "restoring patch upgrade queues the reserved follow-up padding")
expect(upgradeThread.uses == 0 and cottonOne.container == nil and cottonTwo.container == nil,
    "restoration upgrade consumes two strips and two thread uses")
expect(upgradeClothing.patch:getScratchDefense() == 5 and upgradeClothing.patch:getBiteDefense() == 2,
    "conditional second application creates the reserved padding patch")
auto.ticks = auto.POLL_INTERVAL - 1
auto.onPlayerUpdate(player)
expect(#queue.queue == 0 and auto.pending == nil,
    "a completed upgrade cannot immediately queue an equivalent replacement")

reset()
local nearBroken, brokenPart = makeClothing({ patch = {
    hasHole = true, scratch = 1, bite = 1, fabricType = "Cotton", conditionGain = 2
}, condition = 10, conditionLossPerHole = 10 })
player.worn = { nearBroken }
inventory:addItem(nearBroken)
bagInventory:addItem(fabric("Base.LeatherStrips", "Leather", 20, 10))
bagInventory:addItem(thread(2))
bagInventory:addItem(makeItem("Base.Needle", "Needle"))
targets = auto.collectTargets(player)
resources = auto.collectResources(player)
expect(#auto.buildCandidates(player, targets, resources) == 0,
    "patch removal is refused when condition equals the hole-loss bound")
nearBroken.condition = 11
expect(#auto.buildCandidates(player, targets, resources) == 1,
    "patch removal is allowed above the hole-loss bound")

reset()
local unpatched, cleanPart = makeClothing({ hole = false })
player.worn = { unpatched }
inventory:addItem(unpatched)
bagInventory:addItem(fabric("Base.DenimStripsDirty", "Denim", 50, 50))
targets = auto.collectTargets(player)
resources = auto.collectResources(player)
expect(#resources.materials["Base.DenimStrips"] == 0,
    "dirty material variants are excluded by exact full type")
expect(#auto.buildCandidates(player, targets, resources) == 0,
    "no sewing candidate exists without clean fabric, thread and needle")

reset()
local holedPadding, paddingPart = makeClothing({ hole = true, patch = {
    hasHole = false, scratch = 2, bite = 1, fabricType = "Cotton", conditionGain = 0
}, condition = 50 })
player.worn = { holedPadding }
inventory:addItem(holedPadding)
local patchFabric = fabric("Base.LeatherStrips", "Leather", 20, 10)
bagInventory:addItem(patchFabric)
bagInventory:addItem(thread(1))
bagInventory:addItem(makeItem("Base.Needle", "Needle"))
targets = auto.collectTargets(player)
resources = auto.collectResources(player)
candidates = auto.buildCandidates(player, targets, resources)
expect(#candidates == 1 and candidates[1].after.scratch == 20,
    "a new visible hole over an old patch is evaluated from zero effective defense")
auto.ticks = auto.POLL_INTERVAL - 1
auto.onPlayerUpdate(player)
runQueue()
expect(not holedPadding.hole and holedPadding.patch ~= nil,
    "a new hole over an old patch is removed and patched using vanilla actions")

reset()
local cancelClothing = makeClothing({ hole = true })
player.worn = { cancelClothing }
inventory:addItem(cancelClothing)
bagInventory:addItem(fabric("Base.LeatherStrips", "Leather", 20, 10))
bagInventory:addItem(thread(1))
bagInventory:addItem(makeItem("Base.Needle", "Needle"))
auto.ticks = auto.POLL_INTERVAL - 1
auto.onPlayerUpdate(player)
expect(auto.pending ~= nil and #queue.queue > 0, "transfer and repair actions are queued together")
for index = #queue.queue, 1, -1 do
    local action = queue.queue[index]
    if action.forceCancel then action:forceCancel() end
end
queue.queue = {}
queueBusy = false
expect(auto.pending == nil, "cancelling queued work clears the pending guard")

return assertions
