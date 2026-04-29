package com.modelus.weight;

import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Java-side source of truth and validator for Modelus weight-reducer item lists.
 *
 * <p>Lua remains responsible for applying weights inside Project Zomboid. This
 * class exists so the catalogue has a compile-checked, testable representation
 * and can be exposed to Lua when the Java bridge is available.</p>
 */
public final class WeightReducerCatalog {
    public static final double MULTIPLIER = 0.3D;

    private static final Pattern FULL_TYPE = Pattern.compile("^[A-Za-z0-9_]+\\.[A-Za-z0-9_]+$");

    private static final Map<String, List<String>> ITEMS_BY_FAMILY = new LinkedHashMap<>();

    static {
        ITEMS_BY_FAMILY.put("WOOD", List.of(
            "Base.Log", "Base.LogStacks2", "Base.LogStacks3", "Base.LogStacks4",
            "Base.Plank", "Base.Plank_Nails", "Base.Plank_Broken", "Base.Plank_Broken_Nails",
            "Base.PlankNail", "Base.TreeBranch", "Base.TreeBranch2", "Base.LargeBranch",
            "Base.Twigs", "Base.TwigsBundle", "Base.Sapling", "Base.UnusableWood",
            "Base.Rope", "Base.Twine", "Base.DuctTape", "Base.Woodglue"
        ));

        ITEMS_BY_FAMILY.put("METAL", List.of(
            "Base.SheetMetal", "Base.SmallSheetMetal", "Base.MetalBar", "Base.MetalPipe",
            "Base.MetalDrum", "Base.ScrapMetal", "Base.UnusableMetal", "Base.WeldingRods",
            "Base.IronIngot", "Base.LeadPipe", "Base.Nails", "Base.NailsBox",
            "Base.Screws", "Base.ScrewsBox", "Base.Wire", "Base.BarbedWire",
            "Base.ConcretePowder", "Base.PlasterPowder", "Base.Gravelbag", "Base.Sandbag",
            "Base.BucketConcreteFull", "Base.BucketPlasterFull"
        ));

        ITEMS_BY_FAMILY.put("TOOLS", List.of(
            "Base.Hammer", "Base.BallPeenHammer", "Base.ClubHammer", "Base.Screwdriver",
            "Base.Saw", "Base.GardenSaw", "Base.Wrench", "Base.PipeWrench",
            "Base.LugWrench", "Base.Crowbar", "Base.HandAxe", "Base.Axe",
            "Base.WoodAxe", "Base.PickAxe", "Base.Sledgehammer", "Base.Sledgehammer2",
            "Base.BlowTorch", "Base.WeldingMask", "Base.Tongs", "Base.Scissors",
            "Base.Needle", "Base.WoodenMallet"
        ));

        ITEMS_BY_FAMILY.put("GARDENING", List.of(
            "Base.Shovel", "Base.Shovel2", "Base.GardenHoe", "Base.GardenFork",
            "Base.HandFork", "Base.HandShovel", "Base.EntrenchingTool", "Base.GardenRake",
            "Base.Trowel"
        ));

        ITEMS_BY_FAMILY.put("WEAPONS", List.of(
            "Base.BaseballBat", "Base.Nightstick", "Base.HuntingKnife", "Base.KitchenKnife",
            "Base.Machete", "Base.Katana", "Base.SpearCrafted", "Base.Pistol",
            "Base.Pistol2", "Base.Pistol3", "Base.Revolver", "Base.Revolver_Long",
            "Base.Revolver_Short", "Base.Shotgun", "Base.DoubleBarrelShotgun", "Base.VarmintRifle",
            "Base.HuntingRifle", "Base.AssaultRifle", "Base.AssaultRifle2"
        ));

        ITEMS_BY_FAMILY.put("AMMO", List.of(
            "Base.Bullets9mm", "Base.Bullets9mmBox", "Base.Bullets9mmCarton",
            "Base.Bullets45", "Base.Bullets45Box", "Base.Bullets45Carton",
            "Base.Bullets44", "Base.Bullets44Box", "Base.Bullets44Carton",
            "Base.Bullets38", "Base.Bullets38Box", "Base.Bullets38Carton",
            "Base.ShotgunShells", "Base.ShotgunShellsBox", "Base.ShotgunShellsCarton",
            "Base.3030Bullets", "Base.3030BulletsBox", "Base.3030BulletsCarton",
            "Base.Bullets357", "Base.Bullets357Box", "Base.Bullets357Carton",
            "Base.308Bullets", "Base.308BulletsBox", "Base.308BulletsCarton",
            "Base.556Bullets", "Base.556BulletsBox", "Base.556BulletsCarton"
        ));

        validate();
    }

    private WeightReducerCatalog() {
    }

    public static String flattenedItemsPipeSeparated() {
        return String.join("|", flattenedItems());
    }

    public static String validationSummary() {
        return "WeightReducerCatalog valid: " + flattenedItems().size() + " items, multiplier=" + MULTIPLIER;
    }

    private static List<String> flattenedItems() {
        Set<String> ordered = new LinkedHashSet<>();
        ITEMS_BY_FAMILY.values().forEach(ordered::addAll);
        return List.copyOf(ordered);
    }

    private static void validate() {
        if (MULTIPLIER <= 0.0D || MULTIPLIER > 1.0D) {
            throw new IllegalStateException("Weight reducer multiplier must be in (0, 1].");
        }

        Set<String> seen = new LinkedHashSet<>();
        for (Map.Entry<String, List<String>> entry : ITEMS_BY_FAMILY.entrySet()) {
            if (entry.getValue().isEmpty()) {
                throw new IllegalStateException("Weight reducer family is empty: " + entry.getKey());
            }
            for (String fullType : entry.getValue()) {
                if (!FULL_TYPE.matcher(fullType).matches()) {
                    throw new IllegalStateException("Invalid fullType: " + fullType);
                }
                if (!seen.add(fullType)) {
                    throw new IllegalStateException("Duplicate fullType: " + fullType);
                }
            }
        }
    }
}
