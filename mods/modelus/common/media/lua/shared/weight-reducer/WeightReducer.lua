-- WeightReducer.lua
-- Reduces the weight of construction materials to 50% of vanilla values.
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
-- 0.5 = 50% of original weight.
WeightReducer.MULTIPLIER = 0.5

-- Allowlist of vanilla item types to reduce.
-- Firewood is intentionally excluded: its weight determines campfire burn time.
WeightReducer.ITEMS = {
    -- Wood
    "Base.Log",
    "Base.Plank",
    "Base.Branch",
    "Base.SharpedBranch",
    "Base.WoodenMallet",
    -- Metal
    "Base.MetalSheet",
    "Base.MetalBar",
    "Base.MetalPipe",
    "Base.MetalRod",
    "Base.ScrapMetal",
    "Base.SmallSheetMetal",
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
