local function loadModule(path, environment)
    local chunk = assert(loadfile(path))
    if environment then setfenv(chunk, environment) end
    return chunk()
end

local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local weightEnv = setmetatable({}, { __index = _G })
local weight = loadModule("mods/modelus/common/media/lua/shared/weight-reducer/WeightReducerCatalog.generated.lua", weightEnv)
    or weightEnv.WeightReducerCatalog_Generated
expect(weight.MULTIPLIER == 0.1, "weight multiplier remains 0.1")
local families = { WOOD = 18, METAL = 28, TOOLS = 33, GARDENING = 16, WEAPONS = 29, AMMO = 27, FOOD = 56 }
local seen, total, familyCount = {}, 0, 0
for family, expectedCount in pairs(families) do
    familyCount = familyCount + 1
    local entries = weight.ITEMS_BY_FAMILY[family]
    expect(type(entries) == "table" and #entries == expectedCount, "family count: " .. family)
    for _, fullType in ipairs(entries) do
        expect(type(fullType) == "string" and fullType:match("^[A-Za-z0-9_]+%.[A-Za-z0-9_]+$"),
            "valid full type: " .. tostring(fullType))
        expect(not seen[fullType], "catalog has no duplicate: " .. fullType)
        seen[fullType] = true
        total = total + 1
    end
end
local forbidden = { ["Base.Firewood"] = true, ["Base.FirewoodBundle"] = true,
    ["Base.Charcoal"] = true, ["Base.CharcoalCrafted"] = true, ["Base.Coke"] = true }
for fullType in pairs(forbidden) do expect(not seen[fullType], "burnable excluded: " .. fullType) end
local actualFamilies = 0
for _ in pairs(weight.ITEMS_BY_FAMILY) do actualFamilies = actualFamilies + 1 end
expect(familyCount == 7 and actualFamilies == 7 and #weight.ITEMS == 207 and total == 207,
    "weight catalog has seven families and 207 entries")
local lookupCount = 0
for fullType in pairs(weight._lookup) do
    lookupCount = lookupCount + 1
    expect(seen[fullType] == true, "lookup contains catalog type")
end
expect(lookupCount == 207, "weight lookup has 207 keys")
local flattened = {}
for _, fullType in ipairs(weight.ITEMS) do
    expect(seen[fullType] == true and not flattened[fullType], "flat catalog is a unique family projection")
    flattened[fullType] = true
end
expect(lookupCount == 207, "flat catalog count matches family catalog")

local ammoEnv = setmetatable({}, { __index = _G })
local ammo = loadModule("mods/modelus/common/media/lua/shared/ammo-converter/AmmoConverterCatalog.generated.lua", ammoEnv)
    or ammoEnv.AmmoConverterCatalog_Generated
expect(#ammo.AMMO_TYPES == 9, "ammo catalog retains nine types")
for _, fullType in ipairs(ammo.AMMO_TYPES) do
    expect(ammo._lookup[fullType] == true and ammo.PACKAGING[fullType] ~= nil,
        "ammo type has lookup and packaging: " .. fullType)
end
local scriptMappings, packagingEntries = 0, 0
for _, fullType in pairs(ammo.SCRIPT_TO_FULL_TYPE) do
    scriptMappings = scriptMappings + 1
    expect(ammo._lookup[fullType] == true, "script mapping points to known ammo")
end
for fullType in pairs(ammo.PACKAGING) do
    packagingEntries = packagingEntries + 1
    expect(ammo._lookup[fullType] == true, "packaging only contains known ammo")
end
expect(scriptMappings == 9 and packagingEntries == 9, "ammo mappings and packaging retain nine entries")

local runtimePaths = {
    "mods/modelus/common/media/lua/client/auto-loot/AutoLoot.lua",
    "mods/modelus/common/media/lua/client/auto-eat/AutoEatCans.lua",
    "mods/modelus/common/media/lua/shared/weight-reducer/WeightReducer.lua",
    "mods/modelus/common/media/lua/shared/ModelusBootstrap.lua"
}
for _, path in ipairs(runtimePaths) do
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    expect(not source:find("luajava", 1, true) and not source:find("bindClass", 1, true)
        and not source:find("com.modelus", 1, true) and not source:find("ModelusBridge", 1, true),
        "custom Java bridge removed from " .. path)
end
return assertions
