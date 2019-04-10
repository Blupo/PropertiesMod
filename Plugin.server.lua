local RunService = game:GetService("RunService")

if (not RunService:IsStudio()) then warn("PropertiesMod only works in Studio") return end
if RunService:IsRunMode() then warn("PropertiesMod only works in Edit mode") return end

---

local root = script.Parent
local includes = root:WaitForChild("includes")

local API = require(includes:WaitForChild("RobloxAPI"):WaitForChild("API"))
local TableLayout = require(includes:WaitForChild("TableLayout"):WaitForChild("TableLayout"))

local PROPERTY_NAME_ROW_HEIGHT = 26
local PROPERTY_EDITOR_COLUMN_WIDTH = 150
local PROPNAME_TEXTSIZE = 14
local PROPNAME_FONT = Enum.Font.SourceSans

---

local Selection = game:GetService("Selection")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

---

-- SelectionChanged that doesn't spam that much
-- https://devforum.roblox.com/t/weird-selectionchanged-behavior/22024/2
-- Credit to Fractality

local SelectionChanged
do
	local selectionChanged = Instance.new("BindableEvent")
	local d0, d1 = true, true
	
	RunService.Heartbeat:Connect(function()
		d0, d1 = true, true
	end)
	
	Selection.SelectionChanged:Connect(function()
		if d0 then
			d0 = false
			selectionChanged:Fire()
		elseif d1 then
			d1 = false
			RunService.Heartbeat:Wait()
			selectionChanged:Fire()
		end
	end)
	
	SelectionChanged = selectionChanged.Event
end

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

---

local editors = {}
local editorFilters = {}

local categoryContainers = {}
local nameColumnWidth = 0
local editorColumnWidth = 0

local widgetInfo = {
	WIDGET_ID = "PropertiesMod",
	WIDGET_DEFAULT_TITLE = "Properties",
	WIDGET_PLUGINGUI_INFO = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 268, 400, 270, 250)
}

local toolbar = plugin:CreateToolbar("PropertiesMod")
local configButton = toolbar:CreateButton("Settings", "Configure PropertiesMod and its editors", "")

local StudioAPI = API.new()
local APIData = StudioAPI.Data
local APILib = StudioAPI.Library
local APIOperator = StudioAPI.Operator

APIData:RemoveInaccessibleMembers()
APIData:RemoveDeprecatedMembers()

local function getEditor(class, property)
	if editorFilters[class.."."..property] then
		return editorFilters[class.."."..property]
	else
		
	end
end

--- LOAD EDITORS

local v = require(3049494603) -- semver module

local defaultEditorFolder = root:WaitForChild("default_editors")

local function loadEditorFromFolder(folder)
	local editorinfoFile = folder:WaitForChild("editorinfo.lua", 5)
	if (not editorinfoFile) then warn(folder.Name .. " is missing its editorinfo file, could not be loaded") return end
	
	local editorinfo = require(editorinfoFile)
	if (type(editorinfo) ~= "table") then warn("required the entry point file for "..folder.Name.." but it wasn't a table") return end
	
	local uniqueId = editorinfo.unique_id
	local version = editorinfo.version
	local entryPoint = editorinfo.entry_point or "main.lua"
	
	if (not uniqueId) then warn("unknown ID for editor, debug ID for container is "..folder:GetDebugId()) return end
	if (not version) then warn("unknown version for editor "..uniqueId) return end
--	if (not entryPoint) then warn("entry point was not declared for editor "..uniqueId..", defaulting to main.lua") end
	
	local entryPointFile = folder:WaitForChild(entryPoint, 5)
	if (not entryPointFile) then warn("could not find the entry point file for editor "..uniqueId..", tried looking for "..entryPoint.." but it was not found") return end
	if (not entryPointFile:IsA("ModuleScript")) then warn("found the entry point file for "..uniqueId.." but it wasn't a ModuleScript") return end
	
	local editorConstructor = require(entryPointFile)
	if (type(editorConstructor) ~= "function") then warn("required the entry point file for "..uniqueId.." but it wasn't a function") return end
	
	---
	
	local success, version = pcall(v, version)
	if (not success) then warn("could not serialise version for editor "..uniqueId.." version given was "..tostring(version)) return end
	
	if editors[uniqueId] then
		local loadedEditorVersion = v(editors[uniqueId].info.version)
		
		if loadedEditorVersion > version then
			warn("a more recent version of "..uniqueId.." is already loaded, keeping version "..tostring(loadedEditorVersion))
			return
		else
			warn("a more recent version of "..uniqueId.." has been detected, overwriting version "..tostring(loadedEditorVersion))
		end
	end
	
	local filters = editorinfo.filters
	
	editorinfo.unique_id = nil -- redundancy
	
	editors[uniqueId] = {
		info = editorinfo,
		constructor = editorConstructor
	}
	
	print("loaded editor "..uniqueId.." version "..tostring(version))
