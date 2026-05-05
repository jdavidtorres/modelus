-- AutoEat.lua
-- Automatically eats prepared meals when hungry enough.
-- Selection policy (STRICT): item must be EXPLICITLY prepared/cooked.
--   Allowed: isCooked()==true OR name/type matches a PREPARED_KEYWORDS entry.
--   Blocked: raw ingredients, spices, condiments, rotten, known poison,
--            dangerous-uncooked, items matching RAW_INGREDIENT_PATTERNS.
-- Partial consumption is used when hunger is only moderate.
-- Hook: Events.OnPlayerUpdate (polling), throttled.
-- Scope: client only.

local _LOG_PREFIX = "[Modelus][AutoEat]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. tostring(msg))
    end
end

-- ---------------------------------------------------------------------------
-- Module table
-- ---------------------------------------------------------------------------

AutoEat = AutoEat or {}

-- Hunger level (0-100) at which auto-eat triggers.  Higher = hungrier.
AutoEat.HUNGER_THRESHOLD = 30

-- When hunger >= this, eat a full portion; otherwise eat a conservative 50%.
AutoEat.FULL_EAT_THRESHOLD = 60

-- Ticks between polls (~3 seconds at 60fps).
AutoEat.POLL_INTERVAL = 180

-- Internal tick counter.
AutoEat._tick = 0

-- ---------------------------------------------------------------------------
-- Block-lists: raw ingredients and condiments
-- ---------------------------------------------------------------------------

--- Substrings matched against the lowercased full item type.
--- Any match → item is a raw/base ingredient and is BLOCKED
--- (unless overridden by isCooked()==true at the very end of the filter).
local RAW_INGREDIENT_PATTERNS = {
    -- Vegetables / fruit (raw)
    "potato", "tomato", "carrot", "onion", "cabbage", "corn", "leek",
    "broccoli", "lettuce", "mushroom", "strawberry", "raspberry", "blackberry",
    "blueberry", "cherry", "pear", "plum",
    -- Raw meat / fish
    "rawmeat", "raw_meat", "chickenraw", "beefraw", "porkraw", "lambraw",
    "fishraw", "rabbit", "squirrel", "venison",
    -- Dry staples
    "flour", "rice", "pasta", "driedpasta", "driedrice",
    "sugar", "salt", "pepper",
    -- Eggs (raw state)
    "egg",
    -- Cooking fats
    "butter", "oliveoil",
    -- Yeast / raw dough
    "yeast", "dough",
}

--- Full item types that are condiments/spices — always blocked.
local CONDIMENT_TYPES = {
    ["Base.Salt"]             = true,
    ["Base.Pepper"]           = true,
    ["Base.HotSauce"]         = true,
    ["Base.Ketchup"]          = true,
    ["Base.Mustard"]          = true,
    ["Base.Mayonnaise"]       = true,
    ["Base.BarbequeSource"]   = true,
}

--- Returns true when the lowercased full type matches a raw-ingredient pattern.
local function isRawIngredientType(ftl)
    for _, pat in ipairs(RAW_INGREDIENT_PATTERNS) do
        if ftl:find(pat, 1, true) then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Allow-list: prepared / cooked meal keywords
-- ---------------------------------------------------------------------------

--- An item MUST match at least one of these (in name or full type, lowercased)
--- OR be flagged isCooked()==true to pass the prepared-food gate.
local PREPARED_KEYWORDS = {
    -- Dish types
    "soup", "stew", "bowl", "sandwich", "salad", "meal",
    "roast", "baked", "fried", "grilled", "boiled", "scrambled",
    "omelet", "omelette", "pie", "casserole",
    -- Prepared starches. Keep generic "pasta" out: dry pasta is an ingredient.
    "noodle", "spaghetti", "lasagna", "macaroni", "porridge", "oatmeal", "cereal",
    -- Prepared proteins / assembled items
    "burger", "hotdog", "pizza", "taco", "burrito", "wrap",
    "steak", "chop", "fillet", "curry", "chilli", "chili",
    -- Generic cooked markers in type names
    "cooked", "prepared",
    -- Bread products (baked)
    "bread", "toast", "muffin", "biscuit", "cracker",
    -- Canned / processed ready-to-eat
    "canned", "tinned",
}

