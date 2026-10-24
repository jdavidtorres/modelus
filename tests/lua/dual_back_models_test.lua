local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local function vector(x, y, z)
    local result = { a = x, b = y, c = z }
    function result:x() return self.a end
    function result:y() return self.b end
    function result:z() return self.c end
    function result:set(a, b, c) self.a, self.b, self.c = a, b, c; return self end
    return result
end

local function attachment(id, bone, x, y, z, rx, ry, rz, scale)
    local value = { id = id, bone = bone, offset = vector(x, y, z), rotate = vector(rx, ry, rz), scale = scale or 1 }
    function value:getBone() return self.bone end
    function value:setBone(name) self.bone = name end
    function value:getOffset() return self.offset end
    function value:getRotate() return self.rotate end
    function value:getScale() return self.scale end
    function value:setScale(scale) self.scale = scale end
    return value
end

local scripts = {}
local env = {
    require = function() end,
    ModelAttachment = { new = function(id) return attachment(id, nil, 0, 0, 0, 0, 0, 0) end },
    getScriptManager = function() return { getModelScript = function(_, name) return scripts[name] end } end,
    print = function() end,
    ipairs = ipairs, pairs = pairs, type = type, tostring = tostring
}
setmetatable(env, { __index = _G })

local policyChunk = assert(loadfile("mods/modelus/common/media/lua/shared/dual-back/DualBackPolicy.lua"))
setfenv(policyChunk, env)
local policy = policyChunk()
env.ModelusDualBackPolicy = policy

local sourceIds = {
    big_w_back = true, big_w_back_bag = true, blade_back = true, big_blade_back_bag = true,
    rifle_back = true, rifle_back_bag = true, shovel_back = true, shovel_back_bag = true
}
local expectedTargets = {}
for _, targets in pairs(policy.ANCHOR_IDS) do
    expectedTargets[targets.normal] = true
    expectedTargets[targets.bag] = true
end
local sourceSnapshots = {}
for bodyIndex, bodyName in ipairs({ "Base.MaleBody", "Base.FemaleBody" }) do
    local model = { attachments = {} }
    function model:getAttachmentById(id) return self.attachments[id] end
    function model:addAttachment(value) self.attachments[value.id] = value; return value end
    for sourceIndex, sourceId in ipairs({ "big_w_back", "big_w_back_bag", "blade_back", "big_blade_back_bag",
            "rifle_back", "rifle_back_bag", "shovel_back", "shovel_back_bag" }) do
        local value = attachment(sourceId, "Bip01_BackPack", bodyIndex * 0.01 + sourceIndex,
            -0.03 - bodyIndex * 0.01 - sourceIndex * 0.001, 0.04 + sourceIndex * 0.002,
            bodyIndex * 10 + sourceIndex, bodyIndex * 20 + sourceIndex, bodyIndex * 30 + sourceIndex, 0.8)
        model.attachments[sourceId] = value
        sourceSnapshots[bodyName .. sourceId] = {
            bone = value:getBone(), x = value:getOffset():x(), y = value:getOffset():y(), z = value:getOffset():z(),
            rx = value:getRotate():x(), ry = value:getRotate():y(), rz = value:getRotate():z(), scale = value:getScale()
        }
    end
    scripts[bodyName] = model
end

local modelsChunk = assert(loadfile("mods/modelus/common/media/lua/client/dual-back/DualBackModels.lua"))
setfenv(modelsChunk, env)
local models = modelsChunk()
expect(models.register(), "first registration creates model anchors")

for _, bodyName in ipairs({ "Base.MaleBody", "Base.FemaleBody" }) do
    local model = scripts[bodyName]
    local targetCount = 0
    for targetId in pairs(expectedTargets) do
        local target = model:getAttachmentById(targetId)
        expect(target ~= nil, bodyName .. " has " .. targetId)
        targetCount = targetCount + 1
    end
    expect(targetCount == 8, bodyName .. " has eight unique target anchors")

    for attachmentType, sources in pairs(policy.SOURCE_ANCHORS) do
        for _, variant in ipairs({ "normal", "bag" }) do
            local target = model:getAttachmentById(policy.ANCHOR_IDS[attachmentType][variant])
            local source = model:getAttachmentById(sources[variant])
            local snapshot = sourceSnapshots[bodyName .. sources[variant]]
            expect(target:getBone() == snapshot.bone, "source bone copied")
            expect(target:getOffset():x() == snapshot.x and target:getOffset():z() == snapshot.z, "source X/Z preserved")
            expect(target:getOffset():y() == snapshot.y - policy.LATERAL_OFFSET, "outward Y offset applied")
            expect(target:getRotate():x() == snapshot.rx and target:getRotate():y() == snapshot.ry
                and target:getRotate():z() == snapshot.rz, "source rotation preserved")
            expect(target:getScale() == 1.0, "target scale set to one")
        end
    end

    for sourceId in pairs(sourceIds) do
        local source = model:getAttachmentById(sourceId)
        local snapshot = sourceSnapshots[bodyName .. sourceId]
        expect(source:getBone() == snapshot.bone and source:getOffset():x() == snapshot.x
            and source:getOffset():y() == snapshot.y and source:getOffset():z() == snapshot.z
            and source:getRotate():x() == snapshot.rx and source:getRotate():y() == snapshot.ry
            and source:getRotate():z() == snapshot.rz and source:getScale() == snapshot.scale,
            "vanilla source remains unchanged: " .. sourceId)
    end
end

expect(not models.register(), "second registration creates no duplicate anchors")
local male = scripts["Base.MaleBody"]
male:getAttachmentById("modelus_back2_rifle"):getOffset():set(99, 99, 99)
expect(not models.register(), "reapplying existing anchors reports no creation")
expect(male:getAttachmentById("modelus_back2_rifle"):getOffset():y()
    == male:getAttachmentById("rifle_back"):getOffset():y() - policy.LATERAL_OFFSET,
    "existing target is recalculated from vanilla source")

local missing = { attachments = {} }
function missing:getAttachmentById(id) return self.attachments[id] end
function missing:addAttachment(value) self.attachments[value.id] = value; return value end
scripts["Base.FemaleBody"] = missing
local countBefore = 0
for _ in pairs(male.attachments) do countBefore = countBefore + 1 end
expect(not models.register(), "missing source refuses registration")
local countAfter = 0
for _ in pairs(male.attachments) do countAfter = countAfter + 1 end
expect(countBefore == countAfter, "missing source does not partially mutate another body")

return assertions
