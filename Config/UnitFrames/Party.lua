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
local Addon, ns = ...
local Config = ns.Config or {}
ns.Config = Config

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia

local barSparkMap = {
	top = {
		{ keyPercent = 0 / 128, offset = -16 / 32 },
		{ keyPercent = 10 / 128, offset = 0 / 32 },
		{ keyPercent = 119 / 128, offset = 0 / 32 },
		{ keyPercent = 128 / 128, offset = -16 / 32 }
	},
	bottom = {
		{ keyPercent = 0 / 128, offset = -16 / 32 },
		{ keyPercent = 10 / 128, offset = 0 / 32 },
		{ keyPercent = 119 / 128, offset = 0 / 32 },
		{ keyPercent = 128 / 128, offset = -16 / 32 }
	}
}

local Scale = 1.58;
Config.Party = {
	-- General
	enabled = true,
	useInParties = true, -- show in non-raid parties
	useInRaid5 = true, -- show in raid groups of 1-5 players
	useInRaid10 = false, -- show in raid groups of 6-10 players
	useInRaid25 = false, -- show in raid groups of 11-25 players
	useInRaid40 = false, -- show in raid groups of 26-40 players
	showAuras = true,
	showPlayer = true,
	point = "LEFT",                     -- anchor point of unitframe, group members within column grow opposite
	xOffset = 0,                        -- horizontal offset within the same column
	yOffset = 0,                        -- vertical offset within the same column
	groupBy = "ROLE",                   -- GROUP, CLASS, ROLE
	groupingOrder = "TANK,HEALER,DAMAGER", -- must match choice in groupBy
	unitsPerColumn = 5,                 -- maximum units per column
	maxColumns = 1,                     -- should be 5/unitsPerColumn
	columnSpacing = 0,                  -- spacing between columns
	columnAnchorPoint = "TOP",          -- anchor point of column, columns grow opposite
	-- Header Position & Layut
	-----------------------------------------
	Position = { "TOPLEFT", UIParent, "TOPLEFT", 74, -60 }, -- party header position
	Size = { 160 * 4, 140 },                             -- size of the entire header frame area
	-- Anchor = "TOP",                                      -- party member frame anchor vertically
	Anchor = "LEFT",                                     -- party member frame anchor horizontally
	GrowthX = 60,                                        -- party member horizontal offset
	-- GrowthX = 0,                        -- party member horizontal offset
	GrowthY = 0,                                         -- party member vertical offset
	-- GrowthY = -60,                      -- party member vertical offset
	Sorting = "INDEX",                                   -- sort method
	SortDirection = "ASC",                               -- sort direction

	PartySize = { 160, 180 },                            -- party member size
	PartyHitRectInsets = { 0, 0, 0, -10 },               -- party member mouseover hit box
	OutOfRangeAlpha = .6,                                -- Alpha of out of range party members

	

	-- Health
	-----------------------------------------
	HealthBarPosition = { "BOTTOM", 0, 0 },
	HealthBarSize = { 80 * Scale, 14 * Scale },
	HealthBarTexture = GetMedia("cast_bar"),
	HealthBarOrientation = "RIGHT",
	HealthBarSparkMap = barSparkMap,
	HealthAbsorbColor = { 1, 1, 1, .5 },
	HealthCastOverlayColor = { 1, 1, 1, .5 },

	HealthBackdropPosition = { "CENTER", 1, -2 },
	HealthBackdropSize = { 140 * Scale, 90 * Scale },
	HealthBackdropTexture = GetMedia("cast_back"),
	HealthBackdropColor = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },

	HealthValuePosition = { "CENTER", 0, 0 },
	HealthValueJustifyH = "CENTER",
	HealthValueJustifyV = "MIDDLE",
	HealthValueFont = GetFont(13 * Scale, true),
	HealthValueColor = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },

	-- Power
	-----------------------------------------
	PowerBarSize = { 72 * Scale, 1 * Scale },
	PowerBarPosition = { "BOTTOM", 0, -1.5 },
	PowerBarTexture = [[Interface\ChatFrame\ChatFrameBackground]],
	PowerBarOrientation = "RIGHT",
	PowerBackdropSize = { 74 * Scale, 3 * Scale },
	PowerBackdropPosition = { "CENTER", 0, 0 },
	PowerBackdropTexture = [[Interface\ChatFrame\ChatFrameBackground]],
	PowerBackdropColor = { 0, 0, 0, .75 },

	-- Portrait
	-----------------------------------------
	PortraitPosition = { "BOTTOM", 0, 22 * Scale },
	PortraitSize = { 70 * Scale, 73 * Scale },
	PortraitAlpha = .85,
	PortraitBackgroundPosition = { "BOTTOM", 0, -6 * Scale },
	PortraitBackgroundSize = { 130 * Scale, 130 * Scale },
	PortraitBackgroundTexture = GetMedia("party_portrait_back"),
	PortraitBackgroundColor = { .5, .5, .5 },
	PortraitShadePosition = { "BOTTOM", 0, 16 * Scale },
	PortraitShadeSize = { 86 * Scale, 86 * Scale },
	PortraitShadeTexture = GetMedia("shade-circle"),
	PortraitBorderPosition = { "BOTTOM", 0, -38 * Scale },
	PortraitBorderSize = { 194 * Scale, 194 * Scale },
	PortraitBorderTexture = GetMedia("party_portrait_border"),
	PortraitBorderColor = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },

	-- Target Highlight Outline
	-----------------------------------------
	TargetHighlightPosition = { "CENTER", 1, -2 },
	TargetHighlightSize = { 140 * Scale, 90 * Scale },
	TargetHighlightTexture = GetMedia("cast_back_outline"),
	TargetHighlightTargetColor = { 255 / 255, 239 / 255, 169 / 255, 1 },
	TargetHighlightFocusColor = { 144 / 255, 195 / 255, 255 / 255, 1 },

	-- Ready Check
	-----------------------------------------
	ReadyCheckPosition = { "CENTER", 0, -7 },
	ReadyCheckSize = { 32 * Scale, 32 * Scale },
	ReadyCheckReadyTexture = [[Interface/RAIDFRAME/ReadyCheck-Ready]],
	ReadyCheckNotReadyTexture = [[Interface/RAIDFRAME/ReadyCheck-NotReady]],
	ReadyCheckWaitingTexture = [[Interface/RAIDFRAME/ReadyCheck-Waiting]],

	-- Resurrection Indicator
	-----------------------------------------
	ResurrectIndicatorPosition = { "CENTER", 0, -7 },
	ResurrectIndicatorSize = { 32 * Scale, 32 * Scale },
	ResurrectIndicatorTexture = [[Interface\RaidFrame\Raid-Icon-Rez]],

	-- Group Role
	-----------------------------------------
	GroupRolePosition = { "TOP", 0, 16 },
	GroupRoleSize = { 40 * Scale, 40 * Scale },
	GroupRoleBackdropPosition = { "CENTER", 0, 0 },
	GroupRoleBackdropSize = { 77 * Scale, 77 * Scale },
	GroupRoleBackdropTexture = GetMedia("point_plate"),
	GroupRoleBackdropColor = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	GroupRoleIconPositon = { "CENTER", 0, 0 },
	GroupRoleIconSize = { 34 * Scale, 34 * Scale },
	GroupRoleDPSTexture = GetMedia("grouprole-icons-dps"),
	GroupRoleHealerTexture = GetMedia("grouprole-icons-heal"),
	GroupRoleTankTexture = GetMedia("grouprole-icons-tank"),

	-- Combat Feedback Text
	-----------------------------------------
	CombatFeedbackAnchorElement = "Portrait",
	CombatFeedbackPosition = { "CENTER", 0, 0 },
	CombatFeedbackFont = GetFont(20 * Scale, true),   -- standard font
	CombatFeedbackFontLarge = GetFont(24 * Scale, true), -- crit/drushing font
	CombatFeedbackFontSmall = GetFont(18 * Scale, true), -- glancing blow font

	-- Unit Name
	NamePosition = { "TOP", 0, 40 },
	NameSize = { 250, 18 },
	NameJustifyH = "CENTER",
	NameJustifyV = "TOP",
	NameFont = GetFont(16, true),
	NameColor = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	-- Auras
	-----------------------------------------
	AurasPosition = { "BOTTOM", 0, -(34 * 2 + 22) },
	AurasSize = { 34 * 3 - 4, 34 * 2 - 4 },
	AuraSize = 30,
	AuraSpacing = 4,
	AurasNumTotal = 6,
	AurasDisableMouse = false,
	AurasDisableCooldown = false,
	AurasOnlyShowPlayer = false,
	AurasShowStealableBuffs = false,
	AurasInitialAnchor = "TOPLEFT",
	AurasSpacingX = 4,
	AurasSpacingY = 4,
	AurasGrowthX = "RIGHT",
	AurasGrowthY = "DOWN",
	AurasTooltipAnchor = "ANCHOR_TOPLEFT",
	AurasSortMethod = "TIME_REMAINING",
	AurasSortDirection = "DESCENDING",
}
