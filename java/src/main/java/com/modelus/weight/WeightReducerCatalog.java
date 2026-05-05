package com.modelus.weight;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Java-side source of truth and validator for Modelus weight-reducer item lists.
 *
 * <p>Lua remains responsible for applying weights inside Project Zomboid. This
 * class exists so the catalogue has a compile-checked, testable representation
 * and can be exposed to Lua when the Java bridge is available.</p>
 *
 * <p>Each entry is a {@link CatalogEntry} carrying {@code fullType}, {@code family},
 * {@code multiplier}, {@code isBurnable}, and {@code fuelCompensationMode}.
 * This avoids raw {@code Map<String, List<String>>} internals leaking into callers.</p>
 */
public final class WeightReducerCatalog {

    public static final double MULTIPLIER = 0.1D;

    private static final Pattern FULL_TYPE = Pattern.compile("^[A-Za-z0-9_]+\\.[A-Za-z0-9_]+$");

    // ── Typed entry ────────────────────────────────────────────────────────────

    /**
     * Immutable descriptor for a single catalog item.
     */
    public static final class CatalogEntry {
        private final String fullType;
        private final String family;
        private final double multiplier;
        private final boolean isBurnable;
        private final FuelCompensationMode fuelCompensationMode;

        public CatalogEntry(
                String fullType,
                String family,
                double multiplier,
                boolean isBurnable,
                FuelCompensationMode fuelCompensationMode) {
            this.fullType = Objects.requireNonNull(fullType, "fullType");
            this.family = Objects.requireNonNull(family, "family");
            this.multiplier = multiplier;
            this.isBurnable = isBurnable;
            this.fuelCompensationMode = Objects.requireNonNull(fuelCompensationMode, "fuelCompensationMode");
        }

        public String fullType() { return fullType; }
        public String family() { return family; }
        public double multiplier() { return multiplier; }
        public boolean isBurnable() { return isBurnable; }
        public FuelCompensationMode fuelCompensationMode() { return fuelCompensationMode; }

        @Override
        public String toString() {
            return "CatalogEntry{fullType='" + fullType + "', family='" + family
                    + "', multiplier=" + multiplier + ", isBurnable=" + isBurnable
                    + ", fuelCompensationMode=" + fuelCompensationMode + "}";
        }
    }

    // ── Raw family → fullTypes map (preserves deterministic order) ─────────────

    /** Ordered family → list-of-fullTypes.  Used to derive typed entries. */
    private static final Map<String, List<String>> RAW_BY_FAMILY = new LinkedHashMap<>();

