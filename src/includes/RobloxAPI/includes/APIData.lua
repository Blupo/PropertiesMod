-- creating a new API takes ~0.25s

local APIData = {}
local t = require(script.Parent:WaitForChild("t"))

local RobloxAPI = require(2247441113)
local RobloxAPIDump = RobloxAPI.ApiDump
local RobloxAPIClasses = RobloxAPIDump.Classes

local dataSanityChecks = {}
local apiSanityChecks = {}

local function arrayToDict(array)
	local dict = {}
	
	for i = 1, #array do
		local value = array[i]
		dict[value] = true
	end
	
	return dict
end

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

dataSanityChecks["Extension"] = function(extension)
	if (not extension.ExtensionType) then return false, "missing extension type" end
	if (type(extension.ExtensionType) ~= "string") then return false, "extension type must be a string, got "..type(extension.ExtensionType) end
	
	if (extension.ExtensionType == "Member") then
		if (not extension.MemberClass) then return false, "missing class that this member belongs to" end
		if (type(extension.MemberClass) ~= "string") then return false, "member class must be a string, got "..type(extension.MemberClass) end
	elseif (extension.ExtensionType == "Class") then
		if (not extension.Superclass) then return false, "missing superclass name" end
		if (type(extension.Superclass) ~= "string") then return false, "superclass must be a string, got "..type(extension.Superclass) end
	end
	
	if (not extension.ExtensionData) then return false, "missing extension data" end -- I mean, the extension data is KIND OF IMPORTANT.
	
	if (extension.ExtensionType == "Member") then
		local isMember, memberCheckMsg = apiSanityChecks.Member(extension.ExtensionData)
		if (not isMember) then return false, "member check failed: "..memberCheckMsg end
		
		local isValidMember, validMemberCheckMsg = apiSanityChecks[extension.ExtensionData.MemberType](extension.ExtensionData)
		if (not isValidMember) then return false, "member check failed: "..validMemberCheckMsg end
	elseif (extension.ExtensionType == "Class") then
		local classIsValid, classCheckMsg = dataSanityChecks.Class(extension.ExtensionData)
		if (not classIsValid) then return false, classCheckMsg end
	else
		return false, "unsupported extension type "..extension.ExtensionType
	end
	
	return true
end

dataSanityChecks["DataTypeDescriptor"] = function(dataTypeDescriptor)
	if (not dataTypeDescriptor.Name) then return false, "missing name" end
	if (type(dataTypeDescriptor.Name) ~= "string") then return false, "name must be a string, got "..type(dataTypeDescriptor.Name) end
	
	if (not dataTypeDescriptor.Category) then return false, "missing category" end
	if (type(dataTypeDescriptor.Category) ~= "string") then return false, "category must be a string, got "..type(dataTypeDescriptor.Category) end
	
	return true
end

dataSanityChecks["ParameterDescriptor"] = function(parameterDescriptor)
	if (not parameterDescriptor.Name) then return false, "missing name" end
	if (type(parameterDescriptor.Name) ~= "string") then return false, "name must be string, got "..type(parameterDescriptor.Name) end
	
	local dataTypeDescSuccess, checkMsg = dataSanityChecks.DataTypeDescriptor(parameterDescriptor.Type)
	if (not dataTypeDescSuccess) then return false, checkMsg end
	
	return true
end

dataSanityChecks["FunctionParameterDescriptor"] = function(functionParameterDescriptor)
	local parameterDescSuccess, checkMsg = dataSanityChecks.ParameterDescriptor(functionParameterDescriptor)
	if (not parameterDescSuccess) then return false, checkMsg end
	
	if (type(functionParameterDescriptor.Default) ~= "nil") then
		if (type(functionParameterDescriptor.Default) ~= "string") then return false, "default must be a string, got "..type(functionParameterDescriptor.Default) end
	end
	
	return true
end

dataSanityChecks["Class"] = function(class)
	if (not class.Name) then return false, "missing name" end
	if (type(class.Name) ~= "string") then return false, "name must be a string, got "..type(class.Name) end
	