--- Returns true when name/type suggests a prepared meal.
local function isPreparedKeyword(name, ft)
    local combined = (name .. " " .. ft):lower()
    for _, kw in ipairs(PREPARED_KEYWORDS) do
        if combined:find(kw, 1, true) then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Selection logic
-- ---------------------------------------------------------------------------

--- STRICT filter: item must pass ALL rejection checks AND the prepared-meal gate.
function AutoEat.isAllowedFood(item, player)
    if not item then return false end

    -- Must be a Food instance.
    local ok1, isFood = pcall(function() return instanceof(item, "Food") end)
    if not (ok1 and isFood) then return false end

    -- Must reduce hunger (PZ: negative hunger value quenches hunger).
    local ok2, hunger = pcall(function() return item:getHunger() end)
    if not ok2 then return false end
    if not hunger or hunger >= 0 then return false end

    -- Exclude spices (API check).
    local ok3, isSpice = pcall(function() return item:isSpice() end)
    if ok3 and isSpice then return false end

    -- Exclude condiments by full type.
    local ft = ""
    pcall(function() ft = item:getFullType() end)
    if CONDIMENT_TYPES[ft] then return false end

    -- Exclude rotten food.
    local ok4, rotten = pcall(function() return item:isRotten() end)
    if ok4 and rotten then return false end

    -- Exclude known poisons.
    if player then
        local ok5, poison = pcall(function() return player:isKnownPoison(item) end)
        if ok5 and poison then return false end
    end

    -- Exclude dangerous-uncooked items that are not cooked.
    local ok6, dangerous = pcall(function() return item:isbDangerousUncooked() end)
    local okC, cooked    = pcall(function() return item:isCooked() end)
    if ok6 and dangerous then
        if not (okC and cooked) then return false end
    end

    local name = ""
    pcall(function() name = item:getName() end)

    -- Exclude raw ingredient types unless the item is explicitly cooked or its
    -- name/type clearly describes a prepared dish. This allows transformed foods
    -- like TomatoSoup/PastaBowl while still blocking Base.Tomato/Base.Pasta.
    local ftl = ft:lower()
    if isRawIngredientType(ftl) then
        if not (okC and cooked) and not isPreparedKeyword(name, ft) then return false end
    end

    -- -----------------------------------------------------------------------
    -- PREPARED-MEAL GATE (strict positive check):
    -- Item must be either (a) isCooked()==true, OR (b) name/type matches a
    -- prepared-meal keyword.  Items that pass all rejection checks but are
    -- neither cooked nor keyword-matched are blocked (e.g. a plain raw apple
    -- not in the pattern list would still be caught here).
    -- -----------------------------------------------------------------------
    local isCookedItem = okC and cooked
    if not isCookedItem and not isPreparedKeyword(name, ft) then
        return false
    end

    return true
end

--- Score a food item; higher = more preferred.
--- Scoring only differentiates among already-allowed items.
function AutoEat.scoreFood(item)
    local score = 0

    -- Base: more filling = higher score.
    local hungerVal = 0
    pcall(function() hungerVal = -(item:getHunger()) end)
    score = score + hungerVal * 10

    -- Bonus for prepared-meal keyword in name/type.
    local name = ""
    local ft   = ""
    pcall(function() name = item:getName() end)
    pcall(function() ft   = item:getFullType() end)
    if isPreparedKeyword(name, ft) then
        score = score + 500
    end

    -- Bonus for isCooked().
    local ok, cooked = pcall(function() return item:isCooked() end)
    if ok and cooked then score = score + 200 end

    return score
end

-- ---------------------------------------------------------------------------
-- Recursive inventory collection
-- ---------------------------------------------------------------------------

