require "Entity/ISEntityUI"

AutoEatCans = AutoEatCans or {}

local catalogOk = pcall(require, "auto-eat/CannedFoodCatalog")
if not catalogOk then
    catalogOk = pcall(require, "CannedFoodCatalog")
end
local CATALOG = catalogOk and ModelusCannedFoodCatalog or nil

local function newPendingCan()
    local pending = { state = "PENDING" }
    function pending:getState() return self.state end
    local function transition(self, target)
        if self.state ~= "PENDING" then return false end
        self.state = target
        return true
    end
    function pending:finish() return transition(self, "SUCCEEDED") end
    function pending:cancel() return transition(self, "CANCELLED") end
    function pending:fail() return transition(self, "FAILED") end
    return pending
end

local function createdOutput(recipeData, expectedType)
    if not recipeData or type(expectedType) ~= "string" or expectedType:match("^%s*$") then
        return nil
    end
    local okList, created = pcall(function() return recipeData:getAllCreatedItems() end)
    if not okList or not created then return nil end
    local okSize, size = pcall(function() return created:size() end)
    if not okSize or size ~= 1 then return nil end
    local okItem, item = pcall(function() return created:get(0) end)
    if not okItem or not item then return nil end
    local okType, fullType = pcall(function() return item:getFullType() end)
    if not okType or fullType ~= expectedType then return nil end
    return item
end

local function getCanDefinition(item)
    if not item then return nil end
    if not CATALOG then return nil end

    local okType, fullType = pcall(function() return item:getFullType() end)
    if not okType or not fullType then return nil end

    local recipeName = CATALOG.openingRecipeFor(fullType)
    local expectedType = CATALOG.expectedOpenedType(fullType)
    if not recipeName or not expectedType then return nil end

    local okItemRecipe, itemRecipe = pcall(function() return item:getOpeningRecipe() end)
    if not okItemRecipe or itemRecipe ~= recipeName then return nil end

    return { recipeName = recipeName, expectedType = expectedType }
end

local function findCan(container)
    if not container then return nil end
    local okItems, items = pcall(function() return container:getItems() end)
    if not okItems or not items then return nil end

    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item then
            local definition = getCanDefinition(item)
            if definition then
                return item, definition
            end

            local isContainer = false
            pcall(function() isContainer = instanceof(item, "InventoryContainer") end)
            if isContainer then
                local nested
                pcall(function() nested = item:getInventory() end)
                local nestedItem, nestedDefinition = findCan(nested)
                if nestedItem then return nestedItem, nestedDefinition end
            end
        end
    end

    return nil
end

local function addContainersRecursively(container, containers)
    if not container then return end
    containers:add(container)

    local items = container:getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item and instanceof(item, "InventoryContainer") then
            addContainersRecursively(item:getInventory(), containers)
        end
    end
end

local function itemIsInContainer(container, target)
    if not container then return false end
    local items = container:getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item == target then return true end
        if item and instanceof(item, "InventoryContainer")
                and itemIsInContainer(item:getInventory(), target) then
            return true
        end
    end
    return false
end

local function stopCraftLogic(attempt, cancelled)
    if attempt.logicStopped or not attempt.logic or not attempt.craftStarted then return end
    attempt.logicStopped = true
    pcall(function() attempt.logic:stopCraftAction(cancelled == true) end)
end

local function clearAttempt(attempt)
    if AutoEatCans.pending == attempt then
        AutoEatCans.pending = nil
    end
end

local function failAttempt(attempt)
    if attempt.completed then return end
    attempt.completed = true
    attempt.pending:fail()
    clearAttempt(attempt)
end

function AutoEatCans.onOpenStart(attempt, action)
    if not attempt or attempt.cancelled then return end
    attempt.action = action
    local okData, recipeData = pcall(function() return action.logic:getRecipeData() end)
    if not okData or not recipeData then
        failAttempt(attempt)
        return
    end
    attempt.recipeData = recipeData
    local okStart = pcall(function() attempt.logic:startCraftAction(action) end)
    if not okStart then
        failAttempt(attempt)
        return
    end
    attempt.craftStarted = true
end

function AutoEatCans.onOpenCancel(attempt)
    if not attempt then return end
    attempt.cancelled = true
    attempt.completed = true
    attempt.pending:cancel()
    stopCraftLogic(attempt, true)
    clearAttempt(attempt)
end

function AutoEatCans.onOpenComplete(attempt)
    if not attempt then return end
    stopCraftLogic(attempt, attempt.cancelled)
    if attempt.cancelled or attempt.completed then
        clearAttempt(attempt)
        return
    end

    if not attempt.recipeData then
        failAttempt(attempt)
        return
    end

    local item = createdOutput(attempt.recipeData, attempt.expectedType)
    if not item or not itemIsInContainer(attempt.player:getInventory(), item)
            or not AutoEat.isAllowedFood(item, attempt.player, attempt.expectedType) then
        failAttempt(attempt)
        return
    end

    local hunger
    local okHunger = pcall(function()
        hunger = attempt.player:getStats():get(CharacterStat.HUNGER)
    end)
    if not okHunger or not hunger or hunger < AutoEat.HUNGER_THRESHOLD then
        failAttempt(attempt)
        return
    end

    if not ISEatFoodAction or not attempt.pending:finish() then
        failAttempt(attempt)
        return
    end

    attempt.completed = true
    AutoEat.queueEatAction(attempt.player, item, hunger)
    clearAttempt(attempt)
end

function AutoEatCans.queueOpenAction(player, canItem, definition)
    if AutoEatCans.pending or not player or not canItem or not definition then return false end

    local recipe = getScriptManager():getCraftRecipe(definition.recipeName)
    if not recipe then return false end

    local logic = HandcraftLogic.new(player, nil, nil)
    local containers = ArrayList.new()
    addContainersRecursively(player:getInventory(), containers)
    logic:setContainers(containers)
    logic:setRecipeFromContextClick(recipe, canItem)
    if not logic:canPerformCurrentRecipe() then return false end

    local action = ISEntityUI.HandcraftStart(player, logic, false, false, 0)
    if not action then return false end

    local pending = newPendingCan()

    local attempt = {
        player = player,
        canItem = canItem,
        expectedType = definition.expectedType,
        logic = logic,
        pending = pending,
        action = action,
    }
    AutoEatCans.pending = attempt

    action:setOnStart(AutoEatCans.onOpenStart, attempt)
    action:setOnComplete(AutoEatCans.onOpenComplete, attempt)
    action:setOnCancel(AutoEatCans.onOpenCancel, attempt)
    ISTimedActionQueue.add(action)
    return true
end

function AutoEatCans.queueBestCan(player, hunger)
    if AutoEatCans.pending or not player or hunger < AutoEat.HUNGER_THRESHOLD then return false end
    local canItem, definition = findCan(player:getInventory())
    if not canItem then return false end
    return AutoEatCans.queueOpenAction(player, canItem, definition)
end

function AutoEatCans.update(player)
    local attempt = AutoEatCans.pending
    if not attempt or not attempt.action or attempt.cancelled or attempt.completed then return end
    if ISTimedActionQueue.hasAction and not ISTimedActionQueue.hasAction(attempt.action) then
        attempt.cancelled = true
        attempt.completed = true
        attempt.pending:cancel()
        stopCraftLogic(attempt, true)
        clearAttempt(attempt)
    end
end
