ModelusAutoLootPolicy = ModelusAutoLootPolicy or {}

local Policy = ModelusAutoLootPolicy

local function trimJava(value)
    local first = 1
    local last = #value
    while first <= last and string.byte(value, first) <= 32 do first = first + 1 end
    while last >= first and string.byte(value, last) <= 32 do last = last - 1 end
    return string.sub(value, first, last)
end

function Policy.isValidFullType(fullType)
    return type(fullType) == "string"
        and string.match(fullType, "^[A-Za-z0-9_]+%.[A-Za-z0-9_]+$") ~= nil
end

function Policy.parseAllowlist(stored)
    local result, seen = {}, {}
    if type(stored) ~= "string" then return result end
    for token in string.gmatch(stored .. "|", "(.-)|") do
        local candidate = trimJava(token)
        if Policy.isValidFullType(candidate) and not seen[candidate] then
            seen[candidate] = true
            result[#result + 1] = candidate
        end
    end
    return result
end

function Policy.serializeAllowlist(types)
    local unique = {}
    for _, fullType in ipairs(types or {}) do
        if Policy.isValidFullType(fullType) then unique[fullType] = true end
    end
    local result = {}
    for fullType in pairs(unique) do result[#result + 1] = fullType end
    table.sort(result)
    return table.concat(result, "|")
end

function Policy.toggleType(types, fullType)
    if not Policy.isValidFullType(fullType) then return false end
    for index, current in ipairs(types) do
        if current == fullType then
            table.remove(types, index)
            return false
        end
    end
    types[#types + 1] = fullType
    return true
end

function Policy.shouldLoot(types, fullType, owned, unwanted, broken, rotten)
    if not Policy.isValidFullType(fullType) or owned or unwanted or broken or rotten then return false end
    for _, allowed in ipairs(types or {}) do
        if allowed == fullType then return true end
    end
    return false
end

function Policy.uniqueEligible(items, eligible, maxItems)
    local result, seen = {}, {}
    if type(eligible) ~= "function" or type(maxItems) ~= "number" or maxItems <= 0 then
        return result
    end
    for _, item in ipairs(items or {}) do
        if item ~= nil and not seen[item] and eligible(item) then
            seen[item] = true
            result[#result + 1] = item
            if #result >= maxItems then break end
        end
    end
    return result
end

return Policy
