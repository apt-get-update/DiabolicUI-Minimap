local parent, ns = ...
local oUF = ns.oUF
local Private = oUF.Private

-- Handles units that do not fire events and need OnUpdate polling
local eventlessObjects = {}
local onUpdates = {}

local function createOnUpdate(timer)
	if (not onUpdates[timer]) then
		local frame = CreateFrame('Frame')
		local objects = eventlessObjects[timer]

		frame:SetScript('OnUpdate', function(self, elapsed)
			self.elapsed = (self.elapsed or 0) + elapsed
			if (self.elapsed > timer) then
				for _, object in next, objects do
					if (object.unit and UnitExists(object.unit)) then
						object:UpdateAllElements('OnUpdate')
					end
				end
				self.elapsed = 0
			end
		end)

		onUpdates[timer] = frame
	end
end

function oUF:HandleEventlessUnit(object)
	object.__eventless = true

	local timer = object.onUpdateFrequency or 0.5

	-- Remove it, in case it's already registered with any timer
	for _, objects in next, eventlessObjects do
		for i, obj in next, objects do
			if (obj == object) then
				table.remove(objects, i)
				break
			end
		end
	end

	if (not eventlessObjects[timer]) then eventlessObjects[timer] = {} end
	table.insert(eventlessObjects[timer], object)

	createOnUpdate(timer)
end
local enableTargetUpdate = Private.enableTargetUpdate

-- Handles unit specific actions.
function oUF:HandleUnit(object, unit)
	local unit = object.unit or unit
	if(unit == 'target') then
		object:RegisterEvent('PLAYER_TARGET_CHANGED', object.UpdateAllElements)
	elseif(unit == 'mouseover') then
		object:RegisterEvent('UPDATE_MOUSEOVER_UNIT', object.UpdateAllElements)
	elseif(unit == 'focus') then
		object:RegisterEvent('PLAYER_FOCUS_CHANGED', object.UpdateAllElements)
	elseif(unit:match('%w+target') or unit:match('boss%d?$')) then
		enableTargetUpdate(object)
	end
end