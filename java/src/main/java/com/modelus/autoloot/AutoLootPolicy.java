package com.modelus.autoloot;

import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import java.util.function.Predicate;
import java.util.regex.Pattern;

/** Pure allowlist and item-eligibility rules for Auto Loot. */
public final class AutoLootPolicy {

    private static final Pattern FULL_TYPE = Pattern.compile("^[A-Za-z0-9_]+\\.[A-Za-z0-9_]+$");

    private AutoLootPolicy() {
    }

    public static Set<String> parseAllowlist(String stored) {
        Set<String> types = new LinkedHashSet<>();
        if (stored == null || stored.isBlank()) {
            return types;
        }

        for (String candidate : stored.split("\\|", -1)) {
            String fullType = candidate.trim();
            if (isValidFullType(fullType)) {
                types.add(fullType);
            }
        }
        return types;
    }

    public static String serializeAllowlist(Collection<String> types) {
        if (types == null || types.isEmpty()) {
            return "";
        }

        TreeSet<String> sorted = new TreeSet<>();
        for (String fullType : types) {
            if (isValidFullType(fullType)) {
                sorted.add(fullType);
            }
        }
        return String.join("|", sorted);
    }

    /** Toggles a valid full type and returns its new enabled state. */
    public static boolean toggleType(Set<String> types, String fullType) {
        if (types == null || !isValidFullType(fullType)) {
            return false;
        }
        if (types.remove(fullType)) {
            return false;
        }
        types.add(fullType);
        return true;
    }

    public static boolean shouldLoot(
            Set<String> types,
            String fullType,
            boolean owned,
            boolean unwanted,
            boolean broken,
            boolean rotten) {
        return types != null
                && isValidFullType(fullType)
                && types.contains(fullType)
                && !owned
                && !unwanted
                && !broken
                && !rotten;
    }

    static boolean isValidFullType(String fullType) {
        return fullType != null && FULL_TYPE.matcher(fullType).matches();
    }

    static <T> List<T> uniqueEligible(Iterable<T> items, Predicate<? super T> eligible, int maxItems) {
        if (items == null || eligible == null || maxItems <= 0) {
            return List.of();
        }

        List<T> result = new ArrayList<>();
        for (T item : items) {
            if (item == null || result.stream().anyMatch(existing -> existing == item)) {
                continue;
            }
            if (!eligible.test(item)) {
                continue;
            }
            result.add(item);
            if (result.size() == maxItems) {
                break;
            }
        }
        return result;
    }
}
