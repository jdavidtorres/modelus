-- AmmoLootDrop.lua
-- Injects loose ammo rounds into zombie loot tables so killed zombies have a
-- small chance to drop common ammunition types.
-- Trigger: OnInitGlobalModData — applies once per server startup.
-- Scope: server-only.

require 'Items/SuburbsDistributions'

local _LOG_PREFIX = "[Modelus][AmmoLootDrop]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

AmmoLootDrop = {}

-- Probability added per slot roll for each ammo type.
-- Shared by all ammo types; no per-type overrides in v1.
AmmoLootDrop.DROP_RATE = 0.5

-- Full item-type strings for every ammo variant covered by this module.
AmmoLootDrop.AMMO_TYPES = {
    "Base.Bullets9mm",
    "Base.Bullets45",
    "Base.Bullets44",
    "Base.Bullets38",
    "Base.ShotgunShells",
    "Base.3030Bullets",
    "Base.Bullets357",
    "Base.308Bullets",
    "Base.556Bullets",
}

-- Guard: prevents double-application if OnInitGlobalModData fires more than once.
AmmoLootDrop._applied = false

-- ---------------------------------------------------------------------------
-- Core
-- ---------------------------------------------------------------------------

--- Injects all configured ammo types into zombie inventory distributions.
--- Safe to call multiple times — only runs once per server session.
function AmmoLootDrop.apply()
    if AmmoLootDrop._applied then
        logDebug("already applied, skipping")
        return
    end

    if not SuburbsDistributions["all"] then
        print(_LOG_PREFIX .. " SuburbsDistributions[\"all\"] is nil — skipping injection")
        return
    end

    if not SuburbsDistributions["all"]["inventorymale"] then
        print(_LOG_PREFIX .. " inventorymale table missing — skipping injection")
        return
    end

    if not SuburbsDistributions["all"]["inventoryfemale"] then
        print(_LOG_PREFIX .. " inventoryfemale table missing — skipping injection")
        return
    end

    for _, ammoType in ipairs(AmmoLootDrop.AMMO_TYPES) do
        table.insert(SuburbsDistributions["all"]["inventorymale"].items, ammoType)
        table.insert(SuburbsDistributions["all"]["inventorymale"].items, AmmoLootDrop.DROP_RATE)
        table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, ammoType)
        table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, AmmoLootDrop.DROP_RATE)
        logDebug("injected " .. ammoType .. " @ " .. tostring(AmmoLootDrop.DROP_RATE))
    end

    if not ItemPickerJava then
        print(_LOG_PREFIX .. " ItemPickerJava is nil — distributions injected but Parse() skipped")
    else
        ItemPickerJava.Parse()
        logDebug("ItemPickerJava.Parse() called")
    end

    AmmoLootDrop._applied = true
end

-- ---------------------------------------------------------------------------
-- Hook
-- ---------------------------------------------------------------------------

Events.OnInitGlobalModData.Add(AmmoLootDrop.apply)
