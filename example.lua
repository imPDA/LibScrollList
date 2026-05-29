local Label = LibTableTools.Label
local Table = LibTableTools.Table


local function CreateInventoryTable()
    local window = CreateControl('LibTableTools_ExampleTLC', GuiRoot, CT_TOPLEVELCONTROL)
    window:SetDimensions(566, 600)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetHidden(false)

    CreateControlFromVirtual('$(parent)Background', window, 'ZO_DefaultBackdrop')

    local DefaultLabel = Label:WithDefaults({
        SetFont = {'ZoFontWinH4'},
        SetVerticalAlignment = {TEXT_ALIGN_CENTER}
    })


    local columns = {
        DefaultLabel('ItemId', 85, 0)
        :SetHorizontalAlignment(TEXT_ALIGN_RIGHT),

        DefaultLabel('ItemName', 400, 16)
        :SetHorizontalAlignment(TEXT_ALIGN_LEFT),

        DefaultLabel('Qty', 60, 0)
        :SetHorizontalAlignment(TEXT_ALIGN_CENTER),
    }

    local headersStyle = {
        SetFont = {'ZoFontGameLargeBold'},
        SetColor = {0.811, 0.862, 0.741}
    }
    local headers = {
        {  'Item ID', headersStyle, sortable = true, },
        {'Item Name', headersStyle, sortable = true, },
        {      'Qty', headersStyle, sortable = true, {tiebreaker = 2, tiebreakerSortingOrder = ZO_SORT_ORDER_UP}},
    }

    local myTable = Table()
    myTable:AddDataType(1, columns, 32)
    myTable:AddHeader(1, headers, 48)

    GLOBAL_IMP_EXAMPLE_TABLE = myTable

    local scrollControl = myTable:Create('InventoryItems', window)
    scrollControl:SetAnchorFill()

    local data = {}
    local bag = BAG_BACKPACK
    local numSlots = GetBagSize(bag)
    for slotIndex = 0, numSlots - 1 do
        local itemId = GetItemId(bag, slotIndex)
        if itemId ~=0 then
            local itemName = GetItemName(bag, slotIndex)
            local itemAmount = select(2, GetItemInfo(bag, slotIndex))
            data[#data+1] = {itemId, itemName, itemAmount}
        end
    end

    table.sort(data, function(a, b) return a[2] < b[2] end)

    myTable:Update(1, data)
end


CreateInventoryTable()
