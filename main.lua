local class = IMP_LibTableTools__class

-- ----------------------------------------------------------------------------

local addon = {}

-- ----------------------------------------------------------------------------

local function template(controlType)
    local T = {}

    setmetatable(T, {
        __call = function(_, name, width, offsetX, header)
            local obj = {}
            -- obj.__extra = {...}
            obj.__type = controlType
            obj.__name = name
            obj.__width = width
            obj.__offsetX = offsetX
            obj.__header = header
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

function Table:__init(columns, rowHeight)
    self.__columns = columns
    self.__rowHeight = rowHeight
end

function Table:Update(data)
    local dataList = ZO_ScrollList_GetDataList(self.scroll)
	ZO_ScrollList_Clear(self.scroll)

    for i = 1, #data do
        dataList[i] = ZO_ScrollList_CreateDataEntry(1, data[i])
    end

    ZO_ScrollList_Commit(self.scroll)
end

function Table:__call(name, parent)
    local containerFullName = ('$(parent)%s'):format(name)
    local container = CreateControl(containerFullName, parent, CT_CONTROL)

    local headerFullName = ('$(parent)%s'):format('Header')
    local headers = CreateControl(headerFullName, container, CT_CONTROL)
    headers:SetAnchor(TOPLEFT, container, TOPLEFT)
    headers:SetAnchor(BOTTOMRIGHT, container, TOPRIGHT, 0, self.__rowHeight)

    local scroll = CreateControlFromVirtual('$(parent)ScrollList', container, 'ZO_ScrollList')
    scroll:SetAnchor(TOPLEFT, headers, BOTTOMLEFT)
    scroll:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT)

	local TYPE_ID = 1  -- TODO: multiple types - for future me
	local height = self.__rowHeight

    -- TODO: for the future me as well
	local hideCallback = nil
	local dataTypeSelectSound = nil
	local resetControlCallback = nil

    assert(not scroll.dataTypes[TYPE_ID], 'Data type already registered to scroll list')

    local previousHeader
    for _, column in ipairs(self.__columns) do
        -- local newHeader = CreateControl(('$(parent)'):format(column.__name), headers, column.__type)
        local newHeader = column:Create(headers)

        local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY, anchorConstrains = newHeader:GetAnchor()
        newHeader:ClearAnchors()

        if previousHeader then
            newHeader:SetAnchor(LEFT, previousHeader, RIGHT, offsetX, 0)
        else
            newHeader:SetAnchor(LEFT, nil, nil, offsetX, 0)
        end
        previousHeader = newHeader

        local setFn = column.__setFn
        newHeader[setFn](newHeader, column.__header[1])
        newHeader:SetFont(column.__header[2])
        newHeader:SetColor(unpack(column.__header[3]))
    end

    local function factoryFunction(objectPool)
        local newRow = CreateControlFromVirtual(name, scroll.contents, 'ZO_SelectableLabel', objectPool:GetNextControlId())
        assert(newRow)

        newRow:SetHeight(height)

        local previousColumn
        for _, column in ipairs(self.__columns) do
            local newColumn = column:Create(newRow)

            local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY, anchorConstrains = newColumn:GetAnchor()
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

    local function setupCallback(rowControl, dataEntryData, scrollList)
        for i, column in ipairs(self.__columns) do
            local setFn = column.__setFn

            local e = rowControl:GetNamedChild(column.__name)
            e[setFn](e, dataEntryData[i])
        end
    end

    local pool = ZO_ObjectPool:New(factoryFunction, resetControlCallback or ZO_ObjectPool_DefaultResetControl)
    scroll.dataTypes[TYPE_ID] = {
        height = height,
        setupCallback = setupCallback,
        hideCallback = hideCallback,
        pool = pool,
        selectSound = dataTypeSelectSound,
        selectable = true,
    }

    UpdateModeFromHeight(scroll, height)

    self.container = container
    self.headers = headers
    self.scroll = scroll

    return container
end

-- ----------------------------------------------------------------------------

-- function addon:Initialize()
--     self.Label = Label
--     self.Texture = Texture

--     self.Table = Table

--     LibTableTools = self
-- end

-- -- ----------------------------------------------------------------------------

-- local function OnAddonLoaded(_, addonName)
--     if addonName ~= addon.name then return end
--     EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED)

--     addon:Initialize()
-- end


-- EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddonLoaded)

addon.Table = Table
addon.Label = Label
addon.Texture = Texture

LibTableTools = addon

IMP_LibTableTools__class = nil
