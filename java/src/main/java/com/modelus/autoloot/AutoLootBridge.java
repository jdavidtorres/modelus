package com.modelus.autoloot;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import se.krka.kahlua.vm.KahluaTable;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;

/** PZ-facing persistence and candidate filtering for Auto Loot. */
public final class AutoLootBridge {

    public static final String MOD_DATA_KEY = "modelusAutoLootAllowlist";
    public static final int MAX_CANDIDATES_PER_SOURCE = 5;

    private AutoLootBridge() {
    }

    public static boolean isTypeAllowed(IsoPlayer player, String fullType) {
        return player != null && isTypeAllowed(new LiveModDataStore(player.getModData()), fullType);
    }

    /** Toggles a type and returns its new enabled state. */
    public static boolean toggleTypeAllowed(IsoPlayer player, String fullType) {
        if (player == null || !AutoLootPolicy.isValidFullType(fullType)) {
            return false;
        }

        return toggleTypeAllowed(new LiveModDataStore(player.getModData()), fullType);
    }

    public static ArrayList<InventoryItem> selectCandidates(IsoPlayer player, ItemContainer source) {
        ArrayList<InventoryItem> candidates = new ArrayList<>();
        if (player == null || source == null || isPlayerUnavailable(player) || isPlayerOwnedContainer(player, source)) {
            return candidates;
        }

        Set<String> allowedTypes = loadAllowlist(new LiveModDataStore(player.getModData()));
        LootAdapter<InventoryItem> adapter = new LiveLootAdapter(player, source);
        candidates.addAll(selectCandidates(source.getItems(), allowedTypes, adapter, MAX_CANDIDATES_PER_SOURCE));
        return candidates;
    }

    /** Rechecks a queued item against current state and source before transfer. */
    public static boolean canCollect(IsoPlayer player, InventoryItem item) {
        if (player == null || item == null || isPlayerUnavailable(player)) {
            return false;
        }

        ItemContainer source = item.getContainer();
        if (source == null || isPlayerOwnedContainer(player, source)) {
            return false;
        }

        Set<String> allowedTypes = loadAllowlist(new LiveModDataStore(player.getModData()));
        return isEligible(new LiveLootAdapter(player, source), item, allowedTypes);
    }

    private static boolean isEligible(
            LootAdapter<InventoryItem> adapter,
            InventoryItem item,
            Set<String> allowedTypes) {
        if (item == null) {
            return false;
        }
        boolean rotten = item instanceof Food food && food.isRotten();
        if (!AutoLootPolicy.shouldLoot(
                allowedTypes,
                adapter.fullTypeOf(item),
                adapter.isPlayerOwnedItem(item),
                adapter.isUnwanted(item),
                adapter.isBroken(item),
                rotten)) {
            return false;
        }
        return adapter.isRemoveAllowed(item) && adapter.destinationAllows(item) && adapter.hasRoomFor(item);
    }

    private static boolean isPlayerUnavailable(IsoPlayer player) {
        return player.isDead()
                || player.getVehicle() != null
                || player.isPlayerMoving()
                || player.isAttacking()
                || player.isStrafing();
    }

    private static boolean isPlayerOwnedContainer(IsoPlayer player, ItemContainer container) {
        return container.isInCharacterInventory(player)
                || container.getOutermostContainer() == player.getInventory();
    }

    private static Set<String> loadAllowlist(ModDataStore store) {
        return AutoLootPolicy.parseAllowlist(store.get());
    }

    static boolean isTypeAllowed(ModDataStore store, String fullType) {
        return store != null
                && AutoLootPolicy.isValidFullType(fullType)
                && loadAllowlist(store).contains(fullType);
    }

    static boolean toggleTypeAllowed(ModDataStore store, String fullType) {
        if (store == null || !AutoLootPolicy.isValidFullType(fullType)) {
            return false;
        }

        Set<String> types = loadAllowlist(store);
        boolean enabled = AutoLootPolicy.toggleType(types, fullType);
        store.put(AutoLootPolicy.serializeAllowlist(types));
        return enabled;
    }

    static <T> List<T> selectCandidates(
            Iterable<T> items,
            Set<String> allowedTypes,
            LootAdapter<T> adapter,
            int maxItems) {
        if (adapter == null) {
            return List.of();
        }
        return AutoLootPolicy.uniqueEligible(items, item -> isEligible(adapter, item, allowedTypes), maxItems);
    }

    private static <T> boolean isEligible(LootAdapter<T> adapter, T item, Set<String> allowedTypes) {
        if (item == null) {
            return false;
        }
        return AutoLootPolicy.shouldLoot(
                        allowedTypes,
                        adapter.fullTypeOf(item),
                        adapter.isPlayerOwnedItem(item),
                        adapter.isUnwanted(item),
                        adapter.isBroken(item),
                        adapter.isRotten(item))
                && adapter.isRemoveAllowed(item)
                && adapter.destinationAllows(item)
                && adapter.hasRoomFor(item);
    }

    interface ModDataStore {
        String get();

        void put(String serialized);
    }

    interface LootAdapter<T> {
        String fullTypeOf(T item);

        boolean isPlayerOwnedItem(T item);

        boolean isUnwanted(T item);

        boolean isBroken(T item);

        boolean isRotten(T item);

        boolean isRemoveAllowed(T item);

        boolean destinationAllows(T item);

        boolean hasRoomFor(T item);
    }

    private static final class LiveModDataStore implements ModDataStore {
        private final KahluaTable modData;

        private LiveModDataStore(KahluaTable modData) {
            this.modData = modData;
        }

        @Override
        public String get() {
            if (modData == null) {
                return null;
            }
            Object value = modData.rawget(MOD_DATA_KEY);
            return value instanceof String stored ? stored : null;
        }

        @Override
        public void put(String serialized) {
            if (modData != null) {
                modData.rawset(MOD_DATA_KEY, serialized);
            }
        }
    }

    private static final class LiveLootAdapter implements LootAdapter<InventoryItem> {
        private final IsoPlayer player;
        private final ItemContainer source;

        private LiveLootAdapter(IsoPlayer player, ItemContainer source) {
            this.player = player;
            this.source = source;
        }

        @Override
        public String fullTypeOf(InventoryItem item) {
            return item.getFullType();
        }

        @Override
        public boolean isPlayerOwnedItem(InventoryItem item) {
            return item.isInPlayerInventory() || item.isEquipped();
        }

        @Override
        public boolean isUnwanted(InventoryItem item) {
            return item.isUnwanted(player);
        }

        @Override
        public boolean isBroken(InventoryItem item) {
            return item.isBroken();
        }

        @Override
        public boolean isRotten(InventoryItem item) {
            return item instanceof Food food && food.isRotten();
        }

        @Override
        public boolean isRemoveAllowed(InventoryItem item) {
            return source.isRemoveItemAllowed(item);
        }

        @Override
        public boolean destinationAllows(InventoryItem item) {
            return player.getInventory().isItemAllowed(item);
        }

        @Override
        public boolean hasRoomFor(InventoryItem item) {
            return player.getInventory().hasRoomFor(player, item);
        }
    }
}
