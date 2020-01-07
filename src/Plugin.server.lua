local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local CoreGui = game:GetService("CoreGui")

if (not RunService:IsStudio()) then warn("PropertiesMod only works in Studio") return end
if RunService:IsRunMode() then warn("PropertiesMod only works in Edit mode") return end

---

local root = script.Parent
local includes = root:WaitForChild("includes")

local RobloxAPI = require(includes:WaitForChild("RobloxAPI"):WaitForChild("API"))
local Widget = require(includes:WaitForChild("PropertiesWidget"))

---

local API = RobloxAPI.new(true)
local APIData = API.Data
local APILib = API.Library
local APIOperator = API.Operator

local pluginSettings = --[[plugin:GetSetting("PropertiesMod") and HttpService:JSONDecode(plugin:GetSetting("PropertiesMod")) or--]] {
	Config = {
		Verbose = false,

		ShowInaccessibleProperties = false,
		ShowDeprecatedProperties = false,

		PreloadClasses = "Common",
		-- Common, All, or None,

		EditorColumnWidth = 150,
		RowHeight = 26,

		TextSize = 14,
	},
	
	FilterPreferences = {},
	PropertyCategoryOverrides = {},
	CategoryStateMemory = {},
}

-- SelectionChanged that doesn't spam that much
-- https://devforum.roblox.com/t/weird-selectionchanged-behavior/22024/2
-- Credit to Fractality

local SelectionChanged do
	local selectionChanged = Instance.new("BindableEvent")
	local d0, d1 = true, true
	
	RunService.Heartbeat:Connect(function()
		d0, d1 = true, true
	end)
	
	Selection.SelectionChanged:Connect(function()
		if d0 then
			d0 = false
			selectionChanged:Fire()
		elseif d1 then
			d1 = false
			RunService.Heartbeat:Wait()
			selectionChanged:Fire()
		end
	end)
	
	SelectionChanged = selectionChanged.Event
end

---

local function selectionChanged()
    Widget.ResetScrollPosition()
    Widget.ResetCategoryVisibility()
    Widget.ResetRowVisibility()

    local selection = Selection:Get()
    if (#selection < 1) then return end
    
    local newColumnWidth = 0
    local rowsToAdd = {}

    -- deal with performance issues later
    for i = 1, #selection do
		local obj = selection[i]
		
		local success, isValidClassName = pcall(function()
            -- 1. Query one of the object's properties to see if we can access it
            -- 2. Check the class name to make sure it isn't blank (because that's a thing I guess)

            return (obj.ClassName ~= "")
        end)
        
        if (success and isValidClassName) then
            local properties = APILib:GetProperties(obj.ClassName)
            
            for className, classProperties in pairs(properties) do
                for j = 1, #classProperties do
                    local property = classProperties[j]
                    local propertyCategory = APIData.Classes[className].Properties[property].Category
                    local normalName = Widget.GetPropertyNormalName(className, property)

                    local textWidth = TextService:GetTextSize(property, pluginSettings.Config.TextSize, Enum.Font.SourceSans, Vector2.new()).X
                    if (textWidth > newColumnWidth) then newColumnWidth = textWidth end
                    
                    if Widget.PropertyRows[normalName] then
                        Widget.SetRowVisibility(normalName, true)
                    else
                        rowsToAdd[#rowsToAdd + 1] = {className, property, true}
                    end
                    
                    Widget.SetCategoryVisibility(propertyCategory, true)
                end
            end
        end
    end

    if (#rowsToAdd > 0) then
        Widget.AddRows(rowsToAdd)
    end

    Widget.SetPropertyNameColumnWidth(newColumnWidth + 24 + 10)
end

---

local selectionConnection = SelectionChanged:Connect(selectionChanged)

plugin.Unloading:Connect(function()
    selectionConnection:Disconnect()
    Widget.Unload()

    plugin:SetSetting("PropertiesMod", HttpService:JSONEncode(pluginSettings))
    print("Cleaned up PropertiesMod")
end)

---

if (not pluginSettings.Config.ShowInaccessibleProperties) then
	APIData:RemoveInaccessibleMembers()
end

if (not pluginSettings.Config.ShowDeprecatedProperties) then
	APIData:RemoveDeprecatedMembers()
end

Widget.Init(plugin, pluginSettings, {
    APIData = APIData,
    APILib = APILib
})

-- Preload API

do
	local classes

	if (pluginSettings.Config.PreloadClasses == "All") then
		classes = APIData.Classes
	elseif (pluginSettings.Config.PreloadClasses == "Common") then
		classes = require(includes:WaitForChild("CommonClasses"))
    end

    local rowsToAdd = {}
    if classes then
        for className in pairs(classes) do
			local properties = APILib:GetImmediateProperties(className)
			
            for _, propertyName in pairs(properties) do
                rowsToAdd[#rowsToAdd + 1] = {className, propertyName, false}
            end
        end
    end

    if (#rowsToAdd > 0) then
        Widget.AddRows(rowsToAdd)
    end
end