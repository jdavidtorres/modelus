local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local currentLocations = {}
local function newGroup()
    local locations = {}
    local group = {}
    function group:getOrCreateLocation(id)
        if not locations[id] then
            local location = { attachment = nil }
            function location:getAttachmentName() return self.attachment end
            function location:setAttachmentName(name) self.attachment = name end
            locations[id] = location
        end
        return locations[id]
    end
    return group, locations
end
local group
group, currentLocations = newGroup()
local env = {
    require = function() end,
    AttachedLocations = { getGroup = function(name) expect(name == "Human", "Human group"); return group end },
    pairs = pairs, ipairs = ipairs, type = type
}
setmetatable(env, { __index = _G })
local policyChunk = assert(loadfile("mods/modelus/common/media/lua/shared/dual-back/DualBackPolicy.lua"))
setfenv(policyChunk, env)
local policy = policyChunk()
env.ModelusDualBackPolicy = policy
local chunk = assert(loadfile("mods/modelus/common/media/lua/shared/dual-back/DualBackLocations.lua"))
setfenv(chunk, env)
local module = chunk()
local count = 0
for _ in pairs(currentLocations) do count = count + 1 end
expect(count == 5, "registers five locations")
expect(currentLocations[policy.locationId("Rifle")].attachment == policy.anchorName("Rifle", false), "normal anchor registered")
expect(not module.setAttachmentNames(false), "normal update idempotent")
expect(module.setAttachmentNames(true), "bag anchors set")
expect(currentLocations[policy.locationId("Rifle")].attachment == policy.anchorName("Rifle", true), "rifle bag anchor")
local before = 0
for _ in pairs(currentLocations) do before = before + 1 end
module.register()
local after = 0
for _ in pairs(currentLocations) do after = after + 1 end
expect(before == after, "registration does not duplicate locations")
local replacementGroup, replacementLocations = newGroup()
group, currentLocations = replacementGroup, replacementLocations
expect(module.register(), "replacement Human group is populated")
expect(replacementLocations[policy.locationId("Rifle")].attachment == policy.anchorName("Rifle", true),
    "replacement group receives current bag anchor mapping")
return assertions
