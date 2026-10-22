ModelusItemIdentification = ModelusItemIdentification or {}

local function addDistinctItem(items, item)
    if not item then return true end

    for _, existingItem in ipairs(items) do
        if existingItem == item then
            return true
        end
    end

    items[#items + 1] = item
    return #items <= 1
end

local function addSelectedRow(items, row)
    if not row then return true end

    if instanceof(row, "InventoryItem") then
        return addDistinctItem(items, row)
    end

    local rowItems = row.items
    if not rowItems then return true end

    for _, item in ipairs(rowItems) do
        if not addDistinctItem(items, item) then
            return false
        end
    end

    return true
end

function ModelusItemIdentification.getSelectedItem()
    if not getPlayerInventory then return nil end

    local page = getPlayerInventory(0)
    if not page or not page.inventoryPane then return nil end

    local isVisibleOk, isVisible = pcall(function()
        return page:isVisible()
    end)
    if not isVisibleOk or not isVisible then return nil end

    local selected = page.inventoryPane.selected
    if not selected then return nil end

    local items = {}
    for _, row in pairs(selected) do
        if not addSelectedRow(items, row) then
            return nil
        end
    end

    if #items ~= 1 then return nil end
    return items[1]
end

function ModelusItemIdentification.getEquippedItem()
    if not getPlayer then return nil end

    local player = getPlayer()
    if not player then return nil end

    local ok, item = pcall(function()
        return player:getPrimaryHandItem()
    end)
    if not ok then return nil end
    return item
end
