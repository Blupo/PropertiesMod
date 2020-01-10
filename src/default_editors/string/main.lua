local WIDGET_GUI_INFO = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 300, 200, 300, 200)

local SCROLLBAR_IMAGES = {
    Top = "rbxassetid://590077572",
    Middle = "rbxassetid://590077572",
    Bottom = "rbxassetid://590077572",
}

---

local widget
local widgetTextBox

local lock

local changePropertyValueEvent = Instance.new("BindableEvent")
local ChangePropertySignal = changePropertyValueEvent.Event

local function openWidgetPrompt(lockName, initialValue)
    if lock then return else lock = lockName end

    widgetTextBox.Text = initialValue
    widget.Title  = "Editing " .. lockName
    widget.Enabled = true
end

local function resetPrompt()
    widget.Enabled = false
    widgetTextBox.Text = ""

    lock = nil
end

local function makeWidget(main, lib)
    widget = main.CreateDockWidgetPluginGui(WIDGET_GUI_INFO)

    local container = Instance.new("Frame")
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Size = UDim2.new(1, 0, 1, 0)
    container.Position = UDim2.new(0.5, 0, 0.5, 0)
    container.BackgroundTransparency = 0
    container.BorderSizePixel = 1
    container.Name = "Container"

    local textEditorFrame = Instance.new("ScrollingFrame")
    textEditorFrame.AnchorPoint = Vector2.new(0.5, 0)
    textEditorFrame.Size = UDim2.new(1, -20, 1, -46)
    textEditorFrame.Position = UDim2.new(0.5, 0, 0, 10)
    textEditorFrame.BackgroundTransparency = 0
    textEditorFrame.BorderSizePixel = 1
    textEditorFrame.ClipsDescendants = true
    textEditorFrame.HorizontalScrollBarInset = Enum.ScrollBarInset.Always
    textEditorFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    textEditorFrame.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
    textEditorFrame.TopImage = SCROLLBAR_IMAGES.Top
    textEditorFrame.MidImage = SCROLLBAR_IMAGES.Middle
    textEditorFrame.BottomImage = SCROLLBAR_IMAGES.Bottom
    textEditorFrame.ScrollBarThickness = 18
    textEditorFrame.Name = "TextEditorContainer"

    local textBox = Instance.new("TextBox")
    textBox.AnchorPoint = Vector2.new(0, 0)
    textBox.Size = UDim2.new(1, 0, 0, 0)
    textBox.Position = UDim2.new(0, 0, 0, 0)
    textBox.BackgroundTransparency = 1
    textBox.ClearTextOnFocus = false
    textBox.Font = Enum.Font.SourceSans
    textBox.TextSize = 14
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextYAlignment = Enum.TextYAlignment.Top
    textBox.TextTruncate = Enum.TextTruncate.AtEnd
    textBox.TextWrapped = true
    textBox.Name = "TextBox"

    local actionButtonsFrame = Instance.new("Frame")
    actionButtonsFrame.AnchorPoint = Vector2.new(0.5, 1)
    actionButtonsFrame.Size = UDim2.new(1, -20, 0, 18)
    actionButtonsFrame.Position = UDim2.new(0.5, 0, 1, -10)
    actionButtonsFrame.BackgroundTransparency = 1
    actionButtonsFrame.Name = "ActionButtons"

    local buttonTemplate = Instance.new("TextButton")
    buttonTemplate.Size = UDim2.new(0, 50, 1, 0)
    buttonTemplate.BackgroundTransparency = 0
    buttonTemplate.BorderSizePixel = 1
    buttonTemplate.Font = Enum.Font.SourceSans
    buttonTemplate.TextSize = 14
    buttonTemplate.TextXAlignment = Enum.TextXAlignment.Center
    buttonTemplate.TextYAlignment = Enum.TextYAlignment.Center

    local confirmButton, cancelButton, blankButton = buttonTemplate:Clone(), buttonTemplate:Clone(), buttonTemplate:Clone()

    confirmButton.Name = "ConfirmButton"
    confirmButton.Text = "OK"
    confirmButton.LayoutOrder = 0

    cancelButton.Name = "CancelButton"
    cancelButton.Text = "Cancel"
    cancelButton.LayoutOrder = 1

    blankButton.Name = "BlankButton"
    blankButton.Text = "Blank"
    blankButton.LayoutOrder = 2

    local actionButtonsLayout = Instance.new("UIListLayout")
    actionButtonsLayout.FillDirection = Enum.FillDirection.Horizontal
    actionButtonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    actionButtonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    actionButtonsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    actionButtonsLayout.Padding = UDim.new(0, 9)

    lib.Themer.SyncProperties(container, {
        BorderColor3 = Enum.StudioStyleGuideColor.Border,
        BackgroundColor3 = Enum.StudioStyleGuideColor.MainBackground
    })

    lib.Themer.SyncProperties(textEditorFrame, {
        BorderColor3 = Enum.StudioStyleGuideColor.Border,
        BackgroundColor3 = Enum.StudioStyleGuideColor.MainBackground
    })

    lib.Themer.SyncProperties(textBox, {
        TextColor3 = Enum.StudioStyleGuideColor.MainText
    })

    lib.Themer.SyncProperties(confirmButton, {
        TextColor3 = Enum.StudioStyleGuideColor.ButtonText,
        BorderColor3 = Enum.StudioStyleGuideColor.ButtonBorder,
        BackgroundColor3 = Enum.StudioStyleGuideColor.Button
    })

    lib.Themer.SyncProperties(cancelButton, {
        TextColor3 = Enum.StudioStyleGuideColor.ButtonText,
        BorderColor3 = Enum.StudioStyleGuideColor.ButtonBorder,
        BackgroundColor3 = Enum.StudioStyleGuideColor.Button
    })

    lib.Themer.SyncProperties(blankButton, {
        TextColor3 = Enum.StudioStyleGuideColor.ButtonText,
        BorderColor3 = Enum.StudioStyleGuideColor.ButtonBorder,
        BackgroundColor3 = Enum.StudioStyleGuideColor.Button
    })

    local function updateTextFrame()
        local textEditorFrameSize = textEditorFrame.AbsoluteSize
        local textBounds = textBox.TextBounds

        textBox.Size = UDim2.new(0, textEditorFrameSize.X, 0, (textEditorFrameSize.Y > textBounds.Y) and textEditorFrameSize.Y or textBounds.Y)
        textEditorFrame.CanvasSize = UDim2.new(0, textEditorFrameSize.X, 0, textBounds.Y)
    end

    textEditorFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTextFrame)
    textBox:GetPropertyChangedSignal("Text"):Connect(updateTextFrame)

    confirmButton.MouseButton1Click:Connect(function()
        changePropertyValueEvent:Fire(lock, textBox.Text)
        resetPrompt()
    end)

    blankButton.MouseButton1Click:Connect(function()
        textBox.Text = ""
    end)

    cancelButton.MouseButton1Click:Connect(resetPrompt)

    widgetTextBox = textBox

    textBox.Parent = textEditorFrame

    actionButtonsLayout.Parent = actionButtonsFrame
    confirmButton.Parent = actionButtonsFrame
    cancelButton.Parent = actionButtonsFrame
    blankButton.Parent = actionButtonsFrame

    textEditorFrame.Parent = container
    actionButtonsFrame.Parent = container

    container.Parent = widget
