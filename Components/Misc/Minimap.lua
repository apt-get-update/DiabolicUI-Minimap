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
local MinimapMod = ns:NewModule("Minimap", "LibMoreEvents-1.0", "AceHook-3.0", "AceTimer-3.0",
    "AceConsole-3.0")

-- Lua API
local ipairs = ipairs
local math_cos = math.cos
local half_pi = math.pi / 2
local math_sin = math.sin
local next = next
local pairs = pairs
local string_format = string.format
local string_lower = string.lower
local table_insert = table.insert
local type = type
local unpack = unpack

-- Addon API
local Colors = ns.Colors
local GetMedia = ns.API.GetMedia
local IsAddOnEnabled = ns.API.IsAddOnEnabled
local UIHider = ns.Hider
local noop = ns.Noop

-- WoW Strings
local L_NEW = NEW                       -- "New"
local L_MAIL = MAIL_LABEL               -- "Mail"
local L_HAVE_MAIL = HAVE_MAIL           -- "You have unread mail"
local L_HAVE_MAIL_FROM = HAVE_MAIL_FROM -- "Unread mail from:"

local mapScale = 198 / 140

local defaults = {
    enabled = true,
    theme = "Azerite",
    savedPosition = {
        scale = mapScale * ns.API.GetEffectiveScale(),
    }
}

MinimapMod.GetScale = function(self)
    return mapScale
end

local DEFAULT_THEME = "Blizzard"
local CURRENT_THEME = DEFAULT_THEME

local Elements = {}
local Objects = {}
local ObjectOwners = {}

-- Snippets to be run upon object toggling.
----------------------------------------------------
local ObjectSnippets = {
    -- Blizzard Objects
    ------------------------------------------
    Crafting = {
        Enable = function(object)
            object:OnLoad()
            object:SetScript("OnEvent", object.OnEvent)
        end,
        Disable = function(object)
            object:SetScript("OnEvent", nil)
        end,
        Update = function(object)
            object:OnEvent("CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS")
        end
    },
    Eye = {
        Enable = function(object)
            object:SetFrameLevel(object:GetParent():GetFrameLevel() + 2)
        end,
        Disable = function() end,
        Update = function() end
    },
    EyeClassicPvP = {
        Enable = function(object)
            MiniMapBattlefieldIcon:Show()
            MiniMapBattlefieldBorder:Show()
            BattlegroundShine:Show()
            if (BattlefieldIconText) then BattlefieldIconText:Show() end
        end,
        Disable = function(object)
            MiniMapBattlefieldIcon:Hide()
            MiniMapBattlefieldBorder:Hide()
            BattlegroundShine:Hide()
            if (BattlefieldIconText) then BattlefieldIconText:Hide() end
        end,
        Update = function(object)
            if (PVPBattleground_UpdateQueueStatus) then PVPBattleground_UpdateQueueStatus() end
            BattlefieldFrame_UpdateStatus(false)
        end
    },
    -- AzeriteUI Objects
    ------------------------------------------
    AzeriteEye = {
        Enable = function(object)
            MiniMapLFGFrame:SetParent(Minimap)
            MiniMapLFGFrame:SetFrameLevel(100)
            MiniMapLFGFrame:ClearAllPoints()
            MiniMapLFGFrame:SetPoint("TOPRIGHT", Minimap, -4, -2)
            MiniMapLFGFrame:SetHitRectInsets(-8, -8, -8, -8)
            MiniMapLFGFrameBorder:Hide()
            MiniMapLFGFrameIcon:Hide()
        end,
        Disable = function(object)
            MiniMapLFGFrame:SetParent(_G[ObjectOwners.Eye])
            MiniMapLFGFrame:SetFrameLevel(MinimapBackdrop:GetFrameLevel() + 2)
            MiniMapLFGFrame:ClearAllPoints()
            MiniMapLFGFrame:SetPoint("TOPLEFT", 25, -100)
            MiniMapLFGFrame:SetHitRectInsets(0, 0, 0, 0)
            MiniMapLFGFrameBorder:Show()
            MiniMapLFGFrameIcon:Show()
        end,
        Update = function(object) end
    },
    AzeriteEyeClassicPvP = {
        Enable = function(object)
            MiniMapBattlefieldFrame:SetFrameStrata("MEDIUM")
            MiniMapBattlefieldFrame:SetFrameLevel(70) -- Minimap's XP button is 60
            MiniMapBattlefieldFrame:ClearAllPoints()
            MiniMapBattlefieldFrame:SetPoint("BOTTOMLEFT", Minimap, 4, 2)
            MiniMapBattlefieldFrame:SetHitRectInsets(-8, -8, -8, -8)
            MiniMapBattlefieldIcon:Hide()
            MiniMapBattlefieldBorder:Hide()
            BattlegroundShine:Hide()
            if (BattlefieldIconText) then BattlefieldIconText:Hide() end
        end,
        Disable = function(object)
            MiniMapBattlefieldFrame:SetFrameStrata(Minimap:GetFrameStrata())
            MiniMapBattlefieldFrame:SetFrameLevel(Minimap:GetFrameLevel() + 1)
            MiniMapBattlefieldFrame:ClearAllPoints()
            MiniMapBattlefieldFrame:SetPoint("BOTTOMLEFT", Minimap, 13, -13)
            MiniMapBattlefieldFrame:SetHitRectInsets(0, 0, 0, 0)
            MiniMapBattlefieldIcon:Show()
            MiniMapBattlefieldBorder:Show()
            BattlegroundShine:Show()
            if (BattlefieldIconText) then BattlefieldIconText:Show() end
        end,
        Update = function(object)
        end
    }
}

