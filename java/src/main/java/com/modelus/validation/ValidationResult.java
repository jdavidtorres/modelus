package com.modelus.validation;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Aggregated result from one or more {@link WeightValidationRule} runs.
 *
 * <p>A {@code ValidationResult} is either passing (no errors) or failing.
 * It collects all diagnostic messages so every problem is visible at once
 * rather than failing on the first error.</p>
 */
public final class ValidationResult {

    private final String ruleName;
    private final List<String> errors;
    private final List<String> warnings;

    private ValidationResult(String ruleName, List<String> errors, List<String> warnings) {
        this.ruleName = ruleName;
        this.errors = Collections.unmodifiableList(new ArrayList<>(errors));
        this.warnings = Collections.unmodifiableList(new ArrayList<>(warnings));
    }

    /** Factory: passing result with optional warnings. */
    public static ValidationResult passing(String ruleName, List<String> warnings) {
        return new ValidationResult(ruleName, List.of(), warnings);
    }

    /** Factory: passing result, no warnings. */
    public static ValidationResult passing(String ruleName) {
        return passing(ruleName, List.of());
    }

    /** Factory: failing result with at least one error. */
    public static ValidationResult failing(String ruleName, List<String> errors) {
        if (errors == null || errors.isEmpty()) {
            throw new IllegalArgumentException("Failing result must have at least one error.");
        }
        return new ValidationResult(ruleName, errors, List.of());
    }

    /** Factory: failing result with a single error message. */
    public static ValidationResult failing(String ruleName, String error) {
        return failing(ruleName, List.of(error));
    }

    public String ruleName() { return ruleName; }

    public boolean isPassing() { return errors.isEmpty(); }
    public boolean isFailing() { return !errors.isEmpty(); }

    public List<String> errors() { return errors; }
    public List<String> warnings() { return warnings; }

    /**
     * Merge multiple results into one aggregate.
     * The aggregate passes only if all individual results pass.
     */
    public static ValidationResult merge(String name, List<ValidationResult> results) {
        List<String> allErrors = new ArrayList<>();
        List<String> allWarnings = new ArrayList<>();
        for (ValidationResult r : results) {
            allErrors.addAll(r.errors());
            allWarnings.addAll(r.warnings());
        }
        return new ValidationResult(name, allErrors, allWarnings);
    }

    @Override
    public String toString() {
        return "ValidationResult{rule='" + ruleName + "', passing=" + isPassing()
                + ", errors=" + errors.size() + ", warnings=" + warnings.size() + "}";
    }
}
