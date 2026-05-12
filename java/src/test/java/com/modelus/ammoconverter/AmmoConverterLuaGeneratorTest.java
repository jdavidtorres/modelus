package com.modelus.ammoconverter;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AmmoConverterLuaGeneratorTest {

  @Test
  void generated_lua_declares_catalog_table() {
    String lua = AmmoConverterLuaGenerator.buildLua();
    assertTrue(lua.contains("AmmoConverterCatalog_Generated = {}"));
  }

  @Test
  void generated_lua_contains_canonical_ammo_types() {
    String lua = AmmoConverterLuaGenerator.buildLua();
    assertTrue(lua.contains("\"Base.Bullets9mm\""));
    assertTrue(lua.contains("\"Base.ShotgunShells\""));
    assertTrue(lua.contains("\"Base.556Bullets\""));
  }

  @Test
  void generated_lua_contains_script_id_normalization() {
    String lua = AmmoConverterLuaGenerator.buildLua();
    assertTrue(lua.contains("[\"base:bullets_9mm\"] = \"Base.Bullets9mm\""));
    assertTrue(lua.contains("[\"base:shotgun_shells\"] = \"Base.ShotgunShells\""));
  }

  @Test
  void generated_lua_contains_packaging_values() {
    String lua = AmmoConverterLuaGenerator.buildLua();
    assertTrue(lua.contains("[\"Base.Bullets9mm\"] = { box = \"Base.Bullets9mmBox\", carton = \"Base.Bullets9mmCarton\", boxValue = 50, cartonValue = 600 }"));
    assertTrue(lua.contains("[\"Base.ShotgunShells\"] = { box = \"Base.ShotgunShellsBox\", carton = \"Base.ShotgunShellsCarton\", boxValue = 25, cartonValue = 300 }"));
  }

  @Test
  void generated_lua_is_deterministic() {
    assertEquals(AmmoConverterLuaGenerator.buildLua(), AmmoConverterLuaGenerator.buildLua());
  }

  @Test
  void generated_lua_ammo_type_count_matches_universal_tier() {
    String lua = AmmoConverterLuaGenerator.buildLua();
    int count = 0;
    for (String type : AmmoConverterConfig.TIERS.get("universal")) {
      assertTrue(lua.contains("\"" + type + "\""));
      count++;
    }
    assertEquals(9, count);
  }

  @Test
  void stale_content_differs_from_generated_output() {
    assertNotEquals("-- stale\n", AmmoConverterLuaGenerator.buildLua());
  }

  @Test
  void script_normalization_map_covers_all_universal_ammo_types() {
    List<String> universal = AmmoConverterConfig.TIERS.get("universal");
    for (String mappedType : AmmoConverterConfig.SCRIPT_TO_FULL_TYPE.values()) {
      assertTrue(universal.contains(mappedType), "Mapped type must be in universal tier: " + mappedType);
    }
  }
}