-- Element type of custom elements.
local ElementTypes = {
    Backdrop = "Texture",
    Border = "Texture",
    AzeriteEye = "Texture",
    AzeriteEyeClassicPvP = "Texture"
}

-- Mask textures for the supported shapes.
local Shapes = {
    Round = GetMedia("minimap-mask-opaque"),
    RoundTransparent = GetMedia("minimap-mask-transparent")
}

-- Our custom embedded skins.
local Skins = {
    Blizzard = {
        Version = 1,
        Shape = "Round"
    },
    ["Azerite"] = {
        Version = 1,
        Shape = "RoundTransparent",
        HideElements = {
            Addons = true,        -- retail
            BattleField = false,  -- classic + wrath
            BorderTop = true,
            BorderClassic = true, -- wrath
            Calendar = true,
            Clock = true,
            Compass = true,
            Crafting = true,  -- retail
            Difficulty = true,
            Expansion = true, -- retail
            Eye = false,      -- wrath + retail
            Mail = true,
            Tracking = true,
            ToggleButton = true, -- classic
            Zone = true,
            ZoomIn = true,
            ZoomOut = true,
            WorldMap = true -- wrath
        },
        Elements = {
            Backdrop = {
                Owner = "Minimap",
                DrawLayer = "BACKGROUND",
                DrawLevel = -7,
                Path = GetMedia("minimap-mask-opaque"),
                Size = function() return (198 / mapScale), (198 / mapScale) end,
                Point = { "CENTER" },
                Color = { 0, 0, 0, .75 },
            },
            Border = {
                Owner = "Backdrop",
                DrawLayer = "BORDER",
                DrawLevel = 1,
                Path = GetMedia("minimap-border"),
                Size = function() return (404 / mapScale), (404 / mapScale) end,
                Point = { "CENTER", -1, 0 },
                Color = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
            },
            AzeriteEye = {
                Owner = "Eye",
                DrawLayer = "BORDER",
                DrawLevel = 2,
                Path = GetMedia("group-finder-eye-green"),
                Size = { 64, 64 },
                Point = { "CENTER", 0, 0 },
                Color = { .90, .95, 1 }
            },
            -- CATA: check
            AzeriteEyeClassicPvP = (ns.IsClassic or ns.IsWrath or ns.IsCata) and {
                Owner = "EyeClassicPvP",
                DrawLayer = "BORDER",
                DrawLevel = 2,
                Path = GetMedia("group-finder-eye-orange"),
                Size = { 64, 64 },
                Point = { "CENTER", 0, 0 },
                Color = { .90, .95, 1 }
            }
        }
    }
}

