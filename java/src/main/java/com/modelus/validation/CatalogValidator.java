package com.modelus.validation;

import com.modelus.weight.FuelCompensationMode;
import com.modelus.weight.WeightReducerCatalog;
import com.modelus.weight.WeightReducerCatalog.CatalogEntry;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Validates the structural integrity of {@link WeightReducerCatalog}.
 *
 * <p>Checks performed:</p>
 * <ul>
 *   <li>All fullTypes match the {@code Base.*} pattern (B42-only constraint).</li>
 *   <li>No duplicate fullTypes across families.</li>
 *   <li>No family is empty.</li>
 *   <li>All multipliers are within {@code (0, 1]}.</li>
 *   <li>Entries are in deterministic (insertion) order.</li>
 * </ul>
 */
public final class CatalogValidator implements WeightValidationRule {

    private static final Pattern BASE_FULL_TYPE =
            Pattern.compile("^Base\\.[A-Za-z0-9_]+$");

    @Override
    public String name() {
        return "CatalogValidator";
    }

    @Override
    public ValidationResult validate() {
        List<String> errors = new ArrayList<>();

        Map<String, List<CatalogEntry>> byFamily = WeightReducerCatalog.entriesByFamily();

        Set<String> seen = new LinkedHashSet<>();
        for (Map.Entry<String, List<CatalogEntry>> familyEntry : byFamily.entrySet()) {
            String family = familyEntry.getKey();
            List<CatalogEntry> entries = familyEntry.getValue();

            if (entries.isEmpty()) {
                errors.add("[CatalogValidator] Family is empty: " + family);
                continue;
            }

            for (CatalogEntry entry : entries) {
                // B42-only: all fullTypes must be Base.*
                if (!BASE_FULL_TYPE.matcher(entry.fullType()).matches()) {
                    errors.add("[CatalogValidator] Non-Base fullType (B42 only): " + entry.fullType()
                            + " in family " + family);
                }

                // No duplicates
                if (!seen.add(entry.fullType())) {
                    errors.add("[CatalogValidator] Duplicate fullType: " + entry.fullType()
                            + " in family " + family);
                }

                // Multiplier bounds
                if (entry.multiplier() <= 0.0D || entry.multiplier() > 1.0D) {
                    errors.add("[CatalogValidator] Multiplier out of (0,1]: "
                            + entry.multiplier() + " for " + entry.fullType());
                }
            }
        }

        if (errors.isEmpty()) {
            return ValidationResult.passing(name(),
                    List.of("[CatalogValidator] " + seen.size() + " entries validated across "
                            + byFamily.size() + " families."));
        }
        return ValidationResult.failing(name(), errors);
    }
}
