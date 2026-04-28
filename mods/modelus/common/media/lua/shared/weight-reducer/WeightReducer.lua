-- WeightReducer.lua
-- Reduces the weight of selected materials plus category-driven tool/weapon
-- items to 30% of vanilla values.
-- Trigger: OnGameStart for script items + OnPlayerUpdate for live inventory
--          normalization.
-- Scope: shared (client + server) for MP consistency.

local _LOG_PREFIX = "[Modelus][WeightReducer]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

WeightReducer = {}

-- Multiplier applied to the vanilla weight of each item in ITEMS.
-- 0.3 = 30% of original weight (70% reduction).
WeightReducer.MULTIPLIER = 0.3

-- Explicit material allowlist.
-- Firewood is intentionally excluded: its weight determines campfire burn time.
WeightReducer.MATERIAL_ITEMS = {
    -- Construction materials
    "Base.Log",
    "Base.Plank",
    "Base.Nails",
    "Base.NailsBox",
    "Base.Screws",
    "Base.ScrewsBox",
    "Base.Wire",
    "Base.BarbedWire",
    "Base.ConcretePowder",
    "Base.PlasterPowder",
    "Base.Gravelbag",
    "Base.Sandbag",
    "Base.BucketConcreteFull",
    "Base.BucketPlasterFull",
    "Base.SheetMetal",
    "Base.MetalBar",
    "Base.MetalPipe",
    "Base.ScrapMetal",
    "Base.SmallSheetMetal",
    "Base.UnusableMetal",

}

-- Category-driven reduction for script items that the vanilla game already
-- models as hybrid tools/weapons or gardening gear.
WeightReducer.REDUCED_DISPLAY_CATEGORIES = {
    ToolWeapon = true,
    GardeningWeapon = true,
    Gardening = true,
}

-- Explicit weapon types to reduce even if their DisplayCategory isn't one of
-- the hybrid categories above.
WeightReducer.WEAPON_ITEMS = {
    "Base.BaseballBat",
    "Base.Nightstick",
    "Base.HuntingKnife",
    "Base.KitchenKnife",
    "Base.Machete",
    "Base.Katana",
    "Base.SpearCrafted",
    "Base.Pistol",
    "Base.Pistol2",
    "Base.Pistol3",
    "Base.Revolver",
    "Base.Revolver_Long",
    "Base.Revolver_Short",
    "Base.Shotgun",
    "Base.DoubleBarrelShotgun",
    "Base.VarmintRifle",
    "Base.HuntingRifle",
    "Base.AssaultRifle",
    "Base.AssaultRifle2",
}

-- Items that may match a broad display category but should keep vanilla weight.
WeightReducer.DENYLIST = {
    ["Base.Firewood"] = true,
}

-- Guard: prevents double-application if OnGameStart fires more than once.
WeightReducer._applied = false
WeightReducer._updateTick = 0
WeightReducer.UPDATE_INTERVAL_TICKS = 120

local function buildLookup(list)
    local lookup = {}
    for _, fullType in ipairs(list) do
        lookup[fullType] = true
    end
    return lookup
end

WeightReducer._materialLookup = buildLookup(WeightReducer.MATERIAL_ITEMS)
WeightReducer._weaponLookup = buildLookup(WeightReducer.WEAPON_ITEMS)

local function isLiterature(scriptItem)
    local ok, result = pcall(function()
        return scriptItem:isItemType(ItemType.LITERATURE)
    end)
    return ok and result == true
end

local function isReducedByCategory(scriptItem)
    local displayCategory = scriptItem.getDisplayCategory and scriptItem:getDisplayCategory()
    if not displayCategory or not WeightReducer.REDUCED_DISPLAY_CATEGORIES[displayCategory] then
        return false
    end

    -- Gardening is broad and includes seed packets/books; we still want real
    -- usable gardening gear, not literature.
    if displayCategory == "Gardening" and isLiterature(scriptItem) then
        return false
    end

    return true
end

local function shouldReduce(scriptItem)
    if not scriptItem then return false end
    local okHidden, isHidden = pcall(function() return scriptItem:isHidden() end)
    if okHidden and isHidden then return false end

    local okObsolete, isObsolete = pcall(function() return scriptItem:getObsolete() end)
    if okObsolete and isObsolete then return false end

    local okFullType, fullType = pcall(function() return scriptItem:getFullName() end)
    if not okFullType or not fullType then return false end

    if WeightReducer.DENYLIST[fullType] then
        return false
    end

    if WeightReducer._materialLookup[fullType] then
        return true
    end

    if WeightReducer._weaponLookup[fullType] then
        return true
    end

    return isReducedByCategory(scriptItem)
end

local function applyWeightReduction(scriptItem)
    if not scriptItem then
        return
    end

    local okWeight, originalWeight = pcall(function() return scriptItem:getWeight() end)
    if not okWeight or not originalWeight then return end

    local newWeight = originalWeight * WeightReducer.MULTIPLIER
    local okSet = pcall(function() scriptItem:setWeight(newWeight) end)
    if not okSet then return end

    local okName, fullType = pcall(function() return scriptItem:getFullName() end)
    if okName and fullType then
        logDebug(fullType .. ": " .. tostring(originalWeight) .. " → " .. tostring(newWeight))
    end
end

local function applyInventoryItemReduction(item)
    if not item then return end

    local okScriptItem, scriptItem = pcall(function() return item:getScriptItem() end)
    if not okScriptItem or not scriptItem then return end

    if not shouldReduce(scriptItem) then
        return
    end

    local okTarget, targetWeight = pcall(function() return scriptItem:getWeight() end)
    if not okTarget or not targetWeight then return end

    local okActual, actualWeight = pcall(function() return item:getActualWeight() end)
    local okWeight, currentWeight = pcall(function() return item:getWeight() end)
    if okActual and okWeight and (actualWeight ~= targetWeight or currentWeight ~= targetWeight) then
        pcall(function() item:setActualWeight(targetWeight) end)
        pcall(function() item:setWeight(targetWeight) end)
        pcall(function() item:setCustomWeight(true) end)

        local okType, fullType = pcall(function() return item:getFullType() end)
        if okType and fullType then
            logDebug("inventory item normalized: " .. tostring(fullType) .. " → " .. tostring(targetWeight))
        end
    end

    local okIsContainer, isContainer = pcall(function() return item:IsInventoryContainer() end)
    if okIsContainer and isContainer then
        local okInventory, inventory = pcall(function() return item:getInventory() end)
        if not okInventory or not inventory then return end

        local nestedItems = inventory:getItems()
        for i = 1, nestedItems:size() do
            applyInventoryItemReduction(nestedItems:get(i - 1))
        end
    end
end

local function normalizePlayerInventory(player)
    if not player or not player.getInventory then return end

    local items = player:getInventory():getItems()
    for i = 1, items:size() do
        applyInventoryItemReduction(items:get(i - 1))
    end
end

-- ---------------------------------------------------------------------------
-- Core
-- ---------------------------------------------------------------------------

--- Applies the weight multiplier to configured materials and to script items
--- selected by real vanilla display categories.
--- Safe to call multiple times — only runs once per session.
function WeightReducer.apply()
    if WeightReducer._applied then
        logDebug("already applied, skipping")
        return
    end
    WeightReducer._applied = true

    local allItems = getScriptManager():getAllItems()
    for i = 1, allItems:size() do
        local scriptItem = allItems:get(i - 1)
        if shouldReduce(scriptItem) then
            applyWeightReduction(scriptItem)
        end
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

-- ---------------------------------------------------------------------------
-- Hook
-- ---------------------------------------------------------------------------

Events.OnGameStart.Add(WeightReducer.apply)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
