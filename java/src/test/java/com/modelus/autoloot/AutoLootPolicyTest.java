package com.modelus.autoloot;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.Test;

class AutoLootPolicyTest {

    @Test
    void missing_or_invalid_allowlist_entries_produce_an_empty_or_clean_set() {
        assertTrue(AutoLootPolicy.parseAllowlist(null).isEmpty());
        assertTrue(AutoLootPolicy.parseAllowlist("  ").isEmpty());
        assertEquals(Set.of("Base.Apple", "Base.WaterBottle"),
                AutoLootPolicy.parseAllowlist("Base.Apple|invalid|Base.Apple| Base.WaterBottle "));
    }

    @Test
    void allowlist_serialization_is_sorted_and_round_trips() {
        Set<String> types = new LinkedHashSet<>(List.of("Base.WaterBottle", "Base.Apple"));

        String serialized = AutoLootPolicy.serializeAllowlist(types);

        assertEquals("Base.Apple|Base.WaterBottle", serialized);
        assertEquals(types, AutoLootPolicy.parseAllowlist(serialized));
        assertEquals(serialized, AutoLootPolicy.serializeAllowlist(AutoLootPolicy.parseAllowlist(serialized)));
    }

    @Test
    void toggle_adds_then_removes_and_rejects_invalid_types() {
        Set<String> types = new LinkedHashSet<>();

        assertTrue(AutoLootPolicy.toggleType(types, "Base.CannedBolognese"));
        assertFalse(AutoLootPolicy.toggleType(types, "Base.CannedBolognese"));
        assertFalse(AutoLootPolicy.toggleType(types, "Base.Bad|Type"));
        assertFalse(AutoLootPolicy.toggleType(types, " "));
        assertTrue(types.isEmpty());
    }

    @Test
    void full_type_matching_is_exact_for_module_case_and_item_variant() {
        Set<String> types = Set.of("Base.CannedBolognese");

        assertTrue(AutoLootPolicy.shouldLoot(types, "Base.CannedBolognese", false, false, false, false));
        assertFalse(AutoLootPolicy.shouldLoot(types, "Base.CannedBologneseOpen", false, false, false, false));
        assertFalse(AutoLootPolicy.shouldLoot(types, "base.CannedBolognese", false, false, false, false));
        assertFalse(AutoLootPolicy.shouldLoot(types, "Other.CannedBolognese", false, false, false, false));
    }

    @Test
    void every_exclusion_rejects_an_otherwise_allowed_item() {
        Set<String> types = Set.of("Base.Apple");

        assertFalse(AutoLootPolicy.shouldLoot(types, "Base.Apple", true, false, false, false));
        assertFalse(AutoLootPolicy.shouldLoot(types, "Base.Apple", false, true, false, false));
        assertFalse(AutoLootPolicy.shouldLoot(types, "Base.Apple", false, false, true, false));
        assertFalse(AutoLootPolicy.shouldLoot(types, "Base.Apple", false, false, false, true));
        assertFalse(AutoLootPolicy.shouldLoot(types, "Base.Other", false, false, false, false));
    }

    @Test
    void unique_eligible_items_keep_identity_and_order_and_obey_limit() {
        Item first = new Item("same");
        Item equalButDistinct = new Item("same");
        List<Item> candidates = new ArrayList<>(List.of(first, first, equalButDistinct, new Item("skip")));

        List<Item> selected = AutoLootPolicy.uniqueEligible(
                candidates, item -> !item.id().equals("skip"), 2);

        assertEquals(2, selected.size());
        assertSame(first, selected.get(0));
        assertSame(equalButDistinct, selected.get(1));
        assertTrue(AutoLootPolicy.uniqueEligible(candidates, item -> true, 0).isEmpty());
    }

    private record Item(String id) {
        @Override
        public boolean equals(Object other) {
            return other instanceof Item item && id.equals(item.id);
        }

        @Override
        public int hashCode() {
            return id.hashCode();
        }
    }
}
