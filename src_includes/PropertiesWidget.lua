local includes = script.Parent

local Themer = require(includes:WaitForChild("Themer"))

---

local DOUBLE_CLICK_TIME = 0.5

local RIGHT_ARROW_IMAGE = "rbxassetid://367872391"
local DOWN_ARROW_IMAGE = "rbxassetid://913309373"

local SCROLLBAR_IMAGES = {
    Top = "rbxassetid://590077572",
    Middle = "rbxassetid://590077572",
    Bottom = "rbxassetid://590077572",
}

local WIDGET_INFO = {
	WIDGET_ID = "PropertiesMod",
	WIDGET_DEFAULT_TITLE = "Properties",
	WIDGET_PLUGINGUI_INFO = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 268, 400, 270, 250)
}

---

local Widget = {
    Categories = {},
    PropertyRows = {},
}

local APIData
local APILib
local Settings

local propertyNameColumnWidth = 0

local plugin
local widget
local propertiesListScrollingFrame
local propertiesListUIListLayout

local function getPropertyNormalName(className, propertyName)
	return className .. "/" .. propertyName
end

local function parsePropertyNormalName(propertyNormalName)
	return string.match(propertyNormalName, "(.+)/(.+)")
end

local function isPropertyInaccessible(className, propertyName)
	local property = APIData.Classes[className].Properties[propertyName]

	return (property.Security.Read == "RobloxSecurity") or (property.Security.Read == "RobloxScriptSecurity") or (property.Tags.NotScriptable)
end

local function getEditorColumnWidth()
    return math.max(Settings.Config.EditorColumnWidth, widget.AbsoluteSize.X - propertyNameColumnWidth)
end

local function getListWidth()
    return propertyNameColumnWidth + getEditorColumnWidth()
end

local function newPropertyRow(className, propertyName)
	local normalName = getPropertyNormalName(className, propertyName)
	if Widget.PropertyRows[normalName] then return end

	local row = Instance.new("Frame")
	row.Name = normalName
	row.Size = UDim2.new(0, getListWidth(), 0, Settings.Config.RowHeight)
	row.BorderSizePixel = 0
	row.BackgroundTransparency = 1

	local propertyNameCell = Instance.new("Frame")
	propertyNameCell.AnchorPoint = Vector2.new(0, 0.5)
	propertyNameCell.Position = UDim2.new(0, 0, 0.5, 0)
	propertyNameCell.Size = UDim2.new(0, propertyNameColumnWidth, 0, Settings.Config.RowHeight)
	propertyNameCell.Name = "PropertyName"

	local editorCell = Instance.new("Frame")
	editorCell.AnchorPoint = Vector2.new(1, 0.5)
	editorCell.Position = UDim2.new(1, 0, 0.5, 0)
	editorCell.Size = UDim2.new(0, getEditorColumnWidth(), 0, Settings.Config.RowHeight)
	editorCell.Name = "Editor"

	-- populate

	local isReadOnly = APILib:IsPropertyReadOnly(className, propertyName)
	local isInaccessible = isPropertyInaccessible(className, propertyName)

	local propertyNameLabel = Instance.new("TextButton")
	propertyNameLabel.AnchorPoint = Vector2.new(0, 0.5)
	propertyNameLabel.Size = UDim2.new(1, -24, 1, 0)
	propertyNameLabel.Position = UDim2.new(0, 24, 0.5, 0)
	propertyNameLabel.Active = true
	propertyNameLabel.BackgroundTransparency = 1
	propertyNameLabel.BorderSizePixel = 0
	propertyNameLabel.AutoButtonColor = false
	propertyNameLabel.Font = Enum.Font.SourceSans
	propertyNameLabel.TextSize = Settings.Config.TextSize
	propertyNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	propertyNameLabel.TextYAlignment = Enum.TextYAlignment.Center
    propertyNameLabel.Text = propertyName

	Themer.SyncProperties(propertyNameCell, {
		BackgroundColor3 = Enum.StudioStyleGuideColor.TableItem,
		BorderColor3 = Enum.StudioStyleGuideColor.Border
	})

	Themer.SyncProperties(editorCell, {
		BackgroundColor3 = Enum.StudioStyleGuideColor.TableItem,
		BorderColor3 = Enum.StudioStyleGuideColor.Border
	})

	if isInaccessible then
		Themer.SyncProperty(propertyNameLabel, "TextColor3", Enum.StudioStyleGuideColor.ErrorText)
	else
		Themer.SyncProperty(propertyNameLabel, "TextColor3", {Enum.StudioStyleGuideColor.MainText, isReadOnly and Enum.StudioStyleGuideModifier.Disabled or Enum.StudioStyleGuideModifier.Default})
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

		Themer.SyncProperty(propertyNameCell, "BackgroundColor3", {Enum.StudioStyleGuideColor.TableItem, Enum.StudioStyleGuideModifier.Hover})
	end)

	propertyNameCell.MouseLeave:Connect(function()
		if (isReadOnly or isInaccessible) then return end

		Themer.SyncProperty(propertyNameCell, "BackgroundColor3", Enum.StudioStyleGuideColor.TableItem)
    end)

    propertyNameCell:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        editorCell.Size = UDim2.new(0, getEditorColumnWidth(), 0, Settings.Config.RowHeight)
        row.Size = UDim2.new(0, getListWidth(), 0, Settings.Config.RowHeight)
    end)

	propertyNameLabel.Parent = propertyNameCell
	propertyNameCell.Parent = row
	editorCell.Parent = row

	Widget.PropertyRows[normalName] = row
