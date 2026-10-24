local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local env = { ipairs = ipairs, pairs = pairs, type = type }
setmetatable(env, { __index = _G })
local chunk = assert(loadfile("mods/modelus/common/media/lua/shared/dual-back/DualBackPolicy.lua"))
setfenv(chunk, env)
local policy = chunk()

expect(policy.SLOT_TYPE == "ModelusBack2" and policy.SLOT_NAME ~= "Back", "unique non-Back slot identity")
local expected = { BigWeapon = true, BigBlade = true, Rifle = true, Shovel = true, Sword = true }
local ids = {}
for attachmentType in pairs(expected) do
    expect(policy.isEligible(attachmentType), attachmentType .. " eligible")
    local id = policy.locationId(attachmentType)
    expect(id and not ids[id], "location IDs are unique")
    ids[id] = true
end
for _, attachmentType in ipairs({ "Pan", "Saucepan", "Guitar", "Racket", "Holster", "Knife" }) do
    expect(not policy.isEligible(attachmentType), attachmentType .. " excluded")
end
local definition = policy.buildSlotDefinition()
local count = 0
for attachmentType, id in pairs(definition.attachments) do
    count = count + 1
    expect(expected[attachmentType] and id == policy.locationId(attachmentType), "definition maps eligible type")
end
expect(count == 5, "exactly five attachment types")
return assertions
