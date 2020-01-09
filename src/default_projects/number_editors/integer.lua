-- this is imported from MPW, please review it at some point
local SustainableButton = require(script.Parent:FindFirstChild("SustainableButton"))
local NumberEditorComponents = require(script.Parent:FindFirstChild("NumberEditorComponents"))

local NON_INT_PATTERN = "[^%-0-9]"

return function(main, lib, propertyData)
    local isReadOnly = propertyData.Tags.ReadOnly

    local textBox, incrementUp, incrementDown = NumberEditorComponents(lib.Themer, isReadOnly)

    if (not isReadOnly) then
        SustainableButton(incrementUp, function()
            textBox.Text = tostring(tonumber(textBox.Text) + 1)
        end, 0.25)

        SustainableButton(incrementDown, function()
            textBox.Text = tostring(tonumber(textBox.Text) - 1)
        end, 0.25)

        textBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                main.Update(tonumber(textBox.Text) or 0)
            end
        end)

        textBox:GetPropertyChangedSignal("Text"):Connect(function()
            textBox.Text = string.gsub(textBox.Text, NON_INT_PATTERN, "")
        end)
    end

    main.PropertyValueUpdated:Connect(function(newValue)
        textBox.Text = newValue or ""
    end)

    textBox.Parent = main.Display
    incrementUp.Parent = main.Display
    incrementDown.Parent = main.Display
end