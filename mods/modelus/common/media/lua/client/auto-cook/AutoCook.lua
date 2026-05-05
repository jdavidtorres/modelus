-- AutoCook.lua
-- Adds an "Auto Cook" context-menu option on cookable base items.
-- On click, automatically picks the best available food ingredient from
-- reachable containers and queues it into the recipe, chaining until the
-- recipe is full or no valid ingredient remains.
-- Selection strategy: variety-first (bucket by usage count) then freshness.
-- v3 (rewrite) -- B42-compatible, Kahlua-safe.
-- Hook: Events.OnFillInventoryObjectContextMenu (additive, no patching).
-- Scope: client only.

require "TimedActions/ISAddItemInRecipe"
require "TimedActions/ISInventoryTransferAction"

-- ---------------------------------------------------------------------------
-- Module table
-- ---------------------------------------------------------------------------

local AutoCook = {}
AutoCook.LOG_PREFIX = "[Modelus][AutoCook]"
AutoCook.MaxDuplicate = 2

-- ---------------------------------------------------------------------------
-- Logging helper
-- ---------------------------------------------------------------------------

local function log(msg)
    print(AutoCook.LOG_PREFIX .. " " .. tostring(msg))
end

-- ---------------------------------------------------------------------------
-- ModelusAutoCookContinue timed action
-- Zero-duration timed action that re-enters session:continue() after the
-- previous ISAddItemInRecipe finishes.
-- ---------------------------------------------------------------------------

ModelusAutoCookContinue = ISBaseTimedAction:derive("ModelusAutoCookContinue")

function ModelusAutoCookContinue:new(player, session)
    local o = ISBaseTimedAction.new(self, player)
    setmetatable(o, self)
    self.__index = self
    o.player     = player
    o.session    = session
    o.stopOnWalk = false
    o.stopOnRun  = false
    o.maxTime    = 1
    return o
end

function ModelusAutoCookContinue:isValid()
    if not self.session then return false end
    if not self.session.baseItem then return false end
    if self.session.baseItem:isRemoved() then return false end
    return true
end

function ModelusAutoCookContinue:update()
end

function ModelusAutoCookContinue:start()
end

function ModelusAutoCookContinue:stop()
    ISBaseTimedAction.stop(self)
end

function ModelusAutoCookContinue:perform()
    self.session:continue()
    ISBaseTimedAction.perform(self)
end

-- ---------------------------------------------------------------------------
-- AutoCook.Session
-- ---------------------------------------------------------------------------

AutoCook.Session = {}
AutoCook.Session.__index = AutoCook.Session

function AutoCook.Session:new(player, recipe, baseItem, containerList)
    local s = setmetatable({}, AutoCook.Session)
    s.player        = player
    s.recipe        = recipe
    s.baseItem      = baseItem
    s.containerList = containerList
    s.useCounts     = {}
    s.addAction     = nil
    return s
end

-- ---------------------------------------------------------------------------
-- Session:pickCandidate()
-- Variety-first selection; tie-break by freshness.
-- ---------------------------------------------------------------------------

local function freshnessScore(item)
    local offAgeMax = item:getOffAgeMax()
    local age       = item:getAge()
    return offAgeMax - age
end

function AutoCook.Session:pickCandidate()
    local items
    local ok, err = pcall(function()
        items = self.recipe:getItemsCanBeUse(self.player, self.baseItem, self.containerList)
    end)
    if not ok or not items then
        log("pickCandidate: getItemsCanBeUse error: " .. tostring(err))
        return nil
    end

    local best        = nil
    local bestCount   = AutoCook.MaxDuplicate + 1
    local bestFresh   = -9999

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            -- Must be food
            if not instanceof(item, "Food") then
                -- skip non-food
            else
                -- Reject frozen when not allowed
                local frozen = false
                if item.isFrozen then
                    frozen = item:isFrozen()
                end
                local allowFrozen = true
                if self.recipe.isAllowFrozenItem then
                    allowFrozen = self.recipe:isAllowFrozenItem()
                end
                if frozen and not allowFrozen then
                    -- skip frozen
                elseif false then
                    -- placeholder
                else
                    -- Reject needToBeCooked
                    local needCooked = false
                    if self.recipe.needToBeCooked then
                        local ok2, val = pcall(function() return self.recipe:needToBeCooked(item) end)
                        if ok2 then needCooked = val end
                    end

                    if needCooked then
                        -- skip
                    else
                        -- Reject rotten
                        local rotten = false
                        if item.isRotten then
                            local ok3, val = pcall(function() return item:isRotten() end)
                            if ok3 then rotten = val end
                        end

                        -- Reject poisoned
                        local poisoned = false
                        if self.player.isKnownPoison then
                            local ok4, val = pcall(function() return self.player:isKnownPoison(item) end)
                            if ok4 then poisoned = val end
                        end

                        if not rotten and not poisoned then
                            local fullType = item:getFullType()
                            local count = self.useCounts[fullType] or 0

                            if count < AutoCook.MaxDuplicate then
                                local fresh = freshnessScore(item)
                                -- variety-first: prefer lower count; tie-break by freshness
                                if count < bestCount or (count == bestCount and fresh > bestFresh) then
                                    best      = item
                                    bestCount = count
                                    bestFresh = fresh
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

-- ---------------------------------------------------------------------------
-- Session:start() -- begins the auto-cook chain
-- ---------------------------------------------------------------------------

