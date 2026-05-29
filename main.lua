local class = IMP_LibTableTools__class

-- ----------------------------------------------------------------------------

local addon = {}

-- ----------------------------------------------------------------------------

local function template(controlType)
    local T = {}

    setmetatable(T, {
        __call = function(_, name, width, offsetX)
            local obj = {}

            obj.__type = controlType
            obj.__name = name
            obj.__width = width
            obj.__offsetX = offsetX
            obj.__calls = {}

            function obj:Create(parent)
                local realName = ('$(parent)%s'):format(name)
                local real = CreateControl(realName, parent, controlType)

                real:SetWidth(width)
                real:SetAnchor(LEFT, parent, LEFT, offsetX)

                for _, call in ipairs(self.__calls) do
                    local methodName = call[1]
                    local args = { select(2, unpack(call)) }
                    real[methodName](real, unpack(args))
                end

                return real
            end

            if controlType == CT_LABEL then
                obj.__setFn = 'SetText'
            end

            setmetatable(obj, {
                __index = function(t, key)
                    if key == 'Create' then return nil end

                    return function(_, ...)
                        table.insert(t.__calls, { key, ... })
                        return t
                    end
                end
            })

            return obj
        end
    })

    function T:WithDefaults(defaults)
        local baseFactory = self
        local newFactory = {}
        setmetatable(newFactory, {
            __call = function(_, name, ...)
                local proxy = baseFactory(name, ...)
                for methodName, methodArgs in pairs(defaults) do
                    local callEntry = {methodName, unpack(methodArgs)}
                    table.insert(proxy.__calls, 1, callEntry)
                end
                return proxy
            end
        })
        return newFactory
    end

    return T
end

local Label = template(CT_LABEL)
local Texture = template(CT_LABEL)


local SCROLL_LIST_UNIFORM = 1
local SCROLL_LIST_NON_UNIFORM = 2
local SCROLL_LIST_OPERATIONS = 3
local NO_HEIGHT_SET = -1
local function UpdateModeFromHeight(self, height)
    if self.mode == SCROLL_LIST_UNIFORM then
        if self.uniformControlHeight == NO_HEIGHT_SET then
            self.uniformControlHeight = height
        elseif height ~= self.uniformControlHeight then
            self.uniformControlHeight = nil
            self.mode = SCROLL_LIST_NON_UNIFORM
            ZO_ScrollList_Commit(self)
        end
    end
end

local Table = class()

function Table:__init()
    self.__dataTypes = {}
    self.__headerDataType = nil
    self.__headerSpec = nil

    self.isCreated = false

    -- self.headerControls = {}

    self.sortingKey = nil
    self.sortingOrder = ZO_SORT_ORDER_UP
    self.sortingKeys = {}
end

function Table:AddDataType(dataTypeId, columns, height)
    assert(not self.__dataTypes[dataTypeId], 'Data type already added')

    self.__dataTypes[dataTypeId] = {
        columns = columns,
        height = height,
    }
end

function Table:AddHeader(dataTypeId, headerSpec, headerHeight)
    assert(self.__dataTypes[dataTypeId], 'Data type not added yet')

    self.__headerDataType = dataTypeId
    self.__headerSpec = headerSpec
    self.__headerHeight = headerHeight
end

function Table:Create(name, parent)
    assert(not self.isCreated, 'Table already created')

    local containerName = ('$(parent)%s'):format(name)
    local container = CreateControl(containerName, parent, CT_CONTROL)

    -- if no header set, it will be empty container, kinda meh
    -- but it simplifies things a bit, no infinite checks all around
    local header = CreateControl('$(parent)Header', container, CT_CONTROL)
    header:SetAnchor(TOPLEFT, container, TOPLEFT)
    header:SetAnchor(TOPRIGHT, container, TOPRIGHT)
    self.headerContainer = header

    local scroll = CreateControlFromVirtual('$(parent)ScrollList', container, 'ZO_ScrollList')
    scroll:SetAnchor(TOPLEFT, header, BOTTOMLEFT)
    scroll:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT)
    self.scroll = scroll

    for id = 1, #self.__dataTypes do
        self:__addDataType(id)
    end

    self.container = container

    local sortingIndicator = CreateControl('$(parent)SortingOrderIndicator', header, CT_TEXTURE)
    sortingIndicator:SetDimensions(16, 12)
    self.sortingIndicator = sortingIndicator

    if self.__headerSpec then
        self:__buildHeaders()
    end

    self.isCreated = true
    return container
end

