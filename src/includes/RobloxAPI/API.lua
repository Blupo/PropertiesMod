local includes = script.Parent:WaitForChild("includes")

local APIData = require(includes:WaitForChild("APIData"))
local APILibrarian = require(includes:WaitForChild("APILibrarian"))
local APIOperator = require(includes:WaitForChild("APIOperator"))

---

local RobloxAPI = {}

function RobloxAPI.new(enableCache)
	local apiData = APIData.new()
	
	local self = {
		Data = apiData,
		Library = APILibrarian.new(apiData, enableCache),
		Operator = APIOperator.new(apiData)
	}
	setmetatable(self, {__index = RobloxAPI})
	
	return self
end

return RobloxAPI