--	if (not class.MemoryCategory) then return false, "missing memory category" end
--	if (type(class.MemoryCategory) ~= "string") then return false, "memory category must be a string, got "..type(class.MemoryCategory) end
	
	if (not class.Tags) then return false, "missing tags" end
	if (type(class.Tags) ~= "table") then return "tags must be a table, got "..type(class.Tags) end
	
	if (not class.Callbacks) then return false, "missing callbacks" end
	if (not class.Events) then return false, "missing events" end
	if (not class.Functions) then return false, "missing functions" end
	if (not class.Properties) then return false, "missing properties" end
	if (type(class.Callbacks) ~= "table") then return false, "callbacks must be a table, got "..type(class.Callbacks) end
	if (type(class.Events) ~= "table") then return false, "events must be a table, got "..type(class.Events) end
	if (type(class.Functions) ~= "table") then return false, "functions must be a table, got "..type(class.Functions) end
	if (type(class.Properties) ~= "table") then return false, "properties must be a table, got "..type(class.Properties) end
	
	for i = 1, #class.Callbacks do
		local member = class.Callbacks[i]
		
		local memberIsValid, memberCheckMsg = apiSanityChecks.Member(member)
		if (not memberIsValid) then return false, "member failed check: "..memberCheckMsg end
		
		local callbackIsValid, callbackCheckMsg = apiSanityChecks.Callback(member)
		if (not callbackIsValid) then return false, "callback failed check: "..callbackCheckMsg end
	end
	
	for i = 1, #class.Events do
		local member = class.Callbacks[i]
		
		local memberIsValid, memberCheckMsg = apiSanityChecks.Member(member)
		if (not memberIsValid) then return false, "member failed check: "..memberCheckMsg end
		
		local eventIsValid, eventCheckMsg = apiSanityChecks.Callback(member)
		if (not eventIsValid) then return false, "callback failed check: "..eventCheckMsg end
	end
	
	for i = 1, #class.Functions do
		local member = class.Callbacks[i]
		
		local memberIsValid, memberCheckMsg = apiSanityChecks.Member(member)
		if (not memberIsValid) then return false, "member failed check: "..memberCheckMsg end
		
		local functionIsValid, functionCheckMsg = apiSanityChecks.Callback(member)
		if (not functionIsValid) then return false, "callback failed check: "..functionCheckMsg end
	end
	
	for i = 1, #class.Properties do
		local member = class.Callbacks[i]
		
		local memberIsValid, memberCheckMsg = apiSanityChecks.Member(member)
		if (not memberIsValid) then return false, "member failed check: "..memberCheckMsg end
		
		local propertyIsValid, propertyCheckMsg = apiSanityChecks.Callback(member)
		if (not propertyIsValid) then return false, "callback failed check: "..propertyCheckMsg end
	end
	
	return true
end

---

apiSanityChecks["Member"] = function(member)
	if (not member.Name) then return false, "missing name" end
	if (not member.MemberType) then return false, "missing member type" end
	if (not member.Tags) then return false, "missing tags table" end
	
	if (type(member.Name) ~= "string") then return false, "name must be a string, got "..type(member.Name) end
	if (type(member.MemberType) ~= "string") then return false, "member type must be a string, got "..type(member.MemberType) end
	if (type(member.Tags) ~= "table") then return false, "tags must be a table, got "..type(member.Tags) end
	
	if (not member.Security) then return false, "missing security" end
	
	if (member.MemberType == "Property") then
		if (type(member.Security) ~= "table") then return false, "security must be a table, got "..type(member.Security) end
		
		if (not member.Security.Read) then return false, "missing read security" end
		if (not member.Security.Write) then return false, "missing write security" end
		if (type(member.Security.Read) ~= "string") then return false, "read security must be a string, got"..type(member.Security.Read) end
		if (type(member.Security.Write) ~= "string") then return false, "write security must be a string, got"..type(member.Security.Write) end
	else
		if (type(member.Security) ~= "string") then return false, "security must be a string, got "..type(member.Security) end
	end
	
	if (not apiSanityChecks[member.MemberType]) then return false, "unknown member type "..member.MemberType end
	
	return true
end

apiSanityChecks["Callback"] = function(member)
	local returnTypeSuccess, returnTypeCheckMsg = dataSanityChecks.DataTypeDescriptor(member.ReturnType)
	if (not returnTypeSuccess) then return false, returnTypeCheckMsg end
	
	if (not member.Parameters) then return false, "missing parameters" end
	if (type(member.Parameters) ~= "table") then return false, "parameters must be a table, got "..type(member.Parameters) end
	
	for i = 1, #member.Parameters do
		local parameter = member.Parameters[i]
		
		local parameterDescSuccess, parameterDescCheckMsg = dataSanityChecks.ParameterDescriptor(parameter)
		if (not parameterDescSuccess) then return false, string.format("parameter failed check (%s): %s", (parameter.Name or "unknown parameter"), parameterDescCheckMsg) end
	end
	
	return true
end

apiSanityChecks["Event"] = function(member)
	if (not member.Parameters) then return false, "missing parameters" end
	if (type(member.Parameters) ~= "table") then return false, "parameters must be a table, got "..type(member.Parameters) end
	
	for i = 1, #member.Parameters do
		local parameter = member.Parameters[i]
		
		local parameterDescSuccess, checkMsg = dataSanityChecks.ParameterDescriptor(parameter)
		if (not parameterDescSuccess) then return false, string.format("parameter failed check (%s): %s", (parameter.Name or "unknown parameter"), checkMsg) end
	end
	
	return true
