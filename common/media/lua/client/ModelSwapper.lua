---@param item InventoryItem
---@param player IsoPlayer
local function ToggleModel(item, player)
    local inv = player:getInventory()
    local itemType = item:getFullType()

    if itemType:sub(-2) == "_s" then
        itemType = itemType:sub(1, -3) .. "_l"
    elseif itemType:sub(-2) == "_l" then
        itemType = itemType:sub(1, -3) .. "_s"
    else
        return
    end

    inv:Remove(item)
    inv:AddItem(itemType)
end

---@param playerNum integer
---@param context ISContextMenu
---@param items table<integer, ContextMenuItemStack>|table<integer, InventoryItem>
local function OnFillInventoryObjectContextMenu(playerNum, context, items)
    local addedItems = {}
    local items = ISInventoryPane.getActualItems(items)
    local player = getSpecificPlayer(playerNum)

    for _, item in ipairs(items) do
        local type = item:getFullType()
        if player:getInventory() == item:getContainer()
            and item:getModule() == "mangaItems"
            and not addedItems[type]
            and (type:sub(-2) == "_s" or type:sub(-2) == "_l") then

            addedItems[type] = true
            local side = (type:sub(-2) == "_s") and "Sideways" or "Upright"
            context:addOption('Set '..side, player, function () ToggleModel(item, player) end)
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(OnFillInventoryObjectContextMenu)