function Table:Update(dataTypeId, data)
    assert(self.isCreated, 'Call Create() before Update()')
    assert(self.__dataTypes[dataTypeId], 'Unknown data type: ' .. dataTypeId)

    local dataList = ZO_ScrollList_GetDataList(self.scroll)
    ZO_ScrollList_Clear(self.scroll)

    for i = 1, #data do
        dataList[i] = ZO_ScrollList_CreateDataEntry(dataTypeId, data[i])
    end

    ZO_ScrollList_Commit(self.scroll)
end

function Table:__addDataType(dataTypeId)
    local scroll = self.scroll

    local dataTypeSpec = self.__dataTypes[dataTypeId]
    local columns, height = dataTypeSpec.columns, dataTypeSpec.height

    local factory = function(objectPool)
        local newRow = CreateControlFromVirtual(
            '$(parent)Row', scroll.contents, 'ZO_SelectableLabel',
            objectPool:GetNextControlId()
        )
        newRow:SetHeight(height)

        local previousColumn
        for _, column in ipairs(columns) do
            local newColumn = column:Create(newRow)
            local _, _, _, _, offsetX = newColumn:GetAnchor()
            newColumn:ClearAnchors()
            if previousColumn then
                newColumn:SetAnchor(LEFT, previousColumn, RIGHT, offsetX, 0)
            else
                newColumn:SetAnchor(LEFT, nil, nil, offsetX, 0)
            end
            previousColumn = newColumn
        end
        return newRow
    end

    local setupCallback = function(rowControl, dataEntryData, scrollList)
        for i, column in ipairs(columns) do
            local e = rowControl:GetNamedChild(column.__name)
            if e then
                local setFn = column.__setFn
                e[setFn](e, dataEntryData[i])
            end
        end
    end

    local pool = ZO_ObjectPool:New(factory, ZO_ObjectPool_DefaultResetControl)

    scroll.dataTypes[dataTypeId] = {
        height = height,
        setupCallback = setupCallback,
        hideCallback = nil,
        pool = pool,
        selectSound = nil,
        selectable = true,
    }

    UpdateModeFromHeight(scroll, height)
end

local function HeaderLabel_ColorText(label, over)
    local normalColor = label.defaultNormalColor or ZO_NORMAL_TEXT
    local highlightColor = label.defaultHighlightColor or ZO_HIGHLIGHT_TEXT

    if over then
        label:SetColor(highlightColor:UnpackRGBA())
    else
        label:SetColor(normalColor:UnpackRGBA())
    end

    -- else
    --     local disabledColor = label.defaultDisabledColor or ZO_DISABLED_TEXT
    --     label:SetColor(disabledColor:UnpackRGBA())
    -- end
end

function Table:__buildHeaders()
    local headerContainer = self.headerContainer

    local dataTypeSpec = self.__dataTypes[self.__headerDataType]
    local columns = dataTypeSpec.columns
    local headerSpec = self.__headerSpec

    -- local sortState = self.sortState[self.__headerDataType]

    self.headerControls = {}

    local previousHeader
    for i, column in ipairs(columns) do
        local columnSpec = headerSpec[i]
        local headerText = columnSpec[1]
        local overrides = columnSpec[2] or {}

        local headerColumnCtrl = column:Create(headerContainer)

        headerColumnCtrl:SetText(headerText)

        for methodName, args in pairs(overrides) do
            headerColumnCtrl[methodName](headerColumnCtrl, unpack(args))
        end

        local sortable = columnSpec.sortable

        headerColumnCtrl.dataTypeId = self.__headerDataType
        headerColumnCtrl.columnIndex = i
        headerColumnCtrl.table = self

        if sortable then
            self.sortingKeys[i] = columnSpec[3] or {}
            headerColumnCtrl:SetMouseEnabled(true)
            headerColumnCtrl:SetHandler('OnMouseDown', self.__onHeaderClick)
            headerColumnCtrl:SetHandler('OnMouseEnter', function() HeaderLabel_ColorText(headerColumnCtrl, true) end)
            headerColumnCtrl:SetHandler('OnMouseExit', function() HeaderLabel_ColorText(headerColumnCtrl, false) end)
        end

        local _, _, _, _, offsetX = headerColumnCtrl:GetAnchor()
        headerColumnCtrl:ClearAnchors()

        if previousHeader then
            headerColumnCtrl:SetAnchor(LEFT, previousHeader, RIGHT, offsetX, 0)
        else
            headerColumnCtrl:SetAnchor(LEFT, nil, nil, offsetX, 0)
        end

        previousHeader = headerColumnCtrl

        self.headerControls[i] = headerColumnCtrl
    end

    headerContainer:SetHeight(self.__headerHeight or dataTypeSpec.height)

    self:__updateSortingIndicator()