--- Recursively collect all Food instances from `container` into Lua table `out`.
--- Mirrors the WeightReducer pattern: getItems() + IsInventoryContainer() recurse.
local function collectFoodItems(container, out)
    if not container then return end
    local items
    local ok = pcall(function() items = container:getItems() end)
    if not ok or not items then return end
    local count = 0
    pcall(function() count = items:size() end)
    for i = 0, count - 1 do
        local item
        pcall(function() item = items:get(i) end)
        if item then
            local isFood = false
            pcall(function() isFood = instanceof(item, "Food") end)
            if isFood then
                out[#out + 1] = item
            end
            -- Recurse into nested containers (bags inside bags, etc.).
            local isContainer = false
            pcall(function() isContainer = item:IsInventoryContainer() end)
            if isContainer then
                local nested
                pcall(function() nested = item:getInventory() end)
                if nested then
                    collectFoodItems(nested, out)
                end
            end
        end
    end
end

--- Find the best prepared food in player inventory (full recursive search).
function AutoEat.findBestFood(player)
    local inv
    local ok = pcall(function() inv = player:getInventory() end)
    if not ok or not inv then return nil end

    local candidates = {}
    collectFoodItems(inv, candidates)

    local best      = nil
    local bestScore = -math.huge
    for _, item in ipairs(candidates) do
        if AutoEat.isAllowedFood(item, player) then
            local score = AutoEat.scoreFood(item)
            if score > bestScore then
                bestScore = score
                best = item
            end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Action dispatch
-- ---------------------------------------------------------------------------

--- Queue an eat action for `item`.
--- Uses a conservative portion (50%) when hunger is below FULL_EAT_THRESHOLD.
local function queueEatAction(player, item, hunger)
    local portion = 1  -- full
    if hunger < AutoEat.FULL_EAT_THRESHOLD then
        portion = 0.5  -- conservative partial eat
    end

    local ok, err = pcall(function()
        if ISEatFoodAction then
            local action = ISEatFoodAction:new(player, item, portion, 1)
            ISTimedActionQueue.add(action)
            logDebug("queued ISEatFoodAction portion=" .. tostring(portion) .. " for " .. tostring(item:getFullType()))
        else
            logDebug("ISEatFoodAction not available")
        end
    end)
    if not ok then
        logDebug("queueEatAction: error: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- Poll handler
-- ---------------------------------------------------------------------------

local function onPlayerUpdate(player)
    if player:getPlayerNum() ~= 0 then return end

    -- Throttle.
    AutoEat._tick = AutoEat._tick + 1
    if AutoEat._tick < AutoEat.POLL_INTERVAL then return end
    AutoEat._tick = 0

    -- Check hunger (PZ: higher = hungrier).
    local hunger = 0
    local okH = pcall(function() hunger = player:getHunger() end)
    if not okH then return end
    if hunger < AutoEat.HUNGER_THRESHOLD then return end

    -- Only act when queue is idle.
    local okQ, busy = pcall(function()
        return ISTimedActionQueue.isPlayerDoingAction and ISTimedActionQueue.isPlayerDoingAction(player)
    end)
    if not okQ or busy then
        logDebug("queue busy or check failed — skipping")
        return
    end

    -- Skip during combat/movement.
    local okA, attacking = pcall(function() return player:isAttacking() end)
    local okS, strafing  = pcall(function() return player:isStrafing() end)
    local okR, running   = pcall(function() return player:isRunning() end)
    if (okA and attacking) or (okS and strafing) or (okR and running) then
        logDebug("player in motion/combat — skipping")
        return
    end

    local item = AutoEat.findBestFood(player)
    if not item then
        logDebug("hungry but no valid prepared food found")
        return
    end

    logDebug("hunger=" .. tostring(hunger) .. " eating " .. tostring(item:getFullType()))
    queueEatAction(player, item, hunger)
end

-- ---------------------------------------------------------------------------
-- Event registration
-- ---------------------------------------------------------------------------

Events.OnPlayerUpdate.Add(onPlayerUpdate)
