local RunService = game:GetService("RunService")

return function(button, activateCallback, delta)
    delta = delta or 0.005

    local actualDelta = delta
    local activated = false
    local sustained = false
    local sustainedTime = 0
    local last = tick()

    button.MouseButton1Down:Connect(function()
        activated = true

        activateCallback()
        delay(0.5, function()
            if activated then
                sustained = true
                last = tick()
            end
        end)
    end)

    button.MouseButton1Up:Connect(function()
        activated = false
        sustained = false
        sustainedTime = 0
        actualDelta = delta
    end)

    button.MouseButton1Click:Connect(function()
        if activated then return end
        activateCallback()
    end)

    local activatorRepeater
    activatorRepeater = RunService.Heartbeat:Connect(function(step)
        if (not button) then activatorRepeater:Disconnect() activatorRepeater = nil return end
        if (not sustained) then return end

        sustainedTime = sustainedTime + step

        -- decrease delta the longer you hold down the button
        -- todo: fine-tune these values
        if ((sustainedTime > 1) and (sustainedTime <= 5)) then
            actualDelta = delta - (math.log(sustainedTime + 1) * 0.5 * delta)
        end

        if (tick() - last) > actualDelta then
            last = tick()

            activateCallback()
        end
    end)
end