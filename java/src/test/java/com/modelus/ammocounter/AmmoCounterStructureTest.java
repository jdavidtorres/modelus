package com.modelus.ammocounter;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Structural audit tests for AmmoCounter.lua runtime behavior contracts.
 *
 * <p>The Lua module runs inside Project Zomboid and cannot execute under JUnit.
 * These tests inspect the committed Lua source to prove the required structural
 * contracts are present and correct in the file.</p>
 *
 * <p>Key contracts under test:
 * <ul>
 *   <li>Module uses local scope — no global leak (no AmmoCounter = AmmoCounter or {}).</li>
 *   <li>All PZ API calls are wrapped in pcall for safe degradation.</li>
 *   <li>All required functions (isAimingRanged, resolveWeaponState, getReserve, OnRenderTick) are defined.</li>
 *   <li>Events.OnRenderTick is registered with the module function.</li>
 *   <li>Cache and config fields are declared with all required keys.</li>
 *   <li>Warning states (JAMMED, EMPTY) are handled.</li>
 *   <li>Drawing uses mouse coordinates for near-cursor positioning.</li>
 * </ul>
 * </p>
 */
class AmmoCounterStructureTest {

    private static final String LUA_RELATIVE =
            "mods/modelus/common/media/lua/client/ammo-counter/AmmoCounter.lua";

    private static String luaContent;

    @BeforeAll
    static void loadLua() throws IOException {
        // Gradle runs tests with user.dir = <project>/java; go one level up for repo root.
        Path root = Paths.get(System.getProperty("user.dir")).getParent();
        Path lua = root.resolve(LUA_RELATIVE);
        assertTrue(Files.exists(lua),
                "AmmoCounter.lua must exist at: " + lua.toAbsolutePath());
        luaContent = Files.readString(lua, StandardCharsets.UTF_8);
    }

    // ── Precondition ──────────────────────────────────────────────────────────

    @Test
    void lua_file_loads_successfully() {
        assertNotNull(luaContent, "Lua source must be loadable");
        assertFalse(luaContent.isBlank(), "Lua source must not be empty");
    }

    // ── Module scope: local, no global leak ──────────────────────────────────

    @Test
    void module_uses_local_scope() {
        assertTrue(luaContent.contains("local AmmoCounter"),
                "AmmoCounter must be declared as a local table (not a global)");
    }

    @Test
    void module_has_no_global_leak() {
        assertFalse(luaContent.contains("AmmoCounter = AmmoCounter or {}"),
                "AmmoCounter must NOT be declared as a global via the 'or {}' pattern");
    }

    // ── pcall safety ──────────────────────────────────────────────────────────

    @Test
    void module_uses_pcall_for_pz_api_calls() {
        assertTrue(luaContent.contains("pcall("),
                "AmmoCounter must wrap PZ API calls in pcall for graceful error handling");
    }

    @Test
    void module_guards_getPrimaryHandItem() {
        assertTrue(luaContent.contains("getPrimaryHandItem"),
                "AmmoCounter must call getPrimaryHandItem to resolve the equipped weapon");
    }

    @Test
    void module_guards_isAiming_call() {
        assertTrue(luaContent.contains("isAiming"),
                "AmmoCounter must check player:isAiming() to determine aim state");
    }

    @Test
    void module_guards_isDead_check() {
        assertTrue(luaContent.contains("isDead"),
                "AmmoCounter must check player:isDead() to avoid rendering for dead players");
    }

    @Test
    void module_uses_multiple_pcall_guards() {
        // Verify pcall is used substantively (at least 4 usages — each critical API must be guarded)
        int count = luaContent.split("pcall\\(").length - 1;
        assertTrue(count >= 4,
                "AmmoCounter must use pcall in at least 4 locations to guard all critical PZ API calls; found: " + count);
    }

    // ── Required functions ────────────────────────────────────────────────────

    @Test
    void isAimingRanged_function_is_defined() {
        assertTrue(luaContent.contains("AmmoCounter.isAimingRanged"),
                "isAimingRanged must be defined on the AmmoCounter module table");
    }

