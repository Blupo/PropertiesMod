local function makeWidget()
end

local function constructor(main, lib, propertyData)
    local isReadOnly = propertyData.Tags.ReadOnly

    local widgetToggle = Instance.new("TextButton")
    widgetToggle.AnchorPoint = Vector2.new(0.5, 0.5)
    widgetToggle.Size = UDim2.new(1, 0, 1, 0)
    widgetToggle.Position = UDim2.new(0.5, 0, 0.5, 0)
    widgetToggle.BackgroundTransparency = 0
    widgetToggle.BorderSizePixel = 1
    widgetToggle.Text = ""
    widgetToggle.TextTransparency = 1
    widgetToggle.Name = "WidgetToggle"

    local indicatorText = Instance.new("TextLabel")
    indicatorText.AnchorPoint = Vector2.new(1, 0.5)
    indicatorText.Size = UDim2.new(1, -8, 1, 0)
    indicatorText.Position = UDim2.new(1, 0, 0.5, 0)
    indicatorText.BackgroundTransparency = 1
    indicatorText.ClipsDescendants = true
    indicatorText.Text = ""
    indicatorText.Font = Enum.Font.SourceSans
    indicatorText.TextSize = 14
    indicatorText.TextXAlignment = Enum.TextXAlignment.Left
    indicatorText.TextYAlignment = Enum.TextYAlignment.Center
    indicatorText.TextTruncate = Enum.TextTruncate.AtEnd
    indicatorText.Name = "Indicator"

    lib.Themer.SyncProperty(indicatorText, "TextColor3", {Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Disabled})

    lib.Themer.SyncProperties(widgetToggle, {
        BorderColor3 = Enum.StudioStyleGuideColor.Border,
        BackgroundColor3 = Enum.StudioStyleGuideColor.TableItem
    })

    widgetToggle.MouseButton1Click:Connect(function()
        if isReadOnly then return end

        warn("there is no enum picker widget yet")
    end)

    main.PropertyValueUpdated:Connect(function(newValue)
        indicatorText.Text = newValue and newValue.Name or "..."
    end)

    indicatorText.Parent = widgetToggle
    widgetToggle.Parent = main.Display
end

return {
    UniqueId = "enums",
    Name = "Default Enum Editor",
    Description = "The Enum editor included with PropertiesMod",
    Attribution = "",

    Filters = {"Special:Enum"},
    Constructor = constructor
}