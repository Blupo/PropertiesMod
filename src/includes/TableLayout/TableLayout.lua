local DEFAULT_SIZE_KEY = ":DEFAULT"

---

local function purgeDuplicates(tab)
	if (#tab <= 1) then return end
	local x = 1
	
	repeat
		for i = #tab, x + 1, -1 do
			if (tab[i] == tab[x]) then
				table.remove(tab, i)
			end
		end
		
		x = x + 1
	until (x >= #tab)
end

local function purgeWithCondition(tab, callback)
	for i = #tab, 1, -1 do
		if (not callback(tab[i])) then
			table.remove(tab, i)
		end
	end
end

local function getIndexOfValue(value, tab)
	for i = 1, #tab do
		local v = tab[i]
		
		if value == v then
			return i
		end
	end
end

local function isValidID(id)
	-- CANNOT by empty
	-- CANNOT contain :
	-- CANNOT be all whitespace
	
	if string.len(id) < 1 then warn("TableLayout: ID \""..id.."\" is invalid because it is empty") return false end
	
	local rmWhitespace = string.gsub(id, "%s+", "")
	if string.len(rmWhitespace) < 1 then warn("TableLayout: ID \""..id.."\" is invalid because it only consists of whitespace") return false end
	
	if string.match(id, ":") then warn("TableLayout: ID \""..id.."\" is invalid because it contains :") return false end
	
	return true
end

---

local rowLayoutTemplate = Instance.new("UIListLayout")
rowLayoutTemplate.Name = ":ULL"
rowLayoutTemplate.SortOrder = Enum.SortOrder.LayoutOrder
rowLayoutTemplate.FillDirection = Enum.FillDirection.Vertical
rowLayoutTemplate.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayoutTemplate.VerticalAlignment = Enum.VerticalAlignment.Top

local columnLayoutTemplate = rowLayoutTemplate:Clone()
columnLayoutTemplate.FillDirection = Enum.FillDirection.Horizontal
columnLayoutTemplate.HorizontalAlignment = Enum.HorizontalAlignment.Left

---

local TableLayout = {}

function TableLayout.new(initialConfig)
	initialConfig = initialConfig or {}
	
	local self = {
		__layoutMap = {
			Rows = initialConfig.Rows or {},
			Columns = initialConfig.Columns or {}
		},
		
		__visibilityMap = {
			Rows = {},
			Columns = {}
		},
		
		-- sizeMap gets populated later in the init process
		__sizeMap = {},
		__rowContainers = {},
		
		Rows = {},
		Columns = {},
		Cells = {}
	}
	setmetatable(self, {__index = TableLayout})
	
	self.__getRowHeight = function(rowID)
		local sizeMap = self.__sizeMap
		
		return sizeMap.Rows[rowID] or sizeMap.Rows[DEFAULT_SIZE_KEY]
	end
	
	self.__getColumnWidth = function(columnID)
		local sizeMap = self.__sizeMap
		
		return sizeMap.Columns[columnID] or sizeMap.Columns[DEFAULT_SIZE_KEY]
	end
	
	self.__getCellSize = function(rowID, columnID)
		local sizeMap = self.__sizeMap
		
		local width = self.__getColumnWidth(columnID)
		local height = self.__getRowHeight(rowID)
		
		return UDim2.new(0, width, 0, height)
	end
	
	self.__getTableSize = function()
		local rowMap = self.__layoutMap.Rows
		local columnMap = self.__layoutMap.Columns
		
		local rowVisibilityMap = self.__visibilityMap.Rows
		local columnVisibilityMap = self.__visibilityMap.Columns
		
		local width, height = 0, 0
		
		for i = 1, #rowMap do
			local rowID = rowMap[i]
			
			if rowVisibilityMap[rowID] then
				height = height + self.__getRowHeight(rowID)
			end
		end
		
		for i = 1, #columnMap do
			local columnID = columnMap[i]
			
			if columnVisibilityMap[columnID] then
				width = width + self.__getColumnWidth(columnID)
			end
		end
		
		return Vector2.new(width, height)
	end
	
	self.__updateTableSize = function()
		local uiRoot = self.UIRoot
		local tableSize = self.__getTableSize()
		
		uiRoot.Size = UDim2.new(0, tableSize.X, 0, tableSize.Y)
	end
	
	self.__createCell = function(rowID, columnID)
		local cell = Instance.new("Frame")
		cell.Name = rowID..":"..columnID
		cell.AnchorPoint = Vector2.new(0, 0)
		cell.Size = self.__getCellSize(rowID, columnID)
		
		local sizeChanged
		sizeChanged = cell:GetPropertyChangedSignal("Size"):Connect(function()
			if (not self.Cells[rowID..":"..columnID]) then sizeChanged:Disconnect() sizeChanged = nil return end
			local oldSize = cell.Size
			local properCellSize = self.__getCellSize(rowID, columnID)
			
			if (cell.Size ~= properCellSize) then
				cell.Size = properCellSize
				warn("Something attempted to set the size for cell "..rowID..":"..columnID..", to "..tostring(oldSize).." use the rows and columns to change the size of the cell")
			end
		end)
		
		if self.__styleCallback then self.__styleCallback(cell) end
		
		self.Cells[rowID..":"..columnID] = cell
		return cell
	end
	
	self.__createRow = function(id, insertIndex)
		if (not isValidID(id)) then return end
		
		local rowMap = self.__layoutMap.Rows
		local columnMap = self.__layoutMap.Columns
		
		local rows = self.Rows
		local columns = self.Columns
		
		local rowSizeMap = self.__sizeMap.Rows
		local rowContainers = self.__rowContainers
		
		table.insert(rowMap, insertIndex, id)
		
		-- build UI
		local newRow = {}
		local newRowContainerUI = Instance.new("Frame")
		local columnLayout = columnLayoutTemplate:Clone()
		
		for i = 1, #columnMap do
			local columnID = columnMap[i]		
			
			local newCellUI = self.__createCell(id, columnID)
			newCellUI.LayoutOrder = i
			
			columns[columnID][id] = newCellUI
			newRow[columnID] = newCellUI
			newCellUI.Parent = newRowContainerUI
		end
		
		newRowContainerUI.Name = id
		newRowContainerUI.LayoutOrder = insertIndex
		newRowContainerUI.Size = UDim2.new(1, 0, 0, self.__getRowHeight(id))
		newRowContainerUI.BackgroundTransparency = 1
		newRowContainerUI.BorderSizePixel = 0
		
		rowContainers[id] = newRowContainerUI
		rows[id] = newRow
		columnLayout.Parent = newRowContainerUI
		
		-- shift the other rows
		for i = insertIndex + 1, #rowMap do
			local rowID = rowMap[i]
			
			local rowContainer = rowContainers[rowID]
			rowContainer.LayoutOrder = rowContainer.LayoutOrder + 1
		end
		
		newRowContainerUI.Parent = self.UIRoot
		
		self.__updateTableSize()
		return newRow
	end
	
	self.__createColumn = function(id, insertIndex)
		if (not isValidID(id)) then return end
		
		local rowMap = self.__layoutMap.Rows
		local columnMap = self.__layoutMap.Columns
		
		local rows = self.Rows
		local columns = self.Columns
		
		local columnSizeMap = self.__sizeMap.Columns
		local rowContainers = self.__rowContainers
		
		table.insert(columnMap, insertIndex, id)
		
		-- build UI
		local newColumn = {}
		
		for i = 1, #rowMap do
			local rowID = rowMap[i]
			local rowContainer = rowContainers[rowID]
			
			local newCellUI = self.__createCell(rowID, id)
			newCellUI.LayoutOrder = insertIndex
			
			rows[rowID][id] = newCellUI
			newColumn[rowID] = newCellUI
			newCellUI.Parent = rowContainer
		end
		
		columns[id] = newColumn
		
		-- shift the other columns
		for i = insertIndex + 1, #columnMap do			
			local columnID = columnMap[i]
			local column = columns[columnID]
			
			for _, cell in pairs(column) do
				cell.LayoutOrder = cell.LayoutOrder + 1
			end
		end
		
		self.__updateTableSize()
		return newColumn
	end
	
	-- build layout and visibility maps
	do
		local rowMap = self.__layoutMap.Rows
		local columnMap = self.__layoutMap.Columns
		
		local rowVisibilityMap = self.__visibilityMap.Rows
		local columnVisibilityMap = self.__visibilityMap.Columns
		
		purgeDuplicates(rowMap)
		purgeDuplicates(columnMap)
		
		-- validate names
		purgeWithCondition(rowMap, isValidID)
		purgeWithCondition(columnMap, isValidID)
		
		for i = 1, #rowMap do
			rowVisibilityMap[rowMap[i]] = true
		end
		
		for i = 1, #columnMap do
			columnVisibilityMap[columnMap[i]] = true
		end
	end
	
	-- build size map
	do
		local sizeMap = self.__sizeMap
		
		local initialSizes = initialConfig.Sizes or {}
		local initialRowSizes = initialSizes.Rows or {}
		local initialColumnSizes = initialSizes.Columns or {}
		
		if (not initialRowSizes[DEFAULT_SIZE_KEY]) then
			initialRowSizes[DEFAULT_SIZE_KEY] = 0
		end
		
		if (not initialColumnSizes[DEFAULT_SIZE_KEY]) then
			initialColumnSizes[DEFAULT_SIZE_KEY] = 0
		end 
		
		sizeMap.Rows = initialRowSizes
		sizeMap.Columns = initialColumnSizes
	end
	
	-- create UI
	local uiRoot = Instance.new("Frame")
	self.UIRoot = uiRoot

	local rowLayout = rowLayoutTemplate:Clone()
	
	-- build UI
	do
		local rowMap = self.__layoutMap.Rows
		local columnMap = self.__layoutMap.Columns
		
		local rows = self.Rows
		local columns = self.Columns
		
		local rowContainers = self.__rowContainers

		-- populate column map		
		for i = 1, #columnMap do
			local columnID = columnMap[i]
			local newColumn = {}
			
			columns[columnID] = newColumn
		end
		
		for i = 1, #rowMap do
			local rowID = rowMap[i]
			
			local newRow = {}
			local newRowContainerUI = Instance.new("Frame")
			local columnLayout = columnLayoutTemplate:Clone()
			
			for i = 1, #columnMap do
				local columnID = columnMap[i]		
				
				local newCellUI = self.__createCell(rowID, columnID)
				newCellUI.LayoutOrder = i
				
				columns[columnID][rowID] = newCellUI
				newRow[columnID] = newCellUI
				newCellUI.Parent = newRowContainerUI
			end
			
			newRowContainerUI.Name = rowID
			newRowContainerUI.LayoutOrder = i
			newRowContainerUI.Size = UDim2.new(1, 0, 0, self.__getRowHeight(rowID))
			newRowContainerUI.BackgroundTransparency = 1
			newRowContainerUI.BorderSizePixel = 0
			
			rowContainers[rowID] = newRowContainerUI
			rows[rowID] = newRow
			columnLayout.Parent = newRowContainerUI
			newRowContainerUI.Parent = self.UIRoot
		end
	end
	
	rowLayout.Parent = uiRoot
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

function TableLayout:SetGroupSize(groupID, size)
	
end

function TableLayout:SetRowHeight(rowID, height)
	local row = self.Rows[rowID]
	if (not row) then warn("TableLayout: Cannot resize row "..rowID.." because it does not exist") return self end
	
	local rowSizeMap = self.__sizeMap.Rows
	rowSizeMap[rowID] = height
	
	local rowContainer = self.__rowContainers[rowID]
	if (not rowContainer) then warn("TableLayout: UI container for row "..rowID.." does not exist, you may need to rebuild the TableLayout") return self end
	
	rowContainer.Size = UDim2.new(1, 0, 0, height)
	
	for _, cell in pairs(row) do
		cell.Size = UDim2.new(0, cell.Size.X.Offset, 0, height)
	end
	
	self.__updateTableSize()
	return self
end

function TableLayout:SetColumnWidth(columnID, width)
	local column = self.Columns[columnID]
	if (not column) then warn("TableLayout: Cannot resize column "..columnID.." because it does not exist") return self end
	
	local columnSizeMap = self.__sizeMap.Columns
	columnSizeMap[columnID] = width
	
	for _, cell in pairs(column) do
		cell.Size = UDim2.new(0, width, 0, cell.Size.Y.Offset)
	end
	
	self.__updateTableSize()
	return self
end

function TableLayout:AddRow(rowID, insertOptions)
	if (not isValidID(rowID)) then return end
	
	insertOptions = insertOptions or { direction = "after" }
	insertOptions.direction = insertOptions.direction or "after"
	
	local rowMap = self.__layoutMap.Rows
	local rowSizeMap = self.__sizeMap.Rows
	local rowVisibilityMap = self.__visibilityMap.Rows
	
	local rows = self.Rows
	local columns = self.Columns
	if getIndexOfValue(rowID, rowMap) then warn("TableLayout: Cannot add row "..rowID.." because it already exists") return self end
	
	if insertOptions.size then rowSizeMap[rowID] = insertOptions.size end
	
	-- figure out where to put it
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
	
	local insertIndex = (insertOptions.direction == "after") and anchorIndex + 1 or anchorIndex
	
	rowVisibilityMap[rowID] = true
	
	return self.__createRow(rowID, insertIndex)
end

function TableLayout:AddColumn(columnID, insertOptions)
	if (not isValidID(columnID)) then return end
	
	insertOptions = insertOptions or { direction = "after" }
	insertOptions.direction = insertOptions.direction or "after"
	
	local columnMap = self.__layoutMap.Columns
	local columnSizeMap = self.__sizeMap.Columns
	local columnVisibilityMap = self.__visibilityMap.Columns
	
	local rows = self.Rows
	local columns = self.Columns
	if getIndexOfValue(columnID, columnMap) then warn("TableLayout: Cannot add column "..columnID.." because it already exists") return self end
	
	if insertOptions.size then columnSizeMap[columnID] = insertOptions.size end
	
	-- figure out where to put it
	if insertOptions.anchorID then
		if (not rows[insertOptions.anchorID]) then
			insertOptions.anchorID = nil
		end
	end
	insertOptions.anchorID = insertOptions.anchorID or columnMap[#columnMap]
	
	local anchorIndex = getIndexOfValue(insertOptions.anchorID, columnMap)
	if (not anchorIndex) then
		insertOptions.direction = "after"
		anchorIndex = 0
	end
	
	local insertIndex = (insertOptions.direction == "after") and anchorIndex + 1 or anchorIndex
	
	columnVisibilityMap[columnID] = true
	
	return self.__createColumn(columnID, insertIndex)
end

function TableLayout:RemoveRow(rowID)
	local rowMap = self.__layoutMap.Rows
	local rowSizeMap = self.__sizeMap.Rows
	local rowVisibilityMap = self.__visibilityMap.Rows
	local rowContainers = self.__rowContainers
	local rows = self.Rows
	local cells = self.Cells
	
	if (not getIndexOfValue(rowID, rowMap)) then
		warn("TableLayout: Cannot remove row "..rowID.." because it does not exist")
		return self
	end
	local rowIndex = getIndexOfValue(rowID, rowMap)
	
	-- destroy stuff
	for columnID, cell in pairs(rows[rowID]) do
		cells[rowID..":"..columnID] = nil
		cell:Destroy()
	end
	
	rowContainers[rowID]:Destroy()
	
	-- shift the other rows
	for i = rowIndex + 1, #rowMap do
		local rowID = rowMap[i]
		
		local rowContainer = rowContainers[rowID]
		rowContainer.LayoutOrder = rowContainer.LayoutOrder - 1
	end
	
	rows[rowID] = nil
	rowSizeMap[rowID] = nil
	rowVisibilityMap[rowID] = nil
	rowContainers[rowID] = nil
	table.remove(rowMap, getIndexOfValue(rowID, rowMap))
	
	self.__updateTableSize()
	
	return self
end

function TableLayout:RemoveColumn(columnID)
	local columnMap = self.__layoutMap.Columns
	local columnSizeMap = self.__sizeMap.Columns
	local columnVisibilityMap = self.__visibilityMap.Columns
	local columns = self.Columns
	local cells = self.Cells
	
	if (not getIndexOfValue(columnID, columnMap)) then
		warn("TableLayout: Cannot remove column "..columnID.." because it does not exist")
		return self
	end
	local columnIndex = getIndexOfValue(columnID, columnMap)
	
	-- destroy stuff
	for rowID, cell in pairs(columns[columnID]) do
		cells[rowID..":"..columnID] = nil
		cell:Destroy()
	end
	
	-- shift the other columns
	for i = columnIndex + 1, #columnMap do
		local columnID = columnMap[i]
		
		for _, cell in pairs(columns[columnID]) do
			cell.LayoutOrder = cell.LayoutOrder - 1
		end
	end
	
	columns[columnID] = nil
	columnSizeMap[columnID] = nil
	columnVisibilityMap[columnID] = nil
	table.remove(columnMap, getIndexOfValue(columnID, columnMap))
	
	self.__updateTableSize()
	
	return self
end

function TableLayout:SetVisible(groupID, visibility)
	local rowID, columnID = string.match(groupID, "(.*):(.*)")
	rowID = (rowID ~= "") and rowID or nil
	columnID = (columnID ~= "") and columnID or nil
	
	local rows = self.Rows
	local columns = self.Columns
	
	local rowVisibilityMap = self.__visibilityMap.Rows
	local columnVisibilityMap = self.__visibilityMap.Columns

	local rowContainers = self.__rowContainers
	
	if (rowID and columnID) then
		warn("TableLayout: You can only set the visiblity of rows and columns, not cells")
		return self
	elseif (rowID and (not columnID)) then
		if (not rows[rowID]) then
			warn("TableLayout: Cannot set the visibility of row "..rowID.." because it does not exist")
			return self
		end
		
		rowVisibilityMap[rowID] = visibility
		rowContainers[rowID].Visible = visibility
	elseif ((not rowID) and columnID) then
		if (not columns[columnID]) then
			warn("TableLayout: Cannot set the visibility of column "..columnID.." because it does not exist")
			return self
		end
		
		columnVisibilityMap[columnID] = visibility
		for _, cell in pairs(columns[columnID]) do
			cell.Visible = visibility
		end
	end
	
	self.__updateTableSize()
	
	return self
end

function TableLayout:SortRows(callback)
	local rowMap = self.__layoutMap.Rows
	table.sort(rowMap, callback)
	
	for i = 1, #rowMap do
		local rowID = rowMap[i]
		local rowContainer = self.__rowContainers[rowID]
		
		rowContainer.LayoutOrder = i
	end
	
	return self
end

function TableLayout:SortColumns(callback)
	local columnMap = self.__layoutMap.Columns
	table.sort(columnMap, callback)
	
	for i = 1, #columnMap do
		local columnID = columnMap[i]
		local column = self.Columns[columnID]
		
		for _, cell in pairs(column) do
			cell.LayoutOrder = i
		end
	end
	
	return self
end

function TableLayout:GetSize()
	return self.__getTableSize()
end

function TableLayout:SetStyleCallback(callback)
	self.__styleCallback = callback
	
	return self
end

function TableLayout:Rebuild()
	warn("TableLayout: Rebuild has not been implemented")
	
	return self
end

function TableLayout:Destroy()
	self.UIRoot:Destroy()
	setmetatable(self, nil)
	self = nil
	
	return nil
end

return TableLayout