-- AmmoLootDropBox.lua
-- Injects boxed ammo into zombie loot tables so killed zombies have a chance to
-- drop ammo boxes.
-- Trigger: OnInitGlobalModData — applies once per server startup.
-- Scope: server-only.

require 'Items/SuburbsDistributions'

local _LOG_PREFIX = "[Modelus][AmmoLootDropBox]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

AmmoLootDropBox = {}

-- Matches the reference mod's default sandbox value for boxed ammo.
AmmoLootDropBox.DROP_RATE = 1.0

AmmoLootDropBox.AMMO_BOX_TYPES = {
    "Base.3030Box",
    "Base.Bullets357Box",
    "Base.308Box",
    "Base.Bullets38Box",
    "Base.Bullets44Box",
    "Base.Bullets45Box",
    "Base.Bullets9mmBox",
    "Base.ShotgunShellsBox",
    "Base.556Box",
}

AmmoLootDropBox._applied = false

function AmmoLootDropBox.apply()
    if AmmoLootDropBox._applied then
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

    for _, ammoType in ipairs(AmmoLootDropBox.AMMO_BOX_TYPES) do
        table.insert(SuburbsDistributions["all"]["inventorymale"].items, ammoType)
        table.insert(SuburbsDistributions["all"]["inventorymale"].items, AmmoLootDropBox.DROP_RATE)
        table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, ammoType)
        table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, AmmoLootDropBox.DROP_RATE)
        logDebug("injected " .. ammoType .. " @ " .. tostring(AmmoLootDropBox.DROP_RATE))
    end

    if not ItemPickerJava then
        print(_LOG_PREFIX .. " ItemPickerJava is nil — distributions injected but Parse() skipped")
    else
        ItemPickerJava.Parse()
        logDebug("ItemPickerJava.Parse() called")
    end

    AmmoLootDropBox._applied = true
end

Events.OnInitGlobalModData.Add(AmmoLootDropBox.apply)