--	nameCells[normalName] = propertyNameCell
--	editorCells[normalName] = editorCell
	return row
end

local function createCategoryContainer(categoryName)
	if (Widget.Categories[categoryName]) then return end

	local isToggled do
		if (type(Settings.CategoryStateMemory[categoryName]) == "boolean") then
			isToggled = Settings.CategoryStateMemory[categoryName]
		else
			isToggled = true
		end
	end

	local categoryFrame = Instance.new("Frame")
	categoryFrame.Name = categoryName
    categoryFrame.BackgroundTransparency = 1
    categoryFrame.Visible = false

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.AnchorPoint = Vector2.new(0.5, 0)
	header.Size = UDim2.new(1, 0, 0, Settings.Config.RowHeight)
	header.Position = UDim2.new(0.5, 0, 0, 0)
	header.BorderSizePixel = 0

	local headerToggle = Instance.new("ImageButton")
	headerToggle.Name = "Toggle"
	headerToggle.AnchorPoint = Vector2.new(0, 0.5)
	headerToggle.Size = UDim2.new(0, 24, 0, 24)
	headerToggle.Position = UDim2.new(0, 0, 0.5, 0)
	headerToggle.BackgroundTransparency = 1
	headerToggle.Image = isToggled and RIGHT_ARROW_IMAGE or DOWN_ARROW_IMAGE

	local headerText = Instance.new("TextButton")
	headerText.Name = "HeaderText"
	headerText.AnchorPoint = Vector2.new(1, 0.5)
	headerText.Size = UDim2.new(1, -24, 1, 0)
	headerText.Position = UDim2.new(1, 0, 0.5, 0)
	headerText.AutoButtonColor = false
	headerText.BackgroundTransparency = 1
	headerText.Font = Enum.Font.SourceSansBold
	headerText.TextSize = Settings.Config.TextSize
	headerText.TextXAlignment = Enum.TextXAlignment.Left
	headerText.TextYAlignment = Enum.TextYAlignment.Center
	headerText.Text = categoryName

	local categoryPropertiesListUI = Instance.new("Frame")
	categoryPropertiesListUI.Name = "PropertiesList"
	categoryPropertiesListUI.AnchorPoint = Vector2.new(0.5, 1)
	categoryPropertiesListUI.Position = UDim2.new(0.5, 0, 1, 0)
	categoryPropertiesListUI.BackgroundTransparency = 1
	categoryPropertiesListUI.BorderSizePixel = 0
	categoryPropertiesListUI.Visible = isToggled

	local categoryPropertiesListUIListLayout = propertiesListUIListLayout:Clone()

	local function toggle()
		isToggled = (not isToggled)
		Settings.CategoryStateMemory[categoryName] = isToggled

		headerToggle.Image = isToggled and RIGHT_ARROW_IMAGE or DOWN_ARROW_IMAGE

		categoryPropertiesListUI.Visible = isToggled

		local tableSize = categoryPropertiesListUIListLayout.AbsoluteContentSize
		categoryPropertiesListUI.Size = isToggled and UDim2.new(0, getListWidth(), 0, tableSize.Y) or UDim2.new(0, getListWidth(), 0, 0)
	end

	Themer.SyncProperty(header, "BackgroundColor3", Enum.StudioStyleGuideColor.MainBackground)
	Themer.SyncProperty(headerToggle, "ImageColor3", Enum.StudioStyleGuideColor.ButtonText)
	Themer.SyncProperty(headerText, "TextColor3", Enum.StudioStyleGuideColor.BrightText)

	headerToggle.MouseButton1Click:Connect(toggle)

	local lastClickTime = 0
	headerText.MouseButton1Down:Connect(function()
		local now = tick()

		if ((now - lastClickTime) < DOUBLE_CLICK_TIME) then
			toggle()

			lastClickTime = 0
		else
			lastClickTime = now
		end
	end)

	categoryPropertiesListUI:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		categoryFrame.Size = UDim2.new(0, getListWidth(), 0, categoryPropertiesListUI.AbsoluteSize.Y + Settings.Config.RowHeight)
	end)

	categoryPropertiesListUIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local tableSize = categoryPropertiesListUIListLayout.AbsoluteContentSize

		categoryPropertiesListUI.Size = isToggled and UDim2.new(0, getListWidth(), 0, tableSize.Y) or UDim2.new(0, getListWidth(), 0, 0)
    end)

    categoryPropertiesListUI.Size = UDim2.new(0, getListWidth(), 0, Settings.Config.RowHeight)

	headerToggle.Parent = header
	headerText.Parent = header
    categoryPropertiesListUIListLayout.Parent = categoryPropertiesListUI
    header.Parent = categoryFrame
    categoryPropertiesListUI.Parent = categoryFrame
	categoryFrame.Parent = propertiesListScrollingFrame

	Widget.Categories[categoryName] = {
		UI = categoryFrame,
		TableUI = categoryPropertiesListUI
	}

	return Widget.Categories[categoryName]
