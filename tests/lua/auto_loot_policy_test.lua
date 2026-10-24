local chunk = assert(loadfile("mods/modelus/common/media/lua/shared/auto-loot/AutoLootPolicy.lua"))
setfenv(chunk, setmetatable({}, { __index = _G }))
local policy = chunk()
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local parsed = policy.parseAllowlist("Base.Apple|invalid|Base.Apple| Base.WaterBottle \t|\1Base.Pear\2")
expect(#parsed == 3 and parsed[1] == "Base.Apple" and parsed[2] == "Base.WaterBottle"
    and parsed[3] == "Base.Pear", "parse trims Java control bytes, rejects invalid and deduplicates")
expect(policy.serializeAllowlist({ "Base.WaterBottle", "Base.Apple", "Base.Apple" })
    == "Base.Apple|Base.WaterBottle", "serialization sorts and deduplicates")
expect(policy.serializeAllowlist({}) == "", "empty allowlist serializes as empty string")
expect(#policy.parseAllowlist(nil) == 0 and #policy.parseAllowlist("\0 \31") == 0,
    "nil and blank values parse as empty")
expect(policy.isValidFullType("Base.Apple") and not policy.isValidFullType("Base.Apple.Extra")
    and not policy.isValidFullType("Base.Bad|Type"), "full type validation is exact")

local allowlist = {}
expect(policy.toggleType(allowlist, "Base.Apple") and #allowlist == 1, "toggle adds valid type")
expect(not policy.toggleType(allowlist, "Base.Bad|Type") and #allowlist == 1,
    "invalid toggle leaves list unchanged")
expect(not policy.toggleType(allowlist, "Base.Apple") and #allowlist == 0, "toggle removes type")
expect(policy.shouldLoot({ "Base.Apple" }, "Base.Apple", false, false, false, false),
    "allowed eligible type passes")
expect(not policy.shouldLoot({ "Base.Apple" }, "base.Apple", false, false, false, false),
    "type matching is case-sensitive")
for index = 1, 4 do
    local flags = { false, false, false, false }
    flags[index] = true
    expect(not policy.shouldLoot({ "Base.Apple" }, "Base.Apple", flags[1], flags[2], flags[3], flags[4]),
        "each exclusion flag rejects")
end
local a, b, c = {}, {}, {}
local selected = policy.uniqueEligible({ a, a, b, c }, function(item) return item ~= c end, 2)
expect(#selected == 2 and selected[1] == a and selected[2] == b,
    "candidate selection identity-deduplicates, preserves order, and respects limit")
expect(#policy.uniqueEligible({ a }, function() return true end, 0) == 0,
    "non-positive candidate limit returns empty list")
return assertions
