local APILibrarian = {}

---

function APILibrarian.new(apiData, enableCache)
	assert(apiData, "API data missing")
	
	local self = {
		__canCache = enableCache,
		APIData = apiData,
	}
	setmetatable(self, {__index = APILibrarian})

	if enableCache then
		self.__cache = {}
	end
	
	return self
end

function APILibrarian:IsDeprecated(class, memberType, memberName)
	local apiClass = self.APIData.Classes[class]
	assert(apiClass, "class does not exist")
	
	local memberGroup do
		if (memberType == "Property") then
			memberGroup = apiClass.Properties
		elseif (memberType == "Event") then
			memberGroup = apiClass.Events
		elseif (memberType == "Function") then
			memberGroup = apiClass.Functions
		elseif (memberType == "Callback") then
			memberGroup = apiClass.Callbacks
		end
	end
	
	local member = memberGroup[memberName]
	assert(member, "property does not exist")
	
	return member.Tags.Deprecated
end

function APILibrarian:IsPropertyReadOnly(class, property)
	local apiClass = self.APIData.Classes[class]
	assert(apiClass, "class does not exist")
	
	local propertiesGroup = apiClass.Properties
	local property = propertiesGroup[property]
	assert(property, "property does not exist")
	
	return property.Tags.ReadOnly
end

function APILibrarian:GetProperties(class)
	if self.__canCache then
		local functionCache = self.__cache.Properties

		if (not functionCache) then
			self.__cache.Properties = {}
		end

		if functionCache[class] then
			return functionCache[class]
		end
	end

	local properties = {}
	
	local apiClass = self.APIData.Classes[class]
	assert(apiClass, "class does not exist")
	
	while apiClass do
		properties[apiClass.Name] = {}
		
		local classProperties = apiClass.Properties
		local propertiesGroup = properties[apiClass.Name]
		
		for propertyName in pairs(classProperties) do
			propertiesGroup[#propertiesGroup + 1] = propertyName
		end
		
		apiClass = apiClass.Superclass
	end

	if self.__canCache then
		self.__cache.Properties[class] = properties
	end
	
	return properties
end

function APILibrarian:GetImmediateProperties(class)
	if self.__canCache then
		local functionCache = self.__cache.ImmediateProperties

		if (not functionCache) then
			self.__cache.ImmediateProperties = {}
		end

		if functionCache[class] then
			return functionCache[class]
		end
	end

	local properties = {}
	
	local apiClass = self.APIData.Classes[class]
	assert(apiClass, "class does not exist")
	
	local classProperties = apiClass.Properties
	
	for propertyName in pairs(classProperties) do
		properties[#properties + 1] = propertyName
	end

	if self.__canCache then
		self.__cache.ImmediateProperties[class] = properties
	end
	
	return properties
end

function APILibrarian:GetClassHierarchy(class)
	if self.__canCache then
		local functionCache = self.__cache.Hierarchy

		if (not functionCache) then
			self.__cache.Hierarchy = {}
		end

		if functionCache[class] then
			return functionCache[class]
		end
	end
	
	local hierarchy = {}
	
	local apiClass = self.APIData.Classes[class]
	assert(apiClass, "class does not exist")
	
	while apiClass do
		hierarchy[#hierarchy + 1] = apiClass.Name
		
		apiClass = apiClass.Superclass
	end

	if self.__canCache then
		self.__cache.Hierarchy[class] = hierarchy
	end
	
	return hierarchy
end

return APILibrarian