# LibScrollList

A Lua library for creating feature-rich scrollable lists (tables) in The Elder Scrolls Online UI.  
Built on top of the game’s `ZO_ScrollList` control, it offers a column‑oriented data display with configurable cell types (text, textures, buttons), sortable headers, and support for multiple data type templates.

## Installation

Copy `LibScrollList.lua` into your addon’s directory and make sure it is loaded before your own code.  

In your addon manifest (`*.txt`) add:

```
## DependsOn: LibScrollList>=2
```
> You may want to change `2` to the last version available at the time you read this.

The library will expose a global table `LibScrollList`.

## Quick Start

Please refer to [example](./example.lua).

## API Reference

### I. Utility

#### `LibScrollList.combine(base, overrides)`

Performs a deep merge of two tables.  
Nested tables are merged recursively; non‑table values from `overrides` simply overwrite those in `base`.

*Returns* a new table containing the merged result.

### II. Cell Types

Cell types define how a single cell in a row is created and how its value is set.  
Every cell type accepts a **style** table in its constructor that allows full customisation of the underlying UI control (see [Style Format](#style-format)).

#### 1. `Label`

Displays text.

```lua
local lbl = LibScrollList.Label(style, setFn)
```

- `style` (*table*) – style table applied when the control is created.  
- `setFn` (*function(ctrl, value)*) – function called to set the cell’s value; defaults to `ctrl:SetText(value)`.

**Methods**
> Do not use them, they are for internal use only!

- `lbl:Create(name, parent, width)`  
  Creates a `CT_LABEL` control, applies the style, and sets its width.  
  *Returns* the newly created control.

- `lbl:Set(ctrl, value)`  
  Sets the cell’s value using the stored `setFn`.

#### 2. `Texture`

Displays an image (texture).

```lua
local tex = LibScrollList.Texture(style, setFn)
```

- `style` – style applied to an inner `CT_TEXTURE` control.  
- `setFn` – defaults to `ctrl:SetTexture(value)`.

**Methods**
> Do not use them, they are for internal use only!

- `tex:Create(name, parent, width)`  
  Creates a container control with a centered `CT_TEXTURE` child named `Icon`.  
  *Returns* the container.

- `tex:Set(ctrl, value)`  
  Sets the texture path on the inner `Icon` control.

#### 3. `Button`

Creates a clickable button inside a cell.

```lua
local btn = LibScrollList.Button(style, setFn, callback)
```

- `style` – applied to an inner `CT_BUTTON` control.  
- `setFn` – defaults to `ctrl:SetState(newState, locked)`.  
- `callback` (*function()*) – called when the button is clicked (`OnMouseDown`).

**Methods**
> Do not use them, they are for internal use only!

- `btn:Create(name, parent, width)`  
  Creates a container with a centered `CT_BUTTON` named `Button`. If a `callback` was provided, the button will be mouse‑enabled and call it on click.  
  *Returns* the container.

- `btn:Set(ctrl, newState, locked)`  
  Sets the button state (e.g. `BSTATE_NORMAL`, `BSTATE_PRESSED`, etc.).

### III. Column

A column definition ties a cell type to header appearance, sorting, and layout properties.

```lua
local col = LibScrollList.Column(name, width, offsetX, cell,
                                      headerText, header, sortable)
```

- `name` (*string*) – unique name used for the cell’s child control (e.g. `"Name"`).  
- `width` (*number*) – column width in pixels.  
- `offsetX` (*number*) – horizontal spacing added between the previous column’s right edge and this column’s left edge. For the first column, it acts as a left margin.  
- `cell` (*Label | Texture | Button*) – the cell type instance that will render data for this column.  
- `headerText` (*string*, optional) – initial text/value for the header cell. Defaults to `""`.  
- `header` (*cell type instance*, optional) – if the header should use a different cell type than `cell`. Defaults to `nil` (uses `cell`).  
- `sortable` (*boolean*) – whether clicking the header toggles sorting for this column.

**Methods**
> Do not use them, they are for internal use only!

- `col:CreateCell(parent)`  
  Creates and returns the cell control for a data row.

- `col:CreateHeader(parent)`  
  Creates the header cell control, sets its initial value from `headerText`, and returns it.

- `col:Set(ctrl, value)`  
  Sets the value of a data row cell.

- `col:SetHeader(ctrl, value)`  
  Sets the value of a header cell.

Here’s the updated **Table** section, now including the `ClearSorting` method. The rest of the documentation remains unchanged.

### IV. ScrollList / Table
> `Table` is a leftover after initial development cycle, after name change, alias `ScrollList` was added. You can see both versions in my code and they can be used equally, but `Table` can be deprecated in the future, so `ScrollList` is preferrable!

The main list control that manages the scroll area, headers, and data.

```lua
local tbl = LibScrollList.ScrollList(withHeaders)
```

- `withHeaders` (*boolean*) – if `true`, a header row is created above the scroll list.

**Methods**

#### `tbl:AddDataType(dataTypeId, columns, height, postCreateCallback, postSetupCallback)`

Registers a data type (template) for the table.  
You can add multiple data types, each with its own columns and row height.  
When calling `Update`, you specify which data type to use.
> Currently, usage of multiple data types is not fully tested and most likely does not work as expected, as there not much use cases for this. If multiple data type use the same layout, I am pretty sure it will work well, but different layouts can be more challenging.

- `dataTypeId` (*number*) – unique identifier for this data type.  
- `columns` (*{Column}*) – array of `Column` objects, in visual order.  
- `height` (*number*) – base row height for this data type.  
- `postCreateCallback(rowControl)` – called once after a row control is created from the object pool.  
- `postSetupCallback(rowControl, dataEntryData, scrollList)` – called each time a row is populated with data.  
  - `rowControl` – the row container control.  
  - `dataEntryData` – the array of data values for this row (same order as `columns`).  
  - `scrollList` – the underlying `ZO_ScrollList` control.

#### `tbl:Create(name, parent, replace)`

Builds all UI controls (header, scroll list, columns).  
Must be called **after** all data types have been added.

- `name` (*string*) – name of the container control (will be `parentName`).  
- `parent` (*control*) – parent control to attach to.  
- `replace` (*boolean*, optional) – if `true`, looks for an existing child named `name` inside `parent` and re‑uses it instead of creating a new one. Useful for re‑initialising a pre‑built control.  

*Returns* the container control.

#### `tbl:Update(dataTypeId, data)`

Clears the current list and populates it with new data.

- `dataTypeId` (*number*) – which data type template to use (must have been added with `AddDataType`).  
- `data` (*{{...}}*) – array of rows. Each row is an array of values, one per column, in the same order as the `columns` table.

Sorting is automatically applied after the data is loaded.

#### `tbl:ResizeToFitNRows(dataTypeId, num)`

Resizes the whole table container so that exactly `num` rows (plus the header) are visible.

- `dataTypeId` – the data type whose row height is used.  
- `num` (*number*) – desired number of visible rows.

#### `tbl:SetDefaultSortingCriteria(criteria ...)`

Sets the initial sorting order used when no user sort is active.  
Accepts a variable number of arguments in pairs: column index followed by sort order.

- **Arguments** – an even number of values, alternating `columnIndex` (number) and `order` (`ZO_SORT_ORDER_UP` or `ZO_SORT_ORDER_DOWN`).

**Example**  
```lua
tbl:SetDefaultSortingCriteria(2, ZO_SORT_ORDER_UP, 1, ZO_SORT_ORDER_DOWN)
-- Sort first by column 2 ascending, then column 1 descending.
```

To disable default sorting, call with no arguments: `tbl:SetDefaultSortingCriteria()`.

#### `tbl:SetMulticolumnSortingEnabled(enabled)`

Enables or disables multi‑column sorting mode.

- `enabled` (*boolean*) – if `true`, clicking additional sortable headers adds them as secondary sort keys. If `false`, only one column can be the sort key at a time (default).

#### `tbl:SetHeadersHidden(hidden)`

Shows or hides the entire header row.

- `hidden` (*boolean*) – `true` to hide the headers, `false` to show them.

Use this to temporarily remove the header without recreating the table, even when `withHeaders` was `true` during construction.

#### `tbl:ClearSorting()`

Removes all active user‑applied sorting criteria. The table will revert to the default sorting order (as defined by `SetDefaultSortingCriteria`), or to no sorting if no defaults are set.

This is equivalent to clicking each active sort header until sorting is removed, but performed programmatically. After calling this method, the sort indicators are updated and the list is re‑sorted.

## Sorting Behavior

- Click a sortable header once to sort ascending, twice to sort descending, a third time to remove sorting from that column.  
- When multi‑column sorting is enabled (`SetMulticolumnSortingEnabled(true)`), additional clicks on other headers add them as secondary keys, with an index number shown next to the sort arrow.  
- The initial sorting order (applied when `Update` is called or the table is first displayed) can be defined with `SetDefaultSortingCriteria`.  
> `nil` values always sort **after** non‑nil values, regardless of the sort direction. 
- Use `ClearSorting()` to reset all user sorting and restore the default state.

## Sorting

- Click a sortable header once to sort ascending, twice to sort descending, a third time to remove sorting from that column.  
- By default, only one column can be the sort key. To enable multi‑column sorting, set `tbl.multicolumnSort = true`. Additional clicks on other headers will add them as secondary keys, with an index number shown next to the sort arrow.  
- The initial sorting order (when the table is first shown) can be changed via `tbl.defaultSortingCriteria`.  
> `nil` values always sort **after** non‑nil values, regardless of the sort direction.

## Style Format

When creating a cell type (`Label`, `Texture`, `Button`), the `style` argument is a table that is applied to the newly created control using the internal `__applyStyle` function. The table can contain:

- **String keys** – method names to call on the control. The value must be a table of arguments.
  ```lua
  {SetColor = {ZO_HIGHLIGHT_TEXT:UnpackRGBA()}}
  ```

- **Numeric keys** – each entry is a table with a special structure for setting handlers.  
  The first element is the handler method (e.g. `"SetHandler"`), followed by the handler name and callback.
  ```lua
  {[1] = {"SetHandler", "OnMouseEnter", function(self) ... end}}
  ```
  *(This is automatically created for buttons that have a click callback.)*

- **Function keys** – the key itself is a function `f(ctrl, ...)`. The value is an argument table. This is useful for complex initialisation not covered by simple method calls.

Example style for a `Label`:
```lua
LibScrollList.Label({
    SetFont = {"ZoFontGame"},
    SetColor = {1, 0.8, 0.2, 1},
})
```

## Advanced Notes

- The library internally uses `ZO_ScrollList` and its object pool system. Row controls are recycled automatically.  
- If rows of the same data type end up having different heights (via `postSetup` dynamic changes), the list switches to **non‑uniform** mode, which may have a performance impact.  
- The header controls are built from the columns of the **first** data type only (dataTypeId = 1). This limitation may be lifted in a future version.

---

*For further examples and integration details, see the source code and the ESO UI documentation on `ZO_ScrollList`.*