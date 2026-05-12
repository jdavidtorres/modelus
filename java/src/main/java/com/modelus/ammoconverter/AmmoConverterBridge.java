package com.modelus.ammoconverter;

import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.InventoryItemFactory;
import zombie.inventory.ItemContainer;

import java.util.ArrayList;
import java.util.List;

/**
 * Performs the ammo conversion transaction for the Modelus mod.
 *
 * <p>
 * The conversion algorithm:
 * </p>
 * <ol>
 * <li>Counts all loose ammo, boxes, and cartons of the source type in the
 * player's inventory.</li>
 * <li>Pre-creates all destination loose rounds. Aborts if any creation fails
 * (no inventory mutation).</li>
 * <li>Preflight-fetches all source items. Aborts if any list is
 * incomplete.</li>
 * <li>Removes all source items, then adds all pre-created destination
 * rounds.</li>
 * </ol>
 *
 * <p>
 * Invariant:
 * {@code totalCreated = looseConsumed + boxesConsumed×boxValue + cartonsConsumed×cartonValue}
 * </p>
 */
public final class AmmoConverterBridge {

  private AmmoConverterBridge() {
  }

  // =========================================================================
  // InventoryAdapter — injectable seam for unit tests
  // =========================================================================

  /**
   * Abstraction over PZ's {@link ItemContainer} operations.
   * The live implementation delegates to real PZ APIs; tests supply a stub.
   *
   * @param <T> the item type (InventoryItem in production, StubItem in tests)
   */
  public interface InventoryAdapter<T> {
    /**
     * Count of items matching {@code inventoryKey} (the type suffix, e.g.
     * "Bullets9mm").
     */
    int countRecurse(String inventoryKey);

    /** Fetch up to {@code count} items matching {@code inventoryKey}. */
    List<T> getSome(String inventoryKey, int count);

    /** Remove one item from the inventory. */
    void remove(T item);

    /**
     * Create one new item of {@code fullType} (e.g. "Base.Bullets9mm").
     * Returns {@code null} on failure.
     */
    T create(String fullType);

    /** Add a pre-created item to the inventory. */
    void add(T item);
  }

  // =========================================================================
  // Live adapter — wraps a real PZ ItemContainer
  // =========================================================================

  private static final class LiveAdapter implements InventoryAdapter<InventoryItem> {
    private final ItemContainer inventory;

    LiveAdapter(ItemContainer inventory) {
      this.inventory = inventory;
    }

    @Override
    public int countRecurse(String inventoryKey) {
      return inventory.getItemCountRecurse(inventoryKey);
    }

    @Override
    public List<InventoryItem> getSome(String inventoryKey, int count) {
      ArrayList<InventoryItem> result = inventory.getSomeTypeRecurse(inventoryKey, count, new ArrayList<>());
      return result != null ? result : List.of();
    }

    @Override
    public void remove(InventoryItem item) {
      inventory.Remove(item);
    }

    @Override
    public InventoryItem create(String fullType) {
      return InventoryItemFactory.CreateItem(fullType);
    }

    @Override
    public void add(InventoryItem item) {
      inventory.AddItem(item);
    }
  }

  // =========================================================================
  // Public entry points
  // =========================================================================

  /**
   * Converts all same-tier ammo of every peer type into destination loose rounds.
   * Called from {@link com.modelus.bridge.ModelusBridge#convertAmmoTo}.
   *
   * @param player         The player whose inventory will be mutated.
   * @param targetAmmoType Canonical full type of the destination ammo, e.g.
   *                       "Base.Bullets9mm".
   */
  public static void convertTo(IsoPlayer player, String targetAmmoType) {
    if (player == null || targetAmmoType == null || targetAmmoType.isBlank())
      return;
    if (!AmmoConverterConfig.isInTiers(targetAmmoType))
      return;

    InventoryAdapter<InventoryItem> adapter = new LiveAdapter(player.getInventory());
    List<String> peers = AmmoConverterConfig.getTierPeers(targetAmmoType);
    for (String srcType : peers) {
      convertWith(adapter, srcType, targetAmmoType);
    }
  }

