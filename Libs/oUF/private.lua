local parent, ns = ...
local oUF = ns.oUF
local Private = oUF.Private or {}
oUF.Private = Private

-- updating of "invalid" units.
function Private.enableTargetUpdate(object)
	object.onUpdateFrequency = object.onUpdateFrequency or .5
	object.__eventless = true

	local total = 0
	object:SetScript('OnUpdate', function(self, elapsed)
		if (not self.unit) then
			return
		elseif (total > self.onUpdateFrequency) then
			self:UpdateAllElements('OnUpdate')
			total = 0
		end

		total = total + elapsed
	end)
end

oUF.Private = Private

function Private.argcheck(value, num, ...)
	assert(type(num) == 'number', "Bad argument #2 to 'argcheck' (number expected, got " .. type(num) .. ')')

	for i = 1, select('#', ...) do
		if(type(value) == select(i, ...)) then return end
	end

	local types = strjoin(', ', ...)
	local name = debugstack(2,2,0):match(": in function [`<](.-)['>]")
	error(string.format("Bad argument #%d to '%s' (%s expected, got %s)", num, name, types, type(value)), 3)
end

function Private.print(...)
	print('|cff33ff99oUF:|r', ...)
end

function Private.error(...)
	Private.print('|cffff0000Error:|r ' .. string.format(...))
end

function Private.unitExists(unit)
	return unit and UnitExists(unit)
end