require "TimedActions/ISInventoryTransferAction"
require "item-identification/ItemIdentification"

ModelusAutoLoot = ModelusAutoLoot or {}
ModelusAutoLoot.POLL_INTERVAL = 60
ModelusAutoLoot._ticks = 0
ModelusAutoLoot._bridgeWarningLogged = false

local function getBridge()
    if ModelusBridge then return ModelusBridge end

    if not ModelusAutoLoot._bridgeWarningLogged then
        ModelusAutoLoot._bridgeWarningLogged = true
        print("[Modelus][AutoLoot] Java bridge is not initialized; feature is disabled")
    end
    return nil
end

local function callBridge(methodName, ...)
    local bridge = getBridge()
    if not bridge or not bridge[methodName] then return false, nil end

    local args = { ... }
    local ok, result = pcall(function()
        return bridge[methodName](unpack(args))
    end)
    return ok, result
end

local function addDistinct(items, item)
    for _, existing in ipairs(items) do
        if existing == item then return true end
    end
    items[#items + 1] = item
    return #items <= 1
end

local function addContextRow(items, row)
    if not row then return true end

    if instanceof(row, "InventoryItem") then
        return addDistinct(items, row)
    end

    if not row.items then return false end
    for _, item in ipairs(row.items) do
        if not addDistinct(items, item) then return false end
    end
    return true
end

local function contextMatchesSelected(contextItems, selectedItem)
    if not contextItems or not selectedItem then return false end

    local actualItems = {}
    for _, row in ipairs(contextItems) do
        if not addContextRow(actualItems, row) then return false end
    end
    return #actualItems == 1 and actualItems[1] == selectedItem
end

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    if playerNum ~= 0 then return end

    local selectedItem = ModelusItemIdentification.getSelectedItem()
    if not contextMatchesSelected(items, selectedItem) then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local fullType = selectedItem:getFullType()
    local option
    local ok, isSelected = callBridge("autoLootIsSelected", player, fullType)
    if not ok then
        option = context:addOption(
            getText("ContextMenu_ModelusAutoLootUnavailable"), nil, nil)
        option.notAvailable = true
        return
    end

    local label = isSelected
        and (getText("ContextMenu_ModelusAutoLootStop") .. " " .. fullType)
        or (getText("ContextMenu_ModelusAutoLootStart") .. " " .. fullType)
    local capturedPlayer = player
    local capturedType = fullType
    option = context:addOption(label, nil, function()
        callBridge("autoLootToggleType", capturedPlayer, capturedType)
    end)
    context:setOptionChecked(option, isSelected == true)
end

local ModelusAutoLootTransferAction = ISInventoryTransferAction:derive("ModelusAutoLootTransferAction")

function ModelusAutoLootTransferAction:isValid()
    local okBase, baseValid = pcall(ISInventoryTransferAction.isValid, self)
    if not okBase or not baseValid then return false end

    local okBridge, canCollect = callBridge("autoLootCanCollect", self.character, self.item)
    return okBridge and canCollect == true
end

local function playerIsIdle(player)
    if not player or player:getPlayerNum() ~= 0 then return false end

    local okDead, isDead = pcall(function() return player:isDead() end)
    local okGhost, isGhost = pcall(function() return player:isGhostMode() end)
    local okVehicle, vehicle = pcall(function() return player:getVehicle() end)
    local okMoving, moving = pcall(function() return player:isPlayerMoving() end)
    local okBusy, busy = pcall(function()
        return ISTimedActionQueue.isPlayerDoingAction(player)
    end)

    return okDead and not isDead
        and okGhost and not isGhost
        and okVehicle and not vehicle
        and okMoving and not moving
        and okBusy and not busy
end

local function tryQueueFromSource(player, source)
    local okCandidates, candidates = callBridge("autoLootCandidates", player, source)
    if not okCandidates or not candidates or not candidates.size then return false end

    for index = 0, candidates:size() - 1 do
        local item = candidates:get(index)
        local sourceContainer = item and item:getContainer()
        if item and sourceContainer == source then
            local action = ModelusAutoLootTransferAction:new(
                player, item, source, player:getInventory())
            local okValid, isValid = pcall(function() return action:isValid() end)
            if okValid and isValid then
                ISTimedActionQueue.add(action)
                return true
            end
        end
    end
    return false
end

local function onPlayerUpdate(player)
    if not playerIsIdle(player) then return end

    ModelusAutoLoot._ticks = ModelusAutoLoot._ticks + 1
    if ModelusAutoLoot._ticks < ModelusAutoLoot.POLL_INTERVAL then return end
    ModelusAutoLoot._ticks = 0

    if not getBridge() then return end

    local okLoot, lootPage = pcall(getPlayerLoot, player:getPlayerNum())
    if not okLoot or not lootPage then return end
    pcall(function() lootPage:refreshBackpacks() end)

    local okContainers, containers = pcall(function()
        return ISInventoryPaneContextMenu.getContainers(player)
    end)
    if not okContainers or not containers then return end

    for index = 0, containers:size() - 1 do
        local source = containers:get(index)
        if source and tryQueueFromSource(player, source) then return end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
Events.OnPlayerUpdate.Add(onPlayerUpdate)

print("[Modelus][AutoLoot] loaded; Java runtime bridge required before use")
