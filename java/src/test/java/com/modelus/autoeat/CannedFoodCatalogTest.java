package com.modelus.autoeat;

import java.util.stream.Stream;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class CannedFoodCatalogTest {

    @ParameterizedTest
    @MethodSource("cannedFoodMappings")
    void maps_each_supported_can_to_its_recipe_and_opened_type(
            String canFullType, String openingRecipe, String openedFullType) {
        assertEquals(openingRecipe, CannedFoodCatalog.openingRecipeFor(canFullType));
        assertEquals(openedFullType, CannedFoodCatalog.expectedOpenedType(canFullType));
    }

    private static Stream<Arguments> cannedFoodMappings() {
        return Stream.of(
                Arguments.of("Base.TinnedBeans", "OpenCannedFood", "Base.OpenBeans"),
                Arguments.of("Base.CannedBolognese", "OpenCannedFood", "Base.CannedBologneseOpen"),
                Arguments.of("Base.CannedCarrots2", "OpenCannedFood", "Base.CannedCarrotsOpen"),
                Arguments.of("Base.CannedChili", "OpenCannedFood", "Base.CannedChiliOpen"),
                Arguments.of("Base.CannedCorn", "OpenCannedFood", "Base.CannedCornOpen"),
                Arguments.of("Base.CannedFruitCocktail", "OpenCannedFood", "Base.CannedFruitCocktailOpen"),
                Arguments.of("Base.CannedMilk", "OpenCannedFood", "Base.CannedMilkOpen"),
                Arguments.of("Base.CannedMushroomSoup", "OpenCannedFood", "Base.CannedMushroomSoupOpen"),
                Arguments.of("Base.CannedPeaches", "OpenCannedFood", "Base.CannedPeachesOpen"),
                Arguments.of("Base.CannedPeas", "OpenCannedFood", "Base.CannedPeasOpen"),
                Arguments.of("Base.CannedPineapple", "OpenCannedFood", "Base.CannedPineappleOpen"),
                Arguments.of("Base.CannedPotato2", "OpenCannedFood", "Base.CannedPotatoOpen"),
                Arguments.of("Base.TinnedSoup", "OpenCannedFood", "Base.TinnedSoupOpen"),
                Arguments.of("Base.CannedTomato2", "OpenCannedFood", "Base.CannedTomatoOpen"),
                Arguments.of("Base.TunaTin", "OpenCannedFood", "Base.TunaTinOpen"),
                Arguments.of("Base.Dogfood", "OpenCannedFood", "Base.DogfoodOpen"),
                Arguments.of("Base.CannedCornedBeef", "OpenCannedFood2", "Base.CannedCornedBeefOpen"),
                Arguments.of("Base.CannedSardines", "OpenCannedFood2", "Base.CannedSardinesOpen"));
    }

    @Test
    void rejects_null_unsupported_beverage_and_unknown_types() {
        assertNull(CannedFoodCatalog.openingRecipeFor(null));
        assertNull(CannedFoodCatalog.expectedOpenedType(null));
        assertUnsupported("Base.Apple");
        assertUnsupported("Base.BeerBottle");
        assertUnsupported("Base.CannedFruitBeverage");
    }

    private static void assertUnsupported(String fullType) {
        assertNull(CannedFoodCatalog.openingRecipeFor(fullType));
        assertNull(CannedFoodCatalog.expectedOpenedType(fullType));
    }
}
