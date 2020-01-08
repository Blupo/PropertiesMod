-- create properties for manipulating Terrain.MaterialColors

local apiExtensionTemplate = {
    ExtensionType = "Member",
    MemberClass = "Terrain",
    ExtensionData = {
        MemberType = "Property",
        Category = "Terrain Colors",
        Security = {
            Read = "None",
            Write = "None"
        },
        Serialization = {
            CanLoad = true,
            CanSave = false
        },
        Tags = {},
        ValueType = {
            Category = "DataType",
            Name = "Color3"
        },
    }
}

local behaviourExtensionTemplate = {
    BehaviourType = "Member",
    ClassName = "Terrain",
    MemberType = "Property",
    BehaviourData = {}
}

local function deepCopy(original)
    -- no metatables
    local copy = {}

    if (type(original) == "table") then
        for k, v in pairs(original) do
            copy[deepCopy(k)] = deepCopy(v)
        end
    else
        return original
    end

    return copy
end

---

local extensions = {
    API = {},
    Behaviours = {},
}

local Terrain = game:GetService("Workspace").Terrain
local MaterialEnums = Enum.Material:GetEnumItems()

for _, materialEnum in pairs(MaterialEnums) do
    local success = pcall(function() return Terrain:GetMaterialColor(materialEnum) end)

    if success then
        local newAPIExtension = deepCopy(apiExtensionTemplate)
        newAPIExtension.ExtensionData.Name = materialEnum.Name.."MaterialColor"

        local newBehaviourExtension = deepCopy(behaviourExtensionTemplate)
        newBehaviourExtension.MemberName = materialEnum.Name.."MaterialColor"

        newBehaviourExtension.BehaviourData.Read = function(terrain)
            return terrain:GetMaterialColor(materialEnum)
        end

        newBehaviourExtension.BehaviourData.Write = function(terrain, color)
            terrain:SetMaterialColor(materialEnum, color)
        end

        extensions.API[#extensions.API + 1] = newAPIExtension
        extensions.Behaviours[#extensions.Behaviours + 1] = newBehaviourExtension
    end
end

return extensions