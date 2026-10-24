local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local function near(actual, expected)
    return math.abs(actual - expected) <= 1e-9
end

local moduleEnvironment = {
    math = math,
    tostring = tostring,
    type = type
}
setmetatable(moduleEnvironment, { __index = _G })
local chunk = assert(loadfile("mods/modelus/common/media/lua/shared/auto-consolidate/ConsolidationPolicy.lua"))
setfenv(chunk, moduleEnvironment)
local policy = chunk()

local function entry(id, fullType, fraction, useDelta, options)
    options = options or {}
    return {
        item = id,
        fullType = fullType,
        fraction = fraction,
        useDelta = useDelta,
        mergeable = options.mergeable ~= false,
        fluid = options.fluid == true
    }
end

local donor, target = policy.choosePair({ entry({}, "Base.Thread", 0.3, 0.01), entry({}, "Base.Thread", 0.4, 0.01) })
expect(donor.fraction == 0.3 and target.fraction == 0.4, "30%+40% selects donor and receiver")
donor, target = policy.choosePair({ entry({}, "Base.Thread", 0.5, 0.01), entry({}, "Base.Thread", 0.5, 0.01) })
expect(donor ~= target, "equal partial quantities still select distinct objects")
local amount, remainder, filled = policy.getTransfer(0.3, 0.4)
expect(near(amount, 0.3) and near(remainder, 0) and near(filled, 0.7), "30%+40% conserves quantity")

amount, remainder, filled = policy.getTransfer(0.7, 0.6)
expect(near(amount, 0.4) and near(remainder, 0.3) and near(filled, 1), "60%+70% caps receiver and conserves quantity")

local full = entry({}, "Base.Thread", 1, 0.01)
local first = entry({}, "Base.Thread", 0.2, 0.01)
local second = entry({}, "Base.Thread", 0.8, 0.01)
donor, target = policy.choosePair({ full, first, second })
expect(donor == first and target == second, "full items are excluded")
expect(policy.choosePair({ entry({}, "Base.Thread", 0, 0.01), entry({}, "Base.Thread", 0.5, 0.01) }) == nil, "empty items excluded")
expect(policy.choosePair({ entry({}, "Base.Thread", 0.2, 0.01), entry({}, "Base.Thread", 0.4, 0.02) }) == nil, "different use delta separated")
expect(policy.choosePair({ entry({}, "Base.Thread", 0.2, 0.01), entry({}, "Base.Thread_Aramid", 0.4, 0.01) }) == nil, "different full type separated")
expect(policy.choosePair({ entry({}, "Base.Pills", 0.2, 0.1, { mergeable = false }), entry({}, "Base.Pills", 0.4, 0.1) }) == nil, "nonmergeable entry excluded")
expect(policy.choosePair({ entry({}, "Base.Pills", 0.2, 0.1, { fluid = true }), entry({}, "Base.Pills", 0.4, 0.1) }) == nil, "fluid entry excluded")

local repeated = {}
donor, target = policy.choosePair({ entry(repeated, "Base.Thread", 0.2, 0.01), entry(repeated, "Base.Thread", 0.4, 0.01) })
expect(donor == nil and target == nil, "duplicate item instances count once")
expect(not policy.isPartial(-0.1) and not policy.isPartial(1.1) and not policy.isPartial(0 / 0), "invalid fractions excluded")

local protectedItem = setmetatable({}, { __index = function(_, key)
    if key == "getCondition" or key == "getConditionMax" then error("condition must not be read") end
end })
donor = entry(protectedItem, "Base.Thread", 0.2, 0.01)
target = entry({}, "Base.Thread", 0.4, 0.01)
local input = { donor, target }
policy.choosePair(input)
expect(#input == 2 and input[1] == donor and input[2] == target, "input list unchanged and condition untouched")

return assertions