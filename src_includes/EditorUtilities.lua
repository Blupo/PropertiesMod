local includes = script.Parent

local t = require(includes:WaitForChild("t"))

local SPECIAL_FILTERS = {
    ["Special:Color"]  = {"DataType:BrickColor", "DataType:Color3", "Property:DataModelMesh/VertexColor"},
    ["Special:Color3"] = {"DataType:Color3", "Property:DataModelMesh/VertexColor"},
    ["Special:Vector"] = {"DataType:Vector2", "DataType:Vector3"},
    ["Special:UDim"] = {"DataType:UDim", "DataType:UDim2"},
    ["Special:number"] = {"Primitive:double", "Primitive:float", "Primitive:int"},
}

---

local interfaces = {}
do
    interfaces.EditorInfo = t.interface({
        UniqueId = t.string,
        Name = t.optional(t.string),
        Description = t.optional(t.string),
        Attribution = t.optional(t.string),

        Filters = t.array(t.string),
        EntryPoint = t.optional(t.string),
        Constructor = t.optional(t.callback),
    })

    interfaces.EditorInfoAndEnforceConstructor = t.interface({
        UniqueId = t.string,
        Name = t.optional(t.string),
        Description = t.optional(t.string),
        Attribution = t.optional(t.string),

        Filters = t.array(t.string),
        Constructor = t.callback,
    })

    interfaces.EditorFolder = function(folder)
        if (not t.instanceOf("Folder")(folder)) then return false, "expected Folder" end

        local editorInfoScript = folder:FindFirstChild("editor_info")
        if (not editorInfoScript) then return false, "could not find editor_info" end
        if (not t.instanceOf("ModuleScript")(editorInfoScript)) then return false, "editor_info was not a script" end

        local editorInfo = require(editorInfoScript)
        if (not interfaces.EditorInfo(editorInfo)) then return false, "EditorInfo interface check failed" end

        local entryPoint, constructor = editorInfo.EntryPoint, editorInfo.Constructor
        if (entryPoint and (not constructor)) then
            local entryPointScript = folder:FindFirstChild(entryPoint)
            if (not entryPointScript) then return false, "could not find EntryPoint script" end
            if (not t.instanceOf("ModuleScript")(entryPointScript)) then return false, "EntryPoint script was not a script" end

            constructor = require(entryPointScript)
            if (not t.callback(constructor)) then return false, "EntryPoint script did not return a callback" end

            return true, ""
        elseif ((not entryPoint) and constructor) then
            if (not t.callback(constructor)) then return false, "Constructor is not a callback" end

            return true, ""
        elseif ((not entryPoint) and (not constructor)) then
            return false, "could not find a constructor or entry point"
        else
            return false, "cannot specify both a constructor and entry point, only one"
        end
    end

    interfaces.EditorProjectFolder = function(folder)
        if (not t.instanceOf("Folder")(folder)) then return false, "expected Folder" end

        local projectInfoScript = folder:FindFirstChild("project_info")
        if (not projectInfoScript) then return false, "could not find project_info" end
        if (not t.instanceOf("ModuleScript")(projectInfoScript)) then return false, "project_info was not a script" end

        local projectInfo = require(projectInfoScript)

        for i = 1, #projectInfo do
            local editorInfo = projectInfo[i]
            if (not interfaces.EditorInfo(editorInfo)) then return false, "EditorInfo interface check failed" end

            local entryPoint, constructor = editorInfo.EntryPoint, editorInfo.Constructor
            if (entryPoint and (not constructor)) then
                local entryPointScript = folder:FindFirstChild(entryPoint)
                if (not entryPointScript) then return false, "could not find EntryPoint script" end
                if (not t.instanceOf("ModuleScript")(entryPointScript)) then return false, "EntryPoint script was not a script" end

                constructor = require(entryPointScript)
                if (not t.callback(constructor)) then return false, "EntryPoint script did not return a callback" end

            --  return true, ""
            elseif ((not entryPoint) and constructor) then
                if (not t.callback(constructor)) then return false, "Constructor is not a callback" end

            --  return true, ""
            elseif ((not entryPoint) and (not constructor)) then
                return false, "could not find a constructor or entry point"
            else
                return false, "cannot specify both a constructor and entry point, only one"
            end
        end

        -- EditorInfo checks for ALL editors must pass
        return true, ""
    end

    interfaces.EditorScript = function(script)
        if (not t.instanceOf("ModuleScript")(script)) then return false, "expected ModuleScript" end

        local editorInfo = require(script)
        if (not interfaces.EditorInfoAndEnforceConstructor(editorInfo)) then return false, "EditorInfo interface check failed (EditorScripts must use Constructor)" end

        return true, ""
    end