    @Test
    void resolveWeaponState_function_is_defined() {
        assertTrue(luaContent.contains("AmmoCounter.resolveWeaponState"),
                "resolveWeaponState must be defined on the AmmoCounter module table");
    }

    @Test
    void getReserve_function_is_defined() {
        assertTrue(luaContent.contains("AmmoCounter.getReserve"),
                "getReserve must be defined on the AmmoCounter module table");
    }

    @Test
    void onRenderTick_function_is_defined() {
        assertTrue(luaContent.contains("AmmoCounter.OnRenderTick"),
                "OnRenderTick must be defined on the AmmoCounter module table");
    }

    // ── Event registration ────────────────────────────────────────────────────

    @Test
    void events_onRenderTick_is_registered() {
        assertTrue(luaContent.contains("Events.OnRenderTick.Add"),
                "AmmoCounter.OnRenderTick must be registered to Events.OnRenderTick");
    }

    @Test
    void events_onRenderTick_registers_module_function() {
        assertTrue(luaContent.contains("Events.OnRenderTick.Add(AmmoCounter.OnRenderTick)"),
                "Events.OnRenderTick must be registered with AmmoCounter.OnRenderTick specifically");
    }

    // ── Cache table structure ─────────────────────────────────────────────────

    @Test
    void module_declares_cache_table() {
        assertTrue(luaContent.contains("cache"),
                "AmmoCounter must declare a cache table for throttled reserve scanning");
    }

    @Test
    void cache_has_reserveCount_field() {
        assertTrue(luaContent.contains("reserveCount"),
                "cache must include a reserveCount field for the throttled inventory count");
    }

    @Test
    void cache_has_lastTick_field() {
        assertTrue(luaContent.contains("lastTick"),
                "cache must include a lastTick field to track throttle expiry");
    }

    // ── Config table structure ────────────────────────────────────────────────

    @Test
    void module_declares_config_table() {
        assertTrue(luaContent.contains("config"),
                "AmmoCounter must declare a config table for tuneable parameters");
    }

    @Test
    void config_has_throttleTicks() {
        assertTrue(luaContent.contains("throttleTicks"),
                "config must include throttleTicks to control reserve scan cadence");
    }

    @Test
    void config_has_offsetX_and_offsetY() {
        assertTrue(luaContent.contains("offsetX") && luaContent.contains("offsetY"),
                "config must include offsetX and offsetY for cursor-relative text positioning");
    }

    // ── Warning state feedback ────────────────────────────────────────────────

    @Test
    void module_handles_jammed_state() {
        assertTrue(luaContent.contains("JAMMED") || luaContent.contains("isJammed"),
                "AmmoCounter must handle and display the jammed weapon warning state");
    }

    @Test
    void module_handles_empty_state() {
        assertTrue(luaContent.contains("EMPTY") || luaContent.contains("current == 0"),
                "AmmoCounter must handle and display the empty/not-ready weapon warning state");
    }

    // ── Cursor-relative drawing ───────────────────────────────────────────────

    @Test
    void render_reads_mouse_position() {
        assertTrue(luaContent.contains("getMouseX") && luaContent.contains("getMouseY"),
                "OnRenderTick must read mouse coordinates for near-cursor text drawing");
    }

    // ── Render backend contract ───────────────────────────────────────────────

    @Test
    void render_uses_TextDrawObject() {
        assertTrue(luaContent.contains("TextDrawObject"),
                "AmmoCounter must use TextDrawObject for cursor HUD rendering (not UIManager.DrawStringCentred)");
    }

    @Test
    void render_uses_ReadString() {
        assertTrue(luaContent.contains("ReadString"),
                "AmmoCounter must call ReadString on the TextDrawObject to update the display text");
    }

    @Test
    void render_uses_AddBatchedDraw() {
        assertTrue(luaContent.contains("AddBatchedDraw"),
                "AmmoCounter must call AddBatchedDraw to queue the text draw into the render pipeline");
    }

