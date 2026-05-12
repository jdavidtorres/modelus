-- AmmoConverter.lua
-- Trigger: idle player polling
-- Mantiene munición mínima para el arma equipada convirtiendo munición compatible
-- Author: Modelus

require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

local _LOG_PREFIX = "[Modelus][AmmoConverter]"
local TARGET_MIN_ROUNDS = 500
local POLL_INTERVAL = 180
local _tick = 0
local _lastNoSourceAmmo = nil   -- supress repeated no-source logs
local _containerNudged = false  -- flag: OnContainerUpdate fired, skip next poll wait

local generatedOk = pcall(require, "ammo-converter/AmmoConverterCatalog.generated")
if not generatedOk then
    generatedOk = pcall(require, "AmmoConverterCatalog.generated")
end

local CATALOG = AmmoConverterCatalog_Generated
if not generatedOk or not CATALOG or not CATALOG.AMMO_TYPES or not CATALOG.PACKAGING then
    print(_LOG_PREFIX .. " [ERROR] AmmoConverterCatalog.generated.lua not found or invalid. Run ./gradlew generateAmmoConverterLua.")
    CATALOG = { AMMO_TYPES = {}, SCRIPT_TO_FULL_TYPE = {}, PACKAGING = {}, _lookup = {} }
else
    print(_LOG_PREFIX .. " generated catalog loaded: " .. tostring(#CATALOG.AMMO_TYPES) .. " ammo types")
end

local function inventoryKey(fullType)
    local typeString = tostring(fullType)
    local dot = string.find(typeString, "%.")
    if dot then
        return string.sub(typeString, dot + 1)
    end
    return typeString
end

local function isKnownAmmoType(fullType)
    return CATALOG._lookup[tostring(fullType)] == true and CATALOG.PACKAGING[tostring(fullType)] ~= nil
end

local function normalizeAmmoType(rawType)
    if not rawType then return nil end

    local ammoType = tostring(rawType)
    local mapped = CATALOG.SCRIPT_TO_FULL_TYPE[string.lower(ammoType)]
    if mapped then
        return mapped
    end

    if string.find(ammoType, "^Base%.") then
        return ammoType
    end

    return ammoType
end

-- ---------------------------------------------------------------------------
-- Helper: Resolve target ammo type from equipped weapon
-- ---------------------------------------------------------------------------

local function getWeaponAmmoType(player)
    local weapon = player:getPrimaryHandItem()
    if not weapon then return nil end
    if not instanceof(weapon, "HandWeapon") then return nil end
    if not weapon:isRanged() then return nil end

    local ammoType = weapon:getAmmoType()
    if ammoType then
        return normalizeAmmoType(ammoType)
    end

    -- Fallback: magazines (B42)
    local magazine = weapon:getMagazine()
    if magazine then
        return normalizeAmmoType(magazine:getFullType())
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Inventory helpers
-- ---------------------------------------------------------------------------

local function numberFromJava(value)
    return tonumber(value) or tonumber(tostring(value)) or 0
end

local function countInventoryType(inventory, fullType)
    local key = inventoryKey(fullType)
    local ok, count = pcall(function()
        return inventory:getItemCountRecurse(key)
    end)
    if not ok then
        return 0, false, tostring(count)
    end
    return numberFromJava(count), true, nil
end

local function fetchInventoryItems(inventory, fullType, requested)
    if requested <= 0 then return {}, true, nil end

    local key = inventoryKey(fullType)
    local ok, items = pcall(function()
        return inventory:getSomeTypeRecurse(key, requested)
    end)
    if not ok or not items or not items.size then
        return nil, false, tostring(items)
    end

    local result = {}
    for i = 0, items:size() - 1 do
        result[#result + 1] = items:get(i)
    end

    if #result ~= requested then
        return result, false, "requested=" .. tostring(requested) .. " fetched=" .. tostring(#result)
    end

    return result, true, nil
end

local function removeInventoryItem(item)
    if not item then return false, "missing item" end

    local container = nil
    if item.getContainer then
        local okContainer, itemContainer = pcall(function()
            return item:getContainer()
        end)
        if okContainer then
            container = itemContainer
        end
    end
    if not container then return false, "missing item container" end

    local okRemove, removeErr = pcall(function()
        container:DoRemoveItem(item)
    end)
    if not okRemove then
        return false, tostring(removeErr)
    end

    if sendRemoveItemFromContainer then
        pcall(sendRemoveItemFromContainer, container, item)
    end

    return true, nil
end

local function addTargetAmmo(inventory, targetAmmo, count)
    for i = 1, count do
        local okAdd, added = pcall(function()
            return inventory:AddItem(targetAmmo)
        end)
        if not okAdd or not added then
            return false, "index=" .. tostring(i) .. " err=" .. tostring(added)
        end
    end
    return true, nil
end

-- ---------------------------------------------------------------------------
-- Conversion planning / action
-- ---------------------------------------------------------------------------

local function collectSource(inventory, fullType, count)
    local items, okFetch, fetchErr = fetchInventoryItems(inventory, fullType, count)
    if not okFetch then
        return nil, tostring(fetchErr)
    end
    return items, nil
end

local function takePackages(available, packageValue, needed)
    if needed <= 0 or available <= 0 then return 0, needed, 0 end

    local count = math.min(available, math.ceil(needed / packageValue))
    local created = count * packageValue
    return count, math.max(0, needed - created), created
end

local function buildConversionPlan(player, targetAmmo, maxToCreate)
    local inventory = player:getInventory()
    local targetBefore = countInventoryType(inventory, targetAmmo)
    local needed = maxToCreate or nil
    local plan = {
        targetAmmo = targetAmmo,
        sources = {},
        totalToCreate = 0,
        targetBefore = targetBefore,
    }

    -- dry-run logs are verbose: only print if DEBUG_AMMO_CONVERTER global is set
    local _dbg = DEBUG_AMMO_CONVERTER == true
    if _dbg then
        print(_LOG_PREFIX .. " dry-run START target=" .. tostring(targetAmmo) .. " targetBefore=" .. tostring(targetBefore) .. " maxToCreate=" .. tostring(maxToCreate or "all"))
    end

    for _, srcType in ipairs(CATALOG.AMMO_TYPES) do
        if needed and needed <= 0 then break end

        if srcType ~= targetAmmo then
            local pkg = CATALOG.PACKAGING[srcType]
            local availableLoose = countInventoryType(inventory, srcType)
            local availableBoxes = countInventoryType(inventory, pkg.box)
            local availableCartons = countInventoryType(inventory, pkg.carton)
            local looseCount = availableLoose
            local boxCount = availableBoxes
            local cartonCount = availableCartons

            if needed then
                looseCount = math.min(availableLoose, needed)
                needed = needed - looseCount
                boxCount, needed = takePackages(availableBoxes, pkg.boxValue, needed)
                cartonCount, needed = takePackages(availableCartons, pkg.cartonValue, needed)
            end

            local totalRounds = looseCount + (boxCount * pkg.boxValue) + (cartonCount * pkg.cartonValue)

            if _dbg then
                print(_LOG_PREFIX .. " dry-run source src=" .. srcType .. " target=" .. tostring(targetAmmo) .. " loose=" .. tostring(looseCount) .. "/" .. tostring(availableLoose) .. " boxes=" .. tostring(boxCount) .. "/" .. tostring(availableBoxes) .. " cartons=" .. tostring(cartonCount) .. "/" .. tostring(availableCartons) .. " totalRounds=" .. tostring(totalRounds))
            end

            if totalRounds > 0 then
                local looseItems, looseErr = collectSource(inventory, srcType, looseCount)
                local boxItems, boxErr = collectSource(inventory, pkg.box, boxCount)
                local cartonItems, cartonErr = collectSource(inventory, pkg.carton, cartonCount)
                if looseErr or boxErr or cartonErr then
                    print(_LOG_PREFIX .. " dry-run FAIL src=" .. srcType .. " looseErr=" .. tostring(looseErr) .. " boxErr=" .. tostring(boxErr) .. " cartonErr=" .. tostring(cartonErr))
                    return nil
                end

                plan.sources[#plan.sources + 1] = {
                    srcType = srcType,
                    packageDef = pkg,
                    looseCount = looseCount,
                    boxCount = boxCount,
                    cartonCount = cartonCount,
                    looseItems = looseItems,
                    boxItems = boxItems,
                    cartonItems = cartonItems,
                    totalRounds = totalRounds,
                }
                plan.totalToCreate = plan.totalToCreate + totalRounds
            end
        end
    end

    if _dbg then
        print(_LOG_PREFIX .. " dry-run DONE target=" .. tostring(targetAmmo) .. " totalToCreate=" .. tostring(plan.totalToCreate) .. " sourceGroups=" .. tostring(#plan.sources))
    end
    return plan
end

local function isPlayerIdle(player)
    local okQ, busy = pcall(function()
        return ISTimedActionQueue.isPlayerDoingAction and ISTimedActionQueue.isPlayerDoingAction(player)
    end)
    if not okQ or busy then return false end

    local okA, attacking = pcall(function() return player:isAttacking() end)
    local okS, strafing = pcall(function() return player:isStrafing() end)
    local okR, running = pcall(function() return player:isRunning() end)
    if (okA and attacking) or (okS and strafing) or (okR and running) then return false end

    return true
end

ModelusAmmoConverterAction = ISBaseTimedAction:derive("ModelusAmmoConverterAction")

function ModelusAmmoConverterAction:new(player, plan)
    local o = ISBaseTimedAction.new(self, player)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.plan = plan
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = math.max(1, math.min(300, math.floor((plan.totalToCreate or 0) / 10)))
    return o
end

function ModelusAmmoConverterAction:isValid()
    return self.player ~= nil and self.plan ~= nil and self.plan.totalToCreate and self.plan.totalToCreate > 0
end

function ModelusAmmoConverterAction:start()
    print(_LOG_PREFIX .. " action START target=" .. tostring(self.plan.targetAmmo) .. " totalToCreate=" .. tostring(self.plan.totalToCreate))
end

function ModelusAmmoConverterAction:update()
end

function ModelusAmmoConverterAction:stop()
    ISBaseTimedAction.stop(self)
end

function ModelusAmmoConverterAction:perform()
    local inventory = self.player:getInventory()
    local targetAmmo = self.plan.targetAmmo

    for _, source in ipairs(self.plan.sources) do
        for _, item in ipairs(source.looseItems) do
            local okRemove, removeErr = removeInventoryItem(item)
            if not okRemove then
                print(_LOG_PREFIX .. " action FAIL remove loose src=" .. source.srcType .. " err=" .. tostring(removeErr))
                ISBaseTimedAction.perform(self)
                return
            end
        end
        for _, item in ipairs(source.boxItems) do
            local okRemove, removeErr = removeInventoryItem(item)
            if not okRemove then
                print(_LOG_PREFIX .. " action FAIL remove box src=" .. source.srcType .. " err=" .. tostring(removeErr))
                ISBaseTimedAction.perform(self)
                return
            end
        end
        for _, item in ipairs(source.cartonItems) do
            local okRemove, removeErr = removeInventoryItem(item)
            if not okRemove then
                print(_LOG_PREFIX .. " action FAIL remove carton src=" .. source.srcType .. " err=" .. tostring(removeErr))
                ISBaseTimedAction.perform(self)
                return
            end
        end
    end

    local okAdd, addErr = addTargetAmmo(inventory, targetAmmo, self.plan.totalToCreate)
    if not okAdd then
        print(_LOG_PREFIX .. " action FAIL add target=" .. tostring(targetAmmo) .. " err=" .. tostring(addErr))
        ISBaseTimedAction.perform(self)
        return
    end

    local targetAfter = countInventoryType(inventory, targetAmmo)
    local expectedTargetAfter = self.plan.targetBefore + self.plan.totalToCreate
    local ok = targetAfter == expectedTargetAfter
    print(_LOG_PREFIX .. " action " .. (ok and "OK" or "WARN") .. " target=" .. tostring(targetAmmo) .. " targetBefore=" .. tostring(self.plan.targetBefore) .. " targetAfter=" .. tostring(targetAfter) .. " expectedTargetAfter=" .. tostring(expectedTargetAfter) .. " totalCreated=" .. tostring(self.plan.totalToCreate))

    ISBaseTimedAction.perform(self)
end

local function doConvert(player)
    local weaponAmmo = getWeaponAmmoType(player)
    if not weaponAmmo then
        print(_LOG_PREFIX .. " No ranged weapon equipped")
        return
    end

    if not isKnownAmmoType(weaponAmmo) then
        print(_LOG_PREFIX .. " conversion skipped unknown target=" .. tostring(weaponAmmo))
        return
    end

    local plan = buildConversionPlan(player, weaponAmmo)
    if not plan then
        print(_LOG_PREFIX .. " conversion aborted target=" .. tostring(weaponAmmo) .. " reason=plan-build-failed")
        return
    end

    if plan.totalToCreate <= 0 then
        print(_LOG_PREFIX .. " conversion noop target=" .. tostring(weaponAmmo) .. " reason=no-sources")
        return
    end

    ISTimedActionQueue.add(ModelusAmmoConverterAction:new(player, plan))
end

-- ---------------------------------------------------------------------------
-- Idle trigger
-- ---------------------------------------------------------------------------

local function onPlayerUpdate(player)
    if not player then return end

    _tick = _tick + 1
    if _tick < POLL_INTERVAL and not _containerNudged then return end
    _tick = 0
    _containerNudged = false

    if not isPlayerIdle(player) then return end

    local ammoType = getWeaponAmmoType(player)
    if not ammoType then return end
    if not isKnownAmmoType(ammoType) then return end

    local inventory = player:getInventory()
    local current = countInventoryType(inventory, ammoType)
    if current >= TARGET_MIN_ROUNDS then
        _lastNoSourceAmmo = nil  -- reset so next shortage logs again
        return
    end

    local shortage = TARGET_MIN_ROUNDS - current
    local plan = buildConversionPlan(player, ammoType, shortage)
    if not plan then
        print(_LOG_PREFIX .. " idle conversion aborted target=" .. tostring(ammoType) .. " reason=plan-build-failed")
        return
    end

    if plan.totalToCreate <= 0 then
        if _lastNoSourceAmmo ~= ammoType then
            print(_LOG_PREFIX .. " idle conversion noop target=" .. tostring(ammoType) .. " current=" .. tostring(current) .. " targetMin=" .. tostring(TARGET_MIN_ROUNDS) .. " reason=no-sources")
            _lastNoSourceAmmo = ammoType
        end
        return
    end

    _lastNoSourceAmmo = nil
    print(_LOG_PREFIX .. " idle conversion queued target=" .. tostring(ammoType) .. " current=" .. tostring(current) .. " targetMin=" .. tostring(TARGET_MIN_ROUNDS) .. " totalToCreate=" .. tostring(plan.totalToCreate))
    ISTimedActionQueue.add(ModelusAmmoConverterAction:new(player, plan))
end

local function onContainerUpdate(container)
    -- Nudge: reset the poll tick so the next OnPlayerUpdate fires immediately
    -- instead of waiting up to POLL_INTERVAL more ticks.
    _containerNudged = true
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnContainerUpdate.Add(onContainerUpdate)

print(_LOG_PREFIX .. " loaded (idle targetMin=" .. tostring(TARGET_MIN_ROUNDS) .. ")")