end

---

local EditorUtils = {}

function EditorUtils.GetFullFilterList(shortFilterList)
    local fullFilterList = {}

    for i = 1, #shortFilterList do
        local filter = shortFilterList[i]

        local specialFilterList = SPECIAL_FILTERS[filter]
        if specialFilterList then
            for j = 1, #specialFilterList do
                local specialFilter = specialFilterList[j]

                fullFilterList[specialFilter] = true
            end
        else
            fullFilterList[filter] = true
        end
    end

    return fullFilterList
end

--[[

    Returns an array of Editors, constructed from either a EditorFolder, EditorProjectFolder, or EditorScript
    (automatically determined by the function)

    @param Variant<EditorFolder, EditorProjectFolder, EditorScript>
    @return array<Editor>

--]]

EditorUtils.ConstructEditors = t.wrap(function(base)
    if interfaces.EditorFolder(base) then
        local editorInfo = require(base:FindFirstChild("editor_info"))

        local newEditor = {
            UniqueId = editorInfo.UniqueId or "",
            Name = editorInfo.Name or editorInfo.UniqueId,
            Description = editorInfo.Description or "",
            Attribution = editorInfo.Attribution or "",

            Filters = EditorUtils.GetFullFilterList(editorInfo.Filters),
        }

        if editorInfo.EntryPoint then
            local constructor = require(base:FindFirstChild(editorInfo.EntryPoint))

            newEditor.Constructor = constructor
        elseif editorInfo.Constructor then
            newEditor.Constructor = editorInfo.Constructor
        end

        return {newEditor}
    elseif interfaces.EditorScript(base) then
        local editorInfo = require(base)

        return {
            {
                UniqueId = editorInfo.UniqueId or "",
                Name = editorInfo.Name or editorInfo.UniqueId,
                Description = editorInfo.Description or "",
                Attribution = editorInfo.Attribution or "",

                Filters = EditorUtils.GetFullFilterList(editorInfo.Filters),
                Constructor = editorInfo.Constructor,
            }
        }
    elseif interfaces.EditorProjectFolder(base) then
        local editors = {}

        local projectInfo = require(base:FindFirstChild("project_info"))

        for i = 1, #projectInfo do
            local editorInfo = projectInfo[i]

            local newEditor = {
                UniqueId = editorInfo.UniqueId or "",
                Name = editorInfo.Name or editorInfo.UniqueId,
                Description = editorInfo.Description or "",
                Attribution = editorInfo.Attribution or "",

                Filters = EditorUtils.GetFullFilterList(editorInfo.Filters),
            }

            if editorInfo.EntryPoint then
                local constructor = require(base:FindFirstChild(editorInfo.EntryPoint))

                newEditor.Constructor = constructor
            elseif editorInfo.Constructor then
                newEditor.Constructor = editorInfo.Constructor
            end

            editors[#editors + 1] = newEditor
        end

        return editors
    else
        warn("how did you get past the type checks?")
        return {}
    end

     --[[
    local newEditor = {
        UniqueId = editorInfo.UniqueId or "",
        Name = editorInfo.Name or editorInfo.UniqueId,
        Description = editorInfo.Description or "",
        Attribution = editorInfo.Attribution or "",

        Filters = normalFilters,
        Constructor = constructor,
    }
    --]]
end, t.union(interfaces.EditorFolder, interfaces.EditorProjectFolder, interfaces.EditorScript))

return EditorUtils