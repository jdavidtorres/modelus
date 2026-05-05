package com.modelus.validation;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for {@link AmmoConverterTableValidator}.
 *
 * Validates the AmmoConverter.lua tier and packaging tables without running the game:
 *  - Verbose diagnostics must be OFF by default (quiet logging requirement).
 *  - All declared TIERS entries must be recognized canonical Base.* full types.
 *  - No duplicate entries within a tier.
 *  - Every PACKAGING entry must reference an existing TIERS loose type.
 *  - Self-target pairs (srcType == dstType) are architecturally prevented by peers table construction.
 *  - PACKAGING round values must be positive integers.
 *  - OnContainerUpdate must not bypass throttle (guarded event check).
 */
class AmmoConverterTableValidatorTest {

    private final AmmoConverterTableValidator validator = new AmmoConverterTableValidator();

    // -------------------------------------------------------------------------
    // Task 1.2 — Quiet default logging
    // -------------------------------------------------------------------------

    @Test
    void verboseDiagnostics_defaults_to_false() {
        ValidationResult result = validator.validateVerboseFlag();
        assertTrue(result.isPassing(),
                "AmmoConverter.lua must have _VERBOSE_DIAGNOSTICS = false. Errors: " + result.errors());
    }

    // -------------------------------------------------------------------------
    // Task 2.1 — Tier tables contain valid Base.* types, no duplicates
    // -------------------------------------------------------------------------

    @Test
    void tierTables_contain_only_known_canonical_types() {
        ValidationResult result = validator.validateTierTypes();
        assertTrue(result.isPassing(),
                "TIERS must only contain recognized Base.* ammo full types. Errors: " + result.errors());
    }

    @Test
    void tierTables_have_no_duplicate_entries() {
        ValidationResult result = validator.validateNoDuplicatesInTiers();
        assertTrue(result.isPassing(),
                "No ammo type should appear more than once across all TIERS. Errors: " + result.errors());
    }

    // -------------------------------------------------------------------------
    // Task 2.2 — Packaging table coherence
    // -------------------------------------------------------------------------

    @Test
    void packagingTable_keys_are_all_known_tier_types() {
        ValidationResult result = validator.validatePackagingKeysAreTierTypes();
        assertTrue(result.isPassing(),
                "Every PACKAGING key must be a loose type present in TIERS. Errors: " + result.errors());
    }

    @Test
    void packagingTable_roundValues_are_positive() {
        ValidationResult result = validator.validatePackagingRoundValues();
        assertTrue(result.isPassing(),
                "Every PACKAGING boxValue and cartonValue must be > 0. Errors: " + result.errors());
    }

    // -------------------------------------------------------------------------
    // Task 4.2 — OnContainerUpdate guarded (no unthrottled re-entry)
    // -------------------------------------------------------------------------

    @Test
    void containerUpdate_event_is_guarded_not_direct_onIdleCheck() {
        ValidationResult result = validator.validateContainerUpdateIsGuarded();
        assertTrue(result.isPassing(),
                "OnContainerUpdate must not call onIdleCheck directly without throttle guard. Errors: " + result.errors());
    }

    // -------------------------------------------------------------------------
    // Triangulation — known good tier types are present
    // -------------------------------------------------------------------------

    @Test
    void tierTables_include_expected_pistol_calibers() {
        List<String> pistolTypes = validator.getTierTypes("pistol");
        assertTrue(pistolTypes.contains("Base.Bullets9mm"),
                "Pistol tier must include Base.Bullets9mm");
        assertTrue(pistolTypes.contains("Base.Bullets38"),
                "Pistol tier must include Base.Bullets38");
        assertTrue(pistolTypes.size() >= 2,
                "Pistol tier must have at least 2 calibers");
    }

    @Test
    void tierTables_include_expected_rifle_calibers() {
        List<String> rifleTypes = validator.getTierTypes("rifle");
        assertTrue(rifleTypes.contains("Base.556Bullets"),
                "Rifle tier must include Base.556Bullets");
        assertTrue(rifleTypes.size() >= 2,
                "Rifle tier must have at least 2 calibers");
    }
}
