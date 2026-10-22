package com.modelus.autoeat;

import java.util.List;
import java.util.function.Function;

import zombie.entity.components.crafting.recipe.CraftRecipeData;
import zombie.inventory.InventoryItem;

/** Java-side helpers for the auto-eat canned-food action flow. */
public final class AutoEatBridge {

    private AutoEatBridge() {
    }

    /**
     * Returns the sole item created by the recipe when it matches the expected type.
     * The returned value is the original inventory-item instance from the recipe data.
     */
    public static InventoryItem createdOutput(CraftRecipeData data, String expectedType) {
        if (data == null || expectedType == null || expectedType.isBlank()) {
            return null;
        }

        return selectCreatedOutput(data.getAllCreatedItems(), InventoryItem::getFullType, expectedType);
    }

    static <T> T selectCreatedOutput(
            List<T> createdItems,
            Function<? super T, String> fullTypeOf,
            String expectedType) {
        if (createdItems == null || createdItems.size() != 1
                || fullTypeOf == null || expectedType == null || expectedType.isBlank()) {
            return null;
        }

        T item = createdItems.get(0);
        if (item == null || !expectedType.equals(fullTypeOf.apply(item))) {
            return null;
        }
        return item;
    }

    /** Tracks the terminal outcome of one automatic can-opening attempt. */
    public static final class PendingCan {

        public enum State {
            PENDING,
            SUCCEEDED,
            CANCELLED,
            FAILED
        }

        private State state = State.PENDING;

        public State getState() {
            return state;
        }

        public boolean finish() {
            return transitionTo(State.SUCCEEDED);
        }

        public boolean cancel() {
            return transitionTo(State.CANCELLED);
        }

        public boolean fail() {
            return transitionTo(State.FAILED);
        }

        private boolean transitionTo(State terminalState) {
            if (state != State.PENDING) {
                return false;
            }
            state = terminalState;
            return true;
        }
    }
}
