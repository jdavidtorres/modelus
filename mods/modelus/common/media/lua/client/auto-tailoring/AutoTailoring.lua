require "TimedActions/ISRemovePatch"
require "TimedActions/ISRepairClothing"
require "TimedActions/ISTimedActionQueue"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISGarmentUI"
require "Definitions/ClothingRecipesDefinitions"

ModelusAutoTailoring = ModelusAutoTailoring or {}
local Auto = ModelusAutoTailoring
local Policy = require "auto-tailoring/TailoringPolicy"

Auto.POLL_INTERVAL = 180
Auto.ticks = 0
Auto.pending = nil
Auto.suspended = false

local MATERIALS = {
    { fullType = "Base.RippedSheets", fabricType = "Cotton", order = 1 },
    { fullType = "Base.DenimStrips", fabricType = "Denim", order = 2 },
    { fullType = "Base.LeatherStrips", fabricType = "Leather", order = 3 }
}
local MATERIAL_BY_TYPE = {}
for index = 1, #MATERIALS do
    MATERIAL_BY_TYPE[MATERIALS[index].fullType] = MATERIALS[index]
end

local function sameItem(first, second)
    if first == second then return true end
    if not first or not second then return false end
    local okFirst, firstId = pcall(function() return first:getID() end)
    local okSecond, secondId = pcall(function() return second:getID() end)
    return okFirst and okSecond and firstId == secondId
end

local function isWorn(player, clothing)
    local wornItems = player:getWornItems()
    for index = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(index)
        if item and sameItem(item, clothing) then return true end
    end
    return false
end