end

for _, editor in pairs(defaultEditorFolder:GetChildren()) do
	loadEditorFromFolder(editor)
end

--- LOAD EXTENSIONS

local defaultExtensionFolder = root:WaitForChild("default_extensions")

local function loadExtension(module)
	local extension = require(module)
	
	local apiExtensions = extension.API
	local behaviourExtensions = extension.Behaviours
	
	APIData:Extend(apiExtensions or {})
	APIOperator:ExtendCustomBehaviours(behaviourExtensions or {})
end

for _, extension in pairs(defaultExtensionFolder:GetChildren()) do
	loadExtension(extension)
end

--- WIDGET

local widget = plugin:CreateDockWidgetPluginGui(widgetInfo.WIDGET_ID, widgetInfo.WIDGET_PLUGINGUI_INFO)
widget.Archivable = false
widget.Name = widgetInfo.WIDGET_ID
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
widget.Title = widgetInfo.WIDGET_DEFAULT_TITLE

local propertiesListScrollingFrame = Instance.new("ScrollingFrame")
propertiesListScrollingFrame.Name = "PropertiesListContainer"
propertiesListScrollingFrame.AnchorPoint = Vector2.new(0.5, 0.5)
propertiesListScrollingFrame.Size = UDim2.new(1, 0, 1, -2)
propertiesListScrollingFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
propertiesListScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
propertiesListScrollingFrame.CanvasPosition = Vector2.new(0, 0)
propertiesListScrollingFrame.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
propertiesListScrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
propertiesListScrollingFrame.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
propertiesListScrollingFrame.TopImage = "rbxassetid://2060768460"
propertiesListScrollingFrame.MidImage = "rbxassetid://2060767807"
propertiesListScrollingFrame.BottomImage = "rbxassetid://2060770132"
propertiesListScrollingFrame.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
propertiesListScrollingFrame.BorderColor3 = Color3.fromRGB(34, 34, 34)
propertiesListScrollingFrame.BorderSizePixel = 1
propertiesListScrollingFrame.ScrollBarThickness = 18
propertiesListScrollingFrame.ClipsDescendants = true

local propertiesListUIListLayout = Instance.new("UIListLayout")
propertiesListUIListLayout.FillDirection = Enum.FillDirection.Vertical
propertiesListUIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
propertiesListUIListLayout.SortOrder = Enum.SortOrder.Name
propertiesListUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
propertiesListUIListLayout.Padding = UDim.new(0, 0)