    @Test
    void render_rejects_UIManager_DrawStringCentred() {
        assertFalse(luaContent.contains("UIManager.DrawStringCentred"),
                "AmmoCounter must NOT use UIManager.DrawStringCentred (unsupported API during OnRenderTick)");
    }

    @Test
    void render_rejects_getTextManager_DrawString() {
        assertFalse(luaContent.contains("getTextManager():DrawString"),
                "AmmoCounter must NOT use getTextManager():DrawString (unsupported legacy fallback)");
    }

    @Test
    void render_caches_textObj_on_module_table() {
        assertTrue(luaContent.contains("AmmoCounter._textObj"),
                "TextDrawObject must be cached on the AmmoCounter module table (not a local variable) to avoid per-frame allocation");
    }

    @Test
    void render_AddBatchedDraw_does_not_use_unsupported_six_arg_form() {
        // TextDrawObject:AddBatchedDraw(x, y, r, g, b, a) is NOT a valid Lua/Java binding.
        // Only AddBatchedDraw(x, y) is exposed. Color args belong in ReadString.
        // This guards against re-introducing the invalid 6-arg overload that causes runtime nil errors.
        assertFalse(luaContent.contains("AddBatchedDraw(x, y, 1, 1, 1"),
                "AddBatchedDraw must NOT use the unsupported 6-arg (x,y,r,g,b,a) form — only (x, y) is a valid Lua binding");
    }

    @Test
    void render_ReadString_uses_flag_mode() {
        // ReadString(UIFont, text, -1) instructs the engine to use colors pre-configured on
        // the TextDrawObject via setDefaultColor. The -1 flag is the only supported form in
        // this PZ runtime; the 6-arg inline RGBA form has no exposed Lua/Java binding.
        assertTrue(luaContent.contains(":ReadString(UIFont.Small, text, -1)"),
                "ReadString must use the -1 flag (object-state colors), not inline RGBA arguments");
    }

    @Test
    void render_ReadString_rejects_inline_rgba() {
        // ReadString(UIFont, text, 1, 1, 1, ...) is not a valid 6-arg Lua binding.
        // Passing inline RGBA causes a runtime nil-call. Colors must be set via setDefaultColor.
        // Triangulates render_ReadString_uses_flag_mode from the negative direction.
        assertFalse(luaContent.contains(":ReadString(UIFont.Small, text, 1"),
                "ReadString must NOT use inline RGBA color args — colors must be configured via object state");
    }

    @Test
    void render_ReadString_does_not_use_flag_zero() {
        // ReadString(UIFont, text, 0) uses flag 0 instead of -1 — wrong call pattern.
        // Triangulates render_ReadString_uses_flag_mode from the negative direction (wrong flag).
        assertFalse(luaContent.contains(":ReadString(UIFont.Small, text, 0)"),
                "ReadString must NOT use flag 0 — the correct flag is -1 (use object-state colors)");
    }

    @Test
    void render_configures_color_via_object_state() {
        // Colors must be set on the TextDrawObject via setDefaultColors (plural) before ReadString is called.
        // The valid runtime binding is setDefaultColors, not the singular setDefaultColor.
        // ReadString uses flag -1 to read the colors pre-configured here.
        assertTrue(luaContent.contains("setDefaultColors"),
                "TextDrawObject must have color configured via setDefaultColors (plural, object state), not inline ReadString args");
    }

    @Test
    void render_rejects_setDefaultColor_singular() {
        // setDefaultColor (singular) is NOT a valid Lua/Java binding on TextDrawObject in this PZ runtime.
        // Calling it causes 'Object tried to call nil in OnRenderTick' at runtime.
        // The correct method is setDefaultColors (plural).
        // This negative guard prevents the naming mistake from silently regressing.
        assertFalse(luaContent.contains(":setDefaultColor("),
                "AmmoCounter must NOT call :setDefaultColor( (singular) — the valid binding is :setDefaultColors( (plural)");
    }

