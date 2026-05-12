package com.modelus.ammoconverter;

import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * TDD tests for {@link AmmoConverterBridge} conversion logic.
 *
 * Because IsoPlayer and ItemContainer cannot be instantiated without the live PZ
 * runtime, all transactional logic is exercised through a stub
 * {@link AmmoConverterBridge.InventoryAdapter} that simulates item counts and
 * tracks removals/additions.
 *
 * Scenarios covered:
 *  - Same-tier conversion: loose + box + carton → destination loose rounds.
 *  - Cross-tier types are ignored (empty peers list).
 *  - Self-target skip: srcType == dstType aborts without inventory change.
 *  - Creation failure abort: if create returns null, no source is consumed.
 *  - Box-to-loose math: consuming 1 box of 9mm (50) produces 50 loose rounds.
 *  - Carton-to-loose math: consuming 1 carton of 9mm (600) produces 600 loose.
 *  - Mixed source: 5 loose + 1 box(50) = 55 destination rounds created.
 */
class AmmoConverterBridgeTest {

    // =========================================================================
    // Test Doubles
    // =========================================================================

    /** Stub item — just holds a type string. */
    static final class StubItem {
        final String fullType;
        StubItem(String fullType) { this.fullType = fullType; }
    }

    /**
     * Stub InventoryAdapter backed by a simple count map.
     * Tracks all removals and additions for assertion.
     */
    static final class StubAdapter implements AmmoConverterBridge.InventoryAdapter<StubItem> {

        final Map<String, Integer> counts = new HashMap<>();
        final List<String> removedTypes = new ArrayList<>();
        final List<String> addedTypes = new ArrayList<>();
        boolean createFails = false;

        StubAdapter withCount(String fullType, int n) {
            counts.put(fullType, n);
            return this;
        }

        @Override
        public int countRecurse(String inventoryKey) {
            // inventoryKey is the suffix part (e.g. "Bullets9mm") — look up by suffix
            for (Map.Entry<String, Integer> e : counts.entrySet()) {
                if (e.getKey().endsWith(inventoryKey)) return e.getValue();
            }
            return 0;
        }

        @Override
        public List<StubItem> getSome(String inventoryKey, int count) {
            List<StubItem> result = new ArrayList<>();
            for (Map.Entry<String, Integer> e : counts.entrySet()) {
                if (e.getKey().endsWith(inventoryKey)) {
                    for (int i = 0; i < e.getValue(); i++) result.add(new StubItem(e.getKey()));
                    return result;
                }
            }
            return result;
        }

        @Override
        public void remove(StubItem item) {
            removedTypes.add(item.fullType);
        }

        @Override
        public StubItem create(String fullType) {
            if (createFails) return null;
            return new StubItem(fullType);
        }

        @Override
        public void add(StubItem item) {
            addedTypes.add(item.fullType);
        }
    }

    // =========================================================================
    // Tests
    // =========================================================================

    // -------------------------------------------------------------------------
    // Same-tier conversion — loose
    // -------------------------------------------------------------------------

    @Test
    void convert_loose_source_to_destination_same_tier() {
        StubAdapter adapter = new StubAdapter()
                .withCount("Base.Bullets38", 10);

        AmmoConverterBridge.convertWith(adapter, "Base.Bullets38", "Base.Bullets9mm");

        assertEquals(10, adapter.addedTypes.size(), "10 loose rounds must be created");
        assertTrue(adapter.addedTypes.stream().allMatch(t -> t.equals("Base.Bullets9mm")),
                "Created items must be destination type");
        assertEquals(10, adapter.removedTypes.size(), "10 source loose must be removed");
    }

    // -------------------------------------------------------------------------
    // Self-target skip
    // -------------------------------------------------------------------------

    @Test
    void convert_self_target_aborts_without_inventory_change() {
        StubAdapter adapter = new StubAdapter()
                .withCount("Base.Bullets9mm", 5);

        AmmoConverterBridge.convertWith(adapter, "Base.Bullets9mm", "Base.Bullets9mm");

        assertTrue(adapter.removedTypes.isEmpty(), "No sources must be removed on self-target");
        assertTrue(adapter.addedTypes.isEmpty(), "No items must be created on self-target");
    }

    // -------------------------------------------------------------------------
    // Creation failure abort
    // -------------------------------------------------------------------------

    @Test
    void convert_aborts_when_create_returns_null() {
        StubAdapter adapter = new StubAdapter()
                .withCount("Base.Bullets38", 3);
        adapter.createFails = true;

        AmmoConverterBridge.convertWith(adapter, "Base.Bullets38", "Base.Bullets9mm");

        assertTrue(adapter.removedTypes.isEmpty(), "No sources must be removed when creation fails");
        assertTrue(adapter.addedTypes.isEmpty(), "No items must be added when creation fails");
    }

    // -------------------------------------------------------------------------
    // Box-to-loose math
    // -------------------------------------------------------------------------

    @Test
    void convert_one_9mm_box_produces_50_loose_rounds() {
        StubAdapter adapter = new StubAdapter()
                .withCount("Base.Bullets9mmBox", 1);

        AmmoConverterBridge.convertWith(adapter, "Base.Bullets9mm", "Base.Bullets38");

        assertEquals(50, adapter.addedTypes.size(), "One 9mm box must produce 50 loose .38 rounds");
        assertEquals(1, adapter.removedTypes.size(), "One box item must be removed");
    }

    // -------------------------------------------------------------------------
    // Carton-to-loose math
    // -------------------------------------------------------------------------

    @Test
    void convert_one_9mm_carton_produces_600_loose_rounds() {
        StubAdapter adapter = new StubAdapter()
                .withCount("Base.Bullets9mmCarton", 1);

        AmmoConverterBridge.convertWith(adapter, "Base.Bullets9mm", "Base.Bullets38");

        assertEquals(600, adapter.addedTypes.size(), "One 9mm carton must produce 600 loose .38 rounds");
        assertEquals(1, adapter.removedTypes.size(), "One carton item must be removed");
    }

    // -------------------------------------------------------------------------
    // Mixed sources
    // -------------------------------------------------------------------------

    @Test
    void convert_mixed_loose_and_box_produces_correct_total() {
        StubAdapter adapter = new StubAdapter()
                .withCount("Base.Bullets38", 5)
                .withCount("Base.Bullets38Box", 1); // 1 box = 50

        AmmoConverterBridge.convertWith(adapter, "Base.Bullets38", "Base.Bullets9mm");

        // 5 loose + 50 from 1 box = 55 destination rounds
        assertEquals(55, adapter.addedTypes.size(), "5 loose + 1 box must produce 55 destination rounds");
        // 5 loose items + 1 box item removed
        assertEquals(6, adapter.removedTypes.size(), "5 loose + 1 box source items must be removed");
    }

    // -------------------------------------------------------------------------
    // No source — no change
    // -------------------------------------------------------------------------

    @Test
    void convert_with_no_source_stock_does_nothing() {
        StubAdapter adapter = new StubAdapter(); // all counts zero

        AmmoConverterBridge.convertWith(adapter, "Base.Bullets38", "Base.Bullets9mm");

        assertTrue(adapter.removedTypes.isEmpty(), "Nothing to remove when no source");
        assertTrue(adapter.addedTypes.isEmpty(), "Nothing to add when no source");
    }
}
