package com.modelus.ammoconverter;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AmmoConverterLuaDriftCheckerTest {

    @Test
    void generated_lua_contains_no_carriage_return() {
        assertFalse(AmmoConverterLuaGenerator.buildLua().contains("\r"));
    }

    @Test
    void generated_file_on_disk_contains_no_carriage_return(@TempDir Path tempDir) throws IOException {
        Path output = tempDir.resolve("AmmoConverterCatalog.generated.lua");
        AmmoConverterLuaGenerator.generate(output);

        assertFalse(Files.readString(output).contains("\r"));
    }

    @Test
    void crlf_and_lf_are_equivalent() {
        assertFalse(AmmoConverterLuaDriftChecker.hasDrift("a = 1\r\nb = 2\r\n", "a = 1\nb = 2\n"));
    }

    @Test
    void lf_and_crlf_are_equivalent() {
        assertFalse(AmmoConverterLuaDriftChecker.hasDrift("a = 1\nb = 2\n", "a = 1\r\nb = 2\r\n"));
    }

    @Test
    void mixed_line_endings_are_accepted() {
        assertFalse(AmmoConverterLuaDriftChecker.hasDrift("a = 1\r\nb = 2\nc = 3\r\n", "a = 1\nb = 2\nc = 3\n"));
    }

    @Test
    void value_change_is_drift() {
        assertTrue(AmmoConverterLuaDriftChecker.hasDrift("a = 1\n", "a = 2\n"));
    }

    @Test
    void trailing_space_is_drift() {
        assertTrue(AmmoConverterLuaDriftChecker.hasDrift("a = 1\n", "a = 1 \n"));
    }

    @Test
    void missing_final_newline_is_drift() {
        assertTrue(AmmoConverterLuaDriftChecker.hasDrift("a = 1\n", "a = 1"));
    }

    @Test
    void isolated_carriage_return_is_drift() {
        assertTrue(AmmoConverterLuaDriftChecker.hasDrift("a = 1\rb = 2", "a = 1\nb = 2"));
    }

    @Test
    void empty_content_matches_empty_content() {
        assertFalse(AmmoConverterLuaDriftChecker.hasDrift("", ""));
    }

    @Test
    void empty_content_differs_from_newline_only() {
        assertTrue(AmmoConverterLuaDriftChecker.hasDrift("", "\n"));
    }

    @Test
    void empty_content_differs_from_non_empty() {
        assertTrue(AmmoConverterLuaDriftChecker.hasDrift("", "x"));
    }
}
