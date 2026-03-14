local Addon, ns = ...
local UnitFrames = ns:NewModule("UnitFrames", "LibMoreEvents-1.0", "AceHook-3.0")
local oUF = ns.oUF

-- Globally available registries
ns.NamePlates = {}
ns.ActiveNamePlates = {}
ns.UnitStyles = {}
ns.UnitFrames = {}
ns.UnitFramesByName = {}

-- Lua API
local string_format = string.format
local string_match = string.match
local table_insert = table.insert
local table_concat = table.concat
local table_remove = table.remove

-- WoW API

-- TODO -- C_NamePlate doesn't exist in WOTLK
-- local C_NamePlate = C_NamePlate
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local SetCVar = SetCVar
local UnitIsUnit = UnitIsUnit

-- Addon API
local IsAddOnEnabled = ns.API.IsAddOnEnabled
local SetObjectScale = ns.API.SetObjectScale
local SetEffectiveObjectScale = ns.API.SetEffectiveObjectScale

-- Utility
-----------------------------------------------------
local Spawn = function(unit, name)
    local fullName = ns.Prefix .. "UnitFrame" .. name
    local frame = oUF:Spawn(unit, fullName)
    -- Vehicle switching is currently broken in Wrath.
    if (ns.IsWrath) then
        if (unit == "player") then
            local enable = frame.Enable
            frame.Enable = function(self)
                enable(self)
                frame:SetAttribute("toggleForVehicle", false)
            end

            local disable = frame.Disable
            frame.Disable = function(self)
                disable(self)
            end

            frame:SetAttribute("toggleForVehicle", false)
        elseif (unit == "pet") then
            local enable = frame.Enable
            frame.Enable = function(self)
                enable(self)
                frame:SetAttribute("toggleForVehicle", false)
            end

            local disable = frame.Disable
            frame.Disable = function(self)
                disable(self)
            end

            frame:SetAttribute("toggleForVehicle", false)
        end
    end

    -- Add to our registries.
    ns.UnitFramesByName[name] = frame
    ns.UnitFrames[#ns.UnitFrames + 1] = frame

    -- Inform the environment it was created.
    -- This fires after the frame has been created
    -- and still is located in its default position,
    -- but before any saved position has been applied.
    -- Any extension listening for this can overwrite
    -- the default position of the frame.
    ns:Fire("UnitFrame_Created", unit, fullName)

    return frame
end


-- Styling
-----------------------------------------------------
local UnitSpecific = function(self, unit)
    local id, style
    if (unit == "player") then
        style = self:GetName():find("HUD") and "PlayerHUD" or "Player"
        if (self:GetName():find("Boss")) then
            style = "Boss"
        end
    elseif (unit == "target") then
        style = "Target"
    elseif (unit == "targettarget") then
        style = "ToT"
    elseif (unit == "pet") then
        style = "Pet"
    elseif (unit == "focus") then
        style = "Focus"
    elseif (unit == "focustarget") then
        style = "FocusTarget"
    elseif (string_match(unit, "party%d?$")) then
        id = string_match(unit, "party(%d)")
        style = "Party"
    elseif (string_match(unit, "raid%d+$")) then
        id = string_match(unit, "raid(%d+)")
        style = "Raid"
    elseif (string_match(unit, "boss%d?$")) then
        id = string_match(unit, "boss(%d)")
        style = "Boss"
    elseif (string_match(unit, "arena%d?$")) then
        id = string_match(unit, "arena(%d)")
        style = "Arena"
    elseif (string_match(unit, "nameplate%d+$")) then
        id = string_match(unit, "nameplate(%d+)")
        style = "NamePlate"
    end

    if (style and ns.UnitStyles[style]) then
        return ns.UnitStyles[style](self, unit, id)
    end
end

-- UnitFrame Callbacks
-----------------------------------------------------
local OnEnter = function(self, ...)
    self.isMouseOver = true
    if (self.OnEnter) then
        self:OnEnter(...)
    end
    if (self.isUnitFrame) then
        return _G.UnitFrame_OnEnter(self, ...)
    end
end

local OnLeave = function(self, ...)
    self.isMouseOver = nil
    if (self.OnLeave) then
        self:OnLeave(...)
    end
    if (self.isUnitFrame) then
        return _G.UnitFrame_OnLeave(self, ...)
    end
end

local OnHide = function(self, ...)
    self.isMouseOver = nil
    if (self.OnHide) then
        self:OnHide(...)
    end
end

local AddForceUpdate = function(self, func)
    if (not self._forceUpdates) then
        self._forceUpdates = {}
    end
    table_insert(self._forceUpdates, func)
end

local RemoveForceUpdate = function(self, func)
    if (not self._forceUpdates) then
        return
    end
    for i, updateFunc in next, self._forceUpdates do
        if (updateFunc == func) then
            table_remove(self._forceUpdates, i)
            break
        end
    end
end

local ForceUpdate = function(self)
    if (self._forceUpdates) then
        for _, updateFunc in next, self._forceUpdates do
            updateFunc(self)
        end
    end
    self:UpdateAllElements("ForceUpdate")
end

UnitFrames.RegisterStyles = function(self)
    oUF:RegisterStyle(ns.Prefix, function(self, unit)
        SetObjectScale(self)

        self.isUnitFrame = true
        self.colors = ns.Colors

        self:RegisterForClicks("AnyUp")
        -- add a reddish beckground to all unit frames for debugging purposes


        self:SetAttribute("unit", unit)
        self:SetScript("OnEnter", OnEnter)
        self:SetScript("OnLeave", OnLeave)
        self:SetScript("OnHide", OnHide)

        self.ForceUpdate = ForceUpdate
        self.AddForceUpdate = AddForceUpdate
        self.RemoveForceUpdate = RemoveForceUpdate

        return UnitSpecific(self, unit)
    end)

    oUF:RegisterStyle(ns.Prefix .. "NamePlates", function(self, unit)
        SetEffectiveObjectScale(self)

        self.isNamePlate = true
        self.colors = ns.Colors

        self:SetPoint("CENTER", 0, 0)

        --self:SetScript("OnEnter", OnEnter)
        --self:SetScript("OnLeave", OnLeave)
        self:SetScript("OnHide", OnHide)

        --self:SetMouseMotionEnabled(true)
        --self:SetMouseClickEnabled(false)

        self.ForceUpdate = ForceUpdate
        self.AddForceUpdate = AddForceUpdate
        self.RemoveForceUpdate = RemoveForceUpdate

        return UnitSpecific(self, unit)
    end)
end

UnitFrames.RegisterMetaFunctions = function(self)
    local LibSmoothBar = LibStub("LibSmoothBar-1.0")
    local LibSpinBar = LibStub("LibSpinBar-1.0")
    local LibOrb = LibStub("LibOrb-1.0")

    oUF:RegisterMetaFunction("CreateBar", function(self, name, parent, ...)
        return LibSmoothBar:CreateSmoothBar(name, parent or self, ...)
    end)

    oUF:RegisterMetaFunction("CreateRing", function(self, name, parent, ...)
        return LibSpinBar:CreateSpinBar(name, parent or self, ...)
    end)

    oUF:RegisterMetaFunction("CreateOrb", function(self, name, parent, ...)
        return LibOrb:CreateOrb(name, parent or self, ...)
    end)
end

UnitFrames.SpawnUnitFrames = function(self)
    oUF:Factory(function(oUF)
        oUF:SetActiveStyle(ns.Prefix)

        -- We're currently not allowing this to be moved,
        -- as its contents including every single point in
        -- every variation of the class resource layout are
        -- all placed relative to UIParent not to the unit frame.
        -- Movement is coming, it's just fairly low on my priority list.
        -- Spawn("player", "PlayerClassPower")
        Spawn("player", "Player")
        Spawn("pet", "Pet")
        Spawn("focus", "Focus")
        Spawn("target", "Target")
        Spawn("targettarget", "ToT")

        -- Spawn boss frames
        local config = ns.Config.Boss
        local boss = SetObjectScale(CreateFrame("Frame", nil, UIParent))
        boss:SetPoint(unpack(config.AnchorPosition))
        boss:SetSize(unpack(config.AnchorSize))
        for id = 1, 5 do
            Spawn("boss" .. id, "Boss" .. id):SetPoint(config.Anchor, bossFrames, config.Anchor, (id - 1) *
                config.GrowthX, (id - 1) * config.GrowthY)
        end

        self:UpdateSettings()
    end)
end


UnitFrames.UpdateSettings = function(self)
    if (InCombatLockdown()) then return end

    local db = ns.db.global.unitframes

    local Player = ns.UnitFramesByName.Player
    if (Player) then
        if (db.enablePlayer) then
            Player:Enable()
        else
            Player:Disable()
        end
    end

    local PlayerHUD = ns.UnitFramesByName.PlayerHUD
    if (PlayerHUD) then
        if (db.enablePlayerHUD) then
            PlayerHUD:Enable()
        elseif (not db.enablePlayerHUD) then
            PlayerHUD:Disable()
        end
    end

    local Target = ns.UnitFramesByName.Target
    if (Target) then
        if (db.enableTarget) then
            Target:Enable()
        elseif (not db.enableTarget) then
            Target:Disable()
        end
    end

    local ToT = ns.UnitFramesByName.ToT
    if (ToT) then
        if (db.enableToT) then
            ToT:Enable()
        elseif (not db.enableToT) then
            ToT:Disable()
        end
    end

    local Focus = ns.UnitFramesByName.Focus
    if (Focus) then
        if (db.enableFocus) then
            Focus:Enable()
        elseif (not db.enableFocus) then
            Focus:Disable()
        end
    end

    local Pet = ns.UnitFramesByName.Pet
    if (Pet) then
        if (db.enablePet) then
            Pet:Enable()
        elseif (not db.enablePet) then
            Pet:Disable()
        end
    end

    for id = 1, 5 do
        local Boss = ns.UnitFramesByName["Boss" .. id]
        if (Boss) then
            if (db.enableBoss) then
                Boss:Enable()
            elseif (not db.enableBoss) then
                Boss:Disable()
            end
        end
    end
end

UnitFrames.ForceUpdate = function(self)
end

UnitFrames.OnEvent = function(self, event, ...)
    if (event == "PLAYER_ENTERING_WORLD") then
        local isInitialLogin, isReloadingUi = ...
        if (isInitialLogin or isReloadingUi) then
            -- There are no guarantees any frames are spawned here,
            -- since they too are created on this event by the oUF factory.
            -- self:KillNamePlateClutter()
        end
        -- self:SetNamePlateScales()
        -- elseif (event == "VARIABLES_LOADED") then
        --     self:SetNamePlateScales()
        -- elseif (event == "UI_SCALE_CHANGED") or (event == "DISPLAY_SIZE_CHANGED") then
        --     self:SetNamePlateScales()
    end
end

UnitFrames.OnInitialize = function(self)
    self:RegisterMetaFunctions()
    self:RegisterStyles()
    self:SpawnUnitFrames()
    -- self:SpawnNamePlates()
end

-- UnitFrames.OnEnable = function(self)
--     self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
--     self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnEvent")
--     self:RegisterEvent("UI_SCALE_CHANGED", "OnEvent")
--     self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
-- end

-- New Module Development
ns.UnitFrame = {}
ns.UnitFrame.defaults = { enabled = true, scale = 1 }

ns.UnitFrame.InitializeUnitFrame = function(self)
    self.isUnitFrame = true
    self.colors = ns.Colors

    self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter", OnEnter)
    self:SetScript("OnLeave", OnLeave)
    self:SetScript("OnHide", OnHide)
end
