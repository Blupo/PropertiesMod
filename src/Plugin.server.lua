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
local defaultEditors = root:WaitForChild("default_editors")
local defaultExtensions = root:WaitForChild("default_extensions")

local RobloxAPI = require(includes:WaitForChild("RobloxAPI"):WaitForChild("API"))
local EditorUtilities = require(includes:WaitForChild("EditorUtilities"))
local Widget = require(includes:WaitForChild("PropertiesWidget"))
local Themer = require(includes:WaitForChild("Themer"))

---

local DEFAULT_SETTINGS = {
    Config = {
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

local EDITOR_LIB = {
    Themer = Themer,
}

local API = RobloxAPI.new(true)
local APIData = API.Data
local APILib = API.Library
local APIOperator = API.Operator

local editors = {
    ["*"] = EditorUtilities.CompileEditor(defaultEditors:WaitForChild("fallback"))
}
local editorMains = {}

local pluginSettings = plugin:GetSetting("PropertiesMod") and HttpService:JSONDecode(plugin:GetSetting("PropertiesMod")) or DEFAULT_SETTINGS

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

local function purgeDuplicates(tab)
	if (#tab <= 1) then return end
	local x = 1

	repeat
		for i = #tab, x + 1, -1 do
			if (tab[i] == tab[x]) then
				table.remove(tab, i)
			end
		end

		x = x + 1
	until (x >= #tab)
end

local function loadExtension(module)
	local extension = require(module)

	local apiExtensions = extension.API
	local behaviourExtensions = extension.Behaviours

	APIData:Extend(apiExtensions or {})
	APIOperator:ExtendCustomBehaviours(behaviourExtensions or {})
end

local function getEditor(className, propertyName)
    local propertyData = APIData.Classes[className].Properties[propertyName]

    return editors["property:" .. Widget.GetPropertyNormalName(className, propertyName)] or editors["*"]
end

local function loadEditor(className, propertyName)
    local editor = getEditor(className, propertyName)
    if (not editor) then return end

    local normalName = Widget.GetPropertyNormalName(className, propertyName)
    local propertyData = APIData.Classes[className].Properties[propertyName]

    local propertyValueChangedConnections = {}
    local propertyValueUpdatedEvent = Instance.new("BindableEvent")

    local function getHomogeneousValue()
        local selection = Selection:Get()
        local filteredSelection = {}
        
        for i = 1, #selection do
            local obj = selection[i]
            
            if obj:IsA(className) then
                filteredSelection[#filteredSelection + 1] = obj
            end
        end
        
        if (#filteredSelection == 0) then
            return
        elseif (#filteredSelection == 1) then
            return filteredSelection[1][propertyName]
        end
        
        local control = filteredSelection[1][propertyName]
        for i = 1, #filteredSelection do
            local obj = filteredSelection[i]
            if (obj[propertyName] ~= control) then return end
        end
        
        return control
    end
    
    local function setSelectionProperty(value)
        local selection = Selection:Get()

        for i = 1, #selection do
            local obj = selection[i]
            
            if obj:IsA(class) then
                obj[propertyName] = value
            end
        end
    end

    local selectionChanged = SelectionChanged:Connect(function()
        local selection = Selection:Get()
        
        for i = 1, #propertyValueChangedConnections do
            propertyValueChangedConnections[i]:Disconnect()
        end
        propertyValueChangedConnections = {}
        
        for i = 1, #selection do
            local obj = selection[i]
                
            if obj:IsA(className) then
                propertyValueChangedConnections[#propertyValueChangedConnections + 1] = obj:GetPropertyChangedSignal(propertyName):Connect(function()
                    propertyValueUpdatedEvent:Fire(getHomogeneousValue())
                end)
            end
        end
        
        propertyValueUpdatedEvent:Fire(getHomogeneousValue())
    end)

    local main = {
        Display = Widget.PropertyRows[normalName]:FindFirstChild("Editor"),

        PropertyValueUpdated = propertyValueUpdatedEvent.Event,

        _PropertyValueUpdatedEvent = propertyValueUpdatedEvent,
        _SelectionChangedEvent = selectionChanged,
    }

    editor.Constructor(main, EDITOR_LIB, propertyData)
    editorMains[normalName] = main
end

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
                    local propertyName = classProperties[j]
                    local propertyCategory = APIData.Classes[className].Properties[propertyName].Category
                    local normalName = Widget.GetPropertyNormalName(className, propertyName)

                    local textWidth = TextService:GetTextSize(propertyName, pluginSettings.Config.TextSize, Enum.Font.SourceSans, Vector2.new()).X
                    if (textWidth > newColumnWidth) then newColumnWidth = textWidth end
                    
                    if Widget.PropertyRows[normalName] then
                        Widget.SetRowVisibility(normalName, true)
                    else
                        Widget.AddRow(className, propertyName, true)
                    --  rowsToAdd[#rowsToAdd + 1] = {className, propertyName, true}

                        loadEditor(className, propertyName)
                    end
                    
                    Widget.SetCategoryVisibility(propertyCategory, true)
                end
            end
        end
    end
    --[[
    if (#rowsToAdd > 0) then
        Widget.AddRows(rowsToAdd)
    end
    --]]
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

for _, extension in pairs(defaultExtensions:GetChildren()) do
    loadExtension(extension)
end

Widget.Init(plugin, pluginSettings, {
    APIData = APIData,
    APILib = APILib
})

-- Preload Classes

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
			
            for i = 1, #properties do
                local propertyName = properties[i]

                Widget.AddRow(className, propertyName, false)
            --  rowsToAdd[#rowsToAdd + 1] = {className, propertyName, true}

                loadEditor(className, propertyName)
            end
        end
    end
end

-- init

selectionChanged()