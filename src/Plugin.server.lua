-- TODO: Scrollbars

local RunService = game:GetService("RunService")

if (not RunService:IsStudio()) then warn("PropertiesMod only works in Studio") return false end
if RunService:IsRunMode() then warn("PropertiesMod only works in Edit mode") return false end

---

local root = script.Parent
local includes = root:WaitForChild("includes")

local RobloxAPI = require(includes:WaitForChild("RobloxAPI"):WaitForChild("API"))

local PROPERTY_ROW_COLUMN_DEFAULT_WIDTH = 150
local SECTION_HEADER_HEIGHT = 26
local PROPERTY_NAME_ROW_HEIGHT = 26
local PROPERTY_EDITOR_COLUMN_WIDTH = 150
local TEXT_TEXTSIZE = 14
local TEXT_FONT = Enum.Font.SourceSans

---

local Selection = game:GetService("Selection")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

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

---

local pluginSettings = --[[plugin:GetSetting("PropertiesMod") and HttpService:JSONDecode(plugin:GetSetting("PropertiesMod")) or--]] {
	Config = {
		Verbose = false,

		ShowInaccessibleProperties = true,
		ShowDeprecatedProperties = false,

		PreloadClasses = "Common",
		-- Common, All, or None,

		EditorColumnWidth = 150,
	},
	
	FilterPreferences = {},
	PropertyCategoryOverrides = {},
	CategoryStateMemory = {},
}

local editors = {}
local editorFilters = {}
local editorPreferences = {}

local categoryContainers = {}
local nameColumnWidth = 0
local editorColumnWidth = 0

local widgetInfo = {
	WIDGET_ID = "PropertiesMod",
	WIDGET_DEFAULT_TITLE = "Properties",
	WIDGET_PLUGINGUI_INFO = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 268, 400, 270, 250)
}

local toolbar = plugin:CreateToolbar("PropertiesMod")
local configButton = toolbar:CreateButton("Settings", "Configure PropertiesMod and its editors (uses a viewport UI)", "")

local API = RobloxAPI.new(true)
local APIData = API.Data
local APILib = API.Library
local APIOperator = API.Operator

if (not pluginSettings.Config.ShowInaccessibleProperties) then
	APIData:RemoveInaccessibleMembers()
end

if (not pluginSettings.Config.ShowDeprecatedProperties) then
	APIData:RemoveDeprecatedMembers()
end

local defaultExtensionFolder = root:WaitForChild("default_extensions")

local function loadExtension(module)
	local extension = require(module)
	
	local apiExtensions = extension.API
	local behaviourExtensions = extension.Behaviours
	
	APIData:Extend(apiExtensions or {})
	APIOperator:ExtendCustomBehaviours(behaviourExtensions or {})
end

--- WIDGET

local tableRows = {}
local nameCells = {}
local editorCells = {}

local function updateRowSize()
	for _, tableRow in pairs(tableRows) do
		tableRow.Size = UDim2.new(0, editorColumnWidth + nameColumnWidth + 24 + 10, 0, PROPERTY_NAME_ROW_HEIGHT)
		tableRow.PropertyName.Size = UDim2.new(0, nameColumnWidth + 24 + 10, 0, PROPERTY_NAME_ROW_HEIGHT)
		tableRow.Editor.Size = UDim2.new(0, editorColumnWidth, 0, PROPERTY_NAME_ROW_HEIGHT)
	end
end

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
propertiesListScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(34, 34, 34)
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

local function propertyIsInaccessible(className, propertyName)
	local property = APIData.Classes[className].Properties[propertyName]

	return (property.Security.Read == "RobloxSecurity") or (property.Security.Read == "RobloxScriptSecurity") or (property.Tags.NotScriptable)
end

local function getPropertyNormalName(className, propertyName)
	return className .. "/" .. propertyName
end

local function parsePropertyNormalName(propertyNormalName)
	return string.match(propertyNormalName, "(.+)/(.+)")
end

