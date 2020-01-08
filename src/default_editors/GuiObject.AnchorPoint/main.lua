local WIDGET_GUI_INFO = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 300, 350, 300, 350)

return function(main, lib, propertyData)
--  local widgetGui = main.CreateDockWidgetPluginGui(WIDGET_GUI_INFO)

    local isReadOnly = propertyData.Tags.ReadOnly

    local toggle = Instance.new("TextButton")
    toggle.Name = "ToggleButton"
    toggle.AnchorPoint = Vector2.new(0.5, 0.5)
    toggle.AutoButtonColor = false
    toggle.Size = UDim2.new(1, 0, 1, 0)
    toggle.Position = UDim2.new(0.5, 0, 0.5, 0)
    toggle.ZIndex = 1
    toggle.BackgroundTransparency = 1
    toggle.TextTransparency = 1
    toggle.Text = "[Click to Edit]"

    lib.Themer.SyncProperties(toggle, {
        TextColor3 = {Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Disabled}
    })

    toggle.Parent = widgetGui
end