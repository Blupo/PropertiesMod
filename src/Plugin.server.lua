local ChangeHistoryService = game:GetService("ChangeHistoryService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

if (not RunService:IsStudio()) then warn("PropertiesMod only works in Studio") return end
if RunService:IsRunMode() then warn("PropertiesMod only works in Edit mode") return end

---

local root = script.Parent

local includes = root:WaitForChild("includes")
local defaultEditors = root:WaitForChild("default_editors")
local defaultProjects = root:FindFirstChild("default_projects")
local defaultExtensions = root:WaitForChild("default_extensions")

local RobloxAPI = require(includes:WaitForChild("RobloxAPI"))
local EditorUtilities = require(includes:WaitForChild("EditorUtilities"))
local Widget = require(includes:WaitForChild("PropertiesWidget"))
local Themer = require(includes:WaitForChild("Themer"))
local t = require(includes:FindFirstChild("t"))

---

local DEFAULT_SETTINGS = {
    Config = {
        CacheDuration = 7 * 86400,
        -- 7 days

        ShowInaccessibleProperties = false,
        ShowDeprecatedProperties = false,
        ShowHiddenProperties = false,

        PreloadClasses = "Common",
        -- Common, All, or None,

        EditorColumnWidth = 100,
        RowHeight = 26,
        TextSize = 14,
    },

    Cache = {
        LastFetchTime = 0,
    },

    FilterPreferences = {},
    PropertyCategoryOverrides = {},
    CategoryStateMemory = {},
}

local EDITOR_LIB = {
    Themer = Themer,
}

local PRIMITIVES_MAP = {
    bool = "boolean",
    float = "number",
    double = "number",
    int64 = "integer",
    int = "integer",
}

local T_MAP = {
    bool = "boolean",
    float = "number",
    double = "number",
    int64 = "integer",
    int = "integer"
}

local API
local APIData
local APILib
local APIOperator

local editors = {
    ["*"] = EditorUtilities.CompileEditor(defaultEditors:WaitForChild("fallback"))
}

local cachedPluginObjects = {}

local pluginSettings = DEFAULT_SETTINGS
--plugin:GetSetting("PropertiesMod") and HttpService:JSONDecode(plugin:GetSetting("PropertiesMod")) or DEFAULT_SETTINGS

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

local function getPropertyType(className, propertyName)
    local propertyData = APIData.Classes[className].Properties[propertyName]
    local propertyValueType = propertyData.ValueType

    local category = propertyValueType.Category
    local name = propertyValueType.Name

    if (category == "Primitive") then
        local primitiveNormalName = PRIMITIVES_MAP[name] and PRIMITIVES_MAP[name] or name

        return "primitive:" .. primitiveNormalName
    elseif (category == "DataType") then
        return "roblox:" .. name
    elseif (category == "Enum") then
        return "enum"
    end

    return "*"
end

local function getEditor(className, propertyName)
    return editors["property:" .. Widget.GetPropertyNormalName(className, propertyName)] or
        editors[getPropertyType(className, propertyName)] or
        editors["*"]
end

local function getSafeSelection()
    local selection = Selection:Get()
    local filteredSelection = {}

    for i = 1, #selection do
        local obj = selection[i]

        local success, isValidClassName = pcall(function()
            -- 1. Query one of the object's properties to see if it passes the security check
            -- 2. Check the class name to make sure it isn't blank (because that's a thing I guess)

            return (obj.ClassName ~= "")
        end)

        if (success and isValidClassName) then
            filteredSelection[#filteredSelection + 1] = obj
        end
    end

    return filteredSelection
end

local function loadEditor(className, propertyName)
    local editor = getEditor(className, propertyName)
    if (not editor) then return end

    local uniqueId = editor.EditorInfo.UniqueId
    local normalName = Widget.GetPropertyNormalName(className, propertyName)
    local propertyData = APIData.Classes[className].Properties[propertyName]

--  local propertyValueChangedConnections = {}
    local propertyValueUpdatedEvent = Instance.new("BindableEvent")

    local function getHomogeneousValue()
        local selection = getSafeSelection()
        if (#selection <= 0) then return end

        local filteredSelection = {}

        for i = 1, #selection do
            local obj = selection[i]

            if obj:IsA(className) then
                filteredSelection[#filteredSelection + 1] = obj
            end
        end

        if (#filteredSelection <= 0) then
            return
        elseif (#filteredSelection == 1) then
            return APIOperator:GetProperty(filteredSelection[1], propertyName, className)
        end

        local control = APIOperator:GetProperty(filteredSelection[1], propertyName, className)
        for i = 1, #filteredSelection do
            local obj = filteredSelection[i]

            if (APIOperator:GetProperty(obj, propertyName, className) ~= control) then return end
        end

        return control
    end

    local updatingMode = "write"
    local function setSelectionPropertyCallback(value)
        if (updatingMode == "no_updates") then return end

        local selection = getSafeSelection()

        if (updatingMode == "write") then
            ChangeHistoryService:SetWaypoint("PropertiesMod.BeforeSet:" .. normalName)
        end

        for i = 1, #selection do
            local obj = selection[i]

            if obj:IsA(className) then
                obj[propertyName] = value
            end
        end

        if (updatingMode == "write") then
            ChangeHistoryService:SetWaypoint("PropertiesMod.AfterSet:" .. normalName)
        end

        propertyValueUpdatedEvent:Fire(getHomogeneousValue())
    end

    local setSelectionProperty
    do
    --  local propertyData = APIData.Classes[className].Properties[propertyName]
        local propertyValueType = propertyData.ValueType

        local category = propertyValueType.Category
        local name = propertyValueType.Name

        if (category == "Primitive") then
            setSelectionProperty = t.wrap(setSelectionPropertyCallback, T_MAP[name] and t[T_MAP[name]] or t[name])
        elseif (category == "DataType") then
            setSelectionProperty = t.wrap(
                setSelectionPropertyCallback,
                (name ~= "Content") and t[name] or t.string
            )
        elseif (category == "Enum") then
            setSelectionProperty = t.wrap(setSelectionPropertyCallback, t.enum(Enum[name]))
        end
    end

    local selectionChanged = SelectionChanged:Connect(function()
    --[[
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
    --]]

        propertyValueUpdatedEvent:Fire(getHomogeneousValue())
    end)

    local main = {
        Display = Widget.PropertyRows[normalName]:FindFirstChild("Editor"),

        CreateDockWidgetPluginGui = function(dockWidgetPluginGuiInfo)
            local pluginGuiName = "PropertiesMod.PluginGuis:" .. uniqueId

            local cachedPluginGui = cachedPluginObjects[pluginGuiName]

            if (not cachedPluginGui) then
                cachedPluginObjects[pluginGuiName] = plugin:CreateDockWidgetPluginGui(pluginGuiName, dockWidgetPluginGuiInfo)
                return cachedPluginObjects[pluginGuiName]
            else
                return cachedPluginGui
            end
        end,
        CreatePluginAction = function(...) return plugin:CreatePluginAction(...) end,
        CreatePluginMenu = function(...) return plugin:CreatePluginMenu(...) end,

        Update = setSelectionProperty,

        GetUpdatingMode = function() return updatingMode end,
        SetUpdatingMode = function(newUpdatingMode)
            if ((newUpdatingMode == "write") or (newUpdatingMode == "preview") or (newUpdatingMode == "no_updates")) then
                updatingMode = newUpdatingMode
            end
        end,

        PropertyValueUpdated = propertyValueUpdatedEvent.Event,
        _PropertyValueUpdatedEvent = propertyValueUpdatedEvent,

        _SelectionChangedEvent = selectionChanged,
    }

    editor.Constructor(main, EDITOR_LIB, propertyData)
    propertyValueUpdatedEvent:Fire(getHomogeneousValue())
end

local function selectionChanged()
    Widget.ResetScrollPosition()
    Widget.ResetCategoryVisibility()
    Widget.ResetRowVisibility()

    local selection = getSafeSelection()
    if (#selection <= 0) then return end

    local newColumnWidth = 0
--  local rowsToAdd = {}

    -- deal with performance issues later
    for i = 1, #selection do
        local obj = selection[i]
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

--- Load API

do
    local lastFetchTime = pluginSettings.Cache.LastFetchTime
    local cacheDuration = pluginSettings.Config.CacheDuration

    local rawAPIData
    if ((tick() - lastFetchTime) >= cacheDuration) then
        print("[PropertiesMod] Fetching the latest API, please wait...")
        print("[PropertiesMod] Fetching from https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/API-Dump.json")

        local success, data = pcall(function() return HttpService:GetAsync("https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/API-Dump.json") end)
        if (not success) then
            warn("[PropertiesMod] Could not get API data, got error: " .. data)
            return nil
        end

        rawAPIData = HttpService:JSONDecode(data)
        pluginSettings.Cache.Data = rawAPIData

        print("[PropertiesMod] Successfully loaded data")
    else
        rawAPIData = pluginSettings.Cache.Data

        print("[PropertiesMod] Loaded cached data")
    end

    API = RobloxAPI.new(rawAPIData, true)
    APIData = API.Data
    APILib = API.Library
    APIOperator = API.Operator
end

if (not pluginSettings.Config.ShowInaccessibleProperties) then
    APIData:RemoveInaccessibleMembers()
end

if (not pluginSettings.Config.ShowDeprecatedProperties) then
    APIData:RemoveDeprecatedMembers()
end

if (not pluginSettings.Config.ShowHiddenProperties) then
    APIData:RemoveHiddenProperties()
end

APIData:RemoveLocalUserSecurityMembers()
APIData:MarkNotAccessibleSecurityPropertiesAsReadOnly()

for _, extension in pairs(defaultExtensions:GetChildren()) do
    loadExtension(extension)
end

-- BasePart/CenterOfMass is disabled, so it's being removed until it's enabled
APIData.Classes.BasePart.Properties.CenterOfMass = nil

-- Instance/RobloxLocked cannot be accessed, but isn't marked in the API as such
APIData.Classes.Instance.Properties.RobloxLocked = nil

Widget.Init(plugin, pluginSettings, {
    APIData = APIData,
    APILib = APILib
})

-- Load Editors

local function addEditor(editor)
    local uniqueId = editor.EditorInfo.UniqueId
    if (uniqueId == "editor.$native.fallback") then return end

    local filters = editor.EditorInfo.Filters

    for i = 1, #filters do
        local filter = filters[i]

        if string.match(filter, "instance:") then
            warn("Instance editors are not supported")
        else
            if (not editors[filter]) then
                editors[filter] = editor

            --  print("loaded editor " .. uniqueId)
            else
                if (pluginSettings.FilterPreferences[filter] == uniqueId) then
                    editors[filter] = editor

                --  print("loaded editor " .. uniqueId)
                end
            end
        end
    end
end

do
    for _, editor in pairs(defaultEditors:GetChildren()) do
        local compiledEditor = EditorUtilities.CompileEditor(editor)
        if compiledEditor then addEditor(compiledEditor) end
    end

    for _, project in pairs(defaultProjects:GetChildren()) do
        local projectEditors = EditorUtilities.CompileEditorsFromProject(project)

        for _, editor in pairs(projectEditors) do
            addEditor(editor)
        end
    end
end

-- Preload Classes

do
    local classes

    if (pluginSettings.Config.PreloadClasses == "All") then
        classes = APIData.Classes
    elseif (pluginSettings.Config.PreloadClasses == "Common") then
        classes = require(includes:WaitForChild("CommonClasses"))
    end

--  local rowsToAdd = {}
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