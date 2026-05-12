package com.modelus.ammoconverter;

import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

/**
 * TDD tests for {@link AmmoConverterConfig}.
 *
 * Covers:
 *  - No duplicate ammo types across all tiers.
 *  - Every PACKAGING key is a valid tier loose type.
 *  - Package values (boxValue, cartonValue) are positive.
 *  - Tier membership helpers return correct results.
 *  - Eligible source types excludes the target itself.
 */
class AmmoConverterConfigTest {

    // -------------------------------------------------------------------------
    // Invariant: no duplicates across tiers
    // -------------------------------------------------------------------------

    @Test
    void tiers_have_no_duplicate_ammo_types() {
        Set<String> seen = new HashSet<>();
        for (List<String> types : AmmoConverterConfig.TIERS.values()) {
            for (String t : types) {
                assertTrue(seen.add(t), "Duplicate ammo type in TIERS: " + t);
            }
        }
    }

    // -------------------------------------------------------------------------
    // Invariant: all PACKAGING keys are in TIERS
    // -------------------------------------------------------------------------

    @Test
    void packaging_keys_are_all_in_tiers() {
        Set<String> allTierTypes = new HashSet<>();
        for (List<String> types : AmmoConverterConfig.TIERS.values()) {
            allTierTypes.addAll(types);
        }
        for (String key : AmmoConverterConfig.PACKAGING.keySet()) {
            assertTrue(allTierTypes.contains(key),
                    "PACKAGING key not in TIERS: " + key);
        }
    }

    // -------------------------------------------------------------------------
    // Invariant: package values are positive
    // -------------------------------------------------------------------------

    @Test
    void packaging_boxValues_are_positive() {
        for (Map.Entry<String, AmmoConverterConfig.PackageDef> e : AmmoConverterConfig.PACKAGING.entrySet()) {
            assertTrue(e.getValue().boxValue() > 0,
                    "boxValue must be > 0 for " + e.getKey());
        }
    }

    @Test
    void packaging_cartonValues_are_positive() {
        for (Map.Entry<String, AmmoConverterConfig.PackageDef> e : AmmoConverterConfig.PACKAGING.entrySet()) {
            assertTrue(e.getValue().cartonValue() > 0,
                    "cartonValue must be > 0 for " + e.getKey());
        }
    }

    // -------------------------------------------------------------------------
    // getTierPeers: returns all same-tier types excluding target
    // -------------------------------------------------------------------------

    @Test
    void getTierPeers_excludes_the_target_type() {
        List<String> peers = AmmoConverterConfig.getTierPeers("Base.Bullets9mm");
        assertFalse(peers.isEmpty(), "9mm must have at least one peer");
        assertFalse(peers.contains("Base.Bullets9mm"), "Peers must not include target itself");
    }

    @Test
    void getTierPeers_includes_other_universal_types() {
        List<String> peers = AmmoConverterConfig.getTierPeers("Base.Bullets9mm");
        assertTrue(peers.contains("Base.Bullets38"), "9mm peers must include .38");
        assertTrue(peers.contains("Base.ShotgunShells"), "9mm peers must include ShotgunShells");
    }

    // -------------------------------------------------------------------------
    // isInTiers: tier membership check
    // -------------------------------------------------------------------------

    @Test
    void isInTiers_returns_true_for_known_type() {
        assertTrue(AmmoConverterConfig.isInTiers("Base.556Bullets"));
    }

    @Test
    void isInTiers_returns_false_for_unknown_type() {
        assertFalse(AmmoConverterConfig.isInTiers("Base.UnknownBullets"));
    }

    // -------------------------------------------------------------------------
    // TIERS must contain expected canonical types
    // -------------------------------------------------------------------------

    @Test
    void tiers_universal_contains_expected_calibers() {
        List<String> universal = AmmoConverterConfig.TIERS.get("universal");
        assertNotNull(universal, "universal tier must exist");
        assertTrue(universal.contains("Base.Bullets9mm"));
        assertTrue(universal.contains("Base.ShotgunShells"));
        assertTrue(universal.contains("Base.556Bullets"));
        assertTrue(universal.size() >= 9, "Universal tier must have at least 9 calibers");
    }

    @Test
    void script_to_full_type_maps_b42_weapon_ammo_ids() {
        assertEquals("Base.Bullets9mm", AmmoConverterConfig.SCRIPT_TO_FULL_TYPE.get("base:bullets_9mm"));
        assertEquals("Base.ShotgunShells", AmmoConverterConfig.SCRIPT_TO_FULL_TYPE.get("base:shotgun_shells"));
    }

    @Test
    void script_to_full_type_values_are_all_in_tiers() {
        Set<String> allTierTypes = new HashSet<>();
        for (List<String> types : AmmoConverterConfig.TIERS.values()) {
            allTierTypes.addAll(types);
        }
        for (String fullType : AmmoConverterConfig.SCRIPT_TO_FULL_TYPE.values()) {
            assertTrue(allTierTypes.contains(fullType), "Mapped script id points outside tiers: " + fullType);
        }
    }
}
