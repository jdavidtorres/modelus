require "TimedActions/ISConsolidateDrainable"
require "TimedActions/ISTimedActionQueue"
require "ISUI/ISInventoryPaneContextMenu"

ModelusAutoConsolidate = ModelusAutoConsolidate or {}
local Auto = ModelusAutoConsolidate
local Policy = require "auto-consolidate/ConsolidationPolicy"

Auto.POLL_INTERVAL = 180
Auto.ticks = 0
Auto.pending = nil
Auto.suspended = false

local function isEquipped(player, item)
    local primary = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()
    return primary == item or secondary == item
end

local function isFluid(item)
    if item:getFluidContainer() ~= nil then return true end
    return item:isWaterSource()
end

local function collectFromContainer(container, entries, visitedContainers, visitedItems, player)
    if not container or visitedContainers[container] then return end
    visitedContainers[container] = true

    local items = container:getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item and not visitedItems[item] then
            visitedItems[item] = true
            if instanceof(item, "InventoryContainer") then
                collectFromContainer(item:getInventory(), entries, visitedContainers, visitedItems, player)
            end

            if instanceof(item, "DrainableComboItem") and not instanceof(item, "Food")
                    and not isEquipped(player, item) then
                local fluid = isFluid(item)
                entries[#entries + 1] = {
                    item = item,
                    fullType = item:getFullType(),
                    fraction = item:getCurrentUsesFloat(),
                    useDelta = item:getUseDelta(),
                    mergeable = item:canConsolidate(),
                    fluid = fluid
                }
            end
        end
    end
end

function Auto.collectEntries(player)
    local entries = {}
    collectFromContainer(player:getInventory(), entries, {}, {}, player)
    return entries
end

local function contains(container, item)
    return container and container:contains(item)
end

local function compatible(player, donor, target)
    if not donor or not target or donor == target then return false end
    if not contains(player:getInventory(), donor) or not contains(player:getInventory(), target) then return false end
    if not instanceof(donor, "DrainableComboItem") or not instanceof(target, "DrainableComboItem") then return false end
    if not donor:canConsolidate() or not target:canConsolidate() then return false end
    if donor:getFullType() ~= target:getFullType() or donor:getUseDelta() ~= target:getUseDelta() then return false end
    if isFluid(donor) or isFluid(target) or instanceof(donor, "Food") or instanceof(target, "Food") then return false end
    return Policy.isPartial(donor:getCurrentUsesFloat()) and Policy.isPartial(target:getCurrentUsesFloat())
end

local function clearPending(pending)
    if Auto.pending == pending then Auto.pending = nil end
end

local function makeAction(player, donor, target, pending)
    local Action = ISConsolidateDrainable:derive("ModelusConsolidateDrainable")

    function Action:isValid()
        if self.started then
            return contains(self.character:getInventory(), self.intoItem)
                and contains(self.character:getInventory(), self.drainable)
                and self.intoItem:canConsolidate() and self.drainable:canConsolidate()
                and self.intoItem:getFullType() == self.drainable:getFullType()
                and self.intoItem:getUseDelta() == self.drainable:getUseDelta()
        end
        return compatible(self.character, self.drainable, self.intoItem)
    end

    function Action:start()
        if not compatible(self.character, self.drainable, self.intoItem) then
            self:forceStop()
            return
        end
        self.fromStart = self.drainable:getCurrentUsesFloat()
        self.intoStart = self.intoItem:getCurrentUsesFloat()
        local amount = math.min(self.fromStart, 1 - self.intoStart)
        self.fromTarget = self.fromStart - amount
        self.intoTarget = self.intoStart + amount
        self.started = true
        ISConsolidateDrainable.start(self)
    end

    function Action:stop()
        ISConsolidateDrainable.stop(self)
        clearPending(pending)
    end

    function Action:perform()
        ISConsolidateDrainable.perform(self)
        clearPending(pending)
    end

    function Action:forceCancel()
        clearPending(pending)
    end

    return Action:new(player, donor, target, nil)
end

function Auto.queuePair(player, donor, target)
    if Auto.pending then return false end
    local pending = { player = player, donor = donor, target = target, phase = "transferring" }
    Auto.pending = pending

    if not contains(player:getInventory(), donor) then
        ISInventoryPaneContextMenu.transferIfNeeded(player, donor, true)
    end
    if not contains(player:getInventory(), target) then
        ISInventoryPaneContextMenu.transferIfNeeded(player, target, true)
    end

    if not ISTimedActionQueue.isPlayerDoingAction(player) then
        if compatible(player, donor, target) then
            pending.phase = "consolidating"
            pending.action = makeAction(player, donor, target, pending)
            ISTimedActionQueue.add(pending.action)
        else
            clearPending(pending)
        end
    end
    return true
end

local function canStart(player)
    if not player or player:getPlayerNum() ~= 0 or player:isDead() then return false end
    if player:isMoving() or player:isAttacking() or player:isStrafing() or player:getVehicle() then return false end
    return not ISTimedActionQueue.isPlayerDoingAction(player)
end

local function updatePending(pending)
    local player = pending.player
    if ISTimedActionQueue.isPlayerDoingAction(player) then return end
    if pending.phase == "transferring" then
        if compatible(player, pending.donor, pending.target) then
            pending.phase = "consolidating"
            pending.action = makeAction(player, pending.donor, pending.target, pending)
            ISTimedActionQueue.add(pending.action)
        else
            clearPending(pending)
        end
    end
end

function Auto.onPlayerUpdate(player)
    if Auto.suspended then return end
    local ok, err = pcall(function()
        if Auto.pending then
            if Auto.pending.player == player then updatePending(Auto.pending) end
            return
        end
        Auto.ticks = Auto.ticks + 1
        if Auto.ticks < Auto.POLL_INTERVAL or not canStart(player) then return end
        Auto.ticks = 0
        local donor, target = Policy.choosePair(Auto.collectEntries(player))
        if donor and target then Auto.queuePair(player, donor.item, target.item) end
    end)
    if not ok then
        Auto.suspended = true
        Auto.pending = nil
        print("[Modelus] auto-consolidate suspended after error: " .. tostring(err))
    end
end

function Auto.onGameStart()
    Auto.ticks = 0
    Auto.pending = nil
    Auto.suspended = false
end

Events.OnPlayerUpdate.Add(Auto.onPlayerUpdate)
Events.OnGameStart.Add(Auto.onGameStart)

return Auto