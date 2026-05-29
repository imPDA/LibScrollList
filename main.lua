local class = IMP_LibTableTools__class

-- ----------------------------------------------------------------------------

local addon = {}

-- ----------------------------------------------------------------------------

local function template(controlType, headerControlType)
    local T = {}

    setmetatable(T, {
        __call = function(_, name, width, offsetX, ...)
            local obj = {}

            local extra = {...}

            obj.__type = controlType
            obj.__name = name
            obj.__width = width
            obj.__offsetX = offsetX
            obj.__calls = {}

            function obj:Create(parent)
                local real = self:__createFn(parent)

                real:SetAnchor(LEFT, parent, LEFT, offsetX)

                for _, call in ipairs(self.__calls) do
                    local methodName = call[1]
                    local args = { select(2, unpack(call)) }
                    real[methodName](real, unpack(args))
                end

                return real
            end

            function obj:CreateHeader(parent)
                if self.__createFnH then
                    local real = self:__createFnH(parent)

                    real:SetAnchor(LEFT, parent, LEFT, offsetX)

                    for _, call in ipairs(self.__calls) do
                        local methodName = call[1]
                        local args = { select(2, unpack(call)) }
                        real[methodName](real, unpack(args))
                    end

                    return real
                else
                    return self:Create(parent)
                end
            end

            function obj:Set(ctrl, ...)
                self.__setFn(ctrl, ...)
            end

            function obj:SetHeader(ctrl, ...)
                if self.__setFnH then
                    self.__setFnH(ctrl, ...)
                else
                    self:Set(ctrl, ...)
                end
            end

            if controlType == CT_LABEL then
                obj.__createFn = function(self_, parent)
                    local c = CreateControl(('$(parent)%s'):format(self_.__name), parent, self_.__type)
                    c:SetWidth(self_.__width)
                    return c
                end
                obj.__setFn = function(ctrl, ...) ctrl:SetText(...) end
            elseif controlType == CT_TEXTURE then
                obj.__createFn = function(self_, parent)
                    local c = CreateControl(('$(parent)%s'):format(self_.__name), parent, CT_CONTROL)
                    c:SetWidth(self_.__width)
                    local c_ = CreateControl('$(parent)Icon', c, self_.__type)
                    c_:SetDimensions(extra[1], extra[2])
                    c_:SetAnchor(CENTER)
                    return c
                end
                obj.__setFn = function(ctrl, ...) ctrl:GetNamedChild('Icon'):SetTexture(...) end
            end

            -- TODO: DRY
            if headerControlType == CT_LABEL then
                obj.__createFnH = function(self_, parent)
                    local c = CreateControl(('$(parent)%s'):format(self_.__name), parent, headerControlType)
                    c:SetWidth(self_.__width)
                    return c
                end
                obj.__setFnH = function(ctrl, ...) ctrl:SetText(...) end
            elseif headerControlType == CT_TEXTURE then
                obj.__createFnH = function(self_, parent)
                    local c = CreateControl(('$(parent)%s'):format(self_.__name), parent, CT_CONTROL)
                    c:SetWidth(self_.__width)
                    local c_ = CreateControl('$(parent)Icon', c, headerControlType)
                    c_:SetDimensions(extra[1], extra[2])
                    c_:SetAnchor(CENTER)
                    return c
                end
                obj.__setFnH = function(ctrl, ...) ctrl:GetNamedChild('Icon'):SetTexture(...) end
            end

            -- TODO: refactor
            local WHITELIST = {
                Create = true,
                CreateHeader = true,
                Set = true,
                SetHeader = true,
                __setFn = true,  -- ?
                __setFnH = true,  -- ?
                __createFn = true,  -- ?
                __createFnH = true,  -- ?
            }

            setmetatable(obj, {
                __index = function(t, key)
                    if WHITELIST[key] then return nil end

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
local Texture = template(CT_TEXTURE)
local TextureWithTextHeader = template(CT_TEXTURE, CT_LABEL)


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

    self.headerControls = {}

    self.sortCriteria = {}
    self.defaultSortingCriteria = {{columnIndex = 1, order = ZO_SORT_ORDER_UP}}  -- TODO: allow custom default sort ccriteria
end

function Table:AddDataType(dataTypeId, columns, height, postCreateCallback, postSetupCallback)
    assert(not self.__dataTypes[dataTypeId], 'Data type already added')

    self.__dataTypes[dataTypeId] = {
        columns = columns,
        height = height,
        postCreate = postCreateCallback,
        postSetup = postSetupCallback,
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

    self:__doSorting()

    ZO_ScrollList_Commit(self.scroll)
end

function Table:__addDataType(dataTypeId)
    local scroll = self.scroll

    local dataTypeSpec = self.__dataTypes[dataTypeId]
    local columns, height = dataTypeSpec.columns, dataTypeSpec.height

    local postCreate = self.__dataTypes[dataTypeId].postCreate
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

        if postCreate then
            postCreate(newRow)
        end

        return newRow
    end

    local postSetup = self.__dataTypes[dataTypeId].postSetup
    local setupCallback = function(rowControl, dataEntryData, scrollList)
        for i, column in ipairs(columns) do
            local e = rowControl:GetNamedChild(column.__name)
            if e then
                column:Set(e, dataEntryData[i])
            end
        end

        if postSetup then
            postSetup(rowControl, dataEntryData, scrollList)
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

local SORT_INDICATOR_HEIGHT = 12
local SORT_INDICATOR_WIDTH = 16
function Table:__buildHeaders()
    local headerContainer = self.headerContainer

    local dataTypeSpec = self.__dataTypes[self.__headerDataType]
    local columns = dataTypeSpec.columns
    local headerSpec = self.__headerSpec

    ZO_ClearTable(self.headerControls)  -- TODO: zo clear numerically indexed table?

    local previousHeader
    for i, column in ipairs(columns) do
        local columnSpec = headerSpec[i]
        local headerText = columnSpec[1]
        local overrides = columnSpec[2] or {}

        local headerColumnCtrl = column:CreateHeader(headerContainer)

        -- TODO: header text is bad naming, it can be texture as well
        -- headerColumnCtrl[column.__setFn](headerColumnCtrl, headerText)
        column:SetHeader(headerColumnCtrl, headerText)

        for methodName, args in pairs(overrides) do
            headerColumnCtrl[methodName](headerColumnCtrl, unpack(args))
        end

        local sortable = columnSpec.sortable

        headerColumnCtrl.dataTypeId = self.__headerDataType
        headerColumnCtrl.columnIndex = i
        headerColumnCtrl.table = self

        if sortable then
            headerColumnCtrl:SetMouseEnabled(true)
            headerColumnCtrl:SetHandler('OnMouseDown', self.__onHeaderClick)
            headerColumnCtrl:SetHandler('OnMouseEnter', function() HeaderLabel_ColorText(headerColumnCtrl, true) end)
            headerColumnCtrl:SetHandler('OnMouseExit', function() HeaderLabel_ColorText(headerColumnCtrl, false) end)

            local sortingIndicator = CreateControl('$(parent)SortingIndicator', headerColumnCtrl, CT_CONTROL)  -- TODO: virtual control
            sortingIndicator:SetResizeToFitDescendents(true)
            sortingIndicator:SetDimensionConstraints(0, 0, 0, SORT_INDICATOR_HEIGHT)

            local sortingLabel = CreateControl('$(parent)Label', sortingIndicator, CT_LABEL)
            sortingLabel:SetAnchor(LEFT)
            sortingLabel:SetFont('ZoFontWinH5')
            sortingLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

            local sortingIcon = CreateControl('$(parent)Icon', sortingIndicator, CT_TEXTURE)
            sortingIcon:SetDimensions(SORT_INDICATOR_WIDTH, SORT_INDICATOR_HEIGHT)
            sortingIcon:SetAnchor(LEFT, sortingLabel, RIGHT)

            -- TODO: is acces by attribute like heacderControl.sortingIndicator is fater than GetNamedChild?
            self:__updateSortingIndicator(headerColumnCtrl)
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

    local headerHeight = self.__headerHeight or dataTypeSpec.height
    if true then  -- if there are sortable coulmns
        headerHeight = headerHeight + SORT_INDICATOR_HEIGHT * 2
    end
    headerContainer:SetDimensionConstraints(0, headerHeight, 0, 0)
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

local function MultiSortCompare(left, right, criteria)
    for _, crit in ipairs(criteria) do
        local col = crit.columnIndex
        local l = left[col]
        local r = right[col]
        if l < r then
            return crit.order == ZO_SORT_ORDER_UP
        elseif l > r then
            return crit.order == ZO_SORT_ORDER_DOWN
        end
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
    local columnIndex = headerCtrl.columnIndex

    local existingIndex = nil
    for i, criterium in ipairs(self.sortCriteria) do
        if criterium.columnIndex == columnIndex then
            existingIndex = i
            break
        end
    end

    if existingIndex then
        local criterium = self.sortCriteria[existingIndex]
        local nextOrder = _getNextSortingOrder(criterium.order)
        if nextOrder ~= nil then
            criterium.order = nextOrder
        else
            table.remove(self.sortCriteria, existingIndex)

            for i, criterium_ in ipairs(self.sortCriteria) do
                local columnIndex_ = criterium_.columnIndex
                local headerControl = self.headerControls[columnIndex_]
                headerControl:GetNamedChild('SortingIndicatorLabel'):SetText(i)
            end

        end
    else
        table.insert(self.sortCriteria, {columnIndex = columnIndex, order = ZO_SORT_ORDER_UP})
    end

    self:__doSorting()

    self:__updateSortingIndicator(headerCtrl)
end

function Table:__doSorting()
    if #self.sortCriteria > 0 then
        local scrollData = ZO_ScrollList_GetDataList(self.scroll)
        table.sort(scrollData, function(left, right)
            return MultiSortCompare(left.data, right.data, self.sortCriteria)
        end)
        ZO_ScrollList_Commit(self.scroll)
    elseif self.defaultSortingCriteria then
        local scrollData = ZO_ScrollList_GetDataList(self.scroll)
        table.sort(scrollData, function(left, right)
            return MultiSortCompare(left.data, right.data, self.defaultSortingCriteria)
        end)
        ZO_ScrollList_Commit(self.scroll)
    end
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

function Table:__updateSortingIndicator(c)
    local sortingIndicator = c:GetNamedChild('SortingIndicator')
    local columnIndex = c.columnIndex

    local existingIndex = nil
    for i, criterium in ipairs(self.sortCriteria) do
        if criterium.columnIndex == columnIndex then
            existingIndex = i
            break
        end
    end

    if not existingIndex then
        sortingIndicator:SetHidden(true)
        return
    end

    local sortingOrder = self.sortCriteria[existingIndex].order

    local offsetX, point, relativePoint, texture

    local hAlignment = c:GetHorizontalAlignment()
    if hAlignment == TEXT_ALIGN_CENTER then
        offsetX = 0
    elseif hAlignment == TEXT_ALIGN_LEFT then
        offsetX = c:GetTextWidth() / 2
    elseif hAlignment == TEXT_ALIGN_RIGHT then
        offsetX = -c:GetTextWidth() / 2
    end

    if sortingOrder == ZO_SORT_ORDER_UP then
        point = BOTTOM
        texture = '/esoui/art/miscellaneous/list_sortup.dds'
    else  -- nil handled above
        point = TOP
        texture = '/esoui/art/miscellaneous/list_sortdown.dds'
    end
    relativePoint = ANCHORS_TABLE[hAlignment][sortingOrder]

    sortingIndicator:ClearAnchors()
    sortingIndicator:SetAnchor(point, c, relativePoint, offsetX, 0)

    sortingIndicator:GetNamedChild('Icon'):SetTexture(texture)
    sortingIndicator:GetNamedChild('Label'):SetText(existingIndex)
    sortingIndicator:SetHidden(false)
end

function Table:ResizeToFitNRows(dataTypeId, num)
    self.container:SetHeight(num * self.__dataTypes[dataTypeId].height + self.headerContainer:GetHeight())
end


addon.Table = Table
addon.Label = Label
addon.Texture = Texture
addon.TextureWithTextHeader = TextureWithTextHeader

LibTableTools = addon

IMP_LibTableTools__class = nil
