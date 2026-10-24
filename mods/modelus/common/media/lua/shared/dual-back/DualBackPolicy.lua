ModelusDualBackPolicy = ModelusDualBackPolicy or {}

local Policy = ModelusDualBackPolicy

Policy.SLOT_TYPE = "ModelusBack2"
Policy.SLOT_NAME = "Back 2"
Policy.SLOT_ANIMSET = "back"
Policy.LATERAL_OFFSET = 0.055

Policy.LOCATION_IDS = {
    BigWeapon = "ModelusBack2BigWeapon",
    BigBlade = "ModelusBack2BigBlade",
    Rifle = "ModelusBack2Rifle",
    Shovel = "ModelusBack2Shovel",
    Sword = "ModelusBack2Sword"
}

Policy.ANCHOR_IDS = {
    BigWeapon = { normal = "modelus_back2_bigweapon", bag = "modelus_back2_bigweapon_bag" },
    BigBlade = { normal = "modelus_back2_blade", bag = "modelus_back2_blade_bag" },
    Rifle = { normal = "modelus_back2_rifle", bag = "modelus_back2_rifle_bag" },
    Shovel = { normal = "modelus_back2_shovel", bag = "modelus_back2_shovel_bag" },
    Sword = { normal = "modelus_back2_blade", bag = "modelus_back2_blade_bag" }
}

Policy.SOURCE_ANCHORS = {
    BigWeapon = { normal = "big_w_back", bag = "big_w_back_bag" },
    BigBlade = { normal = "blade_back", bag = "big_blade_back_bag" },
    Rifle = { normal = "rifle_back", bag = "rifle_back_bag" },
    Shovel = { normal = "shovel_back", bag = "shovel_back_bag" },
    Sword = { normal = "blade_back", bag = "big_blade_back_bag" }
}

Policy.ATTACHMENT_TYPES = { "BigWeapon", "BigBlade", "Rifle", "Shovel", "Sword" }

function Policy.isEligible(attachmentType)
    return Policy.LOCATION_IDS[attachmentType] ~= nil
end

function Policy.locationId(attachmentType)
    return Policy.LOCATION_IDS[attachmentType]
end

function Policy.anchorName(attachmentType, hasBackBag)
    local anchors = Policy.ANCHOR_IDS[attachmentType]
    if not anchors then return nil end
    return hasBackBag and anchors.bag or anchors.normal
end

function Policy.buildSlotDefinition()
    local attachments = {}
    for _, attachmentType in ipairs(Policy.ATTACHMENT_TYPES) do
        attachments[attachmentType] = Policy.locationId(attachmentType)
    end
    return {
        type = Policy.SLOT_TYPE,
        name = Policy.SLOT_NAME,
        animset = Policy.SLOT_ANIMSET,
        attachments = attachments
    }
end

return Policy