-- Element Callbacks
--------------------------------------------
local Minimap_OnMouseWheel = function(self, delta)
    if (delta > 0) then
        (Minimap.ZoomIn or MinimapZoomIn):Click()
    elseif (delta < 0) then
        (Minimap.ZoomOut or MinimapZoomOut):Click()
    end
end

local Minimap_OnMouseUp = function(self, button)
    if (button == "RightButton") then
        ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor")
    else
        local func = Minimap.OnClick or Minimap_OnClick
        if (func) then
            func(self)
        end
    end
end

local Mail_OnEnter = function(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, self)

    -- Add unread mail notifier.
    local sender1, sender2, sender3 = GetLatestThreeSenders()
    if (sender1 or sender2 or sender3) then
        GameTooltip:AddLine(L_HAVE_MAIL_FROM, unpack(Colors.highlight))
        if (sender1) then
            GameTooltip:AddLine(sender1, unpack(Colors.green))
        end
        if (sender2) then
            GameTooltip:AddLine(sender2, unpack(Colors.green))
        end
        if (sender3) then
            GameTooltip:AddLine(sender3, unpack(Colors.green))
        end
    else
        GameTooltip:AddLine(L_HAVE_MAIL, unpack(Colors.highlight))
    end

    GameTooltip:Show()
end

local Mail_OnLeave = function(self)
    GameTooltip:Hide()
end

-- Element API
--------------------------------------------
MinimapMod.UpdateCompass = function(self)
    local compass = self.compass
    if (not compass) then
        return
    end
    if (self.rotateMinimap) then
        local radius = self.compassRadius
        if (not radius) then
            local width = compass:GetWidth()
            if (not width) then
                return
            end
            radius = width / 2
        end

        local playerFacing = GetPlayerFacing()
        if (not playerFacing) or (self.supressCompass) then
            compass:SetAlpha(0)
        else
            compass:SetAlpha(1)
        end

        local angle = (self.rotateMinimap and playerFacing) and -playerFacing or 0
        compass.north:SetPoint("CENTER", radius * math_cos(angle + half_pi), radius * math_sin(angle + half_pi))
    else
        compass:SetAlpha(0)
    end
end

MinimapMod.UpdateMail = function(self)
    local mail = self.mail
    if (not mail) then return end
    local hasMail = HasNewMail()
    if (hasMail) then
        mail:Show()
        mail.frame:Show()
    else
        mail:Hide()
        mail.frame:Hide()
    end
end

MinimapMod.UpdateTimers = function(self)
    self.rotateMinimap = GetCVarBool("rotateMinimap")

    if (self.rotateMinimap) then
        if (not self.compassTimer) then
            self.compassTimer = self:ScheduleRepeatingTimer("UpdateCompass", 1 / 60)
            self:UpdateCompass()
        end
    elseif (self.compassTimer) then
        self:CancelTimer(self.compassTimer)
        self:UpdateCompass()
    end
end

