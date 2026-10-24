local chunk = assert(loadfile("mods/modelus/common/media/lua/shared/auto-eat/CannedFoodCatalog.lua"))
setfenv(chunk, setmetatable({}, { __index = _G }))
local catalog = chunk()
local expected = {
    { "Base.TinnedBeans", "Base.OpenBeans", "OpenCannedFood" },
    { "Base.CannedBolognese", "Base.CannedBologneseOpen", "OpenCannedFood" },
    { "Base.CannedCarrots2", "Base.CannedCarrotsOpen", "OpenCannedFood" },
    { "Base.CannedChili", "Base.CannedChiliOpen", "OpenCannedFood" },
    { "Base.CannedCorn", "Base.CannedCornOpen", "OpenCannedFood" },
    { "Base.CannedFruitCocktail", "Base.CannedFruitCocktailOpen", "OpenCannedFood" },
    { "Base.CannedMilk", "Base.CannedMilkOpen", "OpenCannedFood" },
    { "Base.CannedMushroomSoup", "Base.CannedMushroomSoupOpen", "OpenCannedFood" },
    { "Base.CannedPeaches", "Base.CannedPeachesOpen", "OpenCannedFood" },
    { "Base.CannedPeas", "Base.CannedPeasOpen", "OpenCannedFood" },
    { "Base.CannedPineapple", "Base.CannedPineappleOpen", "OpenCannedFood" },
    { "Base.CannedPotato2", "Base.CannedPotatoOpen", "OpenCannedFood" },
    { "Base.TinnedSoup", "Base.TinnedSoupOpen", "OpenCannedFood" },
    { "Base.CannedTomato2", "Base.CannedTomatoOpen", "OpenCannedFood" },
    { "Base.TunaTin", "Base.TunaTinOpen", "OpenCannedFood" },
    { "Base.Dogfood", "Base.DogfoodOpen", "OpenCannedFood" },
    { "Base.CannedCornedBeef", "Base.CannedCornedBeefOpen", "OpenCannedFood2" },
    { "Base.CannedSardines", "Base.CannedSardinesOpen", "OpenCannedFood2" }
}
local assertions = 0
for _, row in ipairs(expected) do
    assert(catalog.expectedOpenedType(row[1]) == row[2], "opened type mismatch for " .. row[1])
    assert(catalog.openingRecipeFor(row[1]) == row[3], "recipe mismatch for " .. row[1])
    assertions = assertions + 2
end
assert(catalog.openingRecipeFor(nil) == nil and catalog.expectedOpenedType(nil) == nil,
    "nil can lookup returns nil")
assert(catalog.openingRecipeFor("Base.Apple") == nil and catalog.expectedOpenedType("Base.BeerBottle") == nil,
    "unknown can lookup returns nil")
assertions = assertions + 2
return assertions