local function newPropertyRow(className, propertyName)
	local normalName = getPropertyNormalName(className, propertyName)
	if tableRows[normalName] then return end

	local row = Instance.new("Frame")
	row.Name = normalName
	row.Size = UDim2.new(0, editorColumnWidth + nameColumnWidth + 24 + 10, 0, PROPERTY_NAME_ROW_HEIGHT)
	row.BorderSizePixel = 0
	row.BackgroundTransparency = 0

	local propertyNameCell = Instance.new("Frame")
	propertyNameCell.AnchorPoint = Vector2.new(0, 0.5)
	propertyNameCell.Position = UDim2.new(0, 0, 0.5, 0)
	propertyNameCell.Size = UDim2.new(0, nameColumnWidth + 24 + 10, 0, PROPERTY_NAME_ROW_HEIGHT)
	propertyNameCell.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
	propertyNameCell.BorderColor3 = Color3.fromRGB(34, 34, 34)
	propertyNameCell.Name = "PropertyName"

	local editorCell = Instance.new("Frame")
	editorCell.AnchorPoint = Vector2.new(1, 0.5)
	editorCell.Position = UDim2.new(1, 0, 0.5, 0)
	editorCell.Size = UDim2.new(0, editorColumnWidth, 0, PROPERTY_NAME_ROW_HEIGHT)
	editorCell.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
	editorCell.BorderColor3 = Color3.fromRGB(34, 34, 34)	
	editorCell.Name = "Editor"

	-- populate

	local isReadOnly = APILib:IsPropertyReadOnly(className, propertyName)
	local isInaccessible = propertyIsInaccessible(className, propertyName)

	local propertyNameLabel = Instance.new("TextButton")
	propertyNameLabel.AnchorPoint = Vector2.new(0, 0.5)
	propertyNameLabel.Size = UDim2.new(1, -24, 1, 0)
	propertyNameLabel.Position = UDim2.new(0, 24, 0.5, 0)
	propertyNameLabel.Active = true
	propertyNameLabel.BackgroundTransparency = 1
	propertyNameLabel.BorderSizePixel = 0
	propertyNameLabel.AutoButtonColor = false
	propertyNameLabel.Font = Enum.Font.SourceSans
	propertyNameLabel.TextSize = 14
	propertyNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	propertyNameLabel.TextYAlignment = Enum.TextYAlignment.Center
	propertyNameLabel.Text = propertyName

	if isInaccessible then
		propertyNameLabel.TextColor3 = Color3.fromRGB(100, 80, 80)
	else
		propertyNameLabel.TextColor3 = (not isReadOnly) and Color3.new(1, 1, 1) or Color3.fromRGB(85, 85, 85)
	end
	
	propertyNameLabel.MouseButton2Click:Connect(function()
		local rmbMenu = plugin:CreatePluginMenu("PropertiesMod")
		rmbMenu:AddNewAction("ViewOnDevHub", "View on DevHub").Triggered:Connect(function()
			plugin:OpenWikiPage("api-reference/property/" .. className .. "/" .. propertyName)
		end)
		
		rmbMenu:ShowAsync()
		rmbMenu:Destroy()
	end)
	
	propertyNameCell.MouseEnter:Connect(function()
		if (isReadOnly or isInaccessible) then return end

		propertyNameCell.BackgroundColor3 = Color3.fromRGB(66, 66, 66)
	end)
	
	propertyNameCell.MouseLeave:Connect(function()
		if (isReadOnly or isInaccessible) then return end

		propertyNameCell.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
	end)
	
	propertyNameLabel.Parent = propertyNameCell
	propertyNameCell.Parent = row
	editorCell.Parent = row

	tableRows[normalName] = row
	nameCells[normalName] = propertyNameCell
	editorCells[normalName] = editorCell
	return row
end