end

apiSanityChecks["Function"] = function(member)
	local dataTypeDescSuccess, dataTypeDescCheckMsg = dataSanityChecks.DataTypeDescriptor(member.ReturnType)
	if (not dataTypeDescSuccess) then return false, dataTypeDescCheckMsg end
	
	if (not member.Parameters) then return false, "missing parameters" end
	if (type(member.Parameters) ~= "table") then return false, "parameters must be a table, got "..type(member.Parameters) end
	
	for i = 1, #member.Parameters do
		local parameter = member.Parameters[i]
		
		local functionParameterDescSuccess, functionParameterDescCheckMsg = dataSanityChecks.FunctionParameterDescriptor(parameter)
		if (not functionParameterDescSuccess) then return false, string.format("parameter failed check (%s): %s", (parameter.Name or "unknown parameter"), functionParameterDescCheckMsg) end
	end
	
	return true
end

apiSanityChecks["Property"] = function(member)
	if (not member.Category) then return false, "missing category" end
	if (type(member.Category) ~= "string") then return false, "category must be a string, got "..type(member.Category) end
	
	if (not member.Serialization) then return false, "missing serialization" end
	if (type(member.Serialization) ~= "table") then return false, "serialization must be a category, got "..type(member.Serialization) end
	
	-- it's a boolean so it can be false
--	if (not member.Serialization.CanLoad) then return false, "missing canLoad serialization" end
--	if (not member.Serialization.CanSave) then return false, "missing canSave serialization" end
	if (type(member.Serialization.CanLoad) ~= "boolean") then return false, "canLoad must be a boolean, got "..type(member.Serialization.CanLoad) end
	if (type(member.Serialization.CanSave) ~= "boolean") then return false, "canSave must be a boolean, got "..type(member.Serializaion.CanSave) end
	
	local valueTypeSuccess, checkMsg = dataSanityChecks.DataTypeDescriptor(member.ValueType)
	if (not valueTypeSuccess) then return false, checkMsg end
	
	return true
end

---

function APIData.new()
	local self = {
		Classes = {}
	}
	setmetatable(self, {__index = APIData})
	
	local Classes = self.Classes
	
	do		
		--- set-up tracking for the Roblox API to load completely
		local allClassesLoadedEvent = Instance.new("BindableEvent")
		local allClassesLoaded = allClassesLoadedEvent.Event
		
		local classesLeft = 0
		local startTime = tick()
		---
		
		for i = 1, #RobloxAPIClasses do
			classesLeft = classesLeft + 1
			
			local robloxClass = RobloxAPIClasses[i]
			local robloxClassMembers = robloxClass.Members
			
			if (robloxClass.Superclass == "<<<ROOT>>>") then
				robloxClass.Superclass = nil
			end
			
			local classData = {
				Callbacks = {},
				Events = {},
				Functions = {},
				Properties = {},
				
				Name = robloxClass.Name,
				Native = true,
				Tags = arrayToDict(robloxClass.Tags or {}) -- if the class has no tags it is not present
			--	Superclass = {}
			}
			
			for i = 1, #robloxClassMembers do
				local classMember = deepCopy(robloxClassMembers[i])
				local memberType = classMember.MemberType
				
				classMember.Native = true
				classMember.Tags = arrayToDict(classMember.Tags or {}) -- if the member has no tags it is not present
				
				if (memberType == "Callback") then
					classData.Callbacks[classMember.Name] = classMember
				elseif (memberType == "Event") then
					classData.Events[classMember.Name] = classMember
				elseif (memberType == "Function") then
					classData.Functions[classMember.Name] = classMember
				elseif (memberType == "Property") then
					classData.Properties[classMember.Name] = classMember
				else
					-- is there a new member type?
					warn("unknown member type "..memberType)
				end
			end
			
			-- wait for superclass to load in
			spawn(function()
				if robloxClass.Superclass then
					repeat wait() until Classes[robloxClass.Superclass]
					
					classData.Superclass = Classes[robloxClass.Superclass]
					
					setmetatable(classData.Callbacks, {__index = classData.Superclass.Callbacks})
					setmetatable(classData.Events, {__index = classData.Superclass.Events})
					setmetatable(classData.Functions, {__index = classData.Superclass.Functions})
					setmetatable(classData.Properties, {__index = classData.Superclass.Properties})
				end
				
				classesLeft = classesLeft - 1
			end)
			
			Classes[robloxClass.Name] = classData
		end
		
		spawn(function()
			repeat wait() until classesLeft <= 0
			allClassesLoadedEvent:Fire()
		end)
				
		allClassesLoaded:Wait()
	end
	
	return self
