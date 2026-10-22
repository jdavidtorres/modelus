package com.modelus.autoloot;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.Test;

class AutoLootBridgeTest {

    @Test
    void persistent_toggle_reads_and_writes_the_serialized_allowlist() {
        MemoryStore store = new MemoryStore("Base.Apple");

        assertTrue(AutoLootBridge.isTypeAllowed(store, "Base.Apple"));
        assertTrue(AutoLootBridge.toggleTypeAllowed(store, "Base.WaterBottle"));
        assertEquals("Base.Apple|Base.WaterBottle", store.value);
        assertFalse(AutoLootBridge.toggleTypeAllowed(store, "Base.Apple"));
        assertEquals("Base.WaterBottle", store.value);
        assertFalse(AutoLootBridge.isTypeAllowed(store, "Base.Apple"));
        assertTrue(AutoLootBridge.isTypeAllowed(store, "Base.WaterBottle"));
    }

    @Test
    void invalid_type_does_not_mutate_persistent_allowlist() {
        MemoryStore store = new MemoryStore("Base.Apple");

        assertFalse(AutoLootBridge.toggleTypeAllowed(store, "Base.Bad|Type"));
        assertEquals("Base.Apple", store.value);
    }

    @Test
    void candidate_selection_applies_exclusions_and_preserves_source_order() {
        LootItem allowed = new LootItem("Base.Apple");
        LootItem duplicate = allowed;
        LootItem unwanted = new LootItem("Base.Apple").unwanted();
        LootItem broken = new LootItem("Base.Apple").broken();
        LootItem rotten = new LootItem("Base.Apple").rotten();
        LootItem disallowed = new LootItem("Base.Other");
        List<LootItem> source = List.of(allowed, duplicate, unwanted, broken, rotten, disallowed);

        List<LootItem> selected = AutoLootBridge.selectCandidates(source, Set.of("Base.Apple"), new TestAdapter(), 5);

        assertEquals(1, selected.size());
        assertSame(allowed, selected.get(0));
    }

    @Test
    void candidate_selection_honors_capacity_removal_rules_and_cycle_limit() {
        LootItem first = new LootItem("Base.Apple");
        LootItem second = new LootItem("Base.Apple");
        LootItem third = new LootItem("Base.Apple");
        LootItem inaccessible = new LootItem("Base.Apple").removeDenied();
        List<LootItem> source = List.of(first, inaccessible, second, third);

        List<LootItem> selected = AutoLootBridge.selectCandidates(source, Set.of("Base.Apple"), new TestAdapter(), 2);

        assertEquals(List.of(first, second), selected);
        assertTrue(AutoLootBridge.selectCandidates(source, Set.of(), new TestAdapter(), 2).isEmpty());
    }

    @Test
    void candidate_selection_rejects_player_owned_and_no_room_items() {
        LootItem owned = new LootItem("Base.Apple").owned();
        LootItem full = new LootItem("Base.Apple").noRoom();
        LootItem destinationRejects = new LootItem("Base.Apple").destinationDenied();
        List<LootItem> selected = AutoLootBridge.selectCandidates(
                List.of(owned, full, destinationRejects), Set.of("Base.Apple"), new TestAdapter(), 5);

        assertTrue(selected.isEmpty());
    }

    private static final class MemoryStore implements AutoLootBridge.ModDataStore {
        private String value;

        private MemoryStore(String value) {
            this.value = value;
        }

        @Override
        public String get() {
            return value;
        }

        @Override
        public void put(String serialized) {
            value = serialized;
        }
    }

    private static final class LootItem {
        private final String fullType;
        private boolean owned;
        private boolean unwanted;
        private boolean broken;
        private boolean rotten;
        private boolean removeAllowed = true;
        private boolean destinationAllows = true;
        private boolean room = true;

        private LootItem(String fullType) {
            this.fullType = fullType;
        }

        private LootItem owned() { owned = true; return this; }
        private LootItem unwanted() { unwanted = true; return this; }
        private LootItem broken() { broken = true; return this; }
        private LootItem rotten() { rotten = true; return this; }
        private LootItem removeDenied() { removeAllowed = false; return this; }
        private LootItem destinationDenied() { destinationAllows = false; return this; }
        private LootItem noRoom() { room = false; return this; }
    }

    private static final class TestAdapter implements AutoLootBridge.LootAdapter<LootItem> {
        @Override
        public String fullTypeOf(LootItem item) { return item.fullType; }

        @Override
        public boolean isPlayerOwnedItem(LootItem item) { return item.owned; }

        @Override
        public boolean isUnwanted(LootItem item) { return item.unwanted; }

        @Override
        public boolean isBroken(LootItem item) { return item.broken; }

        @Override
        public boolean isRotten(LootItem item) { return item.rotten; }

        @Override
        public boolean isRemoveAllowed(LootItem item) { return item.removeAllowed; }

        @Override
        public boolean destinationAllows(LootItem item) { return item.destinationAllows; }

        @Override
        public boolean hasRoomFor(LootItem item) { return item.room; }
    }
}
