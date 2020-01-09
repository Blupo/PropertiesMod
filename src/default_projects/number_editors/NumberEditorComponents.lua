return function(themer, isReadOnly)
    local textBox = Instance.new("TextBox")
    textBox.Name = "Text"
    textBox.AnchorPoint = Vector2.new(0, 0.5)
--  textBox.BackgroundColor3 = Color3.new(1, 1, 1)
    textBox.BackgroundTransparency = 1
    textBox.BorderSizePixel = 0
    textBox.Size = UDim2.new(1, -24, 1, 0)
    textBox.Position = UDim2.new(0, 8, 0.5, 0)
    textBox.ClearTextOnFocus = false
    textBox.Text = ""
    textBox.Font = Enum.Font.SourceSans
    textBox.TextSize = 14
--	textBox.TextColor3 = Color3.new(0, 0, 0)
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextYAlignment = Enum.TextYAlignment.Center

    local incrementUp = Instance.new("ImageButton")
    incrementUp.Name = "IncrementUp"
    incrementUp.AnchorPoint = Vector2.new(1, 0)
    incrementUp.Size = UDim2.new(0, 16, 0.5, 0)
    incrementUp.Position = UDim2.new(1, 0, 0, 0)
    incrementUp.BackgroundTransparency = 0
    incrementUp.Image = "rbxassetid://2064489060"
    incrementUp.ScaleType = Enum.ScaleType.Fit
--  incrementUp.ImageColor3 = Color3.new(0, 0, 0)

    local incrementDown = Instance.new("ImageButton")
    incrementDown.Name = "IncrementUp"
    incrementDown.AnchorPoint = Vector2.new(1, 1)
    incrementDown.Size = UDim2.new(0, 16, 0.5, 0)
    incrementDown.Position = UDim2.new(1, 0, 1, 0)
    incrementDown.BackgroundTransparency = 0
    incrementDown.Image = "rbxassetid://367867055"
    incrementDown.ScaleType = Enum.ScaleType.Fit
--  incrementDown.ImageColor3 = Color3.new(0, 0, 0)

    themer.SyncProperty(textBox, "TextColor3", {
        Enum.StudioStyleGuideColor.MainText,
        (not isReadOnly) and Enum.StudioStyleGuideModifier.Default or Enum.StudioStyleGuideModifier.Disabled
    })

    themer.SyncProperties(incrementUp, {
        BackgroundColor3 = Enum.StudioStyleGuideColor.Button,
        BorderColor3 = Enum.StudioStyleGuideColor.ButtonBorder,
        ImageColor3 = Enum.StudioStyleGuideColor.ButtonText,
    })

    themer.SyncProperties(incrementDown, {
        BackgroundColor3 = Enum.StudioStyleGuideColor.Button,
        BorderColor3 = Enum.StudioStyleGuideColor.ButtonBorder,
        ImageColor3 = Enum.StudioStyleGuideColor.ButtonText,
    })

    return textBox, incrementUp, incrementDown
end