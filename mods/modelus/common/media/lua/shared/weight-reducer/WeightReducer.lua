-- WeightReducer.lua
-- Reduces the weight of selected materials, tools, weapons, gardening gear,
-- and ammunition to 10% of vanilla values (90% reduction).
-- Trigger: OnGameStart for script items + OnPlayerUpdate for live inventory
--          normalization.
-- Scope: shared (client + server) for MP consistency.
--
-- CATALOG SOURCE: WeightReducerCatalog.generated.lua is maintained in Lua.
--
-- The Lua catalog is validated by tests/lua/catalog_guard_test.lua.

local _LOG_PREFIX = "[Modelus][WeightReducer]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

WeightReducer = {}

-- 0.1 = 10% of original weight (90% reduction).
WeightReducer.MULTIPLIER = 0.1
WeightReducer._applied = false
WeightReducer._updateTick = 0
WeightReducer.UPDATE_INTERVAL_TICKS = 120
WeightReducer.ITEMS = {}
WeightReducer._lookup = {}

-- ── Catalog initialization ───────────────────────────────────────────────────
-- Load the Lua-maintained catalog.
-- BURNABLES NOTE:
-- Firewood, FirewoodBundle, Charcoal, CharcoalCrafted, Coke and similar fuel
-- items are intentionally excluded from the catalog. Their effective burn duration
-- is tied to weight via FireFuelRatio; reducing weight without compensating that
-- ratio would silently shorten fire duration. Burnables remain at vanilla weight.

local generatedOk = pcall(require, "weight-reducer/WeightReducerCatalog.generated")
if not generatedOk then
    generatedOk = pcall(require, "WeightReducerCatalog.generated")
end
if generatedOk and WeightReducerCatalog_Generated
        and WeightReducerCatalog_Generated.ITEMS
        and #WeightReducerCatalog_Generated.ITEMS > 0 then
    WeightReducer.ITEMS = WeightReducerCatalog_Generated.ITEMS
    WeightReducer._lookup = WeightReducerCatalog_Generated._lookup or {}
    WeightReducer.ITEMS_BY_FAMILY = WeightReducerCatalog_Generated.ITEMS_BY_FAMILY
    if WeightReducerCatalog_Generated.MULTIPLIER
            and WeightReducerCatalog_Generated.MULTIPLIER > 0
            and WeightReducerCatalog_Generated.MULTIPLIER <= 1 then
        WeightReducer.MULTIPLIER = WeightReducerCatalog_Generated.MULTIPLIER
    end
    logDebug("Loaded generated catalog: " .. tostring(#WeightReducer.ITEMS) .. " items")
else
    print(_LOG_PREFIX .. " [WARN] WeightReducerCatalog.generated.lua not found; "
        .. "weight reduction will remain disabled.")
end

if #WeightReducer.ITEMS == 0 then
    print(_LOG_PREFIX .. " [ERROR] No catalog source available. "
        .. "Weight reduction disabled.")
end

-- ── Runtime weight application ───────────────────────────────────────────────

local function shouldReduceFullType(fullType)
    return fullType and WeightReducer._lookup[fullType] == true
end

local function formatWeight(weight)
    return tostring(math.floor((weight * 10000) + 0.5) / 10000)
end

local function getScriptWeight(scriptItem)
    if not scriptItem then return nil end

    local ok, value = pcall(function()
        return scriptItem:getActualWeight()
    end)

    if ok and type(value) == "number" then
        return value
    end

    return nil
end

local function setScriptWeight(scriptItem, weight)
    if not scriptItem or not weight then return false end

    local weightValue = formatWeight(weight)
    local okParam = pcall(function()
        scriptItem:DoParam("Weight = " .. weightValue)
    end)

    if okParam then
        return true
    end

    local okSetter = pcall(function()
        scriptItem:setActualWeight(weight)
    end)

    return okSetter == true
end

local function setInventoryItemWeight(item, weight)
    if not item or not weight then return false end

    local okActual = pcall(function()
        item:setActualWeight(weight)
    end)
    local okWeight = pcall(function()
        item:setWeight(weight)
    end)
    pcall(function()
        item:setCustomWeight(true)
    end)

    return okActual or okWeight
end

local function applyScriptWeightReduction(fullType)
    local scriptItem = ScriptManager.instance:getItem(fullType)
    if not scriptItem then
        logDebug("script item not found, skipping: " .. tostring(fullType))
        return
    end

    local originalWeight = getScriptWeight(scriptItem)
    if not originalWeight then
        print(_LOG_PREFIX .. " [WARN] Could not read script weight for "
            .. tostring(fullType) .. "; skipping")
        return
    end

    local newWeight = originalWeight * WeightReducer.MULTIPLIER
    if not setScriptWeight(scriptItem, newWeight) then
        print(_LOG_PREFIX .. " [WARN] Could not write script weight for "
            .. tostring(fullType) .. "; skipping")
        return
    end
    logDebug(fullType .. ": " .. tostring(originalWeight) .. " → " .. tostring(newWeight))
end

-- Recursively normalize an inventory item and any nested containers.
-- IMPORTANT: We always recurse into nested inventories even when the container
-- item itself is not reducible, so reducible items inside normal bags are found.
local function normalizeInventoryItem(item)
    if not item then return end

    local fullType = item:getFullType()
    if shouldReduceFullType(fullType) then
        local scriptItem = item:getScriptItem()
        if scriptItem then
            local targetWeight = getScriptWeight(scriptItem)
            if targetWeight and (item:getActualWeight() ~= targetWeight or item:getWeight() ~= targetWeight) then
                setInventoryItemWeight(item, targetWeight)
                logDebug("inventory item normalized: " .. tostring(fullType) .. " → " .. tostring(targetWeight))
            end
        end
    end

    -- Always recurse into nested inventories regardless of this item's reducibility.
    if item:IsInventoryContainer() then
        local nested = item:getInventory()
        if nested then
            local nestedItems = nested:getItems()
            for i = 1, nestedItems:size() do
                normalizeInventoryItem(nestedItems:get(i - 1))
            end
        end
    end
end

local function normalizePlayerInventory(player)
    if not player then return end

    local items = player:getInventory():getItems()
    for i = 1, items:size() do
        normalizeInventoryItem(items:get(i - 1))
    end
end

local function normalizeLocalPlayerInventory()
    if not getPlayer then return end
    normalizePlayerInventory(getPlayer())
end

function WeightReducer.apply()
    if WeightReducer._applied then
        logDebug("already applied, skipping")
        return
    end

    WeightReducer._applied = true

    for _, fullType in ipairs(WeightReducer.ITEMS) do
        applyScriptWeightReduction(fullType)
    end
end

local function onPlayerUpdate(player)
    if not player or player:getPlayerNum() ~= 0 then
        return
    end

    WeightReducer._updateTick = WeightReducer._updateTick + 1
    if WeightReducer._updateTick < WeightReducer.UPDATE_INTERVAL_TICKS then
        return
    end

    WeightReducer._updateTick = 0
    normalizePlayerInventory(player)
end

Events.OnGameStart.Add(WeightReducer.apply)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnContainerUpdate.Add(normalizeLocalPlayerInventory)