end

---

function Widget.Init(pluginObj, settings, apiLib)
    plugin = pluginObj

    widget = plugin:CreateDockWidgetPluginGui(WIDGET_INFO.WIDGET_ID, WIDGET_INFO.WIDGET_PLUGINGUI_INFO)
    widget.Archivable = false
    widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    widget.Name = WIDGET_INFO.WIDGET_ID
    widget.Title = WIDGET_INFO.WIDGET_DEFAULT_TITLE

    propertiesListScrollingFrame = Instance.new("ScrollingFrame")
    propertiesListScrollingFrame.Name = "PropertiesListContainer"
    propertiesListScrollingFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    propertiesListScrollingFrame.Size = UDim2.new(1, 0, 1, -2)
    propertiesListScrollingFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    propertiesListScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    propertiesListScrollingFrame.CanvasPosition = Vector2.new(0, 0)
    propertiesListScrollingFrame.HorizontalScrollBarInset = Enum.ScrollBarInset.Always
    propertiesListScrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    propertiesListScrollingFrame.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
    propertiesListScrollingFrame.TopImage = SCROLLBAR_IMAGES.Top
    propertiesListScrollingFrame.MidImage = SCROLLBAR_IMAGES.Middle
    propertiesListScrollingFrame.BottomImage = SCROLLBAR_IMAGES.Bottom
    propertiesListScrollingFrame.BorderSizePixel = 1
    propertiesListScrollingFrame.ScrollBarThickness = 18
    propertiesListScrollingFrame.ClipsDescendants = true

    propertiesListUIListLayout = Instance.new("UIListLayout")
    propertiesListUIListLayout.FillDirection = Enum.FillDirection.Vertical
    propertiesListUIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    propertiesListUIListLayout.SortOrder = Enum.SortOrder.Name
    propertiesListUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    propertiesListUIListLayout.Padding = UDim.new(0, 0)

    Themer.SyncProperties(propertiesListScrollingFrame, {
        ScrollBarImageColor3 = Enum.StudioStyleGuideColor.ScrollBar,
        BackgroundColor3 = Enum.StudioStyleGuideColor.Mid,
        BorderColor3 = Enum.StudioStyleGuideColor.Border,
    })

    propertiesListUIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local contentSize = propertiesListUIListLayout.AbsoluteContentSize

        propertiesListScrollingFrame.CanvasSize = UDim2.new(0, contentSize.X, 0, contentSize.Y)
    end)

    widget:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        for _, propertyRow in pairs(Widget.PropertyRows) do
            propertyRow:FindFirstChild("Editor").Size = UDim2.new(0, getEditorColumnWidth(), 0, Settings.Config.RowHeight)
            propertyRow.Size = UDim2.new(0, getListWidth(), 0, Settings.Config.RowHeight)
        end
    end)

    Settings = settings
    APILib = apiLib.APILib
    APIData = apiLib.APIData

    propertiesListUIListLayout.Parent = propertiesListScrollingFrame
    propertiesListScrollingFrame.Parent = widget
