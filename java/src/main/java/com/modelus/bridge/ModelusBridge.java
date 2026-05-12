package com.modelus.bridge;

import com.modelus.ammoconverter.AmmoConverterBridge;
import com.modelus.weight.WeightReducerCatalog;
import zombie.characters.IsoPlayer;

public final class ModelusBridge {
    private ModelusBridge() {
    }

    /**
     * Entry point called from {@code AmmoConverter.lua}.
     * Converts all same-tier source ammo in the player's inventory to
     * destination loose rounds of {@code targetFullType}.
     *
     * @param player        The local player.
     * @param targetFullType Canonical full type, e.g. "Base.Bullets9mm".
     */
    public static void convertAmmoTo(IsoPlayer player, String targetFullType) {
        AmmoConverterBridge.convertTo(player, targetFullType);
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
