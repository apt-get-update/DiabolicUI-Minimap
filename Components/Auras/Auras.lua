--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]

local _, ns = ...

local Auras = ns:NewModule("Auras", "LibMoreEvents-1.0", "AceTimer-3.0", "AceHook-3.0", "AceConsole-3.0",
	"LibSmoothBar-1.0")

-- Lua API
local math_ceil = math.ceil
local math_max = math.max
local pairs = pairs
local select = select
local string_lower = string.lower
local tonumber = tonumber

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local RegisterCooldown = ns.Widgets.RegisterCooldown

local config = {
	enabled = true,
	enableAuraFading = true,
	enableModifier = false,
	modifier = "SHIFT",
	ignoreTarget = false,
	anchorPoint = "TOPRIGHT",
	growthX = "LEFT",
	growthY = "DOWN",
	paddingX = 6,
	paddingY = 12,
	wrapAfter = 8,
	savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "TOPRIGHT",
		[2] = -40 * ns.API.GetEffectiveScale(),
		[3] = -40 * ns.API.GetEffectiveScale()
	}
}

Auras.CreateBuffs = function(self)
	if (self.frame) then return end;

	local AurasFrame = CreateFrame("Frame", ns.Prefix .. "Buffs", UIParent)
	AurasFrame:SetSize(config.wrapAfter * (36 + config.paddingX),
		(36 + config.paddingY) * math_ceil(BUFF_MAX_DISPLAY / config.wrapAfter))
	AurasFrame:SetPoint(config.savedPosition[1], UIParent, config.savedPosition[1], config.savedPosition[2],
		config.savedPosition[3])
	AurasFrame:SetScale(config.savedPosition.scale)

	-- Register events directly on the frame for reliability
	AurasFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	AurasFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	AurasFrame:RegisterEvent("UNIT_AURA")
	AurasFrame:SetScript("OnEvent", function(frame, event, ...)
		if event == "UNIT_AURA" then
			local unit = ...
			if unit == "player" or unit == "vehicle" then
				self:UpdateAuraButtonAlpha()
			end
		else
			self:OnEvent(event, ...)
		end
	end)

	self.frame = AurasFrame

	-----------------------------------------
	-- Header
	-----------------------------------------
	-- The primary buff window.
	local buffs = CreateFrame("Frame", ns.Prefix .. "BuffHeader", AurasFrame, "SecureActionButtonTemplate")
	buffs:UnregisterEvent("UNIT_AURA")
	buffs:RegisterUnitEvent("UNIT_AURA", "player", "vehicle")
	buffs:SetAttribute("unit", "player")
	buffs:SetFrameLevel(10)
	buffs:SetSize(36, 36)
	buffs:SetPoint("TOPRIGHT", 0, 0)
	buffs:SetAttribute("weaponTemplate", "AzeriteAuraTemplate")
	buffs:SetAttribute("template", "AzeriteAuraTemplate")
	buffs:SetAttribute("minHeight", 36)
	buffs:SetAttribute("minWidth", 36)
	buffs:SetAttribute("point", config.anchorPoint)
	buffs:SetAttribute("xOffset", -(36 + config.paddingX))
	buffs:SetAttribute("yOffset", 0)
	buffs:SetAttribute("wrapAfter", config.wrapAfter)
	buffs:SetAttribute("wrapXOffset", 0)
	buffs:SetAttribute("wrapYOffset", -(36 + config.paddingY))
	buffs:SetAttribute("filter", "HELPFUL")
	buffs:SetAttribute("includeWeapons", 1)
	buffs:SetAttribute("sortMethod", "TIME")
	buffs:SetAttribute("sortDirection", "-")
	buffs.UpdateAuraButtonAlpha = function() Auras:UpdateAuraButtonAlpha() end
	buffs.tooltipPoint = "TOPRIGHT"
	buffs.tooltipAnchor = "BOTTOMLEFT"
	buffs.tooltipOffsetX = -10
	buffs.tooltipOffsetY = -10
	-- Aura slot index where the
	-- consolidation button will appear.
	buffs:SetAttribute("consolidateTo", -1)

	-- Auras with less remaining duration than
	-- this many seconds should not be consolidated.
	buffs:SetAttribute("consolidateThreshold", 10) -- default 10

	-- The minimum total duration an aura should
	-- have to be considered for consolidation.
	buffs:SetAttribute("consolidateDuration", 10) -- default 30

	-- The fraction of remaining duration a buff
	-- should still have to be eligible for consolidation.
	buffs:SetAttribute("consolidateFraction", .1) -- default .10
	-- Add a vehicle switcher
	RegisterStateDriver(buffs, "unit", "[vehicleui] vehicle; player")

	self.buffs = buffs

	-----------------------------------------
	-- Consolidation
	-----------------------------------------
	-- The proxybutton appearing in the aura listing
	-- representing the existence of consolidated auras.
	local proxy = CreateFrame("Button", buffs:GetName() .. "ProxyButton", buffs,
		"SecureUnitButtonTemplate, SecureHandlerEnterLeaveTemplate")
	proxy:Hide()
	proxy:SetSize(36, 36)
	buffs.proxy = proxy

	local texture = proxy:CreateTexture(nil, "BACKGROUND")
	texture:SetSize(64, 64)
	texture:SetPoint("CENTER")
	texture:SetTexture(GetMedia("chatbutton-maximize"))
	proxy.texture = texture

	local count = proxy:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(GetFont(12, true))
	count:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	count:SetPoint("BOTTOMRIGHT", -2, 3)
	proxy.count = count

	buffs:SetAttribute("consolidateProxy", proxy)

	-- The other updates aren't called when it is hidden,
	-- so to have the correct count when toggling through chat commands,
	-- we need to have this extra update on each show.
	self:SecureHookScript(proxy, "OnShow", "UpdateAuraButtonAlpha")
	self:SecureHookScript(proxy, "OnHide", "UpdateAuraButtonAlpha")

	-- Consolidation frame where the consolidated auras appear.
	local consolidation = CreateFrame("Frame", buffs:GetName() .. "Consolidation", buffs.proxy, "SecureFrameTemplate")
	consolidation:Hide()
	consolidation:SetSize(36, 36)
	consolidation:SetPoint("TOPRIGHT", proxy, "TOPLEFT", -6, 0)
	consolidation:SetAttribute("minHeight", nil)
	consolidation:SetAttribute("minWidth", nil)
	consolidation:SetAttribute("point", buffs:GetAttribute("point"))
	consolidation:SetAttribute("template", buffs:GetAttribute("template"))
	consolidation:SetAttribute("weaponTemplate", buffs:GetAttribute("weaponTemplate"))
	consolidation:SetAttribute("xOffset", buffs:GetAttribute("xOffset"))
	consolidation:SetAttribute("yOffset", buffs:GetAttribute("yOffset"))
	consolidation:SetAttribute("wrapAfter", buffs:GetAttribute("wrapAfter"))
	consolidation:SetAttribute("wrapYOffset", buffs:GetAttribute("wrapYOffset"))

	consolidation.tooltipPoint = buffs.tooltipPoint
	consolidation.tooltipAnchor = buffs.tooltipAnchor
	consolidation.tooltipOffsetX = buffs.tooltipOffsetX
	consolidation.tooltipOffsetY = buffs.tooltipOffsetY

	buffs:SetAttribute("consolidateHeader", consolidation)

	-- Add a vehicle switcher
	RegisterStateDriver(consolidation, "unit", "[vehicleui] vehicle; player")

	buffs.consolidation = consolidation

	-- Clickbutton to toggle the consolidation window.
	local button = CreateFrame("Button", proxy:GetName() .. "ClickButton", proxy, "SecureHandlerClickTemplate")
	button:SetAllPoints()
	button:SetFrameRef("buffs", buffs)
	button:SetFrameRef("consolidation", consolidation)
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("_onclick", [[
			local consolidation = self:GetFrameRef("consolidation")
			local buffs = self:GetFrameRef("buffs")
			if consolidation:IsShown() then
				consolidation:Hide()
				buffs:CallMethod("UpdateAuraButtonAlpha")
			else
				consolidation:Show()
				buffs:CallMethod("UpdateAuraButtonAlpha")
			end
		]])
	proxy.button = button

	-----------------------------------------
	-- Visibility
	-----------------------------------------
	local visibility = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
	visibility:SetFrameRef("buffs", buffs)
	visibility:SetAttribute("_onstate-vis", [[ self:RunAttribute("UpdateVisibility"); ]])
	visibility:SetAttribute("UpdateVisibility", [[
			local visdriver = self:GetAttribute("visdriver");
			if (not visdriver) then
				return
			end
			local buffs = self:GetFrameRef("buffs");
			local shouldhide = SecureCmdOptionParse(visdriver) == "hide";
			local isshown = buffs:IsShown();
			if (shouldhide and isshown) then
				buffs:Hide();
			elseif (not shouldhide and not isshown) then
				buffs:Show();
			end
		]])

	visibility:SetAttribute("UpdateDriver", [[
			local visdriver;
			local buffs = self:GetFrameRef("buffs");
			local auramode = self:GetAttribute("auramode");
			local ignoreTarget = self:GetAttribute("ignoreTarget");
			if (auramode == "hide") then
				visdriver = "hide";
			elseif (auramode == "show") then
					visdriver = "[@target,exists]hide;show";
			elseif (auramode == "modifier") then
				local modifierkey = self:GetAttribute("modifierkey");
				if (ignoreTarget) then
					visdriver = "[mod:"..modifierkey.."]show;hide";
				else
					visdriver = "[@target,exists]hide;[mod:"..modifierkey.."]show;hide";
				end
			end
			self:SetAttribute("visdriver", visdriver);
			UnregisterStateDriver(self, "vis");
			RegisterStateDriver(self, "vis", visdriver);
		]])
	self.visibility = visibility