end

return function(main, lib, propertyData)
    if (not widget) then makeWidget(main, lib) end

    local isReadOnly = propertyData.Tags.ReadOnly

    local textBox = Instance.new("TextBox")
    textBox.AnchorPoint = Vector2.new(0, 0.5)
    textBox.Size = UDim2.new(1, -38, 1, 0)
    textBox.Position = UDim2.new(0, 8, 0.5, 0)
    textBox.ClearTextOnFocus = false
    textBox.ClipsDescendants = true
    textBox.BackgroundTransparency = 1
    textBox.Font = Enum.Font.SourceSans
    textBox.TextSize = 14
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextYAlignment = Enum.TextYAlignment.Center
--  textBox.TextTruncate = Enum.TextTruncate.AtEnd
    textBox.TextWrapped = false
    textBox.TextEditable = (not isReadOnly)

    -- Instance.Name seems like an unnecessary place to have this enabled for
    -- Also Lighting.TimeOfDay
    if ((not isReadOnly) and (main.PropertyNormal ~= "Instance/Name")) then
        local openTextEditorButton = Instance.new("TextButton")
        openTextEditorButton.AnchorPoint = Vector2.new(1, 0.5)
        openTextEditorButton.Size = UDim2.new(0, 30, 1, 0)
        openTextEditorButton.Position = UDim2.new(1, 0, 0.5, 0)
    --  openTextEditorButton.ClipsDescendants = true
        openTextEditorButton.BackgroundTransparency = 0
        openTextEditorButton.BorderSizePixel = 1
        openTextEditorButton.Font = Enum.Font.SourceSans
        openTextEditorButton.TextSize = 14
        openTextEditorButton.TextXAlignment = Enum.TextXAlignment.Center
        openTextEditorButton.TextYAlignment = Enum.TextYAlignment.Center
        openTextEditorButton.Text = "..."

        lib.Themer.SyncProperties(openTextEditorButton, {
            TextColor3 = Enum.StudioStyleGuideColor.ButtonText,
            BorderColor3 = Enum.StudioStyleGuideColor.ButtonBorder,
            BackgroundColor3 = Enum.StudioStyleGuideColor.Button
        })

        openTextEditorButton.MouseButton1Click:Connect(function()
            openWidgetPrompt(main.PropertyNormal, main.GetPropertyValue())
        end)

        ChangePropertySignal:Connect(function(propertyName, newValue)
            if (propertyName ~= main.PropertyNormal) then return end

            main.Update(newValue)
        end)

        openTextEditorButton.Parent = main.Display
    end

    lib.Themer.SyncProperties(textBox, {
        TextColor3 = {Enum.StudioStyleGuideColor.MainText, isReadOnly and Enum.StudioStyleGuideModifier.Disabled or Enum.StudioStyleGuideModifier.Default}
    })

    textBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            main.Update(textBox.Text)
        end
    end)

    main.PropertyValueUpdated:Connect(function(newValue)
        textBox.Text = newValue or ""
    end)

    textBox.Parent = main.Display
end