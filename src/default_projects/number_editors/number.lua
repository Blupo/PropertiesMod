-- this is imported from MPW, please review it at some point
local SustainableButton = require(script.Parent:FindFirstChild("SustainableButton"))
local NumberEditorComponents = require(script.Parent:FindFirstChild("NumberEditorComponents"))

local numberMask = function(n)
    local decimalPos = string.find(n, "%.")

    if decimalPos then
        local nInt, nDec = string.sub(n, 1, decimalPos - 1), string.sub(n, decimalPos + 1, #n)
        nInt = string.match(nInt, "^%-?%d+")
        nDec = string.gsub(nDec, "%D+", "")

        return nInt.."."..nDec
    else
        return string.match(n, "^%-?%d*")
    end
end

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
            local n = numberMask(textBox.Text) or ""

        --  if tonumber(n) then main.Update(tonumber(n)) end
            textBox.Text = n
        end)
    end

    main.PropertyValueUpdated:Connect(function(newValue)
        textBox.Text = newValue and string.format("%g", newValue) or ""
    end)

    textBox.Parent = main.Display
    incrementUp.Parent = main.Display
    incrementDown.Parent = main.Display
end