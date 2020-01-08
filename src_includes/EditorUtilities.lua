local includes = script.Parent

local t = require(includes:WaitForChild("t"))

---

local verifyEditorInfo = t.interface({
    UniqueId = t.string,
    Name = t.optional(t.string),
    Description = t.optional(t.string),
    Attribution = t.optional(t.string),

    Filters = t.array(t.string),
    EntryPoint = t.string,
})

local EditorUtils = {}

function EditorUtils.GetEditorInfo(dir)
    local editorInfoScript = dir:FindFirstChild("editor_info")
    if (not t.instanceOf("ModuleScript")(editorInfoScript)) then return end

    local editorInfo = require(editorInfoScript)
    if (not verifyEditorInfo(editorInfo)) then return end

    return editorInfo
end

function EditorUtils.CompileEditor(dir)
    local editorInfo = EditorUtils.GetEditorInfo(dir)
    if (not editorInfo) then return end

    local entryPointScript = dir:FindFirstChild(editorInfo.EntryPoint)
    if (not t.instanceOf("ModuleScript")(entryPointScript)) then return end

    local constructor = require(entryPointScript)
    if (not t.callback(constructor)) then return end

    return {
        EditorInfo = editorInfo,
        Constructor = constructor,
    }
end

return EditorUtils