local function newCategoryContainer(catName)
	if (categoryContainers[catName]) then return categoryContainers[catName] end
	
	local isToggled = true
	
	local categoryFrame = Instance.new("Frame")
	categoryFrame.Name = catName
	categoryFrame.BackgroundTransparency = 1
	
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.AnchorPoint = Vector2.new(0.5, 0)
	header.Size = UDim2.new(1, 0, 0, PROPERTY_NAME_ROW_HEIGHT)
	header.Position = UDim2.new(0.5, 0, 0, 0)
	header.BackgroundColor3 = Color3.fromRGB(53, 53, 53)
	header.BorderSizePixel = 0
	
	local headerToggle = Instance.new("TextButton")
	headerToggle.Name = "Toggle"
	headerToggle.AnchorPoint = Vector2.new(0, 0.5)
	headerToggle.Size = UDim2.new(0, 24, 0, 24)
	headerToggle.Position = UDim2.new(0, 0, 0.5, 0)
	headerToggle.BackgroundTransparency = 1
	headerToggle.Font = Enum.Font.SourceSansBold
	headerToggle.TextSize = PROPNAME_TEXTSIZE
	headerToggle.TextColor3 = Color3.new(1, 1, 1)
	headerToggle.TextXAlignment = Enum.TextXAlignment.Center
	headerToggle.TextYAlignment = Enum.TextYAlignment.Center
	headerToggle.Text = "-"
	
	local headerText = Instance.new("TextLabel")
	headerText.Name = "HeaderText"
	headerText.AnchorPoint = Vector2.new(1, 0.5)
	headerText.Size = UDim2.new(1, -24, 1, 0)
	headerText.Position = UDim2.new(1, 0, 0.5, 0)
	headerText.BackgroundTransparency = 1
	headerText.Font = Enum.Font.SourceSansBold
	headerText.TextSize = PROPNAME_TEXTSIZE
	headerText.TextColor3 = Color3.new(1, 1, 1)
	headerText.TextXAlignment = Enum.TextXAlignment.Left
	headerText.TextYAlignment = Enum.TextYAlignment.Center
	headerText.Text = catName
	
	local propertiesTable = TableLayout.new({
		DefaultVisibility = false,
		Columns = { "PropertyName", "Editor" },
		Sizes = {
			Rows = {
				[":default"] = PROPERTY_NAME_ROW_HEIGHT,
			},
			Columns = {
				["Editor"] = PROPERTY_EDITOR_COLUMN_WIDTH,
			}
		}
	})
	
	propertiesTable:SetStyleCallback(function(cell)
		cell.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
	--	cell.BorderColor3 = Color3.fromRGB(34, 34, 34)	
		cell.BorderSizePixel = 0
	end)
	
	local propertiesTableUI = propertiesTable.UIRoot
	propertiesTableUI.Name = "PropertiesList"
	propertiesTableUI.AnchorPoint = Vector2.new(0.5, 1)
	propertiesTableUI.Position = UDim2.new(0.5, 0, 1, 0)
	propertiesTableUI.BackgroundTransparency = 1
	propertiesTableUI.BorderSizePixel = 0
	
	headerToggle.MouseButton1Click:Connect(function()
		isToggled = (not isToggled)
		local tableSize = propertiesTable:GetSize()
		
		headerToggle.Text = isToggled and "-" or "+"
		propertiesTableUI.Visible = isToggled
		categoryFrame.Size = isToggled and UDim2.new(0, tableSize.X, 0, tableSize.Y + PROPERTY_NAME_ROW_HEIGHT) or UDim2.new(0, tableSize.X, 0, PROPERTY_NAME_ROW_HEIGHT)
	end)
	
	propertiesTableUI:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if (not isToggled) then return end
		local newSize = propertiesTableUI.AbsoluteSize
		
		categoryFrame.Size = UDim2.new(0, newSize.X, 0, newSize.Y + PROPERTY_NAME_ROW_HEIGHT)
	end)
	
	categoryContainers[catName] = {
		UI = categoryFrame,
		Table = propertiesTable
	}
	
	headerToggle.Parent = header
	headerText.Parent = header
	header.Parent = categoryFrame
	propertiesTableUI.Parent = categoryFrame
	categoryFrame.Parent = propertiesListScrollingFrame
	
	return categoryContainers[catName]
end

propertiesListUIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	local contentSize = propertiesListUIListLayout.AbsoluteContentSize
	
	propertiesListScrollingFrame.CanvasSize = UDim2.new(0, contentSize.X, 0, contentSize.Y)
end)

---

