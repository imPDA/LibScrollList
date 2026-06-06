local Label = LibScrollList.Label
local Table = LibScrollList.Table
local Column = LibScrollList.Column
local combine = LibScrollList.combine


local function CreateInventoryTable()
    -- 1. Create parent control, I created simple flex window (it will resize to fit everythin inside) with default background
    local window = CreateControl('LibScrollList_ExampleTLC', GuiRoot, CT_TOPLEVELCONTROL)
    window:SetAnchor(CENTER)
    window:SetResizeToFitDescendents(true)

    local background = CreateControlFromVirtual('$(parent)Background', window, 'ZO_DefaultBackdrop')
    background:SetExcludeFromResizeToFitExtents(true)

    -- 2. Create styles for all cells and headers in table
    -- P.S. In this examle all columns are different, but you can use the same style for diffrent columns to make them identically styled
    -- DefaultLabel = Label(defaultStyle)
    -- columns = {
    --     'Column1', 100, 0, DefaultLabel, 'Column 1',
    --     'Column2', 100, 0, DefaultLabel, 'Column 2',
    --     'Column3', 100, 0, DefaultLabel, 'Column 3',
    --     'Column4', 100, 0, DefaultLabel, 'Column 4',
    -- }
    -- This creates 4 columns of the same style, and headers will be the same style as well if you create it with columns

    local defaultCellStyle = {
        SetFont = {'ZoFontWinH4'},
        SetVerticalAlignment = {TEXT_ALIGN_CENTER},
    }

    local defaultHeaderStyle = {
        SetFont = {'ZoFontGameLargeBold'},
        SetColor = {0.811, 0.862, 0.741},
        SetModifyTextType = {MODIFY_TEXT_TYPE_UPPERCASE},
    }

    local alignLeft = {SetHorizontalAlignment = {TEXT_ALIGN_LEFT}}
    local alignCenter = {SetHorizontalAlignment = {TEXT_ALIGN_CENTER}}
    local alignRight = {SetHorizontalAlignment = {TEXT_ALIGN_RIGHT}}

    local addQty = function(ctrl, value) ctrl:SetText(('%s pcs'):format(value)) end  -- setFn to modify value

    local IdCell = Label(combine(defaultCellStyle, alignRight))  -- combine can be used to combine styles
    local NameCell = Label(combine(defaultCellStyle, alignLeft))
    local QtyCell = Label(combine(defaultCellStyle, alignRight), addQty)

    local IdHeader = Label(combine(defaultHeaderStyle, alignRight))
    local NameHeader = Label(combine(defaultHeaderStyle, alignLeft))
    local QtyHeader = Label(combine(defaultHeaderStyle, alignRight), addQty)

    -- 3. Create list of columns
    local SORTABLE = true
    local columns = {
        Column('ItemId',    80,  0, IdCell,     'Item ID', IdHeader,   SORTABLE),
        Column('ItemName', 400, 16, NameCell, 'Item Name', NameHeader, SORTABLE),
        Column('Qty',       80,  0, QtyCell,        'Qty', QtyHeader,  SORTABLE),
    }

    -- 4. Prepare base
    local WITH_HEADERS = true
    local myTable = Table(WITH_HEADERS)
    myTable:AddDataType(1, columns, 32)  -- dataType, list of columns, heigth

    -- GLOBAL_IMP_EXAMPLE_TABLE = myTable

    -- 5. Create all controls (you can do it later, on window open for example)
    local scrollControl = myTable:Create('InventoryItems', window)
    scrollControl:SetDimensions(600, 600)  -- now you can modify it as you want
    scrollControl:SetAnchor(CENTER)  -- and position

    -- 6. Prepare some data, list of values, {<column 1 value>, <column 2 value>}
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

    -- 7. Presort if you want, or if you have no sortable columns set 
    -- table.sort(data, function(a, b) return a[2] < b[2] end)

    -- 8. Fill with data
    myTable:Update(1, data)  -- dataType, list of data
end


CreateInventoryTable()