local function createCategoryContainer(categoryName)
	if (categoryContainers[categoryName]) then return categoryContainers[categoryName] end
	
	local isToggled do
		if pluginSettings.CategoryStateMemory[categoryName] then
			isToggled = pluginSettings.CategoryStateMemory[categoryName]
		else
			isToggled = true
		end
	end
	
	local categoryFrame = Instance.new("Frame")
	categoryFrame.Name = categoryName
	categoryFrame.BackgroundTransparency = 1
	
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.AnchorPoint = Vector2.new(0.5, 0)
	header.Size = UDim2.new(1, 0, 0, PROPERTY_NAME_ROW_HEIGHT)
	header.Position = UDim2.new(0.5, 0, 0, 0)
	header.BackgroundColor3 = Color3.fromRGB(53, 53, 53)
	header.BorderSizePixel = 0
	
	-- todo: make this an ImageButton
	local headerToggle = Instance.new("TextButton")
	headerToggle.Name = "Toggle"
	headerToggle.AnchorPoint = Vector2.new(0, 0.5)
	headerToggle.Size = UDim2.new(0, 24, 0, 24)
	headerToggle.Position = UDim2.new(0, 0, 0.5, 0)
	headerToggle.BackgroundTransparency = 1
	headerToggle.Font = Enum.Font.SourceSansBold
	headerToggle.TextSize = TEXT_TEXTSIZE
	headerToggle.TextColor3 = Color3.new(1, 1, 1)
	headerToggle.TextXAlignment = Enum.TextXAlignment.Center
	headerToggle.TextYAlignment = Enum.TextYAlignment.Center
	headerToggle.Text = isToggled and "-" or "+"
	
	local headerText = Instance.new("TextLabel")
	headerText.Name = "HeaderText"
	headerText.AnchorPoint = Vector2.new(1, 0.5)
	headerText.Size = UDim2.new(1, -24, 1, 0)
	headerText.Position = UDim2.new(1, 0, 0.5, 0)
	headerText.BackgroundTransparency = 1
	headerText.Font = Enum.Font.SourceSansBold
	headerText.TextSize = TEXT_TEXTSIZE
	headerText.TextColor3 = Color3.new(1, 1, 1)
	headerText.TextXAlignment = Enum.TextXAlignment.Left
	headerText.TextYAlignment = Enum.TextYAlignment.Center
	headerText.Text = categoryName
	
	local propertiesTableUI = Instance.new("Frame")
	propertiesTableUI.Name = "PropertiesList"
	propertiesTableUI.AnchorPoint = Vector2.new(0.5, 1)
	propertiesTableUI.Position = UDim2.new(0.5, 0, 1, 0)
	propertiesTableUI.BackgroundTransparency = 1
	propertiesTableUI.BorderSizePixel = 0
	propertiesTableUI.Visible = isToggled

	local propertiesTableLayout = propertiesListUIListLayout:Clone()
	propertiesTableLayout.Parent = propertiesTableUI
	
	headerToggle.MouseButton1Click:Connect(function()
		isToggled = (not isToggled)
		
		headerToggle.Text = isToggled and "-" or "+"

		propertiesTableUI.Visible = isToggled

		local tableSize = propertiesTableLayout.AbsoluteContentSize
		propertiesTableUI.Size = isToggled and UDim2.new(1, 0, 0, tableSize.Y) or UDim2.new(0, 0, 0, 0)
	end)
	
	propertiesTableUI:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		categoryFrame.Size = UDim2.new(1, 0, 0, propertiesTableUI.AbsoluteSize.Y + PROPERTY_NAME_ROW_HEIGHT)
	end)

	propertiesTableLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local tableSize = propertiesTableLayout.AbsoluteContentSize
		
		propertiesTableUI.Size = isToggled and UDim2.new(1, 0, 0, tableSize.Y) or UDim2.new(0, 0, 0, 0)
	end)
	
	headerToggle.Parent = header
	headerText.Parent = header
	header.Parent = categoryFrame
	propertiesTableUI.Parent = categoryFrame
	categoryFrame.Parent = propertiesListScrollingFrame
	
	categoryContainers[categoryName] = {
		UI = categoryFrame,
		TableUI = propertiesTableUI
	}
	
	return categoryContainers[categoryName]
end

-- categories list

propertiesListUIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	local contentSize = propertiesListUIListLayout.AbsoluteContentSize
	
	propertiesListScrollingFrame.CanvasSize = UDim2.new(0, editorColumnWidth + nameColumnWidth + 24 + 10, 0, contentSize.Y)
end)

widget:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	editorColumnWidth = math.max(pluginSettings.Config.EditorColumnWidth, widget.AbsoluteSize.X - (nameColumnWidth + 24 + 10))

	updateRowSize()
end)

---