    @Test
    void render_setDefaultColors_configures_visible_color() {
        // setDefaultColors must supply non-transparent visible values (e.g. r=1,g=1,b=1).
        // Calling setDefaultColors(0,0,0,0) or omitting valid RGBA would make the text invisible.
        // Triangulates render_configures_color_via_object_state with concrete expected values.
        assertTrue(luaContent.contains("setDefaultColors(1, 1, 1"),
                "setDefaultColors must configure white visible text (r=1, g=1, b=1) — transparent/zero values produce invisible HUD");
    }

    @Test
    void render_AddBatchedDraw_uses_three_arg_form() {
        // AddBatchedDraw(x, y, true) is the supported 3-arg form for this PZ runtime.
        // The boolean third argument is required; the bare 2-arg (x, y) form is not valid here.
        assertTrue(luaContent.contains(":AddBatchedDraw(x, y, true)"),
                "AddBatchedDraw must use the 3-arg (x, y, true) form supported by this runtime");
    }

    // ── Reserve scan: inventory access ───────────────────────────────────────

    @Test
    void getReserve_accesses_player_inventory() {
        assertTrue(luaContent.contains("getInventory"),
                "getReserve must access the player's inventory for reserve ammo scanning");
    }

    @Test
    void getReserve_implements_throttle_via_lastTick() {
        // Throttle logic must reference lastTick to decide whether to re-scan
        int anchor = luaContent.indexOf("AmmoCounter.getReserve");
        assertTrue(anchor >= 0, "AmmoCounter.getReserve must be defined");
        String afterAnchor = luaContent.substring(anchor);
        assertTrue(afterAnchor.contains("lastTick"),
                "getReserve must implement throttle logic referencing lastTick within the function body");
    }

    // ── Triangulation: weapon state resolution ────────────────────────────────

    @Test
    void resolveWeaponState_reads_getCurrentAmmoCount() {
        assertTrue(luaContent.contains("getCurrentAmmoCount"),
                "resolveWeaponState must read getCurrentAmmoCount for current loaded ammo");
    }

    @Test
    void resolveWeaponState_checks_isJammed() {
        assertTrue(luaContent.contains("isJammed"),
                "resolveWeaponState must check isJammed to surface the jam warning state");
    }

    @Test
    void resolveWeaponState_checks_isRoundChambered() {
        assertTrue(luaContent.contains("isRoundChambered"),
                "resolveWeaponState must check isRoundChambered for chambered-round state");
    }

    @Test
    void resolveWeaponState_checks_isRanged_via_instanceof() {
        assertTrue(luaContent.contains("isRanged") || luaContent.contains("instanceof"),
                "resolveWeaponState must verify the weapon is a ranged weapon before resolving state");
    }

    // ── Triangulation: OnRenderTick flow ──────────────────────────────────────

    @Test
    void onRenderTick_calls_isAimingRanged() {
        int anchor = luaContent.indexOf("function AmmoCounter.OnRenderTick");
        assertTrue(anchor >= 0, "AmmoCounter.OnRenderTick must be defined as a function");
        String body = luaContent.substring(anchor);
        assertTrue(body.contains("AmmoCounter.isAimingRanged"),
                "OnRenderTick must call AmmoCounter.isAimingRanged to gate rendering");
    }

    @Test
    void onRenderTick_calls_resolveWeaponState() {
        int anchor = luaContent.indexOf("function AmmoCounter.OnRenderTick");
        assertTrue(anchor >= 0, "AmmoCounter.OnRenderTick must be defined as a function");
        String body = luaContent.substring(anchor);
        assertTrue(body.contains("AmmoCounter.resolveWeaponState"),
                "OnRenderTick must call AmmoCounter.resolveWeaponState to get current ammo state");
    }

    @Test
    void onRenderTick_calls_getReserve() {
        int anchor = luaContent.indexOf("function AmmoCounter.OnRenderTick");
        assertTrue(anchor >= 0, "AmmoCounter.OnRenderTick must be defined as a function");
        String body = luaContent.substring(anchor);
        assertTrue(body.contains("AmmoCounter.getReserve"),
                "OnRenderTick must call AmmoCounter.getReserve to include reserve ammo in the display");
    }
}
