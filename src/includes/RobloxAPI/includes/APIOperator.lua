local primitivesMap = {
	bool = "boolean",
	int64 = "int",
	void = "nil",
	float = "number",
	double = "number"
}

local function checkDataType(value, dataTypeIndicator)	
	local valueCategory = dataTypeIndicator.Category
	local valueName = dataTypeIndicator.Name
	
	if (valueCategory == "Primitive") then
		local primitveNormal = primitivesMap[valueName] and primitivesMap[valueName] or valueName
		
		if (primitveNormal == "int") then
			if (type(value) ~= "number") then return false end
			return (value == math.floor(value))
		else
			return (type(value) == primitveNormal)
		end
	elseif (valueCategory == "DataType") then
		if (valueName ~= "Objects") then
			return (typeof(value) == valueName)
		else
			if (type(value) ~= "table") then return false end
			
			for i = 1, #value do
				local object = value[i]
				if (typeof(object) ~= "Instance") then return false end
			end
		end
	elseif (valueCategory == "Enum") then
		if (typeof(value) ~= "EnumItem") then return false end
		return (value.EnumItem ~= Enum[valueName])
	elseif (valueCategory == "Class") then
		if (typeof(value) ~= "Instance") then return false end
		return value:IsA(valueName)
	elseif (valueCategory == "Group") then
		if ((valueName == "Map") or (valueName == "Array") or (valueName == "Dictionary")) then
			return (type(value) == "table")
		elseif (valueName == "Variant") then
			return true
		elseif (valueName == "Tuple") then
			return true
		end
	end
	
	return false
end
		
local function customBehaviourSanityCheck(customBehaviour)
	if (type(customBehaviour) ~= "table") then return false, "custom behaviour must be a table, got "..type(customBehaviour) end
	
	if (not customBehaviour.BehaviourType) then return false, "missing behaviour type" end
	if (type(customBehaviour.BehaviourType) ~= "string") then return false, "behaviour type must be a string, got "..type(customBehaviour.BehaviourType) end
	
	if (not customBehaviour.ClassName) then return false, "missing class name" end
	if (type(customBehaviour.ClassName) ~= "string") then return false, "class name must be a string, got "..type(customBehaviour.ClassName) end
		
	if (customBehaviour.BehaviourType == "Member") then
		if (not customBehaviour.MemberType) then return false, "missing member type" end
		if (type(customBehaviour.MemberType) ~= "string") then return false, "member type must be a string, got "..type(customBehaviour.MemberType) end
		
		local memberType = customBehaviour.MemberType
		if ((memberType ~= "Property") and (memberType ~= "Function")) then
			return false, "only property and function members are currently supported"
		end
		
		if (not customBehaviour.MemberName) then return false, "missing member name" end
		if (type(customBehaviour.MemberName) ~= "string") then return false, "member name must be a string, got "..type(customBehaviour.MemberName) end
		
		if (memberType == "Property") then
			if (not customBehaviour.BehaviourData) then return false, "missing behaviour data" end
			if (type(customBehaviour.BehaviourData) ~= "table") then return false, "behaviour data must be a table, got "..type(customBehaviour.BehaviourData) end
			
			if (not customBehaviour.BehaviourData.Read) then return false, "missing read behaviour" end
			if (type(customBehaviour.BehaviourData.Read) ~= "function") then return false, "read behaviour must be a fucntion, got "..type(customBehaviour.BehaviourData.Read) end
		elseif (memberType == "Function") then
			if (not customBehaviour.BehaviourData) then return false, "missing behaviour data" end
			if (type(customBehaviour.BehaviourData) ~= "function") then return false, "behaviour data must be a function, got "..type(customBehaviour.BehaviourData) end
		end
	elseif (customBehaviour.BehaviourType == "Class") then
		if (not customBehaviour.BehaviourData) then return false, "missing behaviour data" end
		if (type(customBehaviour.BehaviourData) ~= "function") then return false, "behaviour data must be a function, got "..type(customBehaviour.BehaviourData) end
	else
		return false, "unsupported behaviour type"
	end
	
	return true
end

---

local APIOperator = {}

function APIOperator.new(apiData)
	assert(apiData, "API data missing")
	
	local self = {
		APIData = apiData,
	}
	setmetatable(self, {__index = APIOperator})
	
	return self
end

