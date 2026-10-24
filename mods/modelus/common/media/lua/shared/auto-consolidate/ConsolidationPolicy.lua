ModelusConsolidationPolicy = ModelusConsolidationPolicy or {}

local Policy = ModelusConsolidationPolicy

local function isFinite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Policy.isPartial(quantity)
    return isFinite(quantity) and quantity > 0 and quantity < 1
end

function Policy.getTransfer(sourceQuantity, targetQuantity)
    if not Policy.isPartial(sourceQuantity) or not Policy.isPartial(targetQuantity) then
        return nil
    end

    local amount = math.min(sourceQuantity, 1 - targetQuantity)
    if amount <= 0 then return nil end
    return amount, sourceQuantity - amount, targetQuantity + amount
end

function Policy.choosePair(entries)
    local groups = {}
    local groupOrder = {}
    local seenItems = {}

    for index = 1, #entries do
        local entry = entries[index]
        if entry and entry.item and not seenItems[entry.item] then
            seenItems[entry.item] = true
            if entry.mergeable == true and entry.fluid ~= true
                    and type(entry.fullType) == "string" and entry.fullType ~= ""
                    and isFinite(entry.useDelta) and entry.useDelta > 0
                    and Policy.isPartial(entry.fraction) then
                local key = entry.fullType .. "\31" .. tostring(entry.useDelta)
                local group = groups[key]
                if not group then
                    group = { fullType = entry.fullType, useDelta = entry.useDelta, entries = {} }
                    groups[key] = group
                    groupOrder[#groupOrder + 1] = group
                end
                group.entries[#group.entries + 1] = entry
            end
        end
    end

    for index = 1, #groupOrder do
        local group = groupOrder[index]
        if #group.entries >= 2 then
            local donor = group.entries[1]
            local target = group.entries[1]
            for candidateIndex = 2, #group.entries do
                local candidate = group.entries[candidateIndex]
                if candidate.fraction < donor.fraction then donor = candidate end
                if candidate.fraction > target.fraction then target = candidate end
            end
            if donor == target then target = group.entries[2] end
            return donor, target
        end
    end

    return nil
end

return Policy
