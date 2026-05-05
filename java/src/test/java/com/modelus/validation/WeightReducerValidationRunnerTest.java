package com.modelus.validation;

import com.modelus.weight.FuelCompensationMode;
import com.modelus.weight.WeightReducerCatalog;
import com.modelus.weight.WeightReducerCatalog.CatalogEntry;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration test: runs all validators with the live catalog (known-good fixture)
 * and asserts that aggregated diagnostics are collected and the runner passes.
 *
 * <p>Also tests that a known-bad catalog fixture produces aggregated failure diagnostics
 * through the ValidationResult API (not via the runner's System.exit, which we avoid
 * calling in tests).</p>
 */
class WeightReducerValidationRunnerTest {

    @Test
    void runAll_passes_with_live_catalog() {
        ValidationResult result = WeightReducerValidationRunner.runAll();
        assertTrue(result.isPassing(),
                "Validation runner must pass with live catalog. Errors: " + result.errors());
    }

    @Test
    void runAll_reports_warnings_not_errors_for_pz_scripts_skipped() {
        // PZ_SCRIPTS_PATH is optional in local test envs. If it is absent,
        // PZScriptValidator emits a skip warning; if present, the live B42
        // script validation must pass without requiring that warning.
        ValidationResult result = WeightReducerValidationRunner.runAll();
        String scriptsPath = System.getenv("PZ_SCRIPTS_PATH");
        if (scriptsPath == null || scriptsPath.isBlank()) {
            boolean hasSkipWarning = result.warnings().stream()
                    .anyMatch(w -> w.contains("PZ_SCRIPTS_PATH"));
            assertTrue(hasSkipWarning, "Should have skip warning when PZ_SCRIPTS_PATH is not set");
        } else {
            assertTrue(result.isPassing(), "Live B42 script validation should pass when PZ_SCRIPTS_PATH is set");
        }
    }

    @Test
    void known_bad_catalog_produces_aggregated_errors() {
        // Simulate known-bad catalog: two rules, both failing.
        WeightValidationRule badRule1 = () -> ValidationResult.failing(
                "FakeRule1", List.of("Error A", "Error B"));
        WeightValidationRule badRule2 = () -> ValidationResult.failing(
                "FakeRule2", "Error C");

        ValidationResult r1 = badRule1.validate();
        ValidationResult r2 = badRule2.validate();
        ValidationResult merged = ValidationResult.merge("TestAggregate", List.of(r1, r2));

        assertTrue(merged.isFailing());
        assertEquals(3, merged.errors().size(),
                "Merged result must aggregate all 3 errors from both rules");
        assertTrue(merged.errors().contains("Error A"));
        assertTrue(merged.errors().contains("Error B"));
        assertTrue(merged.errors().contains("Error C"));
    }

    @Test
    void catalog_entry_typed_api_is_accessible() {
        List<CatalogEntry> entries = WeightReducerCatalog.entries();
        assertFalse(entries.isEmpty(), "Catalog must not be empty");

        CatalogEntry first = entries.get(0);
        assertNotNull(first.fullType());
        assertNotNull(first.family());
        assertTrue(first.multiplier() > 0 && first.multiplier() <= 1);
        assertNotNull(first.fuelCompensationMode());
        // All active catalog entries should be non-burnable
        assertFalse(first.isBurnable(), "Active catalog entries should not be burnable");
        assertEquals(FuelCompensationMode.NONE, first.fuelCompensationMode());
    }
}
