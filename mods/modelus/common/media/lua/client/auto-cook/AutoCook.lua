-- AutoCook.lua
-- Adds an "Auto Cook" context-menu option on cookable base items.
-- On click, automatically picks the best available food ingredient from
-- reachable containers and queues it into the recipe, chaining until the
-- recipe is full or no valid ingredient remains.
-- Selection strategy: variety-first (bucket by usage count) then freshness.
-- v1 — no persistent settings, no nutrition modes, no AutoCraft.
-- Hook: Events.OnFillInventoryObjectContextMenu (additive, no patching).
-- Scope: client only.

local _LOG_PREFIX = "[Modelus][AutoCook]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

-- ---------------------------------------------------------------------------
-- Module table
-- ---------------------------------------------------------------------------

AutoCook = AutoCook or {}
AutoCook.OPTIONS = AutoCook.OPTIONS or {}
AutoCook.OPTIONS.MaxDuplicate = AutoCook.OPTIONS.MaxDuplicate or 2

-- ---------------------------------------------------------------------------
-- Private: ModelusAutoCookContinue
-- Zero-duration timed action that re-enters session:continue() after the
-- previous ISAddItemInRecipe finishes.  Named with the "Modelus" namespace to
-- avoid colliding with any third-party ISContinue global.
-- ---------------------------------------------------------------------------

local ModelusAutoCookContinue = ISBaseTimedAction:derive("ModelusAutoCookContinue")

function ModelusAutoCookContinue:isValid()
    return self.session ~= nil
        and self.session.baseItem ~= nil
        and not self.session.baseItem:isRemoved()
end

function ModelusAutoCookContinue:update()
    -- zero-duration: nothing to tick
end

function ModelusAutoCookContinue:start()
    logDebug("ModelusAutoCookContinue:start")
end

function ModelusAutoCookContinue:stop()
    logDebug("ModelusAutoCookContinue:stop")
    ISBaseTimedAction.stop(self)
end

function ModelusAutoCookContinue:perform()
    logDebug("ModelusAutoCookContinue:perform")
    ISBaseTimedAction.perform(self)
    if self.session then
        self.session:continue()
    end
end

function ModelusAutoCookContinue:new(session, character)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    o.session      = session
    o.character    = character
    o.stopOnWalk   = false
    o.stopOnRun    = false
    o.maxTime      = 1
    return o
end

-- ---------------------------------------------------------------------------
-- Private: Session
-- Holds per-click state: player, recipe, baseItem, usage counters.
-- Discarded naturally when the chain ends (no modData written).
-- ---------------------------------------------------------------------------

local Session = {}
Session.__index = Session

function Session.new(player, recipe, baseItem)
    local s = setmetatable({}, Session)
    s.playerObj = player
    s.recipe    = recipe
    s.baseItem  = baseItem
    s.addAction = nil
    s.usedItems = {}   -- map: fullType -> count
    local recipeName = recipe
    if recipe and recipe.getUntranslatedName then
        recipeName = recipe:getUntranslatedName()
    end
    logDebug("Session.new recipe=" .. tostring(recipeName))
    return s
end

--- Returns the number of times this fullType has been queued this session.
function Session:countUsed(fullType)
    return self.usedItems[fullType] or 0
end

--- Increments the usage counter for a fullType.
function Session:markUsed(fullType)
    self.usedItems[fullType] = (self.usedItems[fullType] or 0) + 1
end

--- Returns true when the item passes all v1 safety filters.
function Session:filterCandidate(item)
    if not instanceof(item, "Food") then
        return false
    end
    if item:isSpice() then
        return false
    end
    if item:isRotten() then
        return false
    end
    if self.playerObj:isKnownPoison(item) then
        return false
    end
    -- Dangerous-uncooked items may only be added to a cookable recipe.
    if item:isbDangerousUncooked() and not item:isCooked() then
        if not self.recipe:isCookable() then
            return false
        end
    end
    return true
end

--- Freshness heuristic: higher is fresher.
--- Uses remaining shelf life (offAgeMax - age) when available, else 0.
local function freshnessScore(item)
    local offAgeMax = item:getOffAgeMax()
    local age       = item:getAge()
    return offAgeMax - age
end

