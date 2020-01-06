local Studio = settings().Studio

local t = require(script.Parent:FindFirstChild("t"))

---

local Themer = {}
local syncedObjects = {}

local colorSpecifierInterface = t.union(
    t.enum(Enum.StudioStyleGuideColor),

    t.wrap(function(value)
        local guideColor, guideModifier = value[1], value[2]
        local guideColorCheck = t.enum(Enum.StudioStyleGuideColor)(guideColor)
        local guideModifierCheck = t.optional(t.enum(Enum.StudioStyleGuideModifier))(guideModifier)

        return guideColorCheck and guideModifierCheck
    end, t.array(t.any))
)

Themer.SyncProperties = t.wrap(function(object, properties)
    for propertyName, colorSpecifier in pairs(properties) do
        local success, value = pcall(function() return object[propertyName] end)

        if (not success) then properties[propertyName] = nil warn("property " .. propertyName .. " does not exist for " .. object.Name) return end
        if (typeof(value) ~= "Color3") then properties[propertyName] = nil warn("property " .. propertyName .. " is not a Color3 for " .. object.Name) return end

        if (typeof(colorSpecifier) == "EnumItem") then
            properties[propertyName] = {colorSpecifier, Enum.StudioStyleGuideModifier.Default}
            colorSpecifier = properties[propertyName]
        end
        
        object[propertyName] = Studio.Theme:GetColor(colorSpecifier[1], colorSpecifier[2])
    end

    syncedObjects[object] = properties
end, t.tuple(t.Instance, t.map(t.string, colorSpecifierInterface)))

function Themer.DesyncProperties(object)
    if (not syncedObjects[object]) then return end

    syncedObjects[object] = nil
end

Themer.SyncProperty = t.wrap(function(object, property, colorSpecifier)
    local success, value = pcall(function() return object[property] end)

    if (not success) then warn("property " .. property .. " does not exist for " .. object.Name) return end
    if (typeof(value) ~= "Color3") then warn("property " .. property .. " is not a Color3 for " .. object.Name) return end

    if (typeof(colorSpecifier) == "EnumItem") then
        colorSpecifier = {colorSpecifier, Enum.StudioStyleGuideModifier.Default}
    end

    if (not syncedObjects[object]) then
        syncedObjects[object] = { [property] = colorSpecifier }
    else
        syncedObjects[object][property] = colorSpecifier
    end
    
    object[property] = Studio.Theme:GetColor(colorSpecifier[1], colorSpecifier[2])
end, t.tuple(t.Instance, t.string, colorSpecifierInterface))

function Themer.DesyncProperty(object, property)
    if (not syncedObjects[object]) then return end

    syncedObjects[object][property] = nil
end

Themer.ThemeChanged = Studio.ThemeChanged

Studio.ThemeChanged:Connect(function()
    for object, properties in pairs(syncedObjects) do
        for propertyName, colorSpecifier in pairs(properties) do
            object[propertyName] = Studio.Theme:GetColor(colorSpecifier[1], colorSpecifier[2])
        end
    end
end)

return Themer