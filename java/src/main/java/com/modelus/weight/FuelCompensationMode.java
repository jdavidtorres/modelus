package com.modelus.weight;

/**
 * Describes how fuel/burn duration side-effects are compensated when
 * a weight reduction is applied to a burnable item.
 *
 * <ul>
 *   <li>{@link #NONE} — item is not burnable; no compensation needed.</li>
 *   <li>{@link #DURATION_MULTIPLIED} — FireFuelRatio is explicitly multiplied
 *       inversely to the weight multiplier so burn duration stays constant.</li>
 *   <li>{@link #EXCLUDED} — item is burnable but intentionally excluded from
 *       weight reduction; vanilla weight and burn duration are preserved.</li>
 * </ul>
 */
public enum FuelCompensationMode {
    /** Item is not burnable; no fuel-duration compensation required. */
    NONE,

    /**
     * Burn duration is preserved by multiplying FireFuelRatio by
     * {@code 1 / weightMultiplier} at script-patch time.
     */
    DURATION_MULTIPLIED,

    /**
     * Item is burnable but is explicitly excluded from weight reduction
     * to preserve vanilla fire/cooking balance.
     */
    EXCLUDED
}
