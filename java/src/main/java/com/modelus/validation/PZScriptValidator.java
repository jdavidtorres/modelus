package com.modelus.validation;

import com.modelus.weight.WeightReducerCatalog;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

/**
 * Optional validator that checks catalog fullTypes against local B42 PZ script files.
 *
 * <p>This validator is <em>skipped</em> unless the environment variable
 * {@code PZ_SCRIPTS_PATH} points to a directory containing {@code *.txt} script
 * files exported from the Project Zomboid B42 installation.</p>
 *
 * <p>When active it scans all {@code *.txt} files under {@code PZ_SCRIPTS_PATH}
 * looking for {@code item <name>} declarations, collects all known item names,
 * and reports any catalog fullType whose simple name (the part after the first
 * {@code .}) is not found in the scripts.</p>
 *
 * <p>This is a best-effort check for renamed or removed B42 items before release.</p>
 */
public final class PZScriptValidator implements WeightValidationRule {

    /** Environment variable that enables this validator. */
    public static final String ENV_PZ_SCRIPTS_PATH = "PZ_SCRIPTS_PATH";

    /** Matches {@code item SomeName} inside PZ script files. */
    private static final Pattern ITEM_DECL = Pattern.compile(
            "(?i)^\\s*item\\s+(\\w+)\\s*\\{?");

    @Override
    public String name() {
        return "PZScriptValidator";
    }

    @Override
    public ValidationResult validate() {
        String pzScriptsPath = System.getenv(ENV_PZ_SCRIPTS_PATH);
        if (pzScriptsPath == null || pzScriptsPath.isBlank()) {
            return ValidationResult.passing(name(),
                    List.of("[PZScriptValidator] Skipped — PZ_SCRIPTS_PATH not set."));
        }

        Path scriptsDir = Path.of(pzScriptsPath);
        if (!Files.isDirectory(scriptsDir)) {
            return ValidationResult.failing(name(),
                    "[PZScriptValidator] PZ_SCRIPTS_PATH is not a directory: " + pzScriptsPath);
        }

        Set<String> knownItems = new HashSet<>();
        List<String> errors = new ArrayList<>();

        try (Stream<Path> walk = Files.walk(scriptsDir)) {
            walk.filter(p -> p.toString().endsWith(".txt"))
                .forEach(scriptFile -> {
                    try {
                        Files.lines(scriptFile).forEach(line -> {
                            Matcher m = ITEM_DECL.matcher(line);
                            if (m.find()) {
                                knownItems.add(m.group(1).trim());
                            }
                        });
                    } catch (IOException e) {
                        errors.add("[PZScriptValidator] Could not read script file: "
                                + scriptFile + " — " + e.getMessage());
                    }
                });
        } catch (IOException e) {
            return ValidationResult.failing(name(),
                    "[PZScriptValidator] Failed to walk PZ_SCRIPTS_PATH: " + e.getMessage());
        }

        if (!errors.isEmpty()) {
            return ValidationResult.failing(name(), errors);
        }

        if (knownItems.isEmpty()) {
            return ValidationResult.failing(name(),
                    "[PZScriptValidator] No item declarations found under PZ_SCRIPTS_PATH — "
                            + "directory may not contain PZ script exports: " + pzScriptsPath);
        }

        List<String> missing = new ArrayList<>();
        for (String fullType : WeightReducerCatalog.flattenedItems()) {
            String simpleName = simpleName(fullType);
            if (!knownItems.contains(simpleName)) {
                missing.add("[PZScriptValidator] fullType not found in B42 scripts: " + fullType);
            }
        }

        if (!missing.isEmpty()) {
            return ValidationResult.failing(name(), missing);
        }

        return ValidationResult.passing(name(),
                List.of("[PZScriptValidator] All " + WeightReducerCatalog.flattenedItems().size()
                        + " catalog fullTypes found in B42 scripts."));
    }

    private static String simpleName(String fullType) {
        int dot = fullType.indexOf('.');
        return dot >= 0 ? fullType.substring(dot + 1) : fullType;
    }
}