end

Auras.DisableBlizzard = function(self)
	BuffFrame:SetScript("OnLoad", nil)
	BuffFrame:SetScript("OnUpdate", nil)
	BuffFrame:SetScript("OnEvent", nil)
	BuffFrame:SetParent(ns.Hider)
	BuffFrame:UnregisterAllEvents()
	if (TemporaryEnchantFrame) then
		TemporaryEnchantFrame:SetScript("OnUpdate", nil)
		TemporaryEnchantFrame:SetParent(ns.Hider)
	end
end

Auras.Embed = function(self, aura)
	for method, func in pairs(Aura) do
		aura[method] = func
	end
end

Auras.ForAll = function(self, method, ...)
	local buffs = self.buffs
	if (not buffs) then
		return
	end
	local child = buffs:GetAttribute("child1")
	local i = 1
	while (child) do
		local func = child[method]
		if (func) then
			func(child, child:GetID(), ...)
		end
		i = i + 1
		child = buffs:GetAttribute("child" .. i)
	end
end

Auras.UpdateAuraButtonAlpha = function(self)
	local buffs = self.buffs;

	if (not buffs) then return end;

	local consolidateDuration = tonumber(buffs:GetAttribute("consolidateDuration")) or 30
	local consolidateThreshold = tonumber(buffs:GetAttribute("consolidateThreshold")) or 10
	local consolidateFraction = tonumber(buffs:GetAttribute("consolidateFraction")) or 0.1
	local unit, filter = buffs:GetAttribute("unit"), buffs:GetAttribute("filter")
	local slot, consolidated, time = 1, 0, GetTime()
	local name, duration, expires, shouldConsolidate, _

	repeat
		-- Sourced from FrameXML\SecureGroupHeaders.lua
		name, _, _, _, duration, expires, _, _, _, _, _, _, _, _, _, shouldConsolidate = UnitAura(unit, slot, filter)

		if (name and shouldConsolidate) then
			if (not expires or duration > consolidateDuration or (expires - time >= math_max(consolidateThreshold, duration * consolidateFraction))) then
				consolidated = consolidated + 1
			end
		end
		slot = slot + 1
	until (not name)

	-- Update count and counter.
	buffs.numConsolidated = consolidated
	buffs.proxy.count:SetText(buffs.numConsolidated > 0 and buffs.numConsolidated or "")

	-- If there are currently consolidated buffs and both
	-- the proxy button and the consolidation frame are shown,
	-- reduce the alpha of the buff window.
	if (buffs.numConsolidated > 0 and buffs.proxy:IsShown() and buffs.consolidation:IsShown()) then
		buffs:SetAlpha(.5)
	else
		buffs:SetAlpha(1)
	end