function APIOperator:GetProperty(object, propertyName, className)
	className = className or object.ClassName
	
	local apiData = self.APIData
	local apiClass = apiData.Classes[className]
	assert(apiClass, "class does not exist")
	
	local property = apiClass.Properties[propertyName]
	assert(property, propertyName.." is not a valid member of "..className)
	
	if property.Native then
		return object[propertyName]
	else
		local customBehaviour = property.__customBehaviour
		assert(customBehaviour, "behaviour is not defined for "..propertyName)
		
		return customBehaviour.Read(object)
	end
end

function APIOperator:SetProperty(object, propertyName, newValue, className)
	className = className or object.ClassName
	
	local apiData = self.APIData
	local apiClass = apiData.Classes[className]
	assert(apiClass, "class does not exist")
	
	local property = apiClass.Properties[propertyName]
	assert(property, propertyName.." is not a valid member of "..className)
	if (property.Tags.ReadOnly) then warn("cannot set read-only "..propertyName) return end
	
	assert(checkDataType(newValue, property.ValueType), "unexpected value to set")
	
	if property.Native then
		object[propertyName] = newValue
	else
		local customBehaviour = property.__customBehaviour
		assert(customBehaviour, "behaviour is not defined for "..propertyName)
		
		customBehaviour.Write(object)
	end
end

function APIOperator:ExecuteFunction(object, functionName, arguments, className)
	className = className or object.ClassName
	
	local apiData = self.APIData
	local apiClass = apiData.Classes[className]
	assert(apiClass, "class does not exist")
	
	local functionMember = apiClass.Functions[functionName]
	assert(functionMember, functionName.." is not a valid member of "..className)
	
	if functionMember.Native then
		return object[functionName](object, unpack(arguments))
	else
		local customBehaviour = functionMember.__customBehaviour
		assert(customBehaviour, "behaviour is not defined for "..functionName)
		
		return customBehaviour(object, unpack(arguments))
	end
end

function APIOperator:IsA(object, className)
	local apiData = self.APIData
	local apiClass = apiData.Classes[className]
	assert(apiClass, "class does not exist")
	
	if apiClass.Native then
		return object:IsA(className)
	else
		-- todo: respect inheritance
		local customBehaviour = apiClass.__customBehaviour
		assert(customBehaviour, "behaviour is not defined for "..className)
		
		return customBehaviour(object)
	end
end

function APIOperator:ExtendCustomBehaviours(customBehaviours)
	local function addCustomBehaviour(customBehaviour)
		local checkPass, checkMsg = customBehaviourSanityCheck(customBehaviour)
		if (not checkPass) then warn("custom behaviour check failed, got message: "..checkMsg) return end
		
		local className = customBehaviour.ClassName
		local class = self.APIData.Classes[className]
		if (not class) then warn(className.." is not a valid class") return false end
		
		if (customBehaviour.BehaviourType == "Member") then
			local memberType = customBehaviour.MemberType
			local memberName = customBehaviour.MemberName
			
			local member do
				if (memberType == "Function") then
					member = class.Functions[memberName]
				elseif (memberType == "Property") then
					member = class.Properties[memberName]
				end
			end
			if (not member) then warn(memberName.." is not a valid member of "..className) return end
			if member.Native then warn("custom behaviours cannot be defined for native members") return end
			if member.__customBehaviour then warn("behaviour is already defined for "..memberName) return end
			
			if (memberType == "Property") then
				if member.ReadOnly then
					member.__customBehaviour = customBehaviour.BehaviourData
				else
					if (not customBehaviour.BehaviourData.Write) then warn("missing write behaviour") return end
					if (type(customBehaviour.BehaviourData.Write) ~= "function") then warn("write behaviour must be a function, got "..type(customBehaviour.BehaviourData.Write)) return end
						
					member.__customBehaviour = customBehaviour.BehaviourData
				end
			elseif (memberType == "Function") then
				member.__customBehaviour = customBehaviour.BehaviourData
			end
		elseif (customBehaviour.BehaviourType == "Class") then
			if class.Native then warn("custom behaviours cannot be defined for native classes") return end
			if class.__customBehaviour then warn("behaviour is already defined for "..className) return end
			
			class.__customBehaviour = customBehaviour.BehaviourData
		end
	end
	
	for i = 1, #customBehaviours do
		local customBehaviour = customBehaviours[i]
		addCustomBehaviour(customBehaviour)
	end 
end

return APIOperator