end

function Widget.Unload()
    if widget then
        widget:Destroy()
        widget = nil
    end

    if propertiesListScrollingFrame then
        propertiesListScrollingFrame:Destroy()
        propertiesListScrollingFrame = nil
    end

    if propertiesListUIListLayout then
        propertiesListUIListLayout:Destroy()
        propertiesListUIListLayout = nil
    end

    Widget.Categories = {}
    Widget.ProeprtyRows = {}

    Settings = nil
    APILib = nil
    APIData = nil
    plugin = nil
end

function Widget.ResetRowVisibility()
    for _, row in pairs(Widget.PropertyRows) do
        row.Visible = false
    end
end

function Widget.SetRowVisibility(normalName, visibility)
    local propertyRow = Widget.PropertyRows[normalName]
    if (not propertyRow) then return end

    propertyRow.Visible = visibility
end

function Widget.ResetCategoryVisibility()
    for _, category in pairs(Widget.Categories) do
        category.UI.Visible = false
    end
end

function Widget.SetCategoryVisibility(categoryName, visibility)
    local category = Widget.Categories[categoryName]
    if (not category) then return end

    category.UI.Visible = visibility
end

function Widget.AddRow(className, propertyName, visibility)
    if (not widget) then return end
    if (not APIData) then return end

    local normalName = getPropertyNormalName(className, propertyName)
    if Widget.PropertyRows[normalName] then return end

    local propertyData = APIData.Classes[className].Properties[propertyName]
    local category = propertyData.Category

    local categoryTableUI = Widget.Categories[category] and Widget.Categories[category].TableUI or createCategoryContainer(category).TableUI
    local newRow = newPropertyRow(className, propertyName)

    newRow.Visible = visibility
    newRow.Parent = categoryTableUI

    -- resort rows
end

-- optimise sorting by keeping track of the categories that need to be sorted and then doing them at once instead of multiple passes
function Widget.AddRows(rows)
    if (not widget) then return end
    if (not APIData) then return end

    local categoriesToBeResorted = {}
    for i = 1, #rows do
        local row = rows[i]
        local className, propertyName, visibility = row[1], row[2], row[3]

        local normalName = getPropertyNormalName(className, propertyName)
        if (not Widget.PropertyRows[normalName]) then
            local propertyData = APIData.Classes[className].Properties[propertyName]
            local category = propertyData.Category

            local categoryTableUI = Widget.Categories[category] and Widget.Categories[category].TableUI or createCategoryContainer(category).TableUI
            local newRow = newPropertyRow(className, propertyName)

            categoriesToBeResorted[category] = true
            newRow.Visible = visibility
            newRow.Parent = categoryTableUI
        end
    end

    local categoryRows = {}
    for categoryName in pairs(categoriesToBeResorted) do
        local category = Widget.Categories[categoryName]
        local categoryTableUI = category.TableUI

        for _, categoryRow in pairs(categoryTableUI:GetChildren()) do
			if categoryRow:IsA("GuiObject") then
				categoryRows[#categoryRows + 1] = categoryRow.Name
			end
		end

		if (#categoryRows > 0) then
			table.sort(categoryRows, function(a, b)
				local _, propertyNameA = parsePropertyNormalName(a)
				local _, propertyNameB = parsePropertyNormalName(b)

				return propertyNameA < propertyNameB
			end)

            for i, categoryRowName in ipairs(categoryRows) do
				Widget.PropertyRows[categoryRowName].LayoutOrder = i
			end
		end
    end
end

function Widget.GetPropertyNormalName(className, propertyName)
    return getPropertyNormalName(className, propertyName)
end

function Widget.ParsePropertyNormalName(normalName)
    return parsePropertyNormalName(normalName)
end

function Widget.SetPropertyNameColumnWidth(newWidth)
    if (not widget) then return end
    propertyNameColumnWidth = newWidth

    for _, propertyRow in pairs(Widget.PropertyRows) do
        propertyRow:FindFirstChild("PropertyName").Size = UDim2.new(0, propertyNameColumnWidth, 0, Settings.Config.RowHeight)
    end
end

function Widget.ResetScrollPosition()
    if (not widget) then return end

    propertiesListScrollingFrame.CanvasPosition = Vector2.new(0, 0)
end

return Widget