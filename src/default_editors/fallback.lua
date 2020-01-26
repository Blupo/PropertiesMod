local function construct(main, lib)
    local textLabel = Instance.new("TextLabel")
    textLabel.AnchorPoint = Vector2.new(1, 0.5)
    textLabel.Size = UDim2.new(1, -8, 1, 0)
    textLabel.Position = UDim2.new(1, 0, 0.5, 0)
    textLabel.ClipsDescendants = true
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.SourceSans
    textLabel.TextSize = 14
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.TextTruncate = Enum.TextTruncate.AtEnd
    textLabel.TextWrapped = false

    lib.Themer.SyncProperties(textLabel, {
        TextColor3 = {Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Disabled}
    })

    main.PropertyValueUpdated:Connect(function(newValue)
        textLabel.Text = (type(newValue) ~= "nil") and tostring(newValue) or ""
    end)

    textLabel.Parent = main.Display
end

return {
    UniqueId = "fallback",
    Name = "Fallback Viewer",
    Description = "A fallback viewer for any properties that do not have an appropriate editor",
    Attribution = "",

    Filters = {"*"},
    Constructor = construct,
}