-- WeightReducer.lua
-- Reduces the weight of selected materials, tools, weapons, gardening gear,
-- and ammunition to 30% of vanilla values (70% reduction).
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
-- Keep this as an explicit fullType allowlist grouped by family.
-- All entries use Base.* fullTypes. Missing B42 fullTypes are skipped nil-safely.

-- BURNABLES NOTE:
-- Firewood, FirewoodBundle, Charcoal, CharcoalCrafted, Coke and similar fuel
-- items are intentionally excluded. Their effective burn duration is tied to
-- their weight via FireFuelRatio; reducing weight without compensating that
-- ratio would silently shorten fire duration. A safe compensation path requires
-- runtime verification of FireFuelRatio values per B42 build. Until that is
-- verified, burnables remain at vanilla weight to preserve fire/cooking balance.

WeightReducer.ITEMS_BY_FAMILY = {

    -- ──────────────────────────────────────────────────────────────────────
    -- WOOD: construction lumber, planks, logs, branches, natural materials.
    -- Excludes burnables (Firewood*, Charcoal*, Coke) — see BURNABLES NOTE.
    -- ──────────────────────────────────────────────────────────────────────
    WOOD = {
        "Base.Log",
        "Base.LogStacks2",
        "Base.LogStacks3",
        "Base.LogStacks4",
        "Base.Plank",
        "Base.Plank_Nails",       -- B42 nailed plank variant
        "Base.Plank_Broken",      -- B42
        "Base.Plank_Broken_Nails", -- B42
        "Base.PlankNail",         -- legacy B41 name kept for compatibility
        "Base.TreeBranch",        -- legacy
        "Base.TreeBranch2",       -- B42
        "Base.LargeBranch",       -- B42
        "Base.Twigs",             -- B42
        "Base.TwigsBundle",       -- B42
        "Base.Sapling",           -- B42
        "Base.UnusableWood",      -- B42
        "Base.Rope",
        "Base.Twine",
        "Base.DuctTape",
        "Base.Woodglue",
    },

    -- ──────────────────────────────────────────────────────────────────────
    -- METAL: raw metals, fasteners, pipes, wire.
    -- ──────────────────────────────────────────────────────────────────────
    METAL = {
        "Base.SheetMetal",
        "Base.SmallSheetMetal",
        "Base.MetalBar",
        "Base.MetalPipe",
        "Base.MetalDrum",         -- B42
        "Base.ScrapMetal",
        "Base.UnusableMetal",
        "Base.WeldingRods",       -- B42
        "Base.IronIngot",         -- B42
        "Base.LeadPipe",          -- B42
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
    },

    -- ──────────────────────────────────────────────────────────────────────
    -- TOOLS: hand tools, power tools, utility gear.
    -- ──────────────────────────────────────────────────────────────────────
    TOOLS = {
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
        "Base.Sledgehammer",
        "Base.Sledgehammer2",
        "Base.BlowTorch",
        "Base.WeldingMask",
        "Base.Tongs",
        "Base.Scissors",
        "Base.Needle",
        "Base.WoodenMallet",
    },

    -- ──────────────────────────────────────────────────────────────────────
    -- GARDENING: digging, planting, and harvesting tools.
    -- ──────────────────────────────────────────────────────────────────────
    GARDENING = {
        "Base.Shovel",
        "Base.Shovel2",
        "Base.GardenHoe",
        "Base.GardenFork",
        "Base.HandFork",
        "Base.HandShovel",
        "Base.EntrenchingTool",
        "Base.GardenRake",        -- B42
        "Base.Trowel",            -- B42
    },

    -- ──────────────────────────────────────────────────────────────────────
    -- WEAPONS: melee and ranged weapons.
    -- ──────────────────────────────────────────────────────────────────────
    WEAPONS = {
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
    },

    -- ──────────────────────────────────────────────────────────────────────
    -- AMMO: vanilla loose rounds, boxes, and cartons for families covered by
    -- the ammo-loot-drop modules (AmmoLootDropBox/Carton/LootDrop).
    -- Families: 9mm, .45, .44, .38, shotgun, .30-30, .357, .308, 5.56
    -- ──────────────────────────────────────────────────────────────────────
    AMMO = {
        -- 9mm
        "Base.Bullets9mm",
        "Base.Bullets9mmBox",
        "Base.Bullets9mmCarton",
        -- .45 ACP
        "Base.Bullets45",
        "Base.Bullets45Box",
        "Base.Bullets45Carton",
        -- .44 Magnum
        "Base.Bullets44",
        "Base.Bullets44Box",
        "Base.Bullets44Carton",
        -- .38 Special
        "Base.Bullets38",
        "Base.Bullets38Box",
        "Base.Bullets38Carton",
        -- Shotgun shells
        "Base.ShotgunShells",
        "Base.ShotgunShellsBox",
        "Base.ShotgunShellsCarton",
        -- .30-30 Winchester
        "Base.3030Bullets",
        "Base.3030BulletsBox",
        "Base.3030BulletsCarton",
        -- .357 Magnum
        "Base.Bullets357",
        "Base.Bullets357Box",
        "Base.Bullets357Carton",
        -- .308 Winchester
        "Base.308Bullets",
        "Base.308BulletsBox",
        "Base.308BulletsCarton",
        -- 5.56 NATO
        "Base.556Bullets",
        "Base.556BulletsBox",
        "Base.556BulletsCarton",
    },
}

-- Flatten all family groups into a single lookup table.
local function buildLookup(families)
    local lookup = {}
    for _, group in pairs(families) do
        for _, fullType in ipairs(group) do
            lookup[fullType] = true
        end
    end
    return lookup
end

WeightReducer._lookup = buildLookup(WeightReducer.ITEMS_BY_FAMILY)

-- Flat ordered list for iteration during OnGameStart (preserves determinism).
WeightReducer.ITEMS = {}
for _, group in pairs(WeightReducer.ITEMS_BY_FAMILY) do
    for _, fullType in ipairs(group) do
        WeightReducer.ITEMS[#WeightReducer.ITEMS + 1] = fullType
    end
end

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

-- Recursively normalize an inventory item and any nested containers.
-- IMPORTANT: We always recurse into nested inventories even when the container
-- item itself is not reducible, so reducible items inside normal bags are found.
local function normalizeInventoryItem(item)
    if not item then return end

    local fullType = item:getFullType()
    if shouldReduceFullType(fullType) then
        local scriptItem = item:getScriptItem()
        if scriptItem then
            local targetWeight = scriptItem:getWeight()
            if item:getActualWeight() ~= targetWeight or item:getWeight() ~= targetWeight then
                item:setActualWeight(targetWeight)
                item:setWeight(targetWeight)
                item:setCustomWeight(true)
                logDebug("inventory item normalized: " .. tostring(fullType) .. " → " .. tostring(targetWeight))
            end
        end
    end

    -- Always recurse into nested inventories regardless of this item's reducibility.
    if item:IsInventoryContainer and item:IsInventoryContainer() then
        local nested = item:getInventory and item:getInventory()
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
