package com.modelus.validation;

/**
 * Strategy interface for a single weight-reducer validation rule.
 *
 * <p>Implementations inspect the catalog (or filesystem) and return a
 * {@link ValidationResult} describing whether validation passed and any
 * diagnostics collected.  Rules should be stateless.</p>
 */
@FunctionalInterface
public interface WeightValidationRule {

    /**
     * Execute this validation rule.
     *
     * @return a {@link ValidationResult}; never {@code null}.
     */
    ValidationResult validate();

    /** Human-readable name identifying this rule. */
    default String name() {
        return getClass().getSimpleName();
    }
}
