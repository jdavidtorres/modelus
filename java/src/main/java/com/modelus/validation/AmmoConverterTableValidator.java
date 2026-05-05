package com.modelus.validation;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Validates the AmmoConverter.lua tier and packaging tables without running the game.
 *
 * <p>Parses the Lua source file directly to assert structural invariants required by
 * the SDD spec and design:</p>
 * <ul>
 *   <li>Verbose diagnostics default to {@code false} (quiet logging requirement).</li>
 *   <li>All TIERS entries are recognized canonical {@code Base.*} full types.</li>
 *   <li>No duplicate entries within a tier.</li>
 *   <li>Every PACKAGING key corresponds to a loose type in TIERS.</li>
 *   <li>PACKAGING round values are positive.</li>
 *   <li>OnContainerUpdate is guarded (not a direct call to onIdleCheck).</li>
 * </ul>
 */
public final class AmmoConverterTableValidator {

    /** Path to the Lua source file, relative to the repo root. */
    private static final String LUA_PATH =
            "mods/modelus/common/media/lua/client/ammo-converter/AmmoConverter.lua";

    /** Canonical Base.* ammo types recognized as valid by the mod. */
    private static final Set<String> KNOWN_BASE_AMMO_TYPES = Set.of(
            "Base.Bullets9mm",
            "Base.Bullets38",
            "Base.Bullets45",
            "Base.Bullets357",
            "Base.Bullets44",
            "Base.556Bullets",
            "Base.308Bullets",
            "Base.3030Bullets",
            "Base.ShotgunShells"
    );

    // -- Patterns for Lua source extraction -----------------------------------

    private static final Pattern VERBOSE_FLAG =
            Pattern.compile("_VERBOSE_DIAGNOSTICS\\s*=\\s*(true|false)");

    /** Matches quoted string entries inside TIERS table: "Base.Xxx" */
    private static final Pattern TIER_ENTRY =
            Pattern.compile("\"(Base\\.[A-Za-z0-9_]+)\"");

    /** Matches PACKAGING keys: ["Base.Xxx"] = { ... boxValue = N, cartonValue = M */
    private static final Pattern PKG_KEY =
            Pattern.compile("\\[\"(Base\\.[A-Za-z0-9_]+)\"\\]\\s*=\\s*\\{");
    private static final Pattern PKG_BOX_VALUE =
            Pattern.compile("boxValue\\s*=\\s*(\\d+)");
    private static final Pattern PKG_CARTON_VALUE =
            Pattern.compile("cartonValue\\s*=\\s*(\\d+)");

    /** Detects whether OnContainerUpdate calls onIdleCheck without a tick guard. */
    private static final Pattern CONTAINER_DIRECT_IDLE =
            Pattern.compile("OnContainerUpdate.*onIdleCheck|onIdleCheck.*OnContainerUpdate");

    // -- Helper: read Lua source -----------------------------------------------

    private String readLua() throws IOException {
        Path base = repoRoot();
        return Files.readString(base.resolve(LUA_PATH));
    }

    private static Path repoRoot() {
        // Walk up from the java/ directory to the repo root.
        Path cwd = Path.of(System.getProperty("user.dir")).toAbsolutePath();
        // cwd is typically the java/ sub-directory when gradlew runs.
        // Accept either the repo root (contains mods/) or its parent.
        for (Path candidate : List.of(cwd, cwd.getParent())) {
            if (candidate != null && Files.isDirectory(candidate.resolve("mods"))) {
                return candidate;
            }
        }
        return cwd; // fallback — will fail readString with a clear IOException
    }

    // -- Public validation methods --------------------------------------------

