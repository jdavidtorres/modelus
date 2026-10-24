require "dual-back/DualBackPolicy"

ModelusDualBackModels = ModelusDualBackModels or {}
local Models = ModelusDualBackModels
local Policy = ModelusDualBackPolicy

local function copyAnchor(modelScript, sourceId, targetId)
    local source = modelScript:getAttachmentById(sourceId)
    if not source then return nil, "missing source attachment " .. sourceId end

    local target = modelScript:getAttachmentById(targetId)
    local created = target == nil
    if not target then target = modelScript:addAttachment(ModelAttachment.new(targetId)) end
    target:setBone(source:getBone())
    target:getOffset():set(source:getOffset():x(),
        source:getOffset():y() - Policy.LATERAL_OFFSET, source:getOffset():z())
    target:getRotate():set(source:getRotate():x(), source:getRotate():y(), source:getRotate():z())
    target:setScale(1.0)
    return created
end

function Models.register()
    local scripts = {}
    for _, bodyName in ipairs({ "Base.MaleBody", "Base.FemaleBody" }) do
        local modelScript = getScriptManager():getModelScript(bodyName)
        if not modelScript then
            print("[Modelus] dual-back: missing model script " .. bodyName)
            return false
        end
        scripts[#scripts + 1] = modelScript
        for _, attachmentType in ipairs(Policy.ATTACHMENT_TYPES) do
            local sources = Policy.SOURCE_ANCHORS[attachmentType]
            for _, variant in ipairs({ "normal", "bag" }) do
                if not modelScript:getAttachmentById(sources[variant]) then
                    print("[Modelus] dual-back: missing source attachment " .. sources[variant]
                        .. " on " .. bodyName)
                    return false
                end
            end
        end
    end

    local added = false
    for index, modelScript in ipairs(scripts) do
        local bodyName = index == 1 and "Base.MaleBody" or "Base.FemaleBody"
        local seenTargets = {}
        for _, attachmentType in ipairs(Policy.ATTACHMENT_TYPES) do
            local sources = Policy.SOURCE_ANCHORS[attachmentType]
            local targets = Policy.ANCHOR_IDS[attachmentType]
            for _, variant in ipairs({ "normal", "bag" }) do
                local targetId = targets[variant]
                if not seenTargets[targetId] then
                    seenTargets[targetId] = true
                    local created, err = copyAnchor(modelScript, sources[variant], targetId)
                    if created == nil then
                        print("[Modelus] dual-back: " .. tostring(err) .. " on " .. bodyName)
                        return false
                    end
                    added = added or created
                end
            end
        end
    end
    return added
end

return Models
