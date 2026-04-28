-- AmmoLootDropCarton.lua
-- Injects ammo cartons into zombie loot tables so killed zombies have a small
-- chance to drop bulk ammunition cartons.
-- Trigger: OnInitGlobalModData — applies once per server startup.
-- Scope: server-only.

require 'Items/SuburbsDistributions'

local _LOG_PREFIX = "[Modelus][AmmoLootDropCarton]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

AmmoLootDropCarton = {}

-- Matches the reference mod's default sandbox value for ammo cartons.
AmmoLootDropCarton.DROP_RATE = 0.1

AmmoLootDropCarton.AMMO_CARTON_TYPES = {
    "Base.3030Carton",
    "Base.Bullets357Carton",
    "Base.308Carton",
    "Base.556Carton",
    "Base.Bullets38Carton",
    "Base.Bullets44Carton",
    "Base.Bullets45Carton",
    "Base.Bullets9mmCarton",
    "Base.ShotgunShellsCarton",
}

AmmoLootDropCarton._applied = false

function AmmoLootDropCarton.apply()
    if AmmoLootDropCarton._applied then
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

    for _, ammoType in ipairs(AmmoLootDropCarton.AMMO_CARTON_TYPES) do
        table.insert(SuburbsDistributions["all"]["inventorymale"].items, ammoType)
        table.insert(SuburbsDistributions["all"]["inventorymale"].items, AmmoLootDropCarton.DROP_RATE)
        table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, ammoType)
        table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, AmmoLootDropCarton.DROP_RATE)
        logDebug("injected " .. ammoType .. " @ " .. tostring(AmmoLootDropCarton.DROP_RATE))
    end

    if not ItemPickerJava then
        print(_LOG_PREFIX .. " ItemPickerJava is nil — distributions injected but Parse() skipped")
    else
        ItemPickerJava.Parse()
        logDebug("ItemPickerJava.Parse() called")
    end

    AmmoLootDropCarton._applied = true
end

Events.OnInitGlobalModData.Add(AmmoLootDropCarton.apply)
