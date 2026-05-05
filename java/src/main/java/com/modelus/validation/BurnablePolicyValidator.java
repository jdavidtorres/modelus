package com.modelus.validation;

import com.modelus.weight.FuelCompensationMode;
import com.modelus.weight.WeightReducerCatalog;
import com.modelus.weight.WeightReducerCatalog.CatalogEntry;

import java.util.ArrayList;
import java.util.List;

/**
 * Validates that burnable items in the catalog have explicit fuel-duration
 * compensation metadata.
 *
 * <p>Rules:</p>
 * <ul>
 *   <li>A burnable entry ({@code isBurnable == true}) MUST have
 *       {@link FuelCompensationMode#DURATION_MULTIPLIED} or
 *       {@link FuelCompensationMode#EXCLUDED} — never {@link FuelCompensationMode#NONE}.</li>
 *   <li>An entry with {@link FuelCompensationMode#EXCLUDED} is allowed only when
 *       {@code isBurnable == true}; a non-burnable item marked EXCLUDED is a
 *       misconfiguration (warning, not error).</li>
 * </ul>
 *
 * <p>The intent is to prevent silent burn-duration regression when weight
 * reduction is applied without compensating {@code FireFuelRatio}.</p>
 */
public final class BurnablePolicyValidator implements WeightValidationRule {

    /**
     * Optional override list for testing. When {@code null}, the live catalog is used.
     */
    private final List<CatalogEntry> overrideEntries;

    /** Construct with the live catalog. */
    public BurnablePolicyValidator() {
        this.overrideEntries = null;
    }

    /**
     * Construct with an injected entry list (for unit testing).
     *
     * @param entries synthetic entries to validate instead of the live catalog.
     */
    public BurnablePolicyValidator(List<CatalogEntry> entries) {
        this.overrideEntries = List.copyOf(entries);
    }

    @Override
    public String name() {
        return "BurnablePolicyValidator";
    }

    @Override
    public ValidationResult validate() {
        List<String> errors = new ArrayList<>();
        List<String> warnings = new ArrayList<>();

        List<CatalogEntry> entries = overrideEntries != null
                ? overrideEntries
                : WeightReducerCatalog.entries();

        for (CatalogEntry entry : entries) {
            if (entry.isBurnable()) {
                if (entry.fuelCompensationMode() == FuelCompensationMode.NONE) {
                    errors.add("[BurnablePolicyValidator] Burnable entry lacks explicit compensation: "
                            + entry.fullType()
                            + " — must be DURATION_MULTIPLIED or EXCLUDED");
                }
                // DURATION_MULTIPLIED and EXCLUDED are both valid for burnable items.
            } else {
                // Non-burnable items should not be EXCLUDED (misconfiguration)
                if (entry.fuelCompensationMode() == FuelCompensationMode.EXCLUDED) {
                    warnings.add("[BurnablePolicyValidator] Non-burnable item marked EXCLUDED: "
                            + entry.fullType() + " — consider setting NONE");
                }
            }
        }

        if (errors.isEmpty()) {
            return ValidationResult.passing(name(), warnings);
        }
        return ValidationResult.failing(name(), errors);
    }
}