-- Addon Styling & Initialization
--------------------------------------------
MinimapMod.InitializeMBB = function(self)
    local button = CreateFrame("Frame", nil, Minimap)
    button:SetFrameLevel(button:GetFrameLevel() + 10)
    button:SetPoint("BOTTOMRIGHT", -244, 35)
    button:SetSize(32, 32)
    button:SetFrameStrata("LOW") -- MEDIUM collides with Immersion

    local frame = _G.MBB_MinimapButtonFrame
    frame:SetParent(button)
    frame:RegisterForDrag()
    frame:SetSize(32, 32)
    frame:ClearAllPoints()
    frame:SetFrameStrata("LOW") -- MEDIUM collides with Immersion
    frame:SetPoint("CENTER", 0, 0)
    frame:SetHighlightTexture("")
    frame:DisableDrawLayer("OVERLAY")

    frame.ClearAllPoints = noop
    frame.SetPoint = noop
    frame.SetAllPoints = noop

    local icon = _G.MBB_MinimapButtonFrame_Texture
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", 0, 0)
    icon:SetSize(32, 32)
    icon:SetTexture(GetMedia("plus"))
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetAlpha(.85)

    local down, over
    local setalpha = function()
        if (down and over) then
            icon:SetAlpha(1)
        elseif (down or over) then
            icon:SetAlpha(.95)
        else
            icon:SetAlpha(.85)
        end
    end

    frame:SetScript("OnMouseDown", function(self)
        down = true
        setalpha()
    end)

    frame:SetScript("OnMouseUp", function(self)
        down = false
        setalpha()
    end)

    frame:SetScript("OnEnter", function(self)
        MBB_ShowTimeout = -1
        over = true
        setalpha()

        if (GameTooltip:IsForbidden()) then return end

        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:AddLine("MinimapButtonBag v" .. MBB_Version)
        GameTooltip:AddLine(MBB_TOOLTIP1, 0, 1, 0, true)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function(self)
        MBB_ShowTimeout = 0
        over = false
        setalpha()

        if (GameTooltip:IsForbidden()) then return end

        GameTooltip:Hide()
    end)
end

MinimapMod.InitializeAddon = function(self, addon)
    if (not IsAddOnEnabled(addon)) then
        return
    end
    local method = self["Initialize" .. addon]
    if (method) then
        if (not IsAddOnLoaded(addon)) then
            LoadAddOn(addon)
        end
        method(self)
    end
end

-- Module Theme API (really...?)
--------------------------------------------
MinimapMod.RegisterTheme = function(self, name, skin)
    if (Skins[name] or name == DEFAULT_THEME) then return end
    Skins[name] = skin
end

MinimapMod.SetMinimapTheme = function(self, input)
    if (InCombatLockdown()) then return end
    local theme = "azerite"
    self:SetTheme(theme)
end

MinimapMod.SetTheme = function(self, requestedTheme)
    if (InCombatLockdown()) then return end

    -- Theme names are case sensitive,
    -- but we don't want the input to be.
    local name
    for theme in next, Skins do
        if (string_lower(theme) == string_lower(requestedTheme)) then
            name = theme
            break
        end
    end
    if (not name or not Skins[name] or name == CURRENT_THEME) then return end

    local current, new = Skins[CURRENT_THEME], Skins[name]

    -- Disable unused custom elements.
    if (current.Elements) then
        for element, data in next, current.Elements do
            if (data) and (not new.Elements or not new.Elements[element]) then
                Elements[element]:SetParent(UIHider)
                if (ObjectSnippets[element]) then
                    ObjectSnippets[element].Disable(Objects[element])
                end
            end
        end
    end

    -- Update Blizzard element visibility.
    for element, object in next, Objects do
        if (new.HideElements and new.HideElements[element]) then
            object:SetParent(UIHider)
            if (ObjectSnippets[element]) then
                ObjectSnippets[element].Disable(object)
            end
        else
            object:SetParent(ObjectOwners[element])
            if (ObjectSnippets[element]) then
                ObjectSnippets[element].Enable(object)
                ObjectSnippets[element].Update(object)
            end
        end
    end

    -- Enable new theme's custom elements.
    if (new.Elements) then
        for element, data in next, new.Elements do
            if (data) then
                -- Retrieve the owner of the object
                local owner = data and data.Owner and ObjectOwners[data.Owner] or Minimap

                -- Retrieve the object
                local object, objectParent = Elements[element]

                -- If a custom object does not exist, create it.
                if (not object) then
                    -- Figure out what our custom object should be parented to.
                    objectParent = data and data.Owner and Objects[data.Owner] or Minimap

                    -- Create!
                    if (ElementTypes[element] == "Texture") then
                        object = objectParent:CreateTexture()
                        Elements[element] = object
                    end
                end

                -- Silently ignore non-supported objects.
                if (object) then
                    object:SetParent(objectParent or owner)

                    if (data.Size) then
                        if (type(data.Size) == "function") then
                            object:SetSize(data.Size())
                        else
                            object:SetSize(unpack(data.Size))
                        end
                    else
                        object:SetSize(Minimap:GetSize())
                    end

                    if (data.Point) then
                        object:ClearAllPoints()
                        if (type(data.Point) == "function") then
                            object:SetPoint(data.Point())
                        else
                            object:SetPoint(unpack(data.Point))
                        end
                    end

                    if (ElementTypes[element] == "Texture") then
                        object:SetTexture(data.Path)
                        object:SetDrawLayer(data.DrawLayer or "ARTWORK", data.DrawLevel or 0)
                        if (data.Color) then
                            object:SetVertexColor(unpack(data.Color))
                        else
                            object:SetVertexColor(1, 1, 1, 1)
                        end
                    end

                    -- Run object callbacks.
                    if (ObjectSnippets[element]) then
                        ObjectSnippets[element].Enable(Elements[element])
                        ObjectSnippets[element].Update(Elements[element])
                    end
                end
            end
        end
    end

    CURRENT_THEME = name

    -- Update custom element visibility
    self:UpdateCustomElements()