    static {
        RAW_BY_FAMILY.put("WOOD", List.of(
            "Base.Log", "Base.LogStacks2", "Base.LogStacks3", "Base.LogStacks4",
            "Base.Plank", "Base.Plank_Nails", "Base.Plank_Broken", "Base.Plank_Broken_Nails",
            "Base.TreeBranch2", "Base.LargeBranch",
            "Base.Twigs", "Base.TwigsBundle", "Base.Sapling", "Base.UnusableWood",
            "Base.Rope", "Base.Twine", "Base.DuctTape", "Base.Woodglue"
        ));

        RAW_BY_FAMILY.put("METAL", List.of(
            "Base.SheetMetal", "Base.SmallSheetMetal", "Base.MetalBar", "Base.MetalPipe",
            "Base.MetalDrum", "Base.ScrapMetal", "Base.UnusableMetal", "Base.WeldingRods",
            "Base.IronIngot", "Base.IronBar", "Base.IronBarHalf", "Base.IronBarQuarter",
            "Base.SteelBar", "Base.SteelBarHalf", "Base.SteelBarQuarter",
            "Base.LeadPipe", "Base.Nails", "Base.NailsBox",
            "Base.Screws", "Base.ScrewsBox", "Base.Wire", "Base.BarbedWire",
            "Base.ConcretePowder", "Base.PlasterPowder", "Base.Gravelbag", "Base.Sandbag",
            "Base.BucketConcreteFull", "Base.BucketPlasterFull"
        ));

        RAW_BY_FAMILY.put("TOOLS", List.of(
            "Base.Hammer", "Base.BallPeenHammer", "Base.ClubHammer", "Base.Screwdriver",
            "Base.Saw", "Base.GardenSaw", "Base.Wrench", "Base.PipeWrench",
            "Base.LugWrench", "Base.Ratchet", "Base.Crowbar", "Base.HandAxe", "Base.Axe",
            "Base.WoodAxe", "Base.PickAxe", "Base.Sledgehammer", "Base.Sledgehammer2",
            "Base.BlowTorch", "Base.WeldingMask", "Base.Tongs", "Base.Scissors",
            "Base.Needle", "Base.WoodenMallet", "Base.CarpentryChisel", "Base.MasonsChisel",
            "Base.MetalworkingChisel", "Base.StoneChisel", "Base.Epoxy", "Base.TirePump",
            "Base.WalkieTalkie1", "Base.WaterBottle",
            "Base.CarBatteryCharger", "Base.CarBattery2"
        ));

        RAW_BY_FAMILY.put("GARDENING", List.of(
            "Base.Shovel", "Base.Shovel2", "Base.GardenHoe", "Base.GardenFork",
            "Base.HandFork", "Base.HandShovel", "Base.EntrenchingTool", "Base.Rake",
            "Base.MasonsTrowel", "Base.Scythe", "Base.ScytheForged", "Base.HandScythe",
            "Base.HandScytheForged", "Base.PrimitiveScythe", "Base.HandScytheBlade",
            "Base.ScytheBlade"
        ));

        RAW_BY_FAMILY.put("WEAPONS", List.of(
            "Base.BaseballBat", "Base.Nightstick", "Base.HuntingKnife", "Base.KitchenKnife",
            "Base.Machete", "Base.Katana", "Base.SpearCrafted", "Base.SpearBreadKnife", "Base.SpearButterKnife",
            "Base.SpearFork", "Base.SpearHuntingKnife", "Base.SpearKnife", "Base.SpearLetterOpener",
            "Base.SpearMachete", "Base.SpearScissors", "Base.SpearScrewdriver", "Base.Broom", "Base.Pistol",
            "Base.Pistol2", "Base.Pistol3", "Base.Revolver", "Base.Revolver_Long",
            "Base.Revolver_Short", "Base.Shotgun", "Base.DoubleBarrelShotgun", "Base.VarmintRifle",
            "Base.HuntingRifle", "Base.AssaultRifle", "Base.AssaultRifle2"
        ));

        RAW_BY_FAMILY.put("AMMO", List.of(
            "Base.Bullets9mm", "Base.Bullets9mmBox", "Base.Bullets9mmCarton",
            "Base.Bullets45", "Base.Bullets45Box", "Base.Bullets45Carton",
            "Base.Bullets44", "Base.Bullets44Box", "Base.Bullets44Carton",
            "Base.Bullets38", "Base.Bullets38Box", "Base.Bullets38Carton",
            "Base.ShotgunShells", "Base.ShotgunShellsBox", "Base.ShotgunShellsCarton",
            "Base.3030Bullets", "Base.3030Box", "Base.3030Carton",
            "Base.Bullets357", "Base.Bullets357Box", "Base.Bullets357Carton",
            "Base.308Bullets", "Base.308Box", "Base.308Carton",
            "Base.556Bullets", "Base.556Box", "Base.556Carton"
        ));

        RAW_BY_FAMILY.put("FOOD", List.of(
            "Base.CannedBellPepper", "Base.CannedBroccoli", "Base.CannedCabbage",
            "Base.CannedCarrots", "Base.CannedEggplant", "Base.CannedLeek",
            "Base.CannedPotato", "Base.CannedRedRadish", "Base.CannedTomato",
            "Base.WaterRationCan", "Base.MysteryCan", "Base.DentedCan",
            "Base.CannedBolognese", "Base.CannedCarrots2", "Base.CannedChili",
            "Base.CannedCornedBeef", "Base.CannedCorn", "Base.CannedFruitCocktail",
            "Base.CannedMilk", "Base.CannedMushroomSoup", "Base.CannedPeaches",
            "Base.CannedPeas", "Base.CannedPineapple", "Base.CannedPotato2",
            "Base.CannedSardines", "Base.CannedTomato2", "Base.Dogfood",
            "Base.TinnedBeans", "Base.TinnedSoup", "Base.TunaTin",
            "Base.CannedFruitBeverage", "Base.Macandcheese", "Base.CannedRoe",
            "Base.WaterRationCan_Box", "Base.MysteryCan_Box", "Base.DentedCan_Box",
            "Base.CannedBolognese_Box", "Base.CannedCarrots_Box", "Base.CannedChili_Box",
            "Base.CannedCornedBeef_Box", "Base.CannedCorn_Box", "Base.CannedFruitCocktail_Box",
            "Base.CannedMilk_Box", "Base.CannedMushroomSoup_Box", "Base.CannedPeaches_Box",
            "Base.CannedPeas_Box", "Base.CannedPineapple_Box", "Base.CannedPotato_Box",
            "Base.CannedSardines_Box", "Base.CannedTomato_Box", "Base.Dogfood_Box",
            "Base.TinnedBeans_Box", "Base.TinnedSoup_Box", "Base.TunaTin_Box",
            "Base.CannedFruitBeverage_Box", "Base.Macandcheese_Box"
        ));
    }

