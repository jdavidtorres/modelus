package com.modelus.autoeat;

import java.util.List;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertNull;

class AutoEatBridgeTest {

    @Test
    void selects_the_original_single_created_item_when_type_matches() {
        StubItem createdItem = new StubItem("Base.OpenBeans");
        StubItem otherItemWithSameType = new StubItem("Base.OpenBeans");

        StubItem selected = AutoEatBridge.selectCreatedOutput(
                List.of(createdItem), item -> item.fullType, "Base.OpenBeans");

        assertSame(createdItem, selected);
        assertFalse(createdItem == otherItemWithSameType);
    }

    @Test
    void rejects_missing_multiple_mismatched_or_null_outputs() {
        StubItem item = new StubItem("Base.OpenBeans");
        List<StubItem> noItems = List.of();
        List<StubItem> nullItems = null;

        assertNull(AutoEatBridge.selectCreatedOutput(noItems, value -> value.fullType, "Base.OpenBeans"));
        assertNull(AutoEatBridge.selectCreatedOutput(
                List.of(item, item), value -> value.fullType, "Base.OpenBeans"));
        assertNull(AutoEatBridge.selectCreatedOutput(List.of(item), value -> value.fullType, "Base.TinnedSoupOpen"));
        assertNull(AutoEatBridge.selectCreatedOutput(nullItems, value -> value.fullType, "Base.OpenBeans"));
        assertNull(AutoEatBridge.selectCreatedOutput(List.of(item), value -> value.fullType, null));
    }

    @Test
    void pending_can_allows_only_one_terminal_transition() {
        AutoEatBridge.PendingCan pending = new AutoEatBridge.PendingCan();

        assertEquals(AutoEatBridge.PendingCan.State.PENDING, pending.getState());
        assertTrue(pending.finish());
        assertEquals(AutoEatBridge.PendingCan.State.SUCCEEDED, pending.getState());
        assertFalse(pending.finish());
        assertFalse(pending.cancel());
        assertFalse(pending.fail());
        assertEquals(AutoEatBridge.PendingCan.State.SUCCEEDED, pending.getState());
    }

    @Test
    void cancellation_and_failure_are_terminal() {
        AutoEatBridge.PendingCan cancelled = new AutoEatBridge.PendingCan();
        assertTrue(cancelled.cancel());
        assertFalse(cancelled.finish());
        assertEquals(AutoEatBridge.PendingCan.State.CANCELLED, cancelled.getState());

        AutoEatBridge.PendingCan failed = new AutoEatBridge.PendingCan();
        assertTrue(failed.fail());
        assertFalse(failed.finish());
        assertEquals(AutoEatBridge.PendingCan.State.FAILED, failed.getState());
    }

    private static final class StubItem {
        private final String fullType;

        private StubItem(String fullType) {
            this.fullType = fullType;
        }
    }
}