local selectionConnection
selectionConnection = SelectionChanged:Connect(function()
	nameColumnWidth = 0
	editorColumnWidth = 0
	propertiesListScrollingFrame.CanvasPosition = Vector2.new(0, 0)
	
	local selection = Selection:Get()
	
	local selectionClasses = {}
	local selectionProperties = {}
	
	for i = 1, #selection do
		local obj = selection[i]
		
		selectionClasses[#selectionClasses + 1] = obj.ClassName
	end
	purgeDuplicates(selectionClasses)
	
	for i = 1, #selectionClasses do
		local class = selectionClasses[i]
		local properties = APILib:GetProperties(class)
		
		for className, classProperties in pairs(properties) do
			for j = 1, #classProperties do
				local property = classProperties[j]
				
				selectionProperties[#selectionProperties + 1] = className.."."..property
			end
		end
	end
	purgeDuplicates(selectionProperties)
	
	for _, category in pairs(categoryContainers) do
		local catTable = category.Table
		
		for row in pairs(catTable.Rows) do
			catTable:SetVisible(row..":", false)
		end
		
		category.UI.Visible = false
	end
	
	for i = 1, #selectionProperties do
		local property = selectionProperties[i]
		local className, propertyName = string.match(property, "(.+)%.(.+)")
		
		local propertyCategory = APIData.Classes[className].Properties[propertyName].Category
		local categoryContainer
		local propertiesTable
		
		if (not categoryContainers[propertyCategory]) then
			categoryContainer = newCategoryContainer(propertyCategory)
		else
			categoryContainer = categoryContainers[propertyCategory]
		end
		propertiesTable = categoryContainer.Table
		
		categoryContainer.UI.Visible = true
		
		if (not propertiesTable:Get(property..":")) then
			propertiesTable:AddRow(property)
			
			local cell = propertiesTable:Get(property..":PropertyName")
			do
				local isReadOnly = APILib:IsPropertyReadOnly(className, propertyName)
				
				local propertyNameLabel = Instance.new("TextLabel")
				propertyNameLabel.AnchorPoint = Vector2.new(0, 0.5)
				propertyNameLabel.Size = UDim2.new(1, -24, 1, 0)
				propertyNameLabel.Position = UDim2.new(0, 24, 0.5, 0)
				propertyNameLabel.BackgroundTransparency = 1
				propertyNameLabel.TextColor3 = (not isReadOnly) and Color3.new(1, 1, 1) or Color3.fromRGB(85, 85, 85)
				propertyNameLabel.Font = Enum.Font.SourceSans
				propertyNameLabel.TextSize = 14
				propertyNameLabel.TextXAlignment = Enum.TextXAlignment.Left
				propertyNameLabel.TextYAlignment = Enum.TextYAlignment.Center
				propertyNameLabel.Text = propertyName
				
				propertyNameLabel.Parent = cell
			end
			
			propertiesTable:SortRows(function(a, b)
				local _, propertyNameA = string.match(a, "(.+)%.(.+)")
				local _, propertyNameB = string.match(b, "(.+)%.(.+)")
				
				return propertyNameA < propertyNameB
			end)
		else
			propertiesTable:SetVisible(property..":", true)
		end
		
		local textWidth = TextService:GetTextSize(propertyName, PROPNAME_TEXTSIZE, PROPNAME_FONT, Vector2.new()).X
		if (textWidth > nameColumnWidth) then nameColumnWidth = textWidth end
	end
	
	editorColumnWidth = math.max(150, propertiesListScrollingFrame.AbsoluteSize.X - (nameColumnWidth + 24 + 10))
	
	for _, category in pairs(categoryContainers) do
		local categoryTable = category.Table 
		
		categoryTable:SetColumnWidth("PropertyName", nameColumnWidth + 24 + 10)
		categoryTable:SetColumnWidth("Editor", editorColumnWidth)
	end
end)

widget:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	editorColumnWidth = math.max(150, propertiesListScrollingFrame.AbsoluteSize.X - (nameColumnWidth + 24 + 10))
	
	for _, category in pairs(categoryContainers) do
		local categoryTable = category.Table
		local categoryFrame = category.UI
		local tableSize = categoryTable:GetSize()
		
		categoryTable:SetColumnWidth("Editor", editorColumnWidth)
		categoryFrame.Size = UDim2.new(0, tableSize.X, categoryFrame.Size.Y.Scale, categoryFrame.Size.Y.Offset)
	end
end)

--- SETTINGS

local CoreGui = game:GetService("CoreGui")

local settingsIsActive = false

local settingsUI = Instance.new("ScreenGui")
settingsUI.Name = "PropertiesMod Settings"
settingsUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
settingsUI.Enabled = false
settingsUI.Archivable = false

local settingsFrame = Instance.new("Frame")
settingsFrame.Name = "Container"
settingsFrame.AnchorPoint = Vector2.new(0.5, 0.5)
settingsFrame.Size = UDim2.new(1, 0, 1, 0)
settingsFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
settingsFrame.BackgroundColor3 = Color3.new(1, 1, 1)
settingsFrame.BorderSizePixel = 0

configButton.Click:Connect(function()
	settingsIsActive = (not settingsIsActive)
	
	settingsUI.Enabled = settingsIsActive
	configButton:SetActive(settingsIsActive)
end)

--- UNLOAD CLEANUP

plugin.Unloading:Connect(function()
	settingsUI:Destroy()
	widget:Destroy()
	
	selectionConnection:Disconnect()
	print("Cleaned up PropertiesMod")
end)

---

settingsFrame.Parent = settingsUI
propertiesListUIListLayout.Parent = propertiesListScrollingFrame

propertiesListScrollingFrame.Parent = widget
settingsUI.Parent = CoreGui