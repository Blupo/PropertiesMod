local BOX_SIZE = 12

return function(main, lib, propertyData)
    local toggle = Instance.new("ImageButton")
	toggle.Name = "ToggleButton"
	toggle.AnchorPoint = Vector2.new(0, 0.5)
	toggle.AutoButtonColor = false
	toggle.Size = UDim2.new(0, BOX_SIZE, 0, BOX_SIZE)
	toggle.Position = UDim2.new(0, 4, 0.5, 0)

    local isReadOnly = propertyData.Tags.ReadOnly

    lib.Themer.SyncProperties(toggle, {
        BackgroundColor3 = {Enum.StudioStyleGuideColor.InputFieldBackground, isReadOnly and Enum.StudioStyleGuideModifier.Disabled or Enum.StudioStyleGuideModifier.Default},
		BorderColor3 = Enum.StudioStyleGuideColor.Border,
		ImageColor3 = {Enum.StudioStyleGuideColor.Button, Enum.StudioStyleGuideModifier.Selected},
    })

    local boolValue = false

    local function updateState()
        toggle.Image = boolValue and "rbxassetid://1469818624" or ""
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
end