package com.modelus.bridge;

import com.modelus.weight.WeightReducerCatalog;

public final class ModelusBridge {
    private ModelusBridge() {
    }

    public static String onLuaBootstrap(String source) {
        return "Hello from Java bridge. Lua caller: " + source;
    }

    public static String weightReducerItems() {
        return WeightReducerCatalog.flattenedItemsPipeSeparated();
    }

    public static double weightReducerMultiplier() {
        return WeightReducerCatalog.MULTIPLIER;
    }

    public static String weightReducerValidationSummary() {
        return WeightReducerCatalog.validationSummary();
    }
}
