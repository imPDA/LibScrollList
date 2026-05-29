local Label = LibTableTools.Label
local Table = LibTableTools.Table


local function CreateInventoryTable()
    -- 1. Create parent control, I created simple flex window (it will resize to fit everythin inside) with default background
    local window = CreateControl('LibTableTools_ExampleTLC', GuiRoot, CT_TOPLEVELCONTROL)
    window:SetAnchor(CENTER)
    window:SetResizeToFitDescendents(true)

    local background = CreateControlFromVirtual('$(parent)Background', window, 'ZO_DefaultBackdrop')
    background:SetExcludeFromResizeToFitExtents(true)

    -- 2. Create default style for all labels in table
    -- (optional, just makes life simpler as all labels will follow this standard -> simpler to change, less error)
    local DefaultLabel = Label:WithDefaults({
        SetFont = {'ZoFontWinH4'},
        SetVerticalAlignment = {TEXT_ALIGN_CENTER}
    })

    -- 3. Create list of columns
    local columns = {
        DefaultLabel('ItemId', 85, 0)  -- control name, width, offsetX from previous column
        :SetHorizontalAlignment(TEXT_ALIGN_RIGHT),  -- you can modify them using default functions
        -- :SomethingElse(...arguments)  -- and chain all methods like this

        DefaultLabel('ItemName', 400, 16)
        :SetHorizontalAlignment(TEXT_ALIGN_LEFT),

        DefaultLabel('Qty', 60, 0)
        :SetHorizontalAlignment(TEXT_ALIGN_CENTER),
    }

    -- 4. If you want to add header - create style for headers as well
    -- You can create separate style for every header of just use the same style for all of them
    local headersStyle = {
        SetFont = {'ZoFontGameLargeBold'},
        SetColor = {0.811, 0.862, 0.741},
        SetModifyTextType = {MODIFY_TEXT_TYPE_UPPERCASE},
    }
    -- Add `sortable = true` to make header sortable
    local headers = {
        {  'Item ID', headersStyle, sortable = true, },  -- name, style, ?sortable
        {'Item Name', headersStyle, sortable = true, },
        {      'Qty', headersStyle, sortable = true, },
    }

    -- 5. Prepare base
    local myTable = Table()
    myTable:AddDataType(1, columns, 32)  -- dataType, list of columns, heigth
    myTable:AddHeader(1, headers)  -- dataType, list of header styles, height (default = same as row heigth + space for sorting indicator if sortable)

    -- GLOBAL_IMP_EXAMPLE_TABLE = myTable

    -- 6. Create all controls (you can do it later, on window open for example)
    local scrollControl = myTable:Create('InventoryItems', window)
    scrollControl:SetDimensions(570, 600)  -- now you can modify it as you want
    scrollControl:SetAnchor(CENTER)  -- and position

    -- 7. Prepare some data, list of values, {<column 1 value>, <column 2 value>}
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

    -- 8. Presort if you want, or if you have no sortable columns set 
    -- table.sort(data, function(a, b) return a[2] < b[2] end)

    -- 9. Fill with data
    myTable:Update(1, data)  -- dataType, list of data
end


CreateInventoryTable()