end

-- Minimap Widget Settings
--------------------------------------------
-- Create our custom elements
-- *This is a temporary and clunky measure,
--  eventually I want this baked into the themes,
--  including the position based visibility.
MinimapMod.CreateCustomElements = function(self)
    local db = ns.Config.Minimap

    local frame = CreateFrame("Frame", nil, Minimap)
    frame:SetFrameLevel(Minimap:GetFrameLevel())
    frame:SetAllPoints(Minimap)

    self.widgetFrame = frame

    -- Compass
    local compass = CreateFrame("Frame", nil, frame)
    compass:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    compass:SetPoint("TOPLEFT", db.CompassInset, -db.CompassInset)
    compass:SetPoint("BOTTOMRIGHT", -db.CompassInset, db.CompassInset)

    local north = compass:CreateFontString(nil, "ARTWORK", nil, 1)
    north:SetFontObject(db.CompassFont)
    north:SetTextColor(unpack(db.CompassColor))
    north:SetText(db.CompassNorthTag)
    compass.north = north

    self.compass = compass

    -- Coordinates
    local coordinates = frame:CreateFontString(nil, "OVERLAY", nil, 1)
    coordinates:SetJustifyH("CENTER")
    coordinates:SetJustifyV("MIDDLE")
    coordinates:SetFontObject(db.CoordinateFont)
    coordinates:SetTextColor(unpack(db.CoordinateColor))
    coordinates:SetPoint(unpack(db.CoordinatePlace))

    self.coordinates = coordinates

    -- Mail
    local mailFrame = CreateFrame("Button", nil, frame)
    mailFrame:SetFrameLevel(mailFrame:GetFrameLevel() + 5)
    mailFrame:SetScript("OnEnter", Mail_OnEnter)
    mailFrame:SetScript("OnLeave", Mail_OnLeave)

    local mail = frame:CreateFontString(nil, "OVERLAY", nil, 1)
    mail.frame = mailFrame
    mail:SetFontObject(db.MailFont)
    mail:SetTextColor(unpack(db.MailColor))
    mail:SetJustifyH(db.MailJustifyH)
    mail:SetJustifyV(db.MailJustifyV)
    mail:SetFormattedText("%s", L_MAIL)
    mail:SetPoint(unpack(db.MailPosition))
    mailFrame:SetAllPoints(mail)

    self.mail = mail

    self:UpdateCustomElements()
    self.CreateCustomElements = noop
end

-- Update the visibility of the custom elements
MinimapMod.UpdateCustomElements = function(self)
    if (not self.widgetFrame) then return end
    if (CURRENT_THEME == "Azerite") then
        self.widgetFrame:Show()
    else
        self.widgetFrame:Hide()
    end
end

