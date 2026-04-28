-- WeightReducer.lua
-- Reduces the weight of selected materials, tools, weapons, and gardening gear
-- to 30% of vanilla values.
-- Trigger: OnGameStart for script items + OnPlayerUpdate for live inventory
--          normalization.
-- Scope: shared (client + server) for MP consistency.

local _LOG_PREFIX = "[Modelus][WeightReducer]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

WeightReducer = {}

-- 0.3 = 30% of original weight (70% reduction).
WeightReducer.MULTIPLIER = 0.3
WeightReducer._applied = false
WeightReducer._updateTick = 0
WeightReducer.UPDATE_INTERVAL_TICKS = 120

-- SAFE EXPLICIT APPROACH:
-- PZ/Kahlua does not behave reliably when sweeping every ScriptItem by metadata.
-- Keep this as an explicit fullType allowlist and normalize live inventory items
-- by matching their fullType directly.
WeightReducer.ITEMS = {
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
    "Base.Rope",
    "Base.Twine",
    "Base.DuctTape",
    "Base.Woodglue",

    -- Tools / hybrid tool-weapons
    "Base.Hammer",
    "Base.BallPeenHammer",
    "Base.ClubHammer",
    "Base.Screwdriver",
    "Base.Saw",
    "Base.GardenSaw",
    "Base.Wrench",
    "Base.PipeWrench",
    "Base.LugWrench",
    "Base.Crowbar",
    "Base.HandAxe",
    "Base.Axe",
    "Base.WoodAxe",
    "Base.PickAxe",
    "Base.Shovel",
    "Base.Shovel2",
    "Base.GardenHoe",
    "Base.GardenFork",
    "Base.HandFork",
    "Base.HandShovel",
    "Base.EntrenchingTool",
    "Base.Sledgehammer",
    "Base.Sledgehammer2",
    "Base.BlowTorch",
    "Base.WeldingMask",
    "Base.Tongs",
    "Base.Scissors",
    "Base.Needle",
    "Base.WoodenMallet",

    -- Weapons
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

local function buildLookup(list)
    local lookup = {}
    for _, fullType in ipairs(list) do
        lookup[fullType] = true
    end
    return lookup
end

WeightReducer._lookup = buildLookup(WeightReducer.ITEMS)

local function shouldReduceFullType(fullType)
    return fullType and WeightReducer._lookup[fullType] == true
end

local function applyScriptWeightReduction(fullType)
    local scriptItem = ScriptManager.instance:getItem(fullType)
    if not scriptItem then
        logDebug("script item not found, skipping: " .. tostring(fullType))
        return
    end

    local originalWeight = scriptItem:getWeight()
    local newWeight = originalWeight * WeightReducer.MULTIPLIER
    scriptItem:setWeight(newWeight)
    logDebug(fullType .. ": " .. tostring(originalWeight) .. " → " .. tostring(newWeight))
end

local function applyInventoryItemReduction(item)
    if not item then return end

    local fullType = item:getFullType()
    if not shouldReduceFullType(fullType) then
        return
    end

    local scriptItem = item:getScriptItem()
    if not scriptItem then
        return
    end

    local targetWeight = scriptItem:getWeight()
    if item:getActualWeight() ~= targetWeight or item:getWeight() ~= targetWeight then
        item:setActualWeight(targetWeight)
        item:setWeight(targetWeight)
        item:setCustomWeight(true)
        logDebug("inventory item normalized: " .. tostring(fullType) .. " → " .. tostring(targetWeight))
    end

    if item:IsInventoryContainer() and item:getInventory() then
        local nestedItems = item:getInventory():getItems()
        for i = 1, nestedItems:size() do
            applyInventoryItemReduction(nestedItems:get(i - 1))
        end
    end
end

local function normalizePlayerInventory(player)
    if not player then return end

    local items = player:getInventory():getItems()
    for i = 1, items:size() do
        applyInventoryItemReduction(items:get(i - 1))
    end
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
