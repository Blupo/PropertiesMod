local APIData = {}

-- Yes I know that relying on this GitHub repo probably isn't the best solution
local RobloxAPIDump do
	local HttpService = game:GetService("HttpService")
	
	local success, data = pcall(function() return HttpService:GetAsync("https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/API-Dump.json") end)
	if (not success) then
		warn("[RobloxAPI] Could not get API data, got error: " .. data)
		return nil
	end
	
	RobloxAPIDump = HttpService:JSONDecode(data)
end

local RobloxAPIClasses = RobloxAPIDump.Classes

local t = require(script.Parent:WaitForChild("t"))

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

local interfaces = {}

interfaces.DataTypeDescriptor = t.interface({
	Category = t.string,
	Name = t.string
})

interfaces.ParameterDescriptor = t.interface({
	Name = t.string,
	Type = interfaces.DataTypeDescriptor
})

interfaces.FunctionParameterDescriptor = t.interface({
	Name = t.string,
	Type = interfaces.DataTypeDescriptor,
	Default = t.optional(t.string)
})

interfaces.APICallback = t.interface({
	MemberType = t.string,
	Name = t.string,
	Security = t.string,
	Tags = t.map(t.string, t.boolean),
	
	Parameters = t.array(interfaces.ParameterDescriptor),
	ReturnType = interfaces.DataTypeDescriptor,
})
	
interfaces.APIEvent = t.interface({
	MemberType = t.string,
	Name = t.string,
	Security = t.string,
	Tags = t.map(t.string, t.boolean),
	
	Parameters = t.array(interfaces.ParameterDescriptor),
})
	
interfaces.APIFunction = t.interface({
	MemberType = t.string,
	Name = t.string,
	Security = t.string,
	Tags = t.map(t.string, t.boolean),
	
	Parameters = t.array(interfaces.ParameterDescriptor),
	ReturnType = interfaces.DataTypeDescriptor,
})
	
interfaces.APIProperty = t.interface({
	MemberType = t.string,
	Name = t.string,
	Security = t.interface({
		Read = t.string,
		Write = t.string
	}),
	Tags = t.map(t.string, t.boolean),
	
	Category = t.string,
	Serialization = t.interface({
		CanLoad = t.boolean,
		CanSave = t.boolean
	}),
	
	ValueType = interfaces.DataTypeDescriptor,
})

interfaces.APIClass = t.interface({
	Callbacks = t.map(t.string, interfaces.APICallback),
	Events = t.map(t.string, interfaces.APIEvent),
	Functions = t.map(t.string, interfaces.APIFunction),
	Properties = t.map(t.string, interfaces.APIProperty),
	
	MemoryCategory = t.string,
	Name = t.string,
	Tags = t.map(t.string, t.boolean),
	
--	Superclass = t.optional(interfaces.APIClass),
})

interfaces.Extension = t.interface({
	ExtensionType = t.string,
	MemberClass = t.optional(t.string),
	Superclass = t.optional(t.string),
	ExtensionData = t.union(interfaces.APIClass, interfaces.APICallback, interfaces.APIEvent, interfaces.APIFunction, interfaces.APIProperty)
})

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
		
		local isValidExtension, invalidMsg = interfaces.Extension(extension) --dataSanityChecks.Extension(extension)
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