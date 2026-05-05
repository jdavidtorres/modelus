package com.modelus.validation;

import com.modelus.weight.FuelCompensationMode;
import com.modelus.weight.WeightReducerCatalog;
import com.modelus.weight.WeightReducerCatalog.CatalogEntry;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for {@link BurnablePolicyValidator}.
 */
class BurnablePolicyValidatorTest {

    @Test
    void live_catalog_passes_burnable_policy() {
        // All live catalog entries are non-burnable with NONE compensation — should pass.
        BurnablePolicyValidator validator = new BurnablePolicyValidator();
        ValidationResult result = validator.validate();
        assertTrue(result.isPassing(),
                "Live catalog should pass BurnablePolicyValidator. Errors: " + result.errors());
    }

    @Test
    void burnable_with_NONE_compensation_fails() {
        // Synthetic fixture: one burnable item with NONE compensation — must be rejected.
        CatalogEntry burnableNone = new CatalogEntry(
                "Base.Campfire", "FUEL", 0.3, true, FuelCompensationMode.NONE);

        BurnablePolicyValidator validator = new BurnablePolicyValidator(List.of(burnableNone));
        ValidationResult result = validator.validate();

        assertTrue(result.isFailing(),
                "Burnable entry with NONE compensation must cause validator failure");
        assertEquals(1, result.errors().size());
        assertTrue(result.errors().get(0).contains("Base.Campfire"),
                "Error message must identify the offending fullType");
        assertTrue(result.errors().get(0).contains("DURATION_MULTIPLIED or EXCLUDED"),
                "Error message must state the valid alternatives");
    }

    @Test
    void burnable_with_DURATION_MULTIPLIED_passes() {
        CatalogEntry burnableOk = new CatalogEntry(
                "Base.Campfire", "FUEL", 0.3, true, FuelCompensationMode.DURATION_MULTIPLIED);

        BurnablePolicyValidator validator = new BurnablePolicyValidator(List.of(burnableOk));
        ValidationResult result = validator.validate();

        assertTrue(result.isPassing(),
                "Burnable entry with DURATION_MULTIPLIED must pass. Errors: " + result.errors());
    }

    @Test
    void burnable_with_EXCLUDED_passes() {
        CatalogEntry burnableExcluded = new CatalogEntry(
                "Base.Campfire", "FUEL", 0.3, true, FuelCompensationMode.EXCLUDED);

        BurnablePolicyValidator validator = new BurnablePolicyValidator(List.of(burnableExcluded));
        ValidationResult result = validator.validate();

        assertTrue(result.isPassing(),
                "Burnable entry with EXCLUDED must pass. Errors: " + result.errors());
    }

    @Test
    void non_burnable_with_EXCLUDED_produces_warning_not_error() {
        CatalogEntry nonBurnableExcluded = new CatalogEntry(
                "Base.PlasticBag", "MISC", 0.3, false, FuelCompensationMode.EXCLUDED);

        BurnablePolicyValidator validator = new BurnablePolicyValidator(List.of(nonBurnableExcluded));
        ValidationResult result = validator.validate();

        assertTrue(result.isPassing(),
                "Non-burnable EXCLUDED is a warning, not an error — must pass. Errors: " + result.errors());
        assertEquals(1, result.warnings().size(),
                "Must have exactly one warning for EXCLUDED on non-burnable");
    }

    @Test
    void validation_result_merge_aggregates_errors() {
        ValidationResult r1 = ValidationResult.passing("RuleA");
        ValidationResult r2 = ValidationResult.failing("RuleB", "Error from B");
        ValidationResult merged = ValidationResult.merge("Merged", List.of(r1, r2));

        assertTrue(merged.isFailing());
        assertEquals(1, merged.errors().size());
        assertTrue(merged.errors().get(0).contains("Error from B"));
    }

    @Test
    void validation_result_passing_has_no_errors() {
        ValidationResult result = ValidationResult.passing("Test", List.of("a warning"));
        assertTrue(result.isPassing());
        assertFalse(result.isFailing());
        assertEquals(0, result.errors().size());
        assertEquals(1, result.warnings().size());
    }

    @Test
    void validation_result_failing_requires_non_empty_errors() {
        assertThrows(IllegalArgumentException.class,
                () -> ValidationResult.failing("Test", List.of()));
    }
}