end

Auras.UpdateSettings = function(self)
	if (InCombatLockdown()) then
		self.needupdate = true
		return
	end

	if (not self.frame) then return end

	self.frame:SetSize(config.wrapAfter * 36 + (config.wrapAfter - 1) * config.paddingX,
		(36 + config.paddingY) * math_ceil(BUFF_MAX_DISPLAY / config.wrapAfter))

	self.buffs:ClearAllPoints()
	self.buffs:SetPoint(config.anchorPoint)
	self.buffs:SetAttribute("point", config.anchorPoint)
	self.buffs:SetAttribute("xOffset", (36 + config.paddingX) * (config.growthX == "LEFT" and -1 or 1))
	self.buffs:SetAttribute("wrapAfter", config.wrapAfter)
	self.buffs:SetAttribute("wrapYOffset", (36 + config.paddingY) * (config.growthY == "DOWN" and -1 or 1))
	self.buffs.consolidation:SetAttribute("point", self.buffs:GetAttribute("point"))
	self.buffs.consolidation:SetAttribute("xOffset", self.buffs:GetAttribute("xOffset"))
	self.buffs.consolidation:SetAttribute("wrapAfter", self.buffs:GetAttribute("wrapAfter"))
	self.buffs.consolidation:SetAttribute("wrapYOffset", self.buffs:GetAttribute("wrapYOffset"))

	self.visibility:SetAttribute("ignoreTarget", config.ignoreTarget)
	self.visibility:SetAttribute("auramode",
		not config.enabled and "hide" or config.enableModifier and "modifier" or "show")
	self.visibility:SetAttribute("modifierkey", string_lower(config.modifier))
end

Auras.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:ForAll("Update")
		self:UpdateAuraButtonAlpha()
	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (InCombatLockdown()) then return end
		if (self.needupdate) then
			self.needupdate = true
			self:UpdateSettings()
		end
	end
end

Auras.OnEnable = function(self)
	self:DisableBlizzard()
	self:CreateBuffs()
	self:UpdateSettings()
end