--- Variety-first selection: bucket candidates by usage count (ascending),
--- walk buckets up to MaxDuplicate, pick freshest item in first non-empty bucket.
--- Returns chosen item or nil.
function Session:chooseItem(items)
    if not items or items:size() == 0 then
        return nil
    end

    -- Build buckets: buckets[usageCount+1] = { item, ... }
    local buckets = {}
    for i = 1, items:size() do
        local item = items:get(i - 1)
        if self:filterCandidate(item) then
            local bucket = self:countUsed(item:getFullType()) + 1
            if bucket <= AutoCook.OPTIONS.MaxDuplicate then
                if not buckets[bucket] then buckets[bucket] = {} end
                table.insert(buckets[bucket], item)
            end
        end
    end

    -- Walk from bucket 1 (least used types) upward.
    for b = 1, AutoCook.OPTIONS.MaxDuplicate do
        local list = buckets[b]
        if list and #list > 0 then
            -- Pick freshest in this bucket.
            local best = list[1]
            for i = 2, #list do
                if freshnessScore(list[i]) > freshnessScore(best) then
                    best = list[i]
                end
            end
            logDebug("Session:chooseItem → " .. tostring(best:getFullType()) .. " bucket=" .. b)
            return best
        end
    end

    logDebug("Session:chooseItem → nil (no valid candidate within MaxDuplicate)")
    return nil
end

--- Main loop body. Called by ModelusAutoCookContinue:perform() after each
--- ISAddItemInRecipe finishes.
function Session:continue()
    -- Update baseItem in case ISAddItemInRecipe swapped it (stage completion).
    if self.addAction and self.addAction.baseItem then
        self.baseItem = self.addAction.baseItem
        logDebug("Session:continue baseItem updated to " .. tostring(self.baseItem:getName()))
    end

    if not self.baseItem or self.baseItem:isRemoved() then
        logDebug("Session:continue baseItem gone — stopping")
        return
    end

    logDebug("Session:continue on " .. tostring(self.baseItem:getName()))

    local containerList = ISInventoryPaneContextMenu.getContainers(self.playerObj)
    if not containerList then
        logDebug("Session:continue no containers — stopping")
        return
    end

    local items = self.recipe:getItemsCanBeUse(self.playerObj, self.baseItem, containerList)
    local chosen = self:chooseItem(items)
    if items and items.clear then items:clear() end   -- release Java references

    if not chosen then
        logDebug("Session:continue no candidate chosen — stopping cleanly")
        return
    end

    -- Transfer from remote container if necessary.
    if not self.playerObj:getInventory():contains(chosen) then
        logDebug("Session:continue queuing transfer for " .. tostring(chosen:getFullType()))
        ISTimedActionQueue.add(
            ISInventoryTransferAction:new(self.playerObj, chosen, chosen:getContainer(), self.playerObj:getInventory(), nil)
        )
    end

    -- Mark the type used BEFORE queuing so the next iteration sees it.
    self:markUsed(chosen:getFullType())

    -- Queue the vanilla add-ingredient action.
    local cookingPerk = self.playerObj:getPerkLevel(Perks.Cooking) or 0
    self.addAction = ISAddItemInRecipe:new(self.playerObj, self.recipe, self.baseItem, chosen, 70 - cookingPerk)
    logDebug("Session:continue queuing ISAddItemInRecipe for " .. tostring(chosen:getFullType()))
    ISTimedActionQueue.add(self.addAction)

    -- Re-queue ourselves so we fire after the add action completes.
    ISTimedActionQueue.add(ModelusAutoCookContinue:new(self, self.playerObj))
end

-- ---------------------------------------------------------------------------
-- Context-menu hook
-- ---------------------------------------------------------------------------

--- Returns the first active evolved recipe for `item`, or nil.
local function getActiveRecipe(item)
    -- B42 primary path: single evolved recipe accessor.
    if item.getEvolvedRecipe then
        local r = item:getEvolvedRecipe()
        if r then return r end
    end
    -- Fallback: iterate all evolved recipes, pick first.
    if item.getEvolvedRecipes then
        local list = item:getEvolvedRecipes()
        if list and list.size and list:size() > 0 then
            return list:get(0)
        end
    end
    return nil
end

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    -- Only act on a single-item selection.
    if not items or #items ~= 1 then return end

    local stack = items[1]
    -- items[] entries can be a stack table or a bare item; normalise.
    local item = stack.items and stack.items[1] or stack

    if not item or not instanceof(item, "Food") then return end

    local recipe = getActiveRecipe(item)
    if not recipe then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- Hide option when recipe is already at capacity.
    local maxItems = recipe:getMaxItems()
    local curItems = 0
    local extra = item:getExtraItems()
    if extra and extra.size then curItems = extra:size() end

    local option = context:addOption(
        getText("ContextMenu_AutoCook"),
        player,
        function(playerObj, _recipe, baseItem)
            logDebug("context menu clicked — starting session")
            local session = Session.new(playerObj, _recipe, baseItem)
            session:continue()
        end,
        recipe,
        item
    )

    if maxItems > 0 and curItems >= maxItems then
        option.notAvailable = true
        logDebug("onFillInventoryObjectContextMenu: recipe full — option disabled")
    else
        logDebug("onFillInventoryObjectContextMenu: option added for " .. tostring(item:getType()))
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
