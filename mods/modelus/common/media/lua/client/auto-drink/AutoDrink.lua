-- AutoDrink.lua
-- Automatically drinks when thirst is high enough.
-- Selection policy: soda/juice/named drinks first, plain water as fallback.
-- Alcohol is excluded by default.
-- Hook: Events.OnPlayerUpdate (polling), throttled.
-- Scope: client only.

local _LOG_PREFIX = "[Modelus][AutoDrink]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. tostring(msg))
    end
end

-- ---------------------------------------------------------------------------
-- Module table
-- ---------------------------------------------------------------------------

AutoDrink = AutoDrink or {}

-- Thirst level (0-100) at which auto-drink triggers.  Higher = thirstier.
AutoDrink.THIRST_THRESHOLD = 30

-- Ticks between polls (~3 seconds at 60fps).
AutoDrink.POLL_INTERVAL = 180

-- Internal tick counter.
AutoDrink._tick = 0

-- ---------------------------------------------------------------------------
-- Selection logic
-- ---------------------------------------------------------------------------

--- Full item types that are considered alcohol and should be excluded.
local ALCOHOL_TYPES = {
    ["Base.Beer"]         = true,
    ["Base.Wine"]         = true,
    ["Base.Bourbon"]      = true,
    ["Base.Whiskey"]      = true,
    ["Base.Vodka"]        = true,
    ["Base.Rum"]          = true,
    ["Base.Tequila"]      = true,
    ["Base.Gin"]          = true,
    ["Base.Champagne"]    = true,
    ["Base.Martini"]      = true,
    ["Base.Scotch"]       = true,
    ["Base.Brandy"]       = true,
    ["Base.Moonshine"]    = true,
    ["Base.MouthWash"]    = true,
}

--- Priority tiers for drink selection.  Higher = preferred.
--- Tier 3: named sodas/juices (best hydration value, palatable).
--- Tier 2: any non-water, non-alcohol drink.
--- Tier 1: plain water (fallback).
local function drinkTier(item)
    local ft = ""
    local ok = pcall(function() ft = item:getFullType() end)
    if not ok then return 0 end

    -- Exclude alcohol entirely.
    if ALCOHOL_TYPES[ft] then return 0 end

    -- Tier 3: preferred sodas / juices / named beverages.
    local preferred = {
        "Coke", "Cola", "Soda", "Pop", "Juice", "Orange", "Apple", "Lemonade",
        "Energy", "Coffee", "Tea", "Milk", "Smoothie", "Shake",
    }
    local name = ""
    pcall(function() name = item:getName() end)
    local nameLow = name:lower()
    local ftLow   = ft:lower()
    for _, kw in ipairs(preferred) do
        if nameLow:find(kw:lower()) or ftLow:find(kw:lower()) then
            return 3
        end
    end

    -- Tier 1: plain water = fallback tier.
    if ftLow:find("water") then
        return 1
    end

    -- Tier 2: any other drinkable non-alcohol, non-water.
    return 2
end

--- Returns true when the item is a valid drink candidate.
function AutoDrink.isAllowedDrink(item, player)
    if not item then return false end
    -- Must be a Food instance.
    local ok1, isFood = pcall(function() return instanceof(item, "Food") end)
    if not (ok1 and isFood) then return false end

    -- Must have thirst-quench value (PZ convention: negative = quenches thirst).
    local ok2, thirst = pcall(function() return item:getThirst() end)
    if not ok2 then return false end
    if not thirst or thirst >= 0 then return false end

    -- Exclude alcohol (tier == 0).
    local tier = drinkTier(item)
    if tier == 0 then return false end

    -- Skip rotten items.
    local ok3, rotten = pcall(function() return item:isRotten() end)
    if ok3 and rotten then return false end

    -- Skip known poisons.
    if player then
        local ok4, poison = pcall(function() return player:isKnownPoison(item) end)
        if ok4 and poison then return false end
    end

    return true
end

--- Score a drink candidate; higher = more preferred.
function AutoDrink.scoreDrink(item)
    local tier = drinkTier(item)
    -- Secondary: absolute thirst reduction (more negative = more hydrating).
    local thirstVal = 0
    pcall(function() thirstVal = -(item:getThirst()) end)
    return tier * 1000 + thirstVal
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

--- Find the best drink in player inventory (full recursive search).
--- Returns the best item or nil.
function AutoDrink.findBestDrink(player)
    local inv
    local ok = pcall(function() inv = player:getInventory() end)
    if not ok or not inv then return nil end

    local candidates = {}
    collectFoodItems(inv, candidates)

    local best      = nil
    local bestScore = -math.huge
    for _, item in ipairs(candidates) do
        if AutoDrink.isAllowedDrink(item, player) then
            local score = AutoDrink.scoreDrink(item)
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

--- Queue a drink action for `item`.  Guards against missing B42 constructors.
local function queueDrinkAction(player, item)
    local ok, err = pcall(function()
        if ISEatFoodAction then
            local action = ISEatFoodAction:new(player, item, 1, 1)
            ISTimedActionQueue.add(action)
            logDebug("queued ISEatFoodAction for " .. tostring(item:getFullType()))
        else
            logDebug("ISEatFoodAction not available")
        end
    end)
    if not ok then
        logDebug("queueDrinkAction: error: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- Poll handler
-- ---------------------------------------------------------------------------

local function onPlayerUpdate(player)
    if player:getPlayerNum() ~= 0 then return end

    -- Throttle.
    AutoDrink._tick = AutoDrink._tick + 1
    if AutoDrink._tick < AutoDrink.POLL_INTERVAL then return end
    AutoDrink._tick = 0

    -- Check thirst (PZ: higher = thirstier).
    local thirst = 0
    local okT = pcall(function() thirst = player:getThirst() end)
    if not okT then return end
    if thirst < AutoDrink.THIRST_THRESHOLD then return end

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

    local item = AutoDrink.findBestDrink(player)
    if not item then
        logDebug("thirsty but no valid drink found")
        return
    end

    logDebug("thirst=" .. tostring(thirst) .. " drinking " .. tostring(item:getFullType()))
    queueDrinkAction(player, item)
end

-- ---------------------------------------------------------------------------
-- Event registration
-- ---------------------------------------------------------------------------

Events.OnPlayerUpdate.Add(onPlayerUpdate)
