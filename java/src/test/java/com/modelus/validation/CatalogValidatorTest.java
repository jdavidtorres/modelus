package com.modelus.validation;

import com.modelus.weight.FuelCompensationMode;
import com.modelus.weight.WeightReducerCatalog;
import com.modelus.weight.WeightReducerCatalog.CatalogEntry;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for {@link CatalogValidator}.
 */
class CatalogValidatorTest {

    @Test
    void livecatalog_passes_validation() {
        CatalogValidator validator = new CatalogValidator();
        ValidationResult result = validator.validate();
        assertTrue(result.isPassing(),
                "Live catalog should pass CatalogValidator. Errors: " + result.errors());
    }

    @Test
    void catalog_has_no_duplicate_fullTypes() {
        List<String> all = WeightReducerCatalog.flattenedItems();
        long distinct = all.stream().distinct().count();
        assertEquals(all.size(), distinct, "Catalog must not have duplicate fullTypes");
    }

    @Test
    void all_fullTypes_match_Base_prefix() {
        for (String fullType : WeightReducerCatalog.flattenedItems()) {
            assertTrue(fullType.startsWith("Base."),
                    "Non-Base fullType found (B42 only): " + fullType);
        }
    }

    @Test
    void multiplier_is_in_range() {
        double m = WeightReducerCatalog.MULTIPLIER;
        assertTrue(m > 0.0 && m <= 1.0,
                "Multiplier must be in (0, 1] but was: " + m);
    }

    @Test
    void no_family_is_empty() {
        for (Map.Entry<String, List<CatalogEntry>> fam
                : WeightReducerCatalog.entriesByFamily().entrySet()) {
            assertFalse(fam.getValue().isEmpty(),
                    "Family must not be empty: " + fam.getKey());
        }
    }

    @Test
    void duplicate_entry_causes_validation_failure() {
        // Build a list with a deliberate duplicate
        List<CatalogEntry> withDuplicate = new ArrayList<>();
        withDuplicate.add(new CatalogEntry("Base.Hammer", "TOOLS", 0.3, false, FuelCompensationMode.NONE));
        withDuplicate.add(new CatalogEntry("Base.Hammer", "TOOLS", 0.3, false, FuelCompensationMode.NONE)); // dup

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> WeightReducerCatalog.validateEntries(withDuplicate));
        assertTrue(ex.getMessage().contains("Duplicate"), "Expected duplicate error");
    }

    @Test
    void invalid_fullType_causes_validation_failure() {
        List<CatalogEntry> badEntry = List.of(
                new CatalogEntry("invalid-no-dot", "TOOLS", 0.3, false, FuelCompensationMode.NONE));

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> WeightReducerCatalog.validateEntries(badEntry));
        assertTrue(ex.getMessage().contains("Invalid fullType"), "Expected invalid fullType error");
    }

    @Test
    void out_of_bounds_multiplier_causes_validation_failure() {
        List<CatalogEntry> badMult = List.of(
                new CatalogEntry("Base.Hammer", "TOOLS", 1.5, false, FuelCompensationMode.NONE));

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> WeightReducerCatalog.validateEntries(badMult));
        assertTrue(ex.getMessage().contains("multiplier"), "Expected multiplier error");
    }
}