end

function APIData:RemoveInaccessibleMembers()
	-- Removes members with the securities RobloxSecurity or RobloxScriptSecurity
	
	local logMessage = "removed %s %s.%s (inaccessible)"
	local apiClasses = self.Classes
	
	for _, class in pairs(apiClasses) do
		for memberName, member in pairs(class.Callbacks) do
			if ((member.Security == "RobloxSecurity") or (member.Security == "RobloxScriptSecurity") or (member.Tags.NotScriptable)) then
			--	print(string.format(logMessage, member.MemberType, class.Name, memberName))
				class.Callbacks[memberName] = nil
			end
		end
		
		for memberName, member in pairs(class.Events) do
			if ((member.Security == "RobloxSecurity") or (member.Security == "RobloxScriptSecurity") or (member.Tags.NotScriptable)) then
			--	print(string.format(logMessage, member.MemberType, class.Name, memberName))
				class.Events[memberName] = nil
			end
		end
		
		for memberName, member in pairs(class.Functions) do
			if ((member.Security == "RobloxSecurity") or (member.Security == "RobloxScriptSecurity") or (member.Tags.NotScriptable)) then
			--	print(string.format(logMessage, member.MemberType, class.Name, memberName))
				class.Functions[memberName] = nil
			end
		end
		
		for memberName, member in pairs(class.Properties) do
			if ((member.Security.Read == "RobloxSecurity") or (member.Security.Read == "RobloxScriptSecurity") or (member.Tags.NotScriptable)) then
			--	print(string.format(logMessage, member.MemberType, class.Name, memberName))
				class.Properties[memberName] = nil
			end
		end
	end
end

function APIData:RemoveDeprecatedMembers()
	-- Removes members with the Deprecated tag
	
	local logMessage = "removed %s %s.%s (deprecated)"
	local apiClasses = self.Classes
	
	for _, class in pairs(apiClasses) do
		for memberName, member in pairs(class.Callbacks) do
			if (member.Tags.Deprecated) then
			--	print(string.format(logMessage, member.MemberType, class.Name, memberName))
				class.Callbacks[memberName] = nil
			end
		end
		
		for memberName, member in pairs(class.Events) do
			if (member.Tags.Deprecated) then
			--	print(string.format(logMessage, member.MemberType, class.Name, memberName))
				class.Events[memberName] = nil
			end
		end
		
		for memberName, member in pairs(class.Functions) do
			if (member.Tags.Deprecated) then
			--	print(string.format(logMessage, member.MemberType, class.Name, memberName))
				class.Functions[memberName] = nil
			end
		end
		
		for memberName, member in pairs(class.Properties) do
			if (member.Tags.Deprecated) then
			--	print(string.format(logMessage, member.MemberType, class.Name, memberName))
				class.Properties[memberName] = nil
			end
		end
	end
end

function APIData:Extend(extensions)
	local Classes = self.Classes
	
	for i = 1, #extensions do
		local extension = extensions[i]
		
		local isValidExtension, invalidMsg = dataSanityChecks.Extension(extension)
		if isValidExtension then
			local extensionType = extension.ExtensionType
			
			if extensionType == "Class" then
				local superclass = extension.Superclass
				local class = extension.ExtensionData
				
				class.Native = false
				self.Classes[class.Name] = class
				
				if superclass then
					-- wait for superclass to load in
					spawn(function()
						if superclass then
							repeat wait() until Classes[superclass]
							
							class.Superclass = Classes[superclass]
							
							setmetatable(class.Callbacks, {__index = class.Superclass.Callbacks})
							setmetatable(class.Events, {__index = class.Superclass.Events})
							setmetatable(class.Functions, {__index = class.Superclass.Functions})
							setmetatable(class.Properties, {__index = class.Superclass.Properties})
						end
					end)
				end
			elseif extensionType == "Member" then
				local class = extension.MemberClass
				local classData = self.Classes[class]
				
				if classData then
					local classMember = extension.ExtensionData
					local memberType = classMember.MemberType
					
					classMember.Native = false
					classMember.Tags = arrayToDict(classMember.Tags)
					
					if (memberType == "Callback") then
						classData.Callbacks[classMember.Name] = classMember
					elseif (memberType == "Event") then
						classData.Events[classMember.Name] = classMember
					elseif (memberType == "Function") then
						classData.Functions[classMember.Name] = classMember
					elseif (memberType == "Property") then
						classData.Properties[classMember.Name] = classMember
					else
						-- is there a new member type?
						warn("unknown member type "..memberType)
					end
				end
			end
		else
			warn("bad, got message "..invalidMsg)
		end
	end
end

return APIData