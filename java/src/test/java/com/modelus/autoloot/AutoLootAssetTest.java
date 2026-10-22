package com.modelus.autoloot;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import org.json.JSONObject;
import org.junit.jupiter.api.Test;

import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.LuaClosure;

class AutoLootAssetTest {

    private static final Path REPOSITORY_ROOT = Path.of(System.getProperty("user.dir")).getParent();

    @Test
    void auto_loot_and_shared_item_identification_lua_compile_with_pz_parser() throws IOException {
        boolean previousRewriteEvents = LuaCompiler.rewriteEvents;
        LuaCompiler.rewriteEvents = false;
        try {
            assertNotNull(compileLua("mods/modelus/common/media/lua/client/auto-loot/AutoLoot.lua"));
            assertNotNull(compileLua(
                    "mods/modelus/common/media/lua/shared/item-identification/ItemIdentification.lua"));
        } finally {
            LuaCompiler.rewriteEvents = previousRewriteEvents;
        }
    }

    @Test
    void context_menu_translation_json_has_all_auto_loot_labels() throws IOException {
        Path path = REPOSITORY_ROOT.resolve(
                "mods/modelus/common/media/lua/shared/Translate/EN/ContextMenu.json");
        JSONObject translations = new JSONObject(Files.readString(path));

        assertEquals("Auto Loot: collect", translations.getString("ContextMenu_ModelusAutoLootStart"));
        assertEquals("Auto Loot: stop collecting", translations.getString("ContextMenu_ModelusAutoLootStop"));
        assertTrue(translations.has("ContextMenu_ModelusAutoLootUnavailable"));
    }

    private static LuaClosure compileLua(String relativePath) throws IOException {
        Path path = REPOSITORY_ROOT.resolve(relativePath);
        return LuaCompiler.loadstring(Files.readString(path), path.toString(), null);
    }
}
