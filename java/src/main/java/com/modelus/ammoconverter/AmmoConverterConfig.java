package com.modelus.ammoconverter;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Static configuration for the AmmoConverter feature.
 *
 * <p>
 * Mirrors the Lua {@code AmmoConverter.TIERS} and
 * {@code AmmoConverter.PACKAGING}
 * tables with type-safe Java structures. This is the single source of truth for
 * tier membership and packaging round values used by
 * {@link AmmoConverterBridge}.
 * </p>
 *
 * <p>
 * Vanilla B42 packaging ratios:
 * <ul>
 * <li>Pistol: box=50, carton=600 (12×50)</li>
 * <li>Rifle / .44 Mag: box=20, carton=240 (12×20)</li>
 * <li>Shotgun: box=25, carton=300 (12×25)</li>
 * </ul>
 */
public final class AmmoConverterConfig {

  private AmmoConverterConfig() {
  }

  // -------------------------------------------------------------------------
  // TIERS
  // -------------------------------------------------------------------------

  /**
   * All ammo tiers. Currently a single "universal" tier covering all B42
   * calibers.
   */
  public static final Map<String, List<String>> TIERS;

  static {
    Map<String, List<String>> t = new LinkedHashMap<>();
    t.put("universal", List.of(
        "Base.Bullets9mm",
        "Base.Bullets38",
        "Base.Bullets45",
        "Base.Bullets357",
        "Base.Bullets44",
        "Base.556Bullets",
        "Base.308Bullets",
        "Base.3030Bullets",
        "Base.ShotgunShells"));
    TIERS = Collections.unmodifiableMap(t);
  }

  // -------------------------------------------------------------------------
  // SCRIPT ID NORMALIZATION
  // -------------------------------------------------------------------------

  /**
   * B42 weapon scripts expose ammo ids like {@code base:bullets_9mm} from
   * {@code HandWeapon:getAmmoType()}. Runtime inventory operations use canonical
   * item full types like {@code Base.Bullets9mm}. This map is the source of
   * truth for that normalization.
   */
  public static final Map<String, String> SCRIPT_TO_FULL_TYPE;

  static {
    Map<String, String> s = new LinkedHashMap<>();
    s.put("base:bullets_556", "Base.556Bullets");
    s.put("base:bullets_3030", "Base.3030Bullets");
    s.put("base:bullets_308", "Base.308Bullets");
    s.put("base:bullets_44", "Base.Bullets44");
    s.put("base:bullets_9mm", "Base.Bullets9mm");
    s.put("base:bullets_38", "Base.Bullets38");
    s.put("base:bullets_45", "Base.Bullets45");
    s.put("base:bullets_357", "Base.Bullets357");
    s.put("base:shotgun_shells", "Base.ShotgunShells");
    SCRIPT_TO_FULL_TYPE = Collections.unmodifiableMap(s);
  }

  // -------------------------------------------------------------------------
  // PACKAGING
  // -------------------------------------------------------------------------

  /**
   * Immutable packaging definition for a loose ammo type.
   *
   * @param box         Full type of the box item (e.g. "Base.556Box").
   * @param carton      Full type of the carton item (e.g. "Base.556Carton").
   * @param boxValue    How many loose rounds one box is worth.
   * @param cartonValue How many loose rounds one carton is worth.
   */
  public record PackageDef(String box, String carton, int boxValue, int cartonValue) {
  }

  /** Packaging definitions keyed by loose ammo full type. */
  public static final Map<String, PackageDef> PACKAGING;

  static {
    Map<String, PackageDef> p = new LinkedHashMap<>();
    // Rifle / .44 Mag — box=20, carton=240
    p.put("Base.556Bullets", new PackageDef("Base.556Box", "Base.556Carton", 20, 240));
    p.put("Base.3030Bullets", new PackageDef("Base.3030Box", "Base.3030Carton", 20, 240));
    p.put("Base.308Bullets", new PackageDef("Base.308Box", "Base.308Carton", 20, 240));
    p.put("Base.Bullets44", new PackageDef("Base.Bullets44Box", "Base.Bullets44Carton", 20, 240));
    // Pistol — box=50, carton=600
    p.put("Base.Bullets9mm", new PackageDef("Base.Bullets9mmBox", "Base.Bullets9mmCarton", 50, 600));
    p.put("Base.Bullets38", new PackageDef("Base.Bullets38Box", "Base.Bullets38Carton", 50, 600));
    p.put("Base.Bullets45", new PackageDef("Base.Bullets45Box", "Base.Bullets45Carton", 50, 600));
    p.put("Base.Bullets357", new PackageDef("Base.Bullets357Box", "Base.Bullets357Carton", 50, 600));
    // Shotgun — box=25, carton=300
    p.put("Base.ShotgunShells", new PackageDef("Base.ShotgunShellsBox", "Base.ShotgunShellsCarton", 25, 300));
    PACKAGING = Collections.unmodifiableMap(p);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /**
   * Returns {@code true} if {@code ammoType} is registered in any tier.
   */
  public static boolean isInTiers(String ammoType) {
    for (List<String> types : TIERS.values()) {
      if (types.contains(ammoType))
        return true;
    }
    return false;
  }

  /**
   * Returns the list of same-tier peers for {@code targetAmmoType},
   * excluding the target itself. Returns an empty list if the type is
   * not found in any tier.
   */
  public static List<String> getTierPeers(String targetAmmoType) {
    for (List<String> types : TIERS.values()) {
      if (types.contains(targetAmmoType)) {
        List<String> peers = new ArrayList<>(types);
        peers.remove(targetAmmoType);
        return Collections.unmodifiableList(peers);
      }
    }
    return List.of();
  }

  /**
   * Returns the inventory key suffix expected by PZ's {@code ItemContainer}
   * methods.
   * PZ's {@code getItemCountRecurse} / {@code getSomeType} expect the type
   * without
   * the module prefix (e.g. "556Bullets" not "Base.556Bullets").
   */
  public static String inventoryKey(String fullType) {
    int dot = fullType.indexOf('.');
    return dot >= 0 ? fullType.substring(dot + 1) : fullType;
  }
}
