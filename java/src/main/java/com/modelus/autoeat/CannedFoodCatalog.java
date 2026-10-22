package com.modelus.autoeat;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

/** Catalog of supported canned foods that can be opened and auto-eaten. */
public final class CannedFoodCatalog {

    private static final Map<String, String> OPENING_RECIPES;
    private static final Map<String, String> OPENED_TYPES;

    static {
        Map<String, String> recipes = new LinkedHashMap<>();
        Map<String, String> openedTypes = new LinkedHashMap<>();

        add(recipes, openedTypes, "Base.TinnedBeans", "Base.OpenBeans", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedBolognese", "Base.CannedBologneseOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedCarrots2", "Base.CannedCarrotsOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedChili", "Base.CannedChiliOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedCorn", "Base.CannedCornOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedFruitCocktail", "Base.CannedFruitCocktailOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedMilk", "Base.CannedMilkOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedMushroomSoup", "Base.CannedMushroomSoupOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedPeaches", "Base.CannedPeachesOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedPeas", "Base.CannedPeasOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedPineapple", "Base.CannedPineappleOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedPotato2", "Base.CannedPotatoOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.TinnedSoup", "Base.TinnedSoupOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedTomato2", "Base.CannedTomatoOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.TunaTin", "Base.TunaTinOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.Dogfood", "Base.DogfoodOpen", "OpenCannedFood");
        add(recipes, openedTypes, "Base.CannedCornedBeef", "Base.CannedCornedBeefOpen", "OpenCannedFood2");
        add(recipes, openedTypes, "Base.CannedSardines", "Base.CannedSardinesOpen", "OpenCannedFood2");

        OPENING_RECIPES = Collections.unmodifiableMap(recipes);
        OPENED_TYPES = Collections.unmodifiableMap(openedTypes);
    }

    private CannedFoodCatalog() {
    }

    private static void add(
            Map<String, String> recipes,
            Map<String, String> openedTypes,
            String canFullType,
            String openedFullType,
            String recipeName) {
        recipes.put(canFullType, recipeName);
        openedTypes.put(canFullType, openedFullType);
    }

    public static String openingRecipeFor(String canFullType) {
        return OPENING_RECIPES.get(canFullType);
    }

    public static String expectedOpenedType(String canFullType) {
        return OPENED_TYPES.get(canFullType);
    }
}