    /** Task 1.2: _VERBOSE_DIAGNOSTICS must default to false. */
    public ValidationResult validateVerboseFlag() {
        String src;
        try { src = readLua(); } catch (IOException e) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "Cannot read Lua source: " + e.getMessage());
        }
        Matcher m = VERBOSE_FLAG.matcher(src);
        if (!m.find()) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "_VERBOSE_DIAGNOSTICS flag not found in AmmoConverter.lua");
        }
        String value = m.group(1);
        if (!"false".equals(value)) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "_VERBOSE_DIAGNOSTICS must be false by default, found: " + value);
        }
        return ValidationResult.passing("AmmoConverterTableValidator");
    }

    /** Task 2.1: All TIERS entries must be known Base.* types. */
    public ValidationResult validateTierTypes() {
        String src;
        try { src = readLua(); } catch (IOException e) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "Cannot read Lua source: " + e.getMessage());
        }
        // Extract the TIERS block: from "AmmoConverter.TIERS = {" to the matching "}"
        String tiersBlock = extractBlock(src, "AmmoConverter.TIERS");
        if (tiersBlock == null) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "TIERS block not found in AmmoConverter.lua");
        }

        List<String> errors = new ArrayList<>();
        Matcher m = TIER_ENTRY.matcher(tiersBlock);
        while (m.find()) {
            String type = m.group(1);
            if (!KNOWN_BASE_AMMO_TYPES.contains(type)) {
                errors.add("Unknown ammo type in TIERS: " + type);
            }
        }
        return errors.isEmpty()
                ? ValidationResult.passing("AmmoConverterTableValidator")
                : ValidationResult.failing("AmmoConverterTableValidator", errors);
    }

    /** Task 2.1: No duplicate types across all tiers. */
    public ValidationResult validateNoDuplicatesInTiers() {
        String src;
        try { src = readLua(); } catch (IOException e) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "Cannot read Lua source: " + e.getMessage());
        }
        String tiersBlock = extractBlock(src, "AmmoConverter.TIERS");
        if (tiersBlock == null) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "TIERS block not found in AmmoConverter.lua");
        }

        Set<String> seen = new LinkedHashSet<>();
        List<String> errors = new ArrayList<>();
        Matcher m = TIER_ENTRY.matcher(tiersBlock);
        while (m.find()) {
            String type = m.group(1);
            if (!seen.add(type)) {
                errors.add("Duplicate ammo type in TIERS: " + type);
            }
        }
        return errors.isEmpty()
                ? ValidationResult.passing("AmmoConverterTableValidator")
                : ValidationResult.failing("AmmoConverterTableValidator", errors);
    }

    /** Task 2.2: PACKAGING keys must all appear in TIERS. */
    public ValidationResult validatePackagingKeysAreTierTypes() {
        String src;
        try { src = readLua(); } catch (IOException e) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "Cannot read Lua source: " + e.getMessage());
        }

        Set<String> tierTypes = new HashSet<>(allTierTypes(src));
        String pkgBlock = extractBlock(src, "AmmoConverter.PACKAGING");
        if (pkgBlock == null) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "PACKAGING block not found in AmmoConverter.lua");
        }

        List<String> errors = new ArrayList<>();
        Matcher m = PKG_KEY.matcher(pkgBlock);
        while (m.find()) {
            String key = m.group(1);
            if (!tierTypes.contains(key)) {
                errors.add("PACKAGING key not in TIERS: " + key);
            }
        }
        return errors.isEmpty()
                ? ValidationResult.passing("AmmoConverterTableValidator")
                : ValidationResult.failing("AmmoConverterTableValidator", errors);
    }

    /** Task 2.2: PACKAGING boxValue and cartonValue must be positive. */
    public ValidationResult validatePackagingRoundValues() {
        String src;
        try { src = readLua(); } catch (IOException e) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "Cannot read Lua source: " + e.getMessage());
        }

        List<String> errors = new ArrayList<>();
        Matcher bv = PKG_BOX_VALUE.matcher(src);
        while (bv.find()) {
            int val = Integer.parseInt(bv.group(1));
            if (val <= 0) errors.add("boxValue must be > 0, found: " + val);
        }
        Matcher cv = PKG_CARTON_VALUE.matcher(src);
        while (cv.find()) {
            int val = Integer.parseInt(cv.group(1));
            if (val <= 0) errors.add("cartonValue must be > 0, found: " + val);
        }
        if (errors.isEmpty() && !PKG_BOX_VALUE.matcher(src).find()) {
            errors.add("No boxValue entries found in PACKAGING — table may be empty");
        }
        return errors.isEmpty()
                ? ValidationResult.passing("AmmoConverterTableValidator")
                : ValidationResult.failing("AmmoConverterTableValidator", errors);
    }

    /**
     * Task 4.2: OnContainerUpdate must NOT directly call onIdleCheck.
     * It must be guarded so container storms cannot bypass the throttle.
     * We detect the forbidden direct-call pattern in the event handler body.
     */
    public ValidationResult validateContainerUpdateIsGuarded() {
        String src;
        try { src = readLua(); } catch (IOException e) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "Cannot read Lua source: " + e.getMessage());
        }

        // Find the onContainerUpdate function body.
        int fnStart = src.indexOf("local function onContainerUpdate");
        if (fnStart < 0) {
            // If the function was removed entirely, that satisfies the guard (task 4.2 preferred outcome).
            return ValidationResult.passing("AmmoConverterTableValidator",
                    List.of("OnContainerUpdate handler not present — satisfies guard requirement."));
        }

        // Find the closing "end" for this function.
        int fnEnd = src.indexOf("\nend\n", fnStart);
        String fnBody = fnEnd > fnStart ? src.substring(fnStart, fnEnd) : src.substring(fnStart);

        // A direct unguarded call would be: AmmoConverter.onIdleCheck(player)
        // A guarded call routes through the throttled onPlayerUpdate or checks the tick counter.
        // Detect: bare call to onIdleCheck without any guard keyword.
        boolean callsOnIdleCheck = fnBody.contains("onIdleCheck");
        boolean hasThrottleReference = fnBody.contains("_tickCounter") || fnBody.contains("IDLE_CHECK_INTERVAL")
                || fnBody.contains("onPlayerUpdate");

        if (callsOnIdleCheck && !hasThrottleReference) {
            return ValidationResult.failing("AmmoConverterTableValidator",
                    "onContainerUpdate calls onIdleCheck directly without throttle guard — "
                    + "container storms will bypass the tick throttle");
        }
        return ValidationResult.passing("AmmoConverterTableValidator");
    }

    /** Returns the types in a named tier, or empty list if tier not found. */
    public List<String> getTierTypes(String tierName) {
        String src;
        try { src = readLua(); } catch (IOException e) { return List.of(); }

        // Find the tier block: "<tierName> = {" inside TIERS
        String tiersBlock = extractBlock(src, "AmmoConverter.TIERS");
        if (tiersBlock == null) return List.of();

        // Find the sub-block for the named tier
        int tierStart = tiersBlock.indexOf(tierName + " = {");
        if (tierStart < 0) return List.of();
        int braceStart = tiersBlock.indexOf("{", tierStart);
        int braceEnd = tiersBlock.indexOf("}", braceStart);
        if (braceStart < 0 || braceEnd < 0) return List.of();

        String tierBlock = tiersBlock.substring(braceStart, braceEnd);
        List<String> types = new ArrayList<>();
        Matcher m = TIER_ENTRY.matcher(tierBlock);
        while (m.find()) types.add(m.group(1));
        return Collections.unmodifiableList(types);
    }

    // -- Private helpers ------------------------------------------------------

    /**
     * Extracts the Lua table block starting at "{@code prefix = {}" and ending at
     * the matching closing brace, handling nested braces.
     */
    private static String extractBlock(String src, String prefix) {
        int start = src.indexOf(prefix);
        if (start < 0) return null;
        int brace = src.indexOf("{", start);
        if (brace < 0) return null;

        int depth = 0;
        for (int i = brace; i < src.length(); i++) {
            char c = src.charAt(i);
            if (c == '{') depth++;
            else if (c == '}') {
                depth--;
                if (depth == 0) return src.substring(brace, i + 1);
            }
        }
        return null;
    }

    private static List<String> allTierTypes(String src) {
        String tiersBlock = extractBlock(src, "AmmoConverter.TIERS");
        if (tiersBlock == null) return List.of();
        List<String> types = new ArrayList<>();
        Matcher m = TIER_ENTRY.matcher(tiersBlock);
        while (m.find()) types.add(m.group(1));
        return types;
    }
}