function AutoCook.Session:start()
    log("chain start on " .. tostring(self.baseItem:getName()))

    local chosen = self:pickCandidate()
    if not chosen then
        log("chain end: no candidates")
        return
    end

    -- Transfer base item to player inventory if needed
    if not self.player:getInventory():contains(self.baseItem) then
        ISTimedActionQueue.add(
            ISInventoryTransferAction:new(self.player, self.baseItem, self.baseItem:getContainer(), self.player:getInventory(), 1)
        )
    end

    -- Transfer ingredient if needed
    if not self.player:getInventory():contains(chosen) then
        ISTimedActionQueue.add(
            ISInventoryTransferAction:new(self.player, chosen, chosen:getContainer(), self.player:getInventory(), 1)
        )
    end

    -- Track usage
    local fullType = chosen:getFullType()
    self.useCounts[fullType] = (self.useCounts[fullType] or 0) + 1

    -- Queue add-ingredient action
    self.addAction = ISAddItemInRecipe:new(self.player, self.recipe, self.baseItem, chosen)
    log("queuing ISAddItemInRecipe for " .. tostring(fullType))
    ISTimedActionQueue.add(self.addAction)

    -- Queue continue action
    ISTimedActionQueue.add(ModelusAutoCookContinue:new(self.player, self))
end

-- ---------------------------------------------------------------------------
-- Session:continue() -- called by ModelusAutoCookContinue:perform()
-- ---------------------------------------------------------------------------

function AutoCook.Session:continue()
    -- Refresh baseItem in case ISAddItemInRecipe swapped it
    if self.addAction then
        if self.addAction.baseItem then
            self.baseItem = self.addAction.baseItem
        end
    end

    if not self.baseItem then
        log("chain end: baseItem is nil")
        return
    end

    if self.baseItem:isRemoved() then
        log("chain end: baseItem removed")
        return
    end

    -- Check if recipe is full
    local curItems = 0
    local maxItems = 0
    if self.recipe.getCurrentItems then
        local ok1, v1 = pcall(function() return self.recipe:getCurrentItems() end)
        if ok1 then curItems = v1 end
    end
    if self.recipe.getMaxIngredients then
        local ok2, v2 = pcall(function() return self.recipe:getMaxIngredients() end)
        if ok2 then maxItems = v2 end
    end

    if maxItems > 0 and curItems >= maxItems then
        log("chain end: recipe full (" .. curItems .. "/" .. maxItems .. ")")
        return
    end

    local chosen = self:pickCandidate()
    if not chosen then
        log("chain end: no candidates")
        return
    end

    -- Transfer ingredient if needed
    if not self.player:getInventory():contains(chosen) then
        ISTimedActionQueue.add(
            ISInventoryTransferAction:new(self.player, chosen, chosen:getContainer(), self.player:getInventory(), 1)
        )
    end

    -- Track usage
    local fullType = chosen:getFullType()
    self.useCounts[fullType] = (self.useCounts[fullType] or 0) + 1

    -- Queue add-ingredient action
    self.addAction = ISAddItemInRecipe:new(self.player, self.recipe, self.baseItem, chosen)
    log("queuing ISAddItemInRecipe for " .. tostring(fullType))
    ISTimedActionQueue.add(self.addAction)

    -- Queue next continue
    ISTimedActionQueue.add(ModelusAutoCookContinue:new(self.player, self))
end

-- ---------------------------------------------------------------------------
-- Context-menu hook
-- ---------------------------------------------------------------------------

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    -- Only act on a single-item selection
    if not items or #items ~= 1 then return end

    local stack = items[1]
    -- Entries can be a stack table or a bare item; normalise
    local item = stack
    if stack.items then
        item = stack.items[1]
    end

    if not item then return end
    if not instanceof(item, "Food") then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local containerList = ISInventoryPaneContextMenu.getContainers(player)
    if not containerList then
        log("no containers for player " .. tostring(playerNum))
        return
    end

    if not RecipeManager then return end
    if not RecipeManager.getEvolvedRecipe then return end

    local ok, recipeList = pcall(function()
        return RecipeManager.getEvolvedRecipe(item, player, containerList, false)
    end)
    if not ok or not recipeList then return end
    if recipeList:size() == 0 then return end

    log(recipeList:size() .. " evolved recipe(s) for " .. tostring(item:getType()))

    for ri = 0, recipeList:size() - 1 do
        local recipe = recipeList:get(ri)
        if recipe then
            -- Check if recipe is full
            local curItems = 0
            local maxItems = 0
            if recipe.getCurrentItems then
                local ok1, v1 = pcall(function() return recipe:getCurrentItems() end)
                if ok1 then curItems = v1 end
            end
            if recipe.getMaxIngredients then
                local ok2, v2 = pcall(function() return recipe:getMaxIngredients() end)
                if ok2 then maxItems = v2 end
            end

            local isFull = (maxItems > 0 and curItems >= maxItems)

            -- Build option label
            local recipeName = "Auto Cook"
            if recipe.getUntranslatedName then
                local ok3, rname = pcall(function() return recipe:getUntranslatedName() end)
                if ok3 and rname and rname ~= "" then
                    recipeName = "Auto Cook (" .. rname .. ")"
                end
            end

            -- Capture loop variables for the closure
            local capturedRecipe = recipe
            local capturedItem   = item

            local option = context:addOption(
                recipeName,
                nil,
                function()
                    local session = AutoCook.Session:new(player, capturedRecipe, capturedItem, containerList)
                    session:start()
                end
            )

            if isFull then
                option.notAvailable = true
                log("option disabled: recipe full")
            else
                log("option added: " .. tostring(recipeName))
            end
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)

print(AutoCook.LOG_PREFIX .. " loaded; context hook registered")