MinimapMod.PostUpdatePositionAndScale = function(self)
    local config = defaults.savedPosition

    self.widgetFrame:SetScale(ns.API.GetEffectiveScale() / config.scale)
    self:UpdateCustomElements()

    if (ns.IsRetail) then
        MinimapCluster.MinimapContainer:SetScale(1)
    end

    -- TODO: Figure out all the elements I should rescale.

    for name in next, {
        MiniMapBattlefieldFrame = true,
        MiniMapLFGFrame = true,
        QueueStatusButton = true
    } do
        local element = _G[name]
        if (element) then
            element:SetScale(ns.API.GetEffectiveScale() / config.scale)
        end
    end
end


MinimapMod.UpdatePositionAndScale = function(self)
    if (not self.frame) then return end

    if (InCombatLockdown()) then
        self.updateneeded = true
        return
    end

    self.updateneeded = nil

    local config = defaults.savedPosition
    if (config) then
        self.frame:SetScale(config.scale)
    end

    if (self.PostUpdatePositionAndScale) then
        self:PostUpdatePositionAndScale()
    end
end

MinimapMod.UpdatePosition = function(self)
    local db = ns.Config.Minimap
    Minimap:ClearAllPoints()
    Minimap:SetPoint(unpack(ns.db.global.minimap.storedPosition or db.Position))
    Minimap:SetMovable(true)
end

MinimapMod.UpdateSettings = function(self)
    self:SetTheme(defaults.theme)
    self:UpdateCompass()
    self:UpdateMail()
    self:UpdateTimers()
    self:UpdateCustomElements()
    self:UpdatePosition()
end

MinimapMod.InitializeObjectTables = function(self)
    Objects.BorderTop = MinimapBorderTop
    Objects.BorderClassic = MinimapBorder
    Objects.Calendar = GameTimeFrame
    Objects.Clock = TimeManagerClockButton
    Objects.Compass = MinimapCompassTexture
    Objects.Difficulty = MiniMapInstanceDifficulty
    Objects.Eye = MiniMapLFGFrame
    Objects.EyeClassicPvP = MiniMapBattlefieldFrame
    Objects.Mail = MiniMapMailFrame
    Objects.Tracking = MiniMapTracking
    Objects.Zone = MinimapZoneTextButton
    Objects.ZoomIn = MinimapZoomIn
    Objects.ZoomOut = MinimapZoomOut
    Objects.WorldMap = MiniMapWorldMapButton

    ObjectOwners.BorderTop = MinimapCluster
    ObjectOwners.BorderClassic = MinimapBackdrop
    ObjectOwners.Calendar = MinimapCluster
    ObjectOwners.Clock = MinimapCluster
    ObjectOwners.Compass = MinimapBackdrop
    ObjectOwners.Difficulty = MinimapCluster
    ObjectOwners.Expansion = MinimapBackdrop
    ObjectOwners.Eye = MinimapBackdrop
    ObjectOwners.EyeClassicPvP = Minimap
    ObjectOwners.Mail = Minimap
    ObjectOwners.Tracking = MinimapCluster
    ObjectOwners.Zone = MinimapCluster
    ObjectOwners.ZoomIn = Minimap
    ObjectOwners.ZoomOut = Minimap
    ObjectOwners.WorldMap = MinimapBackdrop
end

MinimapMod.OnEnable = function(self)
    LoadAddOn("Blizzard_TimeManager")
    self:InitializeObjectTables()

    MinimapCluster:EnableMouse(false)
    MinimapCluster:SetFrameLevel(1)
    Minimap:RegisterEvent("UPDATE_PENDING_MAIL")
    Minimap:SetScript("OnEvent", function(frame, event, ...)
        if (event == "UPDATE_PENDING_MAIL") then
            self:UpdateMail()
        end
    end)
    self.frame = Minimap
    self.frame:SetMovable(true)
    self.frame:EnableMouseWheel(true)
    self.frame:SetScript("OnMouseWheel", Minimap_OnMouseWheel)
    self.frame:SetScript("OnMouseUp", Minimap_OnMouseUp)

    self:CreateCustomElements()
    self:UpdateSettings()
    self:RegisterChatCommand("setminimaptheme", "SetMinimapTheme")
    self:InitializeAddon("MBB")
end
