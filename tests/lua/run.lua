if not setfenv then
    function setfenv(chunk, environment)
        local index = 1
        while true do
            local name = debug.getupvalue(chunk, index)
            if not name then break end
            if name == "_ENV" then
                debug.setupvalue(chunk, index, environment)
                break
            end
            index = index + 1
        end
        return chunk
    end
end

local root = "."
local syntaxFiles = {
    "mods/modelus/common/media/lua/shared/auto-consolidate/ConsolidationPolicy.lua",
    "mods/modelus/common/media/lua/shared/dual-back/DualBackPolicy.lua",
    "mods/modelus/common/media/lua/shared/dual-back/DualBackLocations.lua",
    "mods/modelus/common/media/lua/client/dual-back/DualBackModels.lua",
    "mods/modelus/common/media/lua/client/dual-back/DualBack.lua",
    "mods/modelus/common/media/lua/client/auto-consolidate/AutoConsolidate.lua",
    "mods/modelus/common/media/lua/shared/auto-loot/AutoLootPolicy.lua",
    "mods/modelus/common/media/lua/client/auto-loot/AutoLoot.lua",
    "mods/modelus/common/media/lua/shared/auto-eat/CannedFoodCatalog.lua",
    "mods/modelus/common/media/lua/client/auto-eat/AutoEatCans.lua",
    "mods/modelus/common/media/lua/shared/weight-reducer/WeightReducer.lua",
    "mods/modelus/common/media/lua/shared/weight-reducer/WeightReducerCatalog.generated.lua",
    "mods/modelus/common/media/lua/shared/ammo-converter/AmmoConverterCatalog.generated.lua",
    "mods/modelus/common/media/lua/client/ammo-converter/AmmoConverter.lua",
    "mods/modelus/common/media/lua/shared/item-identification/ItemIdentification.lua",
    "mods/modelus/common/media/lua/shared/auto-tailoring/TailoringPolicy.lua",
    "mods/modelus/common/media/lua/client/auto-tailoring/AutoTailoring.lua",
    "mods/modelus/common/media/lua/client/ModelusMainScreen.lua",
    "mods/modelus/common/media/lua/shared/ModelusBootstrap.lua",
    "tests/lua/auto_consolidate_policy_test.lua",
    "tests/lua/dual_back_policy_test.lua",
    "tests/lua/dual_back_locations_test.lua",
    "tests/lua/dual_back_models_test.lua",
    "tests/lua/dual_back_runtime_test.lua",
    "tests/lua/dual_back_vanilla_hotbar_test.lua",
    "tests/lua/auto_consolidate_runtime_test.lua",
    "tests/lua/auto_tailoring_policy_test.lua",
    "tests/lua/auto_tailoring_runtime_test.lua",
    "tests/lua/auto_loot_policy_test.lua",
    "tests/lua/auto_loot_runtime_test.lua",
    "tests/lua/canned_food_catalog_test.lua",
    "tests/lua/auto_eat_cans_runtime_test.lua",
    "tests/lua/catalog_guard_test.lua",
    "tests/lua/weight_reducer_runtime_test.lua"
}

local failures = 0
for _, path in ipairs(syntaxFiles) do
    local chunk, err = loadfile(root .. "/" .. path)
    if not chunk then
        failures = failures + 1
        io.stderr:write("FAIL syntax " .. path .. ": " .. tostring(err) .. "\n")
    else
        print("PASS syntax " .. path)
    end
end

local suites = {
    "tests/lua/auto_consolidate_policy_test.lua",
    "tests/lua/dual_back_policy_test.lua",
    "tests/lua/dual_back_locations_test.lua",
    "tests/lua/dual_back_models_test.lua",
    "tests/lua/dual_back_runtime_test.lua",
    "tests/lua/dual_back_vanilla_hotbar_test.lua",
    "tests/lua/auto_consolidate_runtime_test.lua",
    "tests/lua/auto_tailoring_policy_test.lua",
    "tests/lua/auto_tailoring_runtime_test.lua",
    "tests/lua/auto_loot_policy_test.lua",
    "tests/lua/auto_loot_runtime_test.lua",
    "tests/lua/canned_food_catalog_test.lua",
    "tests/lua/auto_eat_cans_runtime_test.lua",
    "tests/lua/catalog_guard_test.lua",
    "tests/lua/weight_reducer_runtime_test.lua"
}
for _, path in ipairs(suites) do
    local chunk, loadError = loadfile(root .. "/" .. path)
    if not chunk then
        failures = failures + 1
        io.stderr:write("FAIL load " .. path .. ": " .. tostring(loadError) .. "\n")
    else
        local ok, suiteError = pcall(chunk)
        if not ok then
            failures = failures + 1
            io.stderr:write("FAIL " .. path .. ": " .. tostring(suiteError) .. "\n")
        else
            print("PASS " .. path .. " (" .. tostring(suiteError) .. " assertions)")
        end
    end
end

if failures > 0 then
    io.stderr:write(tostring(failures) .. " failure(s)\n")
    os.exit(1)
end
print("All Lua checks passed.")