end

local IS_LESS_THAN = -1
local IS_EQUAL_TO = 0
local IS_GREATER_THAN = 1
local function SortingFunction(left, right, key, keys, order)
    local l, r = left[key], right[key]

    local compareResult
    if l < r then
        compareResult = IS_LESS_THAN
    elseif l > r then
        compareResult = IS_GREATER_THAN
    else
        compareResult = IS_EQUAL_TO
    end

    if compareResult == IS_EQUAL_TO then
        local tiebreaker = keys[key].tiebreaker

        if tiebreaker then
            return SortingFunction(left, right, tiebreaker, keys, keys[key].tiebreakerSortingOrder or order)
        end
    else
        if order == ZO_SORT_ORDER_UP then
            return compareResult == IS_LESS_THAN
        end

        return compareResult == IS_GREATER_THAN
    end

    return false
end

local function _getNextSortingOrder(currentSortingOrder)
    if currentSortingOrder == ZO_SORT_ORDER_UP then
        return ZO_SORT_ORDER_DOWN
    elseif currentSortingOrder == ZO_SORT_ORDER_DOWN then
        return
    elseif currentSortingOrder == nil then
        return ZO_SORT_ORDER_UP
    end
end

function Table.__onHeaderClick(headerCtrl)
    local self = headerCtrl.table
    local columnIndex = self.columnIndex

    if self.sortingKey == columnIndex then
        if self.defaultSortingKey then
            self.sortingOrder = _getNextSortingOrder(self.sortingOrder)
            if self.sortingOrder == nil then  -- TODO: probably move this guard after all checks?
                self.sortingKey = self.defaultSortingKey
                self.sortingOrder = self.defaultSortingOrder
            end
        else
            self.sortingOrder = not self.sortingOrder
        end
    else
        self.sortingOrder = ZO_SORT_ORDER_UP
        self.sortingKey = columnIndex
    end


    local scrollData = ZO_ScrollList_GetDataList(self.scroll)
    table.sort(scrollData, function(leftDataEntry, rightDataEntry)
        return SortingFunction(leftDataEntry.data, rightDataEntry.data, self.sortingKey, self.sortingKeys, self.sortingOrder)
    end)
    ZO_ScrollList_Commit(self.scroll)


    self:__updateSortingIndicator()
end

local ANCHORS_TABLE = {
    [TEXT_ALIGN_LEFT] = {
        [ZO_SORT_ORDER_UP]   = TOPLEFT,
        [ZO_SORT_ORDER_DOWN] = BOTTOMLEFT,
    },
    [TEXT_ALIGN_CENTER] = {
        [ZO_SORT_ORDER_UP]   = TOP,
        [ZO_SORT_ORDER_DOWN] = BOTTOM,
    },
    [TEXT_ALIGN_RIGHT] = {
        [ZO_SORT_ORDER_UP]   = TOPRIGHT,
        [ZO_SORT_ORDER_DOWN] = BOTTOMRIGHT,
    },
}

function Table:__updateSortingIndicator()
    if self.sortingKey then
        local c = self.headerControls[self.sortingKey]
        local sortingOrder = self.sortingOrder

        local offsetX, point, relativePoint, texture

        local hAlignment = c:GetHorizontalAlignment()
        if hAlignment == TEXT_ALIGN_CENTER then
            offsetX = 0
        elseif hAlignment == TEXT_ALIGN_LEFT then
            offsetX = c:GetTextWidth() / 2
        elseif hAlignment == TEXT_ALIGN_RIGHT then
            offsetX = -c:GetTextWidth() / 2
        end

        point = sortingOrder and BOTTOM or TOP
        relativePoint = ANCHORS_TABLE[hAlignment][sortingOrder]
        texture = sortingOrder and '/esoui/art/miscellaneous/list_sortup.dds' or '/esoui/art/miscellaneous/list_sortdown.dds'

        self.sortingIndicator:ClearAnchors()

        self.sortingIndicator:SetAnchor(point, c, relativePoint, offsetX, 0)
        self.sortingIndicator:SetTexture(texture)
        self.sortingIndicator:SetHidden(false)
    else
        self.sortingIndicator:SetHidden(true)
    end
end


addon.Table = Table
addon.Label = Label
addon.Texture = Texture

LibTableTools = addon

IMP_LibTableTools__class = nil
