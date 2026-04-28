-- WeightReducer.lua
-- Reduces the weight of selected materials, tools, and weapons to 30% of
-- vanilla values.
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

-- Allowlist of vanilla item types to reduce.
-- Firewood is intentionally excluded: its weight determines campfire burn time.
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

    -- Tools
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

-- Guard: prevents double-application if OnGameStart fires more than once.
WeightReducer._applied = false

-- ---------------------------------------------------------------------------
-- Core
-- ---------------------------------------------------------------------------

--- Applies the weight multiplier to all items in the allowlist.
--- Safe to call multiple times — only runs once per session.
function WeightReducer.apply()
    if WeightReducer._applied then
        logDebug("already applied, skipping")
        return
    end
    WeightReducer._applied = true

    for _, fullType in ipairs(WeightReducer.ITEMS) do
        local scriptItem = ScriptManager.instance:getItem(fullType)
        if not scriptItem then
            logDebug("not found in ScriptManager, skipping: " .. fullType)
        else
            local originalWeight = scriptItem:getWeight()
            local newWeight      = originalWeight * WeightReducer.MULTIPLIER
            scriptItem:setWeight(newWeight)
            logDebug(
                fullType .. ": " ..
                tostring(originalWeight) .. " → " .. tostring(newWeight)
            )
        end
    end
end

-- ---------------------------------------------------------------------------
-- Hook
-- ---------------------------------------------------------------------------

Events.OnGameStart.Add(WeightReducer.apply)