  /**
   * Core conversion — generic over item type for testability.
   * Converts all source stock of {@code srcType} into destination loose rounds of
   * {@code dstType}.
   *
   * <p>
   * This method is package-private so unit tests in the same package can call it
   * directly with a stub adapter — no real PZ runtime required.
   * </p>
   */
  static <T> void convertWith(InventoryAdapter<T> adapter, String srcType, String dstType) {
    if (srcType == null || dstType == null || srcType.equals(dstType))
      return;

    AmmoConverterConfig.PackageDef pkg = AmmoConverterConfig.PACKAGING.get(srcType);
    SourceCounts counts = countSourceItems(adapter, srcType, pkg);
    int totalToCreate = calculateTotalToCreate(counts, pkg);

    if (totalToCreate <= 0)
      return;

    List<T> created = createDestinationItems(adapter, dstType, totalToCreate);
    if (created == null)
      return;

    SourceItems<T> sources = fetchSourceItems(adapter, srcType, counts, pkg);
    if (!validateSourceItems(counts, sources))
      return;

    removeSourceItems(adapter, sources);
    addDestinationItems(adapter, created);
  }

  private static class SourceCounts {
    final int looseCount;
    final int boxCount;
    final int cartonCount;

    SourceCounts(int looseCount, int boxCount, int cartonCount) {
      this.looseCount = looseCount;
      this.boxCount = boxCount;
      this.cartonCount = cartonCount;
    }
  }

  private static class SourceItems<T> {
    final List<T> loose;
    final List<T> boxes;
    final List<T> cartons;

    SourceItems(List<T> loose, List<T> boxes, List<T> cartons) {
      this.loose = loose;
      this.boxes = boxes;
      this.cartons = cartons;
    }
  }

  private static SourceCounts countSourceItems(
      InventoryAdapter<?> adapter, String srcType, AmmoConverterConfig.PackageDef pkg) {
    String looseKey = AmmoConverterConfig.inventoryKey(srcType);
    int looseCount = adapter.countRecurse(looseKey);
    int boxCount = 0;
    int cartonCount = 0;

    if (pkg != null) {
      boxCount = adapter.countRecurse(AmmoConverterConfig.inventoryKey(pkg.box()));
      cartonCount = adapter.countRecurse(AmmoConverterConfig.inventoryKey(pkg.carton()));
    }

    return new SourceCounts(looseCount, boxCount, cartonCount);
  }

  private static int calculateTotalToCreate(
      SourceCounts counts, AmmoConverterConfig.PackageDef pkg) {
    return counts.looseCount
        + counts.boxCount * (pkg != null ? pkg.boxValue() : 0)
        + counts.cartonCount * (pkg != null ? pkg.cartonValue() : 0);
  }

  private static <T> List<T> createDestinationItems(
      InventoryAdapter<T> adapter, String dstType, int totalToCreate) {
    List<T> created = new ArrayList<>(totalToCreate);
    for (int i = 0; i < totalToCreate; i++) {
      T item = adapter.create(dstType);
      if (item == null)
        return null; // abort — no inventory has been touched yet
      created.add(item);
    }
    return created;
  }

  private static <T> SourceItems<T> fetchSourceItems(
      InventoryAdapter<T> adapter,
      String srcType,
      SourceCounts counts,
      AmmoConverterConfig.PackageDef pkg) {
    String looseKey = AmmoConverterConfig.inventoryKey(srcType);
    List<T> looseSrc = counts.looseCount > 0 ? adapter.getSome(looseKey, counts.looseCount) : List.of();
    List<T> boxSrc = counts.boxCount > 0
        ? adapter.getSome(AmmoConverterConfig.inventoryKey(pkg.box()), counts.boxCount)
        : List.of();
    List<T> cartonSrc = counts.cartonCount > 0
        ? adapter.getSome(AmmoConverterConfig.inventoryKey(pkg.carton()), counts.cartonCount)
        : List.of();

    return new SourceItems<>(looseSrc, boxSrc, cartonSrc);
  }

  private static <T> boolean validateSourceItems(SourceCounts counts, SourceItems<T> sources) {
    if (sources.loose.size() < counts.looseCount)
      return false;
    if (sources.boxes.size() < counts.boxCount)
      return false;
    if (sources.cartons.size() < counts.cartonCount)
      return false;
    return true;
  }

  private static <T> void removeSourceItems(InventoryAdapter<T> adapter, SourceItems<T> sources) {
    for (T item : sources.loose)
      adapter.remove(item);
    for (T item : sources.boxes)
      adapter.remove(item);
    for (T item : sources.cartons)
      adapter.remove(item);
  }

  private static <T> void addDestinationItems(InventoryAdapter<T> adapter, List<T> created) {
    for (T item : created)
      adapter.add(item);
  }
}
