local function makeWidget()
end

return function(main, lib, propertyData)
    local rowHeight = main.GetConfigSetting("RowHeight")

    local isReadOnly = propertyData.Tags.ReadOnly

    local container = Instance.new("Frame")
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Size = UDim2.new(1, 0, 1, 0)
    container.Position = UDim2.new(0.5, 0, 0.5, 0)
    container.BackgroundTransparency = 0
    container.BorderSizePixel = 1
    container.Name = "Container"

    local widgetToggle = Instance.new("TextButton")
    widgetToggle.AnchorPoint = Vector2.new(0, 0.5)
    widgetToggle.Size = UDim2.new(0, rowHeight, 0, rowHeight)
    widgetToggle.SizeConstraint = Enum.SizeConstraint.RelativeYY
    widgetToggle.Position = UDim2.new(0, 0, 0.5, 0)
    widgetToggle.BackgroundTransparency = 0
    widgetToggle.BorderSizePixel = 1
    widgetToggle.Text = ""
    widgetToggle.TextTransparency = 1
    widgetToggle.Name = "WidgetToggle"

    local colorIndicator = Instance.new("TextLabel")
    colorIndicator.AnchorPoint = Vector2.new(0.5, 0.5)
    colorIndicator.Size = UDim2.new(0, 10, 0, 10)
    colorIndicator.Position = UDim2.new(0.5, 0, 0.5, 0)
    colorIndicator.BackgroundTransparency = 0
    colorIndicator.BorderSizePixel = 1
    colorIndicator.Text = "..."
    colorIndicator.TextSize = 14
    colorIndicator.TextTransparency = 1
    colorIndicator.Font = Enum.Font.SourceSans
    colorIndicator.Name = "ColorIndicator"

    local colorTextBox = Instance.new("TextBox")
    colorTextBox.AnchorPoint = Vector2.new(1, 0.5)
    colorTextBox.Size = UDim2.new(1, -rowHeight - 8, 1, 0)
    colorTextBox.Position = UDim2.new(1, 0, 0.5, 0)
    colorTextBox.BackgroundTransparency = 1
    colorTextBox.ClipsDescendants = true
    colorTextBox.Text = ""
    colorTextBox.Font = Enum.Font.SourceSans
    colorTextBox.TextSize = 14
    colorTextBox.TextXAlignment = Enum.TextXAlignment.Left
    colorTextBox.TextYAlignment = Enum.TextYAlignment.Center
    colorTextBox.TextTruncate = Enum.TextTruncate.AtEnd
    colorTextBox.ClearTextOnFocus = false
    colorTextBox.TextEditable = false -- todo: make it editable
    colorTextBox.Name = "ColorTextBox"

    lib.Themer.SyncProperty(colorTextBox, "TextColor3", {Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Disabled})

    lib.Themer.SyncProperties(widgetToggle, {
        BorderColor3 = Enum.StudioStyleGuideColor.Border,
        BackgroundColor3 = Enum.StudioStyleGuideColor.TableItem
    })

    lib.Themer.SyncProperties(colorIndicator, {
        BorderColor3 = Enum.StudioStyleGuideColor.Border,
        TextColor3 = Enum.StudioStyleGuideColor.MainText
    })

    lib.Themer.SyncProperties(container, {
        BorderColor3 = Enum.StudioStyleGuideColor.Border,
        BackgroundColor3 = Enum.StudioStyleGuideColor.TableItem
    })

    widgetToggle.MouseButton1Click:Connect(function()
        if isReadOnly then return end

        warn("there is no color editor widget yet")
    end)

    ---

    local function getIndicatorValue(newValue)
        if (propertyData.Name == "VertexColor") then
            return Color3.new(newValue.X, newValue.Y, newValue.Z)
        else
            return (propertyData.ValueType.Name == "Color3") and newValue or newValue.Color
        end
    end

    local function getTextRepresentation(newValue)
        if ((propertyData.ValueType.Name == "Color3") or (propertyData.Name == "VertexColor")) then
            newValue = (propertyData.Name == "VertexColor") and Color3.new(newValue.X, newValue.Y, newValue.Z) or newValue

            return string.format("%d, %d, %d", newValue.r * 255, newValue.g * 255, newValue.b * 255)
        elseif (propertyData.ValueType.Name == "BrickColor") then
            return newValue.Name
        end
    end

    main.PropertyValueUpdated:Connect(function(newValue)
        if newValue then
            colorIndicator.BackgroundTransparency = 0
            colorIndicator.TextTransparency = 1

            colorIndicator.BackgroundColor3 = getIndicatorValue(newValue)
            colorTextBox.Text = getTextRepresentation(newValue)
        else
            colorIndicator.BackgroundTransparency = 1
            colorIndicator.TextTransparency = 0

            colorTextBox.Text = "..."
        end
    end)

    colorIndicator.Parent = widgetToggle
    widgetToggle.Parent = container
    colorTextBox.Parent = container
    container.Parent = main.Display
end