    // ── Typed entries derived once from RAW_BY_FAMILY ─────────────────────────

    private static final List<CatalogEntry> ENTRIES;
    private static final Map<String, List<CatalogEntry>> ENTRIES_BY_FAMILY;

    static {
        List<CatalogEntry> all = new ArrayList<>();
        Map<String, List<CatalogEntry>> byFamily = new LinkedHashMap<>();

        for (Map.Entry<String, List<String>> raw : RAW_BY_FAMILY.entrySet()) {
            String family = raw.getKey();
            List<CatalogEntry> group = new ArrayList<>();
            for (String fullType : raw.getValue()) {
                // No items in the active catalog are burnable — burnables are excluded.
                CatalogEntry entry = new CatalogEntry(
                        fullType, family, MULTIPLIER, false, FuelCompensationMode.NONE);
                group.add(entry);
                all.add(entry);
            }
            byFamily.put(family, Collections.unmodifiableList(group));
        }

        ENTRIES = Collections.unmodifiableList(all);
        ENTRIES_BY_FAMILY = Collections.unmodifiableMap(byFamily);

        validateEntries(ENTRIES);
    }

    private WeightReducerCatalog() {
    }

    // ── Public typed API ───────────────────────────────────────────────────────

    /** All entries in deterministic family/insertion order. */
    public static List<CatalogEntry> entries() {
        return ENTRIES;
    }

    /** Entries grouped by family, deterministic insertion order. */
    public static Map<String, List<CatalogEntry>> entriesByFamily() {
        return ENTRIES_BY_FAMILY;
    }

    /** Ordered set of family names. */
    public static List<String> families() {
        return List.copyOf(ENTRIES_BY_FAMILY.keySet());
    }

    /** Flat ordered list of fullTypes (for use by bridge / Lua integration). */
    public static List<String> flattenedItems() {
        Set<String> ordered = new LinkedHashSet<>();
        ENTRIES.forEach(e -> ordered.add(e.fullType()));
        return List.copyOf(ordered);
    }

    /** Pipe-separated flattened fullTypes. */
    public static String flattenedItemsPipeSeparated() {
        return String.join("|", flattenedItems());
    }

    /** Human-readable validation summary. */
    public static String validationSummary() {
        return "WeightReducerCatalog valid: " + ENTRIES.size() + " items, multiplier=" + MULTIPLIER;
    }

    // ── Internal validation ────────────────────────────────────────────────────

    public static void validateEntries(List<CatalogEntry> entries) {
        if (MULTIPLIER <= 0.0D || MULTIPLIER > 1.0D) {
            throw new IllegalStateException("Weight reducer multiplier must be in (0, 1].");
        }

        Set<String> seen = new LinkedHashSet<>();
        for (CatalogEntry entry : entries) {
            if (entry.family() == null || entry.family().isBlank()) {
                throw new IllegalStateException("Catalog entry has blank family: " + entry.fullType());
            }
            if (!FULL_TYPE.matcher(entry.fullType()).matches()) {
                throw new IllegalStateException("Invalid fullType: " + entry.fullType());
            }
            if (!seen.add(entry.fullType())) {
                throw new IllegalStateException("Duplicate fullType: " + entry.fullType());
            }
            if (entry.multiplier() <= 0.0D || entry.multiplier() > 1.0D) {
                throw new IllegalStateException("Entry multiplier out of (0,1] for: " + entry.fullType());
            }
        }

        // Validate family non-emptiness via entriesByFamily
        for (Map.Entry<String, List<CatalogEntry>> fam : ENTRIES_BY_FAMILY.entrySet()) {
            if (fam.getValue().isEmpty()) {
                throw new IllegalStateException("Weight reducer family is empty: " + fam.getKey());
            }
        }
    }
}
