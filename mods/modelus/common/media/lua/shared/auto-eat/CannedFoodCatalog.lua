ModelusCannedFoodCatalog = ModelusCannedFoodCatalog or {}

local Catalog = ModelusCannedFoodCatalog

Catalog.OPENING_RECIPES = {
    ["Base.TinnedBeans"] = "OpenCannedFood",
    ["Base.CannedBolognese"] = "OpenCannedFood",
    ["Base.CannedCarrots2"] = "OpenCannedFood",
    ["Base.CannedChili"] = "OpenCannedFood",
    ["Base.CannedCorn"] = "OpenCannedFood",
    ["Base.CannedFruitCocktail"] = "OpenCannedFood",
    ["Base.CannedMilk"] = "OpenCannedFood",
    ["Base.CannedMushroomSoup"] = "OpenCannedFood",
    ["Base.CannedPeaches"] = "OpenCannedFood",
    ["Base.CannedPeas"] = "OpenCannedFood",
    ["Base.CannedPineapple"] = "OpenCannedFood",
    ["Base.CannedPotato2"] = "OpenCannedFood",
    ["Base.TinnedSoup"] = "OpenCannedFood",
    ["Base.CannedTomato2"] = "OpenCannedFood",
    ["Base.TunaTin"] = "OpenCannedFood",
    ["Base.Dogfood"] = "OpenCannedFood",
    ["Base.CannedCornedBeef"] = "OpenCannedFood2",
    ["Base.CannedSardines"] = "OpenCannedFood2"
}

Catalog.OPENED_TYPES = {
    ["Base.TinnedBeans"] = "Base.OpenBeans",
    ["Base.CannedBolognese"] = "Base.CannedBologneseOpen",
    ["Base.CannedCarrots2"] = "Base.CannedCarrotsOpen",
    ["Base.CannedChili"] = "Base.CannedChiliOpen",
    ["Base.CannedCorn"] = "Base.CannedCornOpen",
    ["Base.CannedFruitCocktail"] = "Base.CannedFruitCocktailOpen",
    ["Base.CannedMilk"] = "Base.CannedMilkOpen",
    ["Base.CannedMushroomSoup"] = "Base.CannedMushroomSoupOpen",
    ["Base.CannedPeaches"] = "Base.CannedPeachesOpen",
    ["Base.CannedPeas"] = "Base.CannedPeasOpen",
    ["Base.CannedPineapple"] = "Base.CannedPineappleOpen",
    ["Base.CannedPotato2"] = "Base.CannedPotatoOpen",
    ["Base.TinnedSoup"] = "Base.TinnedSoupOpen",
    ["Base.CannedTomato2"] = "Base.CannedTomatoOpen",
    ["Base.TunaTin"] = "Base.TunaTinOpen",
    ["Base.Dogfood"] = "Base.DogfoodOpen",
    ["Base.CannedCornedBeef"] = "Base.CannedCornedBeefOpen",
    ["Base.CannedSardines"] = "Base.CannedSardinesOpen"
}

function Catalog.openingRecipeFor(fullType)
    return Catalog.OPENING_RECIPES[fullType]
end

function Catalog.expectedOpenedType(fullType)
    return Catalog.OPENED_TYPES[fullType]
end

return Catalog
