package com.modelus.validation;

import java.util.ArrayList;
import java.util.List;

/**
 * Entry-point that runs all weight-reducer validators, prints every diagnostic,
 * and exits with code 1 if any rule fails.
 *
 * <p>This class is called by the {@code validateWeightReducer} Gradle task.</p>
 *
 * <p>Validators run in order:</p>
 * <ol>
 *   <li>{@link CatalogValidator} — structural checks (B42 fullTypes, duplicates, bounds)</li>
 *   <li>{@link BurnablePolicyValidator} — burnable fuel-duration policy</li>
 *   <li>{@link PZScriptValidator} — optional local B42 script cross-reference</li>
 * </ol>
 */
public final class WeightReducerValidationRunner {

    private WeightReducerValidationRunner() {
    }

    /** Run all validators; return aggregated result. */
    public static ValidationResult runAll() {
        List<WeightValidationRule> rules = List.of(
                new CatalogValidator(),
                new BurnablePolicyValidator(),
                new PZScriptValidator()
        );

        List<ValidationResult> results = new ArrayList<>();
        for (WeightValidationRule rule : rules) {
            ValidationResult result = rule.validate();
            results.add(result);

            // Print every diagnostic immediately
            for (String warning : result.warnings()) {
                System.out.println("[WARN]  " + warning);
            }
            for (String error : result.errors()) {
                System.err.println("[ERROR] " + error);
            }
        }

        return ValidationResult.merge("WeightReducerValidationRunner", results);
    }

    public static void main(String[] args) {
        System.out.println("=== Modelus Weight-Reducer Validation ===");
        ValidationResult result = runAll();

        System.out.println();
        if (result.isPassing()) {
            System.out.println("[PASS] All validation rules passed.");
            System.exit(0);
        } else {
            System.err.println("[FAIL] " + result.errors().size() + " error(s) found.");
            System.exit(1);
        }
    }
}
