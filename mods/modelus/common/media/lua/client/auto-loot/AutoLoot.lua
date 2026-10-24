require "TimedActions/ISInventoryTransferAction"
require "ISUI/ISInventoryPaneContextMenu"
require "item-identification/ItemIdentification"
require "auto-loot/AutoLootPolicy"

ModelusAutoLoot = ModelusAutoLoot or {}
ModelusAutoLoot.POLL_INTERVAL = 60
ModelusAutoLoot._ticks = 0
ModelusAutoLoot.MOD_DATA_KEY = "modelusAutoLootAllowlist"
ModelusAutoLoot.MAX_CANDIDATES_PER_SOURCE = 5

local Policy = ModelusAutoLootPolicy

function ModelusAutoLoot.loadAllowlist(player)
    if not player then return {} end
    local ok, modData = pcall(function() return player:getModData() end)
    if not ok or not modData then return {} end
    return Policy.parseAllowlist(modData[ModelusAutoLoot.MOD_DATA_KEY])
end

function ModelusAutoLoot.saveAllowlist(player, types)
    if not player then return false end
    local ok, modData = pcall(function() return player:getModData() end)
    if not ok or not modData then return false end
    modData[ModelusAutoLoot.MOD_DATA_KEY] = Policy.serializeAllowlist(types)
    return true
end

function ModelusAutoLoot.isTypeAllowed(player, fullType)
    if not Policy.isValidFullType(fullType) then return false end
    for _, allowed in ipairs(ModelusAutoLoot.loadAllowlist(player)) do
        if allowed == fullType then return true end
    end
    return false
end

function ModelusAutoLoot.toggleTypeAllowed(player, fullType)
    if not player or not Policy.isValidFullType(fullType) then return false end
    local types = ModelusAutoLoot.loadAllowlist(player)
    local enabled = Policy.toggleType(types, fullType)
    ModelusAutoLoot.saveAllowlist(player, types)
    return enabled
end

function ModelusAutoLoot.isPlayerUnavailable(player)
    if not player then return true end
    local okDead, dead = pcall(function() return player:isDead() end)
    local okVehicle, vehicle = pcall(function() return player:getVehicle() end)
    local okMoving, moving = pcall(function() return player:isPlayerMoving() end)
    local okAttacking, attacking = pcall(function() return player:isAttacking() end)
    local okStrafing, strafing = pcall(function() return player:isStrafing() end)
    return not (okDead and okVehicle and okMoving and okAttacking and okStrafing)
        or dead == true or vehicle ~= nil or moving == true or attacking == true or strafing == true
end

function ModelusAutoLoot.isPlayerOwnedContainer(player, source)
    if not player or not source then return true end
    local okOwned, owned = pcall(function() return source:isInCharacterInventory(player) end)
    local okOuter, outer = pcall(function() return source:getOutermostContainer() end)
    local okInventory, inventory = pcall(function() return player:getInventory() end)
    if not okOwned or not okOuter or not okInventory then return true end
    return owned == true or outer == inventory
end

function ModelusAutoLoot.isEligible(player, source, item, allowedTypes)
    if not player or not source or not item or ModelusAutoLoot.isPlayerUnavailable(player)
            or ModelusAutoLoot.isPlayerOwnedContainer(player, source) then return false end

    local ok, result = pcall(function()
        local fullType = item:getFullType()
        local owned = item:isInPlayerInventory() or item:isEquipped()
        local unwanted = item:isUnwanted(player)
        local broken = item:isBroken()
        local rotten = instanceof(item, "Food") and item:isRotten()
        if not Policy.shouldLoot(allowedTypes, fullType, owned, unwanted, broken, rotten) then
            return false
        end
        local inventory = player:getInventory()
        return source:isRemoveItemAllowed(item)
            and inventory:isItemAllowed(item)
            and inventory:hasRoomFor(player, item)
    end)
    return ok and result == true
end

function ModelusAutoLoot.selectCandidates(player, source)
    if ModelusAutoLoot.isPlayerUnavailable(player)
            or ModelusAutoLoot.isPlayerOwnedContainer(player, source) then return {} end
    local okItems, items = pcall(function() return source:getItems() end)
    if not okItems or not items then return {} end
    local okList, values = pcall(function()
        local result = {}
        for index = 0, items:size() - 1 do result[#result + 1] = items:get(index) end
        return result
    end)
    if not okList then return {} end
    local allowed = ModelusAutoLoot.loadAllowlist(player)
    return Policy.uniqueEligible(values, function(item)
        return ModelusAutoLoot.isEligible(player, source, item, allowed)
    end, ModelusAutoLoot.MAX_CANDIDATES_PER_SOURCE)
end

function ModelusAutoLoot.canCollect(player, item)
    if not player or not item or ModelusAutoLoot.isPlayerUnavailable(player) then return false end
    local okSource, source = pcall(function() return item:getContainer() end)
    if not okSource or not source then return false end
    return ModelusAutoLoot.isEligible(player, source, item, ModelusAutoLoot.loadAllowlist(player))
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
    local isSelected = ModelusAutoLoot.isTypeAllowed(player, fullType)

    local label = isSelected
        and (getText("ContextMenu_ModelusAutoLootStop") .. " " .. fullType)
        or (getText("ContextMenu_ModelusAutoLootStart") .. " " .. fullType)
    local capturedPlayer = player
    local capturedType = fullType
    option = context:addOption(label, nil, function()
        ModelusAutoLoot.toggleTypeAllowed(capturedPlayer, capturedType)
    end)
    context:setOptionChecked(option, isSelected == true)
end

local ModelusAutoLootTransferAction = ISInventoryTransferAction:derive("ModelusAutoLootTransferAction")

function ModelusAutoLootTransferAction:isValid()
    local okBase, baseValid = pcall(ISInventoryTransferAction.isValid, self)
    if not okBase or not baseValid then return false end

    return ModelusAutoLoot.canCollect(self.character, self.item)
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
    local candidates = ModelusAutoLoot.selectCandidates(player, source)

    for index = 1, #candidates do
        local item = candidates[index]
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

print("[Modelus][AutoLoot] loaded; Lua runtime active")