local function refreshPropertiesList(selection)
	nameColumnWidth = 0
	editorColumnWidth = 0
	propertiesListScrollingFrame.CanvasPosition = Vector2.new(0, 0)
	
	selection = selection or Selection:Get()
	
	local selectionClasses = {}
	local selectionProperties = {}
	
	for i = 1, #selection do
		local obj = selection[i]
		
		local success = pcall(function()
			if (obj.ClassName == "") then return end
			-- Idk why there are things with no ClassName, but they exist

			selectionClasses[#selectionClasses + 1] = obj.ClassName
		end)
	end
	purgeDuplicates(selectionClasses)

	for _, category in pairs(categoryContainers) do
		category.UI.Visible = false
	end

	for _, tableRow in pairs(tableRows) do
		tableRow.Visible = false
	end

	if (#selectionClasses <= 0) then return end
	
	for i = 1, #selectionClasses do
		local class = selectionClasses[i]
		local properties = APILib:GetProperties(class)
		
		for className, classProperties in pairs(properties) do
			for j = 1, #classProperties do
				local property = classProperties[j]
				
				selectionProperties[#selectionProperties + 1] = getPropertyNormalName(className, property)
			end
		end
	end
	
	local categoriesWithNewRows = {}
	for i = 1, #selectionProperties do
		local property = selectionProperties[i]
		local className, propertyName = parsePropertyNormalName(property)
		
		local propertyCategory = APIData.Classes[className].Properties[propertyName].Category
		local categoryContainer = categoryContainers[propertyCategory]
		local propertiesTable
		
		if (not categoryContainer) then
			categoryContainer = createCategoryContainer(propertyCategory)
		end
		categoryContainer.UI.Visible = true

		local tableRow = tableRows[property]
		if (not tableRow) then
			tableRow = newPropertyRow(className, propertyName)
			tableRow.Parent = categoryContainer.TableUI

			categoriesWithNewRows[#categoriesWithNewRows + 1] = propertyCategory
		else
			tableRow.Visible = true
		end

		local textWidth = TextService:GetTextSize(propertyName, TEXT_TEXTSIZE, TEXT_FONT, Vector2.new()).X
		if (textWidth > nameColumnWidth) then nameColumnWidth = textWidth end
	end

	-- resort any category with new rows
	for _, categoryName in pairs(categoriesWithNewRows) do
		local categoryContainer = categoryContainers[categoryName]

		local rows = {}
		local tableUI = categoryContainer.TableUI

		for _, row in pairs(tableUI:GetChildren()) do
			if row:IsA("GuiObject") then
				rows[#rows + 1] = row.Name
			end
		end

		if (#rows > 0) then
			table.sort(rows, function(a, b)
				local _, propertyNameA = parsePropertyNormalName(a)
				local _, propertyNameB = parsePropertyNormalName(b)
				
				return propertyNameA < propertyNameB
			end)

			for i, rowName in ipairs(rows) do
				tableUI:FindFirstChild(rowName).LayoutOrder = i
			end
		end
	end
	
	editorColumnWidth = math.max(150, widget.AbsoluteSize.X - (nameColumnWidth + 24 + 10))
	updateRowSize()
end

-- SelectionChanged that doesn't spam that much
-- https://devforum.roblox.com/t/weird-selectionchanged-behavior/22024/2
-- Credit to Fractality

local SelectionChanged do
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

local selectionConnection
selectionConnection = SelectionChanged:Connect(refreshPropertiesList)

--- PRELOAD API

do
	local classes

	if (pluginSettings.Config.PreloadClasses == "All") then
		classes = APIData.Classes
	elseif (pluginSettings.Config.PreloadClasses == "Common") then
		classes = require(includes:WaitForChild("CommonClasses"))
	end

	if classes then
		for class in pairs(classes) do
			local properties = APILib:GetImmediateProperties(class)
			
			for _, property in pairs(properties) do
				local propertyCategory = APIData.Classes[class].Properties[property].Category
				local categoryContainer = categoryContainers[propertyCategory]
				
				if (not categoryContainer) then
					categoryContainer = createCategoryContainer(propertyCategory)
				end
				categoryContainer.UI.Visible = false

				local tableRow = tableRows[property]
				tableRow = newPropertyRow(class, property)
				tableRow.Visible = false
				tableRow.Parent = categoryContainer.TableUI
			end
		end

		-- sort

		for _, categoryContainer in pairs(categoryContainers) do
			local rows = {}
			local tableUI = categoryContainer.TableUI
	
			for _, row in pairs(tableUI:GetChildren()) do
				if row:IsA("GuiObject") then
					rows[#rows + 1] = row.Name
				end
			end
	
			if (#rows > 0) then
				table.sort(rows, function(a, b)
					local _, propertyNameA = parsePropertyNormalName(a)
					local _, propertyNameB = parsePropertyNormalName(b)
					
					return propertyNameA < propertyNameB
				end)
	
				for i, rowName in ipairs(rows) do
					tableUI:FindFirstChild(rowName).LayoutOrder = i
				end
			end
		end
	end
end

--- LOAD EXTENSIONS

for _, extension in pairs(defaultExtensionFolder:GetChildren()) do
	loadExtension(extension)
end

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
	plugin:SetSetting("PropertiesMod", HttpService:JSONEncode(pluginSettings))
	print("Cleaned up PropertiesMod")
end)

---

refreshPropertiesList(Selection:Get())

---

settingsFrame.Parent = settingsUI
propertiesListUIListLayout.Parent = propertiesListScrollingFrame

propertiesListScrollingFrame.Parent = widget
settingsUI.Parent = CoreGui