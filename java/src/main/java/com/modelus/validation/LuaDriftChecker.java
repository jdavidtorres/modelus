package com.modelus.validation;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Compares the committed {@code WeightReducerCatalog.generated.lua} against the
 * content that {@link LuaFallbackGenerator#buildLua()} would produce from the
 * current Java catalog.  Exits non-zero when drift is detected so that the
 * {@code checkWeightReducerLuaDrift} Gradle task can fail the build.
 *
 * <p>Usage (from Gradle):</p>
 * <pre>
 *   java -cp ... com.modelus.validation.LuaDriftChecker /path/to/project/root
 * </pre>
 */
public final class LuaDriftChecker {

    private LuaDriftChecker() {
    }

    public static void main(String[] args) throws IOException {
        String projectRoot = args.length > 0 ? args[0] : ".";
        Path committed = Path.of(projectRoot)
                .resolve(LuaFallbackGenerator.GENERATED_LUA_REL_PATH)
                .toAbsolutePath();

        System.out.println("[LuaDriftChecker] Checking drift for: " + committed);

        if (!Files.exists(committed)) {
            System.err.println("[LuaDriftChecker] FAIL — committed file not found: " + committed);
            System.err.println("  Run: ./gradlew generateWeightReducerLua  to generate it.");
            System.exit(1);
        }

        String committedContent = Files.readString(committed, StandardCharsets.UTF_8);
        String expectedContent  = LuaFallbackGenerator.buildLua();

        if (!committedContent.equals(expectedContent)) {
            System.err.println("[LuaDriftChecker] FAIL — committed Lua file is out of sync with Java catalog.");
            System.err.println("  Committed:  " + committed);
            System.err.println("  Run: ./gradlew generateWeightReducerLua  to regenerate and re-commit.");
            printDiffHint(committedContent, expectedContent);
            System.exit(1);
        }

        System.out.println("[LuaDriftChecker] OK — committed file matches Java catalog. No drift detected.");
    }

    /** Print a short human-readable hint about where the first difference is. */
    private static void printDiffHint(String actual, String expected) {
        String[] actualLines   = actual.split("\n", -1);
        String[] expectedLines = expected.split("\n", -1);
        int maxLines = Math.min(actualLines.length, expectedLines.length);
        for (int i = 0; i < maxLines; i++) {
            if (!actualLines[i].equals(expectedLines[i])) {
                System.err.println("  First diff at line " + (i + 1) + ":");
                System.err.println("    committed : " + actualLines[i]);
                System.err.println("    expected  : " + expectedLines[i]);
                return;
            }
        }
        if (actualLines.length != expectedLines.length) {
            System.err.println("  Files have different line counts: committed="
                    + actualLines.length + " expected=" + expectedLines.length);
        }
    }
}
