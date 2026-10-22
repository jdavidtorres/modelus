package com.modelus.bridge;

import com.modelus.ammoconverter.AmmoConverterBridge;
import com.modelus.autoloot.AutoLootBridge;
import com.modelus.autoeat.AutoEatBridge;
import com.modelus.weight.WeightReducerCatalog;
import java.util.ArrayList;
import zombie.characters.IsoPlayer;
import zombie.entity.components.crafting.recipe.CraftRecipeData;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;

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

    public static InventoryItem autoEatCreatedOutput(CraftRecipeData recipeData, String expectedType) {
        return AutoEatBridge.createdOutput(recipeData, expectedType);
    }

    public static AutoEatBridge.PendingCan autoEatBeginOpen() {
        return new AutoEatBridge.PendingCan();
    }

    public static boolean autoLootIsSelected(IsoPlayer player, String fullType) {
        return AutoLootBridge.isTypeAllowed(player, fullType);
    }

    public static boolean autoLootToggleType(IsoPlayer player, String fullType) {
        return AutoLootBridge.toggleTypeAllowed(player, fullType);
    }

    public static ArrayList<InventoryItem> autoLootCandidates(IsoPlayer player, ItemContainer source) {
        return AutoLootBridge.selectCandidates(player, source);
    }

    public static boolean autoLootCanCollect(IsoPlayer player, InventoryItem item) {
        return AutoLootBridge.canCollect(player, item);
    }
}