local function collectFromContainer(container, entries, visitedContainers, visitedItems, depth)
    if not container or visitedContainers[container] then return end
    visitedContainers[container] = true
    local items = container:getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item and not visitedItems[item] then
            visitedItems[item] = true
            entries[#entries + 1] = { item = item, depth = depth }
            if instanceof(item, "InventoryContainer") then
                collectFromContainer(item:getInventory(), entries, visitedContainers, visitedItems, depth + 1)
            end
        end
    end
end

local function sortedEntries(player)
    local entries = {}
    collectFromContainer(player:getInventory(), entries, {}, {}, 0)
    table.sort(entries, function(first, second)
        if first.depth ~= second.depth then return first.depth < second.depth end
        local firstType = first.item:getFullType() or ""
        local secondType = second.item:getFullType() or ""
        return firstType < secondType
    end)
    return entries
end

function Auto.collectTargets(player)
    local targets = {}
    local seenClothing = {}
    local wornItems = player:getWornItems()
    for wornIndex = 0, wornItems:size() - 1 do
        local clothing = wornItems:getItemByIndex(wornIndex)
        if clothing and not seenClothing[clothing] and instanceof(clothing, "Clothing") then
            seenClothing[clothing] = true
            local fabricType = clothing:getFabricType()
            if fabricType and fabricType ~= "" then
                local parts = clothing:getCoveredParts()
                for partIndex = 0, parts:size() - 1 do
                    local part = parts:get(partIndex)
                    local hole = clothing:getVisual():getHole(part) > 0
                    local patch = clothing:getPatchType(part)
                    targets[#targets + 1] = {
                        clothing = clothing,
                        part = part,
                        wornIndex = wornIndex + 1,
                        partIndex = partIndex + 1,
                        fabricType = fabricType,
                        hole = hole,
                        patch = patch,
                        before = {
                            scratch = clothing:getDefForPart(part, false, false),
                            bite = clothing:getDefForPart(part, true, false)
                        },
                        oldPatch = patch and {
                            scratch = patch:getScratchDefense(),
                            bite = patch:getBiteDefense()
                        } or nil
                    }
                end
            end
        end
    end
    return targets
end

function Auto.collectResources(player)
    local entries = sortedEntries(player)
    local resources = { materials = {}, threads = {}, needles = {} }
    local alternateThreads = {}
    local alternateNeedles = {}
    for index = 1, #MATERIALS do
        resources.materials[MATERIALS[index].fullType] = {}
    end
    for index = 1, #entries do
        local item = entries[index].item
        local fullType = item:getFullType()
        local material = MATERIAL_BY_TYPE[fullType]
        if material and item:getFabricType() == material.fabricType then
            local list = resources.materials[fullType]
            list[#list + 1] = item
        end

        local itemType = item:getType()
        local isThread = itemType == "Thread"
        if not isThread and ItemTag and ItemTag.THREAD then
            isThread = item:hasTag(ItemTag.THREAD)
        end
        if isThread and instanceof(item, "DrainableComboItem") then
            local list = itemType == "Thread" and resources.threads or alternateThreads
            list[#list + 1] = item
        end

        local isNeedle = itemType == "Needle"
        if not isNeedle and ItemTag and ItemTag.SEWING_NEEDLE then
            isNeedle = item:hasTag(ItemTag.SEWING_NEEDLE)
        end
        if isNeedle then
            local list = itemType == "Needle" and resources.needles or alternateNeedles
            list[#list + 1] = item
        end
    end
    for index = 1, #alternateThreads do resources.threads[#resources.threads + 1] = alternateThreads[index] end
    for index = 1, #alternateNeedles do resources.needles[#resources.needles + 1] = alternateNeedles[index] end
    return resources
end

function Auto.reserveResources(resources, fullType, patchCount)
    local availableMaterials = resources.materials[fullType] or {}
    if #availableMaterials < patchCount or #resources.needles == 0 then return nil end

    local threadAllocations = {}
    local usesPerItem = {}
    for allocationIndex = 1, patchCount do
        local selected
        for threadIndex = 1, #resources.threads do
            local thread = resources.threads[threadIndex]
            local used = usesPerItem[thread] or 0
            if thread:getCurrentUses() - used >= 1 then
                selected = thread
                usesPerItem[thread] = used + 1
                break
            end
        end
        if not selected then return nil end
        threadAllocations[allocationIndex] = selected
    end

    local materials = {}
    for index = 1, patchCount do materials[index] = availableMaterials[index] end
    return {
        materials = materials,
        threads = threadAllocations,
        needle = resources.needles[1]
    }
end

local function makeCandidate(target, material, reservation, priority, fullRestore, after)
    return {
        target = target,
        fabric = reservation.materials[1],
        secondFabric = reservation.materials[2],
        thread = reservation.threads[1],
        secondThread = reservation.threads[2],
        needle = reservation.needle,
        material = material,
        priority = priority,
        fullRestore = fullRestore,
        after = after,
        fabricOrder = material.order,
        garmentIndex = target.wornIndex,
        partIndex = target.partIndex,
        removePatch = target.patch ~= nil,
        repairHole = target.hole,
        restoreFallback = target.patch ~= nil and material.fabricType == target.fabricType
    }
end

function Auto.buildCandidates(player, targets, resources)
    local candidates = {}
    for targetIndex = 1, #targets do
        local target = targets[targetIndex]
        for materialIndex = 1, #MATERIALS do
            local material = MATERIALS[materialIndex]
            local fabricItems = resources.materials[material.fullType] or {}
            if #fabricItems > 0 then
                local scratch = Clothing.getScratchDefenseFromItem(player, fabricItems[1])
                local bite = Clothing.getBiteDefenseFromItem(player, fabricItems[1])
                local proposed = { scratch = scratch, bite = bite }
                local fullRestore = target.hole and target.patch == nil
                    and target.clothing:canFullyRestore(player, target.part, fabricItems[1])
                local priority
                local after

                if target.patch then
                    local conditionLimit = target.clothing:getCondLossPerHole()
                    if target.clothing:getCondition() > conditionLimit then
                        after = Policy.replacementFloor(target.before, target.oldPatch, proposed, target.hole)
                        if after and Policy.isStrictImprovement(target.before, after)
                                and (target.hole or Policy.isStrictImprovement(target.oldPatch, proposed)) then
                            priority = target.hole and 1 or 3
                        end
                    end
                elseif target.hole then
                    priority = 1
                    after = fullRestore and target.before or proposed
                else
                    after = {
                        scratch = target.before.scratch + proposed.scratch,
                        bite = target.before.bite + proposed.bite
                    }
                    if Policy.isStrictImprovement(target.before, after) then priority = 2 end
                end

                if priority then
                    local patchCount = target.patch and material.fabricType == target.fabricType and 2 or 1
                    local reservation = Auto.reserveResources(resources, material.fullType, patchCount)
                    if reservation then
                        candidates[#candidates + 1] = makeCandidate(
                            target, material, reservation, priority, fullRestore, after)
                    end
                end
            end
        end
    end
    return candidates
end

local function fail(message)
    if Auto.suspended then return end
    Auto.suspended = true
    Auto.pending = nil
    print("[Modelus] auto-tailoring suspended after error: " .. tostring(message))
end

local function protectedAction(fallback, callback)
    local ok, result = pcall(callback)
    if not ok then
        fail(result)
        return fallback
    end
    return result
end

local function resourceAvailable(player, item)
    return item ~= nil and player:getInventory():contains(item)
end

local function resourceSetAvailable(player, fabric, thread, needle, materialType)
    return resourceAvailable(player, fabric) and resourceAvailable(player, thread)
        and resourceAvailable(player, needle) and fabric:getFabricType() == materialType
        and thread:getCurrentUses() >= 1
end

local function resourcesAvailable(player, job, includeSecond, fabric, thread)
    fabric = fabric or job.fabric
    thread = thread or job.thread
    if not resourceSetAvailable(player, fabric, thread, job.needle, job.material.fabricType) then return false end
    if includeSecond and (not resourceAvailable(player, job.secondFabric)
            or not resourceAvailable(player, job.secondThread)
            or job.secondFabric:getFabricType() ~= job.material.fabricType
            or job.secondThread:getCurrentUses() < 1) then return false end
    return true
end

local function samePatch(clothing, part, expected)
    local current = clothing:getPatchType(part)
    if expected == nil then return current == nil end
    if current == nil then return false end
    return current:getFabricType() == expected:getFabricType()
        and current:getScratchDefense() == expected:getScratchDefense()
        and current:getBiteDefense() == expected:getBiteDefense()
end

local function protectionAfterRepair(job)
    local target = job.target
    local clothing = target.clothing
    local hole = clothing:getVisual():getHole(target.part) > 0
    local patch = clothing:getPatchType(target.part)
    local proposed = {
        scratch = Clothing.getScratchDefenseFromItem(job.player, job.fabric),
        bite = Clothing.getBiteDefenseFromItem(job.player, job.fabric)
    }
    if hole then return proposed end
    local current = {
        scratch = clothing:getDefForPart(target.part, false, false),
        bite = clothing:getDefForPart(target.part, true, false)
    }
    if patch == nil then
        return { scratch = current.scratch + proposed.scratch, bite = current.bite + proposed.bite }
    end
    return current
end

local function jobStillWorn(job)
    return isWorn(job.player, job.target.clothing)
end

local ModelusRemovePatch
local ModelusRepairClothing

local function validBeforeRemoval(job)
    local target = job.target
    if not jobStillWorn(job) or not samePatch(target.clothing, target.part, target.patch)
            or not resourcesAvailable(job.player, job, job.restoreFallback)
            or target.clothing:getCondition() <= target.clothing:getCondLossPerHole() then return false end
    local proposed = {
        scratch = Clothing.getScratchDefenseFromItem(job.player, job.fabric),
        bite = Clothing.getBiteDefenseFromItem(job.player, job.fabric)
    }
    local current = {
        scratch = target.clothing:getDefForPart(target.part, false, false),
        bite = target.clothing:getDefForPart(target.part, true, false)
    }
    if job.repairHole then
        local proposed = {
            scratch = Clothing.getScratchDefenseFromItem(job.player, job.fabric),
            bite = Clothing.getBiteDefenseFromItem(job.player, job.fabric)
        }
        return Policy.isStrictImprovement(current, proposed)
    end
    local oldPatch = {
        scratch = target.patch:getScratchDefense(),
        bite = target.patch:getBiteDefense()
    }
    local after = Policy.replacementFloor(current, oldPatch, proposed,
        target.clothing:getVisual():getHole(target.part) > 0)
    return Policy.isStrictImprovement(oldPatch, proposed)
        and Policy.isStrictImprovement(current, after)
end

local function validRepair(job, isFallback, fabric, thread)
    local target = job.target
    local clothing = target.clothing
    if not jobStillWorn(job) or clothing:getPatchType(target.part) ~= nil
            or not resourcesAvailable(job.player, job, false, fabric, thread) then return false end

    local actual = protectionAfterRepair(job)
    if job.removePatch then
        if job.repairHole then
            return Policy.isStrictImprovement(target.before, actual)
        end
        if not Policy.isStrictImprovement(target.before, actual) then
            return job.restoreFallback and not isFallback
                and clothing:canFullyRestore(job.player, target.part, job.fabric)
        end
        return true
    end
    if target.hole and job.fullRestore then return true end
    return Policy.isStrictImprovement(target.before, actual)
end

local function localActionQueueEmpty(player)
    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    return not queue or not queue.queue or #queue.queue == 0
end

local function createRemoveAction(player, job, pending)
    local Action = ModelusRemovePatch
    local action = Action:new(player, job.target.clothing, job.target.part, job.needle)
    action.modelusJob = job
    action.modelusPending = pending
    return action
end

local function createRepairAction(player, job, pending, fallback)
    local fabric = fallback and job.secondFabric or job.fabric
    local thread = fallback and job.secondThread or job.thread
    local action = ModelusRepairClothing:new(player, job.target.clothing, job.target.part, fabric, thread, job.needle)
    action.modelusJob = job
    action.modelusPending = pending
    action.modelusFallback = fallback == true
    return action
end

local function cleanup(pending)
    if Auto.pending == pending then Auto.pending = nil end
end

local function queueJob(player, job)
    if Auto.pending then return false end
    local pending = { player = player, job = job, actions = {}, phase = "queued" }
    Auto.pending = pending

    for index = 1, #job.reservationItems do
        local item = job.reservationItems[index]
        local alreadyQueuedForTransfer = false
        for previousIndex = 1, index - 1 do
            if sameItem(job.reservationItems[previousIndex], item) then
                alreadyQueuedForTransfer = true
                break
            end
        end
        if not alreadyQueuedForTransfer and luautils.haveToBeTransfered(player, item) then
            ISInventoryPaneContextMenu.transferIfNeeded(player, item, true)
        end
    end
    local clothing = job.target.clothing
    if luautils.haveToBeTransfered(player, clothing) then
        ISInventoryPaneContextMenu.transferIfNeeded(player, clothing, true)
    end

    if job.removePatch then
        pending.removeAction = createRemoveAction(player, job, pending)
        pending.actions[#pending.actions + 1] = pending.removeAction
        pending.repairAction = createRepairAction(player, job, pending, false)
        pending.actions[#pending.actions + 1] = pending.repairAction
    else
        pending.repairAction = createRepairAction(player, job, pending, false)
        pending.actions[#pending.actions + 1] = pending.repairAction
    end

    for index = 1, #pending.actions do
        ISTimedActionQueue.add(pending.actions[index])
    end
    return true
end

ModelusRemovePatch = ISRemovePatch:derive("ModelusAutoRemovePatch")
function ModelusRemovePatch:isValidStart()
    return protectedAction(false, function()
        return not Auto.suspended and validBeforeRemoval(self.modelusJob) and ISRemovePatch.isValid(self)
    end)
end
function ModelusRemovePatch:isValid()
    return protectedAction(false, function()
        return not Auto.suspended and validBeforeRemoval(self.modelusJob) and ISRemovePatch.isValid(self)
    end)
end
function ModelusRemovePatch:start()
    if not protectedAction(false, function()
        return not Auto.suspended and validBeforeRemoval(self.modelusJob)
    end) then self:forceStop(); return end
    protectedAction(nil, function() ISRemovePatch.start(self) end)
end
function ModelusRemovePatch:complete()
    return protectedAction(false, function()
        if Auto.suspended or not validBeforeRemoval(self.modelusJob) then return false end
        return ISRemovePatch.complete(self)
    end)
end
function ModelusRemovePatch:forceCancel()
    cleanup(self.modelusPending)
end
function ModelusRemovePatch:stop()
    protectedAction(nil, function() ISRemovePatch.stop(self) end)
    cleanup(self.modelusPending)
end
function ModelusRemovePatch:perform()
    protectedAction(nil, function() ISRemovePatch.perform(self) end)
end

ModelusRepairClothing = ISRepairClothing:derive("ModelusAutoRepairClothing")
function ModelusRepairClothing:isValidStart()
    return protectedAction(false, function()
        return not Auto.suspended and validRepair(self.modelusJob, self.modelusFallback,
            self.fabric, self.thread) and ISRepairClothing.isValid(self)
    end)
end
function ModelusRepairClothing:isValid()
    return protectedAction(false, function()
        return not Auto.suspended and validRepair(self.modelusJob, self.modelusFallback,
            self.fabric, self.thread) and ISRepairClothing.isValid(self)
    end)
end
function ModelusRepairClothing:start()
    if not protectedAction(false, function()
        return not Auto.suspended and validRepair(self.modelusJob, self.modelusFallback,
            self.fabric, self.thread)
    end) then self:forceStop(); return end
    protectedAction(nil, function() ISRepairClothing.start(self) end)
end
function ModelusRepairClothing:complete()
    return protectedAction(false, function()
        if Auto.suspended or not validRepair(self.modelusJob, self.modelusFallback,
                self.fabric, self.thread) then return false end
        return ISRepairClothing.complete(self)
    end)
end
function ModelusRepairClothing:forceCancel()
    cleanup(self.modelusPending)
end
function ModelusRepairClothing:stop()
    protectedAction(nil, function() ISRepairClothing.stop(self) end)
    cleanup(self.modelusPending)
end
function ModelusRepairClothing:perform()
    protectedAction(nil, function()
        local pending = self.modelusPending
        local job = self.modelusJob
        if not self.modelusFallback and job.removePatch and job.restoreFallback
                and job.target.clothing:getVisual():getHole(job.target.part) == 0
                and job.target.clothing:getPatchType(job.target.part) == nil
                and resourceSetAvailable(self.character, job.secondFabric, job.secondThread,
                    job.needle, job.material.fabricType) then
            local fallback = createRepairAction(self.character, job, pending, true)
            local inserted = ISTimedActionQueue.addAfter(self, fallback)
            if inserted then
                pending.actions[#pending.actions + 1] = fallback
                pending.fallbackAction = fallback
            end
        end
        if self.modelusFallback or not pending.fallbackAction then cleanup(pending) end
        ISRepairClothing.perform(self)
    end)
end

local function playerCanAct(player)
    if not player or player:getPlayerNum() ~= 0 or player:isDead() or player:isAsleep()
            or player:isMoving() or player:isAttacking() or player:getVehicle() then return false end
    local okStrafing, strafing = pcall(function() return player:isStrafing() end)
    local okAiming, aiming = pcall(function() return player:isAiming() end)
    local okDragging, dragging = pcall(function() return player:isDraggingCorpse() end)
    return not (okStrafing and strafing) and not (okAiming and aiming)
        and not (okDragging and dragging)
end

local function hasPendingAction(pending)
    for index = 1, #pending.actions do
        if ISTimedActionQueue.hasAction(pending.actions[index]) then return true end
    end
    return false
end

local function safeUpdate(player)
    if Auto.suspended or not player or player:getPlayerNum() ~= 0 then return end
    if Auto.pending then
        local pending = Auto.pending
        if pending.player == player and not hasPendingAction(pending)
                and not ISTimedActionQueue.isPlayerDoingAction(player) then
            cleanup(pending)
            Auto.ticks = 0
        end
        return
    end

    Auto.ticks = Auto.ticks + 1
    if Auto.ticks < Auto.POLL_INTERVAL then return end
    Auto.ticks = 0
    if not playerCanAct(player) or not localActionQueueEmpty(player) then return end

    local targets = Auto.collectTargets(player)
    local resources = Auto.collectResources(player)
    local candidates = Auto.buildCandidates(player, targets, resources)
    local candidate = Policy.chooseNext(candidates)
    if candidate then
        candidate.player = player
        candidate.reservationItems = { candidate.fabric, candidate.thread, candidate.needle }
        if candidate.secondFabric then candidate.reservationItems[#candidate.reservationItems + 1] = candidate.secondFabric end
        if candidate.secondThread then candidate.reservationItems[#candidate.reservationItems + 1] = candidate.secondThread end
        queueJob(player, candidate)
    end
end

function Auto.onPlayerUpdate(player)
    local ok, err = pcall(safeUpdate, player)
    if not ok then fail(err) end
end

function Auto.onGameStart()
    Auto.ticks = 0
    Auto.pending = nil
    Auto.suspended = false
end

Events.OnPlayerUpdate.Add(Auto.onPlayerUpdate)
Events.OnGameStart.Add(Auto.onGameStart)

return Auto