local BOX_SIZE = 12

return function(main, lib, propertyData)
    local toggle = Instance.new("TextButton")
    toggle.Name = "ToggleButton"
    toggle.AnchorPoint = Vector2.new(0.5, 0.5)
    toggle.AutoButtonColor = false
    toggle.Size = UDim2.new(1, 0, 1, 0)
    toggle.Position = UDim2.new(0.5, 0, 0.5, 0)
    toggle.ZIndex = 2
    toggle.BackgroundTransparency = 1
    toggle.TextTransparency = 1

    local indicator = Instance.new("ImageLabel")
    indicator.Name = "Indicator"
    indicator.AnchorPoint = Vector2.new(0, 0.5)
--  indicator.AutoButtonColor = false
    indicator.Size = UDim2.new(0, BOX_SIZE, 0, BOX_SIZE)
    indicator.Position = UDim2.new(0, 8, 0.5, 0)

    local isReadOnly = propertyData.Tags.ReadOnly
    local boolValue = false

    lib.Themer.SyncProperties(indicator, {
        BackgroundColor3 = {
            Enum.StudioStyleGuideColor.CheckedFieldBackground,
            isReadOnly and Enum.StudioStyleGuideModifier.Disabled or
                (boolValue and Enum.StudioStyleGuideModifier.Selected or Enum.StudioStyleGuideModifier.Default)
        },
        BorderColor3 = Enum.StudioStyleGuideColor.CheckedFieldBorder,
        ImageColor3 = {Enum.StudioStyleGuideColor.CheckedFieldIndicator, isReadOnly and Enum.StudioStyleGuideModifier.Disabled or Enum.StudioStyleGuideModifier.Default},
    })

    local function updateState()
        indicator.Image = boolValue and "rbxassetid://1469818624" or ""

        lib.Themer.SyncProperty(indicator, "BackgroundColor3", {
            Enum.StudioStyleGuideColor.CheckedFieldBackground,
            boolValue and Enum.StudioStyleGuideModifier.Selected or Enum.StudioStyleGuideModifier.Default
        })
    end

    toggle.MouseButton1Click:Connect(function()
        if isReadOnly then return end
        boolValue = (not boolValue)

        main.Update(boolValue)
    end)

    main.PropertyValueUpdated:Connect(function(newValue)
        newValue = newValue or false

        boolValue = newValue
        updateState()
    end)

    toggle.Parent = main.Display
    indicator.Parent = main.Display
end