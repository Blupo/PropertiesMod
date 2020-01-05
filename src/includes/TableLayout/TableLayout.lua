local FALLBACK_ROW_HEIGHT = 20
local FALLBACK_COLUMN_WIDTH = 35
local DEFAULT_SIZE_KEY = ":default"

local VERBOSE = false

local function out(...)
	if VERBOSE then print(...) end
end

local function getIndexOfValue(value, tab)
	for i = 1, #tab do
		local v = tab[i]
		
		if value == v then
			return i
		end
	end
end

local function purgeDuplicates(tab)
	if (#tab <= 1) then return end
	local x = 1
	
	repeat
		for i = #tab, x + 1, -1 do
			if (tab[i] == tab[x]) then
				out("Got duplicate "..tab[i].." at "..i)
				table.remove(tab, i)
			end
		end
		
		x = x + 1
	until (x >= #tab)
end

---

local TableLayout = {}

function TableLayout.new(initialConfig)
	out("Building TableLayout...")
	out(initialConfig and "Got initial configuration" or "No configuration provided")
	
	initialConfig = initialConfig or {}
		
	local self = {
		__rowMap = initialConfig.Rows or {},
		__columnMap = initialConfig.Columns or {},
		__sizeMap = {},
		__hiddenGroups = {
			Rows = {},
			Columns = {},
		},
		
		Rows = {},
		Columns = {},
		Cells = {},
	}
	setmetatable(self, {__index = TableLayout})
	
	-- if column is hidden, return 0
	self.__getColumnWidth = function(columnID)
		if self.__hiddenGroups.Columns[columnID] then return 0 end
		
		return self.__sizeMap.Columns[columnID] or self.__sizeMap.Columns[DEFAULT_SIZE_KEY]
	end
	
	-- if row is hidden return 0
	self.__getRowHeight = function(rowID)
		if self.__hiddenGroups.Rows[rowID] then return 0 end
		
		return self.__sizeMap.Rows[rowID] or self.__sizeMap.Rows[DEFAULT_SIZE_KEY]
	end
	
	self.__getCellSize = function(rowID, columnID)
		return UDim2.new(0, self.__getColumnWidth(columnID), 0, self.__getRowHeight(rowID))
	end
	
	self.__getCellPosition = function(rowID, columnID)
		local rowMap = self.__rowMap
		local columnMap = self.__columnMap
		local sizeMap = self.__sizeMap
		local hiddenGroups = self.__hiddenGroups
		
		local rowIndex = getIndexOfValue(rowID, rowMap)
		local columnIndex = getIndexOfValue(columnID, columnMap)
		if ((not rowIndex) or (not columnIndex)) then return UDim2.new() end
		
		local xPos, yPos = 0, 0
		
		for i = 1, rowIndex - 1 do
			local otherRowID = rowMap[i]
			local otherRowSize = self.__getRowHeight(otherRowID)
			
			yPos = yPos + otherRowSize
		end
		
		for i = 1, columnIndex - 1 do
			local otherColumnID = columnMap[i]
			local otherColumnSize = self.__getColumnWidth(otherColumnID)
			
			xPos = xPos + otherColumnSize
		end
		
		return UDim2.new(0, xPos, 0, yPos)
	end
	
	self.__createCell = function(rowID, columnID)
		local cell = Instance.new("Frame")
		cell.Name = rowID..":"..columnID
		cell.AnchorPoint = Vector2.new(0, 0)
		cell.Size = self.__getCellSize(rowID, columnID)
		cell.Position = self.__getCellPosition(rowID, columnID)
		
		local sizeChanged
		sizeChanged = cell:GetPropertyChangedSignal("Size"):Connect(function()
			if (not self.Cells[rowID..":"..columnID]) then sizeChanged:Disconnect() sizeChanged = nil return end
			local oldSize = cell.Size
			local properCellSize = self.__getCellSize(rowID, columnID)
			
			if (cell.Size ~= properCellSize) then
				cell.Size = properCellSize
				warn("Something attempted to set the size for cell "..rowID..":"..columnID..", to "..oldSize.."use the rows and columns to change the size of the cell")
			end
		end)
		
		local positionChanged
		positionChanged = cell:GetPropertyChangedSignal("Position"):Connect(function()
			if (not self.Cells[rowID..":"..columnID]) then positionChanged:Disconnect() positionChanged = nil return end
			local properCellPosition = self.__getCellPosition(rowID, columnID)
			
			if (cell.Position ~= properCellPosition) then
				cell.Position = properCellPosition
				warn("Something attempted to set the position for cell "..rowID..":"..columnID..", you shouldn't be doing this")
			end
		end)
		
		if self.__styleCallback then self.__styleCallback(cell) end
		
		self.Cells[rowID..":"..columnID] = cell
		out("Created cell with ID "..rowID..":"..columnID)
		
		return cell
	end
	
	self.__getSizeOfTable = function()
		local rowMap = self.__rowMap
		local columnMap = self.__columnMap
		
		local width, height = 0, 0
		
		for i = 1, #rowMap do
			local rowID = rowMap[i]
			
			height = height + self.__getRowHeight(rowID)
		end
		
		for i = 1, #columnMap do
			local columnID = columnMap[i]
			
			width = width + self.__getColumnWidth(columnID)
		end
		
		return Vector2.new(width, height)
	end
	
	-- validate row/column names
	out("Validaing row names")
	do
		purgeDuplicates(self.__rowMap)
		purgeDuplicates(self.__columnMap)
		
		for i = #self.__rowMap, 1, -1 do
			local rowID = self.__rowMap[i]
			
			if string.find(rowID, ":") then
				out("Unauthorised character in name "..rowID..", cannot contain :")
				out("Building stopped")
				return
			end
		end
		
		out("Validaing column names")
		for i = 1, #self.__columnMap do
			local columnID = self.__columnMap[i]
			
			if string.find(columnID, ":") then
				out("Unauthorised character in name "..columnID..", cannot contain :")
				out("Building stopped")
				return
			end
		end
		
		out("All names are valid, duplicate values were automatically purged")
	end
	
	-- build size map
	out("Building size map")
	do
		local sizeMap = self.__sizeMap
		
		local initialSizes = initialConfig.Sizes or {}
		local initialRowSizes = initialSizes.Rows or {}
		local initialColumnSizes = initialSizes.Columns or {}
		
		if (not initialRowSizes[DEFAULT_SIZE_KEY]) then
			out("No initial row size provided, using fallback")
			initialRowSizes[DEFAULT_SIZE_KEY] = FALLBACK_ROW_HEIGHT
		end
		
		if (not initialColumnSizes[DEFAULT_SIZE_KEY]) then
			out("No initial column size provided, using fallback")
			initialColumnSizes[DEFAULT_SIZE_KEY] = FALLBACK_COLUMN_WIDTH
		end 
		
		sizeMap.Rows = initialRowSizes
		sizeMap.Columns = initialColumnSizes
	end
	
	-- create UI
	out("Creating UI container")
	local uiRoot = Instance.new("Frame")
	self.UIRoot = uiRoot
	
	-- create cells
	out("Creating cells")
	for i = 1, #self.__rowMap do
		local rowID = self.__rowMap[i]
		
		for j = 1, #self.__columnMap do
			local columnID = self.__columnMap[j]
			
			local cell = self.__createCell(rowID, columnID)
			cell.Parent = uiRoot
		end
	end
	
	-- set table size
	local tableSize = self.__getSizeOfTable()
	uiRoot.Size = UDim2.new(0, tableSize.X, 0, tableSize.Y)
	
	-- build rows
	out("Building rows")
	for i = 1, #self.__rowMap do
		local rowID = self.__rowMap[i]
		local row = {}
		
		for cellName, cell in pairs(self.Cells) do
			local cellRowID, cellColumnID = string.match(cellName, "(.+):(.+)")
			
			if (cellRowID == rowID) then
				row[cellColumnID] = cell
			end
		end
		
		self.Rows[rowID] = row
	end
	
	-- build columns
	out("Building columns")
	for i = 1, #self.__columnMap do
		local columnID = self.__columnMap[i]
		local column = {}
		
		for cellName, cell in pairs(self.Cells) do
			local cellRowID, cellColumnID = string.match(cellName, "(.+):(.+)")
			
			if (cellColumnID == columnID) then
				column[cellRowID] = cell
			end
		end
		
		self.Columns[columnID] = column
	end
	
	out("Built TableLayout")
	return self
end

function TableLayout:Get(id)
	local rowID, columnID = string.match(id, "(.*):(.*)")
	rowID = (rowID ~= "") and rowID or nil
	columnID = (columnID ~= "") and columnID or nil
	
	if (rowID and columnID) then
		return self.Cells[id]
	elseif (rowID and (not columnID)) then
		return self.Rows[rowID]
	elseif ((not rowID) and columnID) then
		return self.Columns[columnID]
	end
end

function TableLayout:SetRowHeight(rowID, newHeight)
	local row = self.Rows[rowID]
	if (not row) then return self end
	
	local rows = self.Rows
	local rowSizeMap = self.__sizeMap.Rows
	local oldHeight = rowSizeMap[rowID] or rowSizeMap[DEFAULT_SIZE_KEY]
	local heightDelta = newHeight - oldHeight
	
	rowSizeMap[rowID] = newHeight
	
	for column, cell in pairs(row) do
		if (not self.__hiddenGroups.Columns[column]) then
			cell.Size = UDim2.new(0, cell.Size.X.Offset, 0, newHeight)
		end
	end
	
	do
		local rowNum = getIndexOfValue(rowID, self.__rowMap)
		
		for i = rowNum + 1, #self.__rowMap do
			local otherRow = self.Rows[self.__rowMap[i]]
			
			for _, cell in pairs(otherRow) do
				cell.Position = UDim2.new(0, cell.Position.X.Offset, 0, cell.Position.Y.Offset + heightDelta)
			end
		end
		
		local uiRoot = self.UIRoot
		uiRoot.Size = UDim2.new(0, uiRoot.Size.X.Offset, 0, uiRoot.Size.Y.Offset + heightDelta)
	end
	
	return self
end

function TableLayout:SetColumnWidth(columnID, newWidth)
	local column = self.Columns[columnID]
	if (not column) then return self end
	
	local columnSizeMap = self.__sizeMap.Columns
	local oldWidth = columnSizeMap[columnID] or columnSizeMap[DEFAULT_SIZE_KEY]
	local widthDelta = newWidth - oldWidth
	columnSizeMap[columnID] = newWidth
	
	for row, cell in pairs(column) do
		if (not self.__hiddenGroups.Rows[row]) then
			cell.Size = UDim2.new(0, newWidth, 0, cell.Size.Y.Offset)
		end
	end
	
	do
		local columnMap = self.__columnMap
		local columnNum = getIndexOfValue(columnID, columnMap)
		
		for i = columnNum + 1, #columnMap do
			local otherColumn = self.Columns[columnMap[i]]
			
			for _, cell in pairs(otherColumn) do
				cell.Position = UDim2.new(0, cell.Position.X.Offset + widthDelta, 0, cell.Position.Y.Offset)
			end
		end
	
		local uiRoot = self.UIRoot
		uiRoot.Size = UDim2.new(0, uiRoot.Size.X.Offset + widthDelta, 0, uiRoot.Size.Y.Offset)
	end
	
	return self
end

function TableLayout:AddRow(rowID, insertOptions)
	insertOptions = insertOptions or { direction = "after" }
	insertOptions.direction = insertOptions.direction or "after"
	
	local rowMap = self.__rowMap
	local columnMap = self.__columnMap
	local rowSizeMap = self.__sizeMap.Rows
	
	local rows = self.Rows
	local columns = self.Columns
	if rows[rowID] then warn("row "..rowID.." already exists") return self end
	if getIndexOfValue(rowID, rowMap) then warn("row "..rowID.." already exists") return self end
	
	local newRow = {}
	
	if insertOptions.anchorID then
		if (not rows[insertOptions.anchorID]) then
			insertOptions.anchorID = nil
		end
	end
	insertOptions.anchorID = insertOptions.anchorID or rowMap[#rowMap]
	
	local anchorIndex = getIndexOfValue(insertOptions.anchorID, rowMap)
	if (not anchorIndex) then
		insertOptions.direction = "after"
		anchorIndex = 0
	end
	
	if insertOptions.size then rowSizeMap[rowID] = insertOptions.size end
	
	local insertIndex = (insertOptions.direction == "after") and anchorIndex + 1 or anchorIndex
	table.insert(rowMap, insertIndex, rowID)
	
	-- build cells
	for i = 1, #columnMap do
		local columnID = columnMap[i]
		
		local cell = self.__createCell(rowID, columnID)
		
		newRow[columnID] = cell
		columns[columnID][rowID] = cell
		
		cell.Parent = self.UIRoot
	end
	
	-- reposition rows
	do
		local heightDelta = insertOptions.size or rowSizeMap[DEFAULT_SIZE_KEY]
		
		for i = insertIndex + 1, #rowMap do
			local otherRow = rows[rowMap[i]]
			
			for _, cell in pairs(otherRow) do
				cell.Position = UDim2.new(0, cell.Position.X.Offset, 0, cell.Position.Y.Offset + heightDelta)
			end
		end
	
		local uiRoot = self.UIRoot
		uiRoot.Size = UDim2.new(0, uiRoot.Size.X.Offset, 0, uiRoot.Size.Y.Offset + heightDelta)
	end
	
	rows[rowID] = newRow
	return self
end

function TableLayout:AddColumn(columnID, insertOptions)
	insertOptions = insertOptions or { direction = "after" }
	insertOptions.direction = insertOptions.direction or "after"
	
	local rowMap = self.__rowMap
	local columnMap = self.__columnMap
	local columnSizeMap = self.__sizeMap.Columns
	
	local rows = self.Rows
	local columns = self.Columns
	if columns[columnID] then warn("column "..columnID.." already exists") return self end
	if getIndexOfValue(columnID, columnMap) then warn("column "..columnID.." already exists") return self end
	
	local newColumn = {}
	
	if insertOptions.anchorID then
		if (not columns[insertOptions.anchorID]) then
			insertOptions.anchorID = nil
		end
	end
	insertOptions.anchorID = insertOptions.anchorID or columnMap[#columnMap]
	
	local anchorIndex = getIndexOfValue(insertOptions.anchorID, columnMap)
	if (not anchorIndex) then
		insertOptions.direction = "after"
		anchorIndex = 0
	end
	
	if insertOptions.size then columnSizeMap[columnID] = insertOptions.size end
	
	local insertIndex = (insertOptions.direction == "after") and anchorIndex + 1 or anchorIndex
	table.insert(columnMap, insertIndex, columnID)
	
	-- build cells
	for i = 1, #rowMap do
		local rowID = rowMap[i]
		
		local cell = self.__createCell(rowID, columnID)
		
		newColumn[rowID] = cell
		rows[rowID][columnID] = cell
		
		cell.Parent = self.UIRoot
	end
	
	-- reposition columns
	do
		local widthDelta = insertOptions.size or columnSizeMap[DEFAULT_SIZE_KEY]
		
		for i = insertIndex + 1, #columnMap do
			local otherColumn = columns[columnMap[i]]
			
			for _, cell in pairs(otherColumn) do
				cell.Position = UDim2.new(0, cell.Position.X.Offset + widthDelta, 0, cell.Position.Y.Offset)
			end
		end
	
		local uiRoot = self.UIRoot
		uiRoot.Size = UDim2.new(0, uiRoot.Size.X.Offset + widthDelta, 0, uiRoot.Size.Y.Offset)
	end
	
	columns[columnID] = newColumn
	return self
end

function TableLayout:RemoveRow(rowID)
	local rowMap = self.__rowMap
	local rowSizeMap = self.__sizeMap.Rows
	local rows = self.Rows
	local cells = self.Cells
	
	local rowIndex = getIndexOfValue(rowID, rowMap)
	if (not rowIndex) then warn("row "..rowID.." does not exist") return self end
	
	local rowHeight = rowSizeMap[rowID] or rowSizeMap[DEFAULT_SIZE_KEY]
	
	table.remove(rowMap, rowIndex)
	rowSizeMap[rowID] = nil
	
	-- destroy cells
	do
		local row = rows[rowID]
		
		for columnID, cell in pairs(row) do
			cells[rowID..":"..columnID] = nil
			cell:Destroy()
		end
		
		rows[rowID] = nil
	end
	
	-- reposition rows
	do
		for i = rowIndex, #rowMap do
			local otherRow = rows[rowMap[i]]
			
			for _, cell in pairs(otherRow) do
				cell.Position = UDim2.new(0, cell.Position.X.Offset, 0, cell.Position.Y.Offset - rowHeight)
			end
		end
	
		local uiRoot = self.UIRoot
		uiRoot.Size = UDim2.new(0, uiRoot.Size.X.Offset, 0, uiRoot.Size.Y.Offset - rowHeight)
	end
	
	return self
end

function TableLayout:RemoveColumn(columnID)
	local columnMap = self.__columnMap
	local columnSizeMap = self.__sizeMap.Columns
	local columns = self.Columns
	local cells = self.Cells
	
	local columnIndex = getIndexOfValue(columnID, columnMap)
	if (not columnIndex) then warn("column "..columnID.." does not exist") return self end
	
	local columnWidth = columnSizeMap[columnID] or columnSizeMap[DEFAULT_SIZE_KEY]
	
	table.remove(columnMap, columnIndex)
	columnSizeMap[columnID] = nil
	
	-- destroy cells
	do
		local column = columns[columnID]
		
		for rowID, cell in pairs(column) do
			cells[rowID..":"..columnID] = nil
			cell:Destroy()
		end
		
		columns[columnID] = nil
	end
	
	-- reposition columns
	do
		for i = columnIndex, #columnMap do
			local otherColumn = columns[columnMap[i]]
			
			for _, cell in pairs(otherColumn) do
				cell.Position = UDim2.new(0, cell.Position.X.Offset - columnWidth, 0, cell.Position.Y.Offset)
			end
		end
	
		local uiRoot = self.UIRoot
		uiRoot.Size = UDim2.new(0, uiRoot.Size.X.Offset - columnWidth, 0, uiRoot.Size.Y.Offset)
	end
	
	return self
end

function TableLayout:Toggle(groupID)
	local rowID, columnID = string.match(groupID, "(.*):(.*)")
	rowID = (rowID ~= "") and rowID or nil
	columnID = (columnID ~= "") and columnID or nil
	
	local rows = self.Rows
	local columns = self.Columns
	local sizeMap = self.__sizeMap
	local hiddenGroups = self.__hiddenGroups
	
	if (rowID and columnID) then
		warn("You can only toggle rows and columns, not cells")
	elseif (rowID and (not columnID)) then
		if (not rows[rowID]) then warn("row "..rowID.." does not exist") return self end
		hiddenGroups.Rows[rowID] = not hiddenGroups.Rows[rowID] 
		
		local row = rows[rowID]
		local rowMap = self.__rowMap
		
		local rowIndex = getIndexOfValue(rowID, rowMap)
		local rowHeight = sizeMap.Rows[rowID] or sizeMap.Rows[DEFAULT_SIZE_KEY]
		
		-- toggle row
		for _, cell in pairs(row) do
			cell.Visible = not hiddenGroups.Rows[rowID]
		end
		
		-- reposition rows
		do
			for i = rowIndex + 1, #rowMap do
				local otherRow = rows[rowMap[i]]
				
				for columnID, cell in pairs(otherRow) do
					cell.Position = UDim2.new(0, cell.Position.X.Offset, 0, cell.Position.Y.Offset - (hiddenGroups.Rows[rowID] and rowHeight or -rowHeight))
				end
			end
		
			local uiRoot = self.UIRoot
			uiRoot.Size = UDim2.new(0, uiRoot.Size.X.Offset, 0, uiRoot.Size.Y.Offset - (hiddenGroups.Rows[rowID] and rowHeight or -rowHeight))
		end
	elseif ((not rowID) and columnID) then
		if (not columns[columnID]) then warn("column "..columnID.." does not exist") return self end
		hiddenGroups.Columns[columnID] = not hiddenGroups.Columns[columnID]
		
		local column = columns[columnID]
		local columnMap = self.__columnMap
		
		local columnIndex = getIndexOfValue(columnID, columnMap)
		local columnWidth = sizeMap.Columns[columnID] or sizeMap.Columns[DEFAULT_SIZE_KEY]
		
		-- toggle column
		for _, cell in pairs(column) do
			cell.Visible = not hiddenGroups.Columns[columnID]
		end
		
		-- reposition columns
		do
			for i = columnIndex + 1, #columnMap do
				local otherColumn = columns[columnMap[i]]
				
				for rowID, cell in pairs(otherColumn) do
					cell.Position = UDim2.new(0, cell.Position.X.Offset - (hiddenGroups.Columns[columnID] and columnWidth or -columnWidth), 0, cell.Position.Y.Offset)
				end
			end
		
			local uiRoot = self.UIRoot
			uiRoot.Size = UDim2.new(0, uiRoot.Size.X.Offset - (hiddenGroups.Columns[columnID] and columnWidth or -columnWidth), 0, uiRoot.Size.Y.Offset)
		end
	else
		warn("You must provide a row or column to toggle")
	end
	
	return self
end

function TableLayout:SetVisible(groupID, visible)
	local rowID, columnID = string.match(groupID, "(.*):(.*)")
	rowID = (rowID ~= "") and rowID or nil
	columnID = (columnID ~= "") and columnID or nil
	
	local rows = self.Rows
	local columns = self.Columns
	local sizeMap = self.__sizeMap
	local hiddenGroups = self.__hiddenGroups
	
	if (rowID and columnID) then
		warn("You can only toggle rows and columns, not cells")
	elseif (rowID and (not columnID)) then
		if (not rows[rowID]) then warn("row "..rowID.." does not exist") return self end
		if (hiddenGroups.Rows[rowID] == (not visible)) then return self end
		hiddenGroups.Rows[rowID] = not visible
		
		local row = rows[rowID]
		local rowMap = self.__rowMap
		
		local rowIndex = getIndexOfValue(rowID, rowMap)
		local rowHeight = sizeMap.Rows[rowID] or sizeMap.Rows[DEFAULT_SIZE_KEY]
		
		-- toggle row
		for _, cell in pairs(row) do
			cell.Visible = visible
		end
		
		-- reposition rows
		do
			for i = rowIndex + 1, #rowMap do
				local otherRow = rows[rowMap[i]]
				
				for columnID, cell in pairs(otherRow) do
					cell.Position = UDim2.new(0, cell.Position.X.Offset, 0, cell.Position.Y.Offset - (hiddenGroups.Rows[rowID] and rowHeight or -rowHeight))
				end
			end
		
			local uiRoot = self.UIRoot
			uiRoot.Size = UDim2.new(0, uiRoot.Size.X.Offset, 0, uiRoot.Size.Y.Offset - (hiddenGroups.Rows[rowID] and rowHeight or -rowHeight))
		end
	elseif ((not rowID) and columnID) then
		if (not columns[columnID]) then warn("column "..columnID.." does not exist") return self end
		if (hiddenGroups.Columns[columnID] == (not visible)) then return self end
		hiddenGroups.Columns[columnID] = not visible
		
		local column = columns[columnID]
		local columnMap = self.__columnMap
		
		local columnIndex = getIndexOfValue(columnID, columnMap)
		local columnWidth = sizeMap.Columns[columnID] or sizeMap.Columns[DEFAULT_SIZE_KEY]
		
		-- toggle column
		for _, cell in pairs(column) do
			cell.Visible = visible
		end
		
		-- reposition columns
		do
			for i = columnIndex + 1, #columnMap do
				local otherColumn = columns[columnMap[i]]
				
				for rowID, cell in pairs(otherColumn) do
					cell.Position = UDim2.new(0, cell.Position.X.Offset - (hiddenGroups.Columns[columnID] and columnWidth or -columnWidth), 0, cell.Position.Y.Offset)
				end
			end
		
			local uiRoot = self.UIRoot
			uiRoot.Size = UDim2.new(0, uiRoot.Size.X.Offset - (hiddenGroups.Columns[columnID] and columnWidth or -columnWidth), 0, uiRoot.Size.Y.Offset)
		end
	else
		warn("You must provide a row or column to toggle")
	end
	
	return self
end

function TableLayout:SetStyleCallback(callback)
	self.__styleCallback = callback
end

function TableLayout:SortRows(callback)
	table.sort(self.__rowMap, callback)
	
	local rows = self.Rows
	
	for rowID, cells in pairs(rows) do
		for columnID, cell in pairs(cells) do
			cell.Position = self.__getCellPosition(rowID, columnID)
		end
	end
end

function TableLayout:GetSize()
	return self.__getSizeOfTable()
end

function TableLayout:Rebuild()
	-- this operation is expensive
	warn("This operation is not supported")
	
	local uiRoot = self.UIRoot
	
	local rowMap = self.__rowMap
	local columnMap = self.__columnMap
	
	local sizeMap = self.__sizeMap
	local rowSizeMap = sizeMap.Rows
	local columnSizeMap = sizeMap.Columns
	
	local cells = self.Cells
	local rows = self.Rows
	local columns = self.Columns
	
	self.__hiddenGroups = { Rows = {}, Columns = {} }
	cells, rows, columns = {}, {}, {}
	uiRoot:ClearAllChildren()
	
	out("Rebuilding TableLayout")
	
	-- create cells
	out("Creating cells")
	for i = 1, #rowMap do
		local rowID = rowMap[i]
		
		for j = 1, #columnMap do
			local columnID = columnMap[j]
			
			local cell = self.__createCell(rowID, columnID)
			cell.Parent = uiRoot
		end
	end
	
	-- set table size
	uiRoot.Size = self.__getSizeOfTable()
	
	-- build rows
	out("Building rows")
	for i = 1, #rowMap do
		local rowID = rowMap[i]
		local row = {}
		
		for cellName, cell in pairs(self.Cells) do
			local cellRowID, cellColumnID = string.match(cellName, "(.+):(.+)")
			
			if (cellRowID == rowID) then
				row[cellColumnID] = cell
			end
		end
		
		rows[rowID] = row
	end
	
	-- build columns
	out("Building columns")
	for i = 1, #columnMap do
		local columnID = columnMap[i]
		local column = {}
		
		for cellName, cell in pairs(self.Cells) do
			local cellRowID, cellColumnID = string.match(cellName, "(.+):(.+)")
			
			if (cellColumnID == columnID) then
				column[cellRowID] = cell
			end
		end
		
		columns[columnID] = column
	end
	
	out("Rebuilt TableLayout")
	return self
end

function TableLayout:Destroy()
	self.UIRoot:Destroy()
	self = nil
	
	return nil
end

return TableLayout