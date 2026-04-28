-- WeightReducer.lua
-- Reduces the weight of selected materials plus category-driven tool/weapon
-- items to 30% of vanilla values.
-- Trigger: OnGameStart — applies once at load time via ScriptManager.
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
    return scriptItem.isItemType and scriptItem:isItemType(ItemType.LITERATURE)
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
    if scriptItem.isHidden and scriptItem:isHidden() then return false end
    if scriptItem.getObsolete and scriptItem:getObsolete() then return false end

    local fullType = scriptItem:getFullName()
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
    local originalWeight = scriptItem:getWeight()
    local newWeight = originalWeight * WeightReducer.MULTIPLIER
    scriptItem:setWeight(newWeight)
    logDebug(scriptItem:getFullName() .. ": " .. tostring(originalWeight) .. " → " .. tostring(newWeight))
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

-- ---------------------------------------------------------------------------
-- Hook
-- ---------------------------------------------------------------------------

Events.OnGameStart.Add(WeightReducer.apply)
