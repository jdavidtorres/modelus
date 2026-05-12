package com.modelus.ammoconverter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/** Fails when committed AmmoConverterCatalog.generated.lua differs from Java output. */
public final class AmmoConverterLuaDriftChecker {

  private AmmoConverterLuaDriftChecker() {
  }

  public static void main(String[] args) throws IOException {
    String projectRoot = args.length > 0 ? args[0] : ".";
    Path committed = Path.of(projectRoot)
        .resolve(AmmoConverterLuaGenerator.GENERATED_LUA_REL_PATH)
        .toAbsolutePath();

    System.out.println("[AmmoConverterLuaDriftChecker] Checking drift for: " + committed);

    if (!Files.exists(committed)) {
      System.err.println("[AmmoConverterLuaDriftChecker] FAIL — committed file not found: " + committed);
      System.err.println("  Run: ./gradlew generateAmmoConverterLua to generate it.");
      System.exit(1);
    }

    String committedContent = Files.readString(committed, StandardCharsets.UTF_8);
    String expectedContent = AmmoConverterLuaGenerator.buildLua();

    if (!committedContent.equals(expectedContent)) {
      System.err.println("[AmmoConverterLuaDriftChecker] FAIL — committed Lua file is out of sync with Java config.");
      System.err.println("  Committed: " + committed);
      System.err.println("  Run: ./gradlew generateAmmoConverterLua to regenerate and re-commit.");
      printDiffHint(committedContent, expectedContent);
      System.exit(1);
    }

    System.out.println("[AmmoConverterLuaDriftChecker] OK — committed file matches Java config. No drift detected.");
  }

  private static void printDiffHint(String actual, String expected) {
    String[] actualLines = actual.split("\n", -1);
    String[] expectedLines = expected.split("\n", -1);
    int maxLines = Math.min(actualLines.length, expectedLines.length);
    for (int i = 0; i < maxLines; i++) {
      if (!actualLines[i].equals(expectedLines[i])) {
        System.err.println("  First diff at line " + (i + 1) + ":");
        System.err.println("    committed: " + actualLines[i]);
        System.err.println("    expected : " + expectedLines[i]);
        return;
      }
    }
    if (actualLines.length != expectedLines.length) {
      System.err.println("  Files have different line counts: committed="
          + actualLines.length + " expected=" + expectedLines.length);
    }
  }
}
