-- BetterCondition.lua
-- Restores weapon condition to conditionMax whenever the player equips a HandWeapon.
-- Hook: wrap of ISEquipWeaponAction:complete()
-- Scope: client only — condition display and player interaction are client-side.

local _LOG_PREFIX = "[Modelus][BetterCondition]"

local function logDebug(msg)
    if getDebug and getDebug() then
        print(_LOG_PREFIX .. " " .. msg)
    end
end

-- Preserve a reference to the original complete() before wrapping.
local _originalComplete = ISEquipWeaponAction.complete

ISEquipWeaponAction.complete = function(self)
    local result = _originalComplete(self)

    if result and self.item and instanceof(self.item, "HandWeapon") then
        local conditionBefore = self.item:getCondition()
        local conditionMax    = self.item:getConditionMax()

        self.item:setCondition(conditionMax)

        logDebug(
            "Restored condition on equip: item=" .. tostring(self.item:getName()) ..
            " before=" .. tostring(conditionBefore) ..
            " after=" .. tostring(conditionMax)
        )
    end

    return result
end
