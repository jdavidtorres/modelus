local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local environment = { math = math, type = type }
setmetatable(environment, { __index = _G })
local chunk = assert(loadfile("mods/modelus/common/media/lua/shared/auto-tailoring/TailoringPolicy.lua"))
setfenv(chunk, environment)
local policy = chunk()

local function defense(scratch, bite)
    return { scratch = scratch, bite = bite }
end

expect(policy.isStrictImprovement(defense(8, 4), defense(10, 4)), "scratch-only strict improvement is accepted")
expect(policy.isStrictImprovement(defense(8, 4), defense(8, 5)), "bite-only strict improvement is accepted")
expect(not policy.isStrictImprovement(defense(8, 4), defense(8, 4)), "equal protection is rejected")
expect(not policy.isStrictImprovement(defense(8, 4), defense(9, 3)), "bite reduction rejects scratch improvement")
expect(not policy.isStrictImprovement(defense(8, 4), defense(7, 5)), "scratch reduction rejects bite improvement")
expect(not policy.isStrictImprovement(defense(0 / 0, 1), defense(2, 2)), "NaN protection is rejected")
expect(not policy.isStrictImprovement(defense(math.huge, 1), defense(2, 2)), "infinite protection is rejected")
expect(not policy.isStrictImprovement(defense(-1, 1), defense(2, 2)), "negative protection is rejected")

local after = policy.replacementFloor(defense(8, 4), defense(4, 2), defense(6, 3), false)
expect(after.scratch == 10 and after.bite == 5, "healthy patch replacement uses the effective-defense delta")
after = policy.replacementFloor(defense(0, 0), defense(4, 2), defense(6, 3), true)
expect(after.scratch == 6 and after.bite == 3, "visible hole replacement uses new patch defense")
expect(policy.replacementFloor(defense(-1, 1), defense(1, 1), defense(2, 2), false) == nil,
    "invalid current defense makes replacement prediction unavailable")

local repair = { priority = 1, garmentIndex = 2, partIndex = 4, after = defense(1, 0) }
local padding = { priority = 2, garmentIndex = 1, partIndex = 1, after = defense(20, 10) }
local upgrade = { priority = 3, garmentIndex = 1, partIndex = 1, after = defense(30, 20) }
expect(policy.chooseNext({ padding, upgrade, repair }) == repair, "repairs precede padding and upgrades")

local fullRestore = { priority = 1, garmentIndex = 1, partIndex = 1, fullRestore = true, after = defense(0, 0) }
local otherFabric = { priority = 1, garmentIndex = 1, partIndex = 1, after = defense(20, 10), fabricOrder = 3 }
expect(policy.chooseNext({ otherFabric, fullRestore }) == fullRestore,
    "full vanilla restoration is preferred on the same repair target")

local lowBite = { priority = 2, garmentIndex = 1, partIndex = 1, after = defense(20, 3), fabricOrder = 1 }
local highBite = { priority = 2, garmentIndex = 1, partIndex = 1, after = defense(10, 8), fabricOrder = 3 }
expect(policy.chooseNext({ lowBite, highBite }) == highBite, "same-zone candidate maximizes bite defense before scratch")

local stableDenim = { priority = 2, garmentIndex = 1, partIndex = 1, after = defense(5, 3), fabricOrder = 2 }
local stableCotton = { priority = 2, garmentIndex = 1, partIndex = 1, after = defense(5, 3), fabricOrder = 1 }
expect(policy.chooseNext({ stableDenim, stableCotton }) == stableCotton, "fabric ties use fixed material order")

return assertions