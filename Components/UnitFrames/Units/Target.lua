-- Make the portrait look better for offline or invisible units.
local Portrait_PostUpdate = function(element, unit, hasStateChanged)
    print("Portrait_PostUpdate", unit, hasStateChanged)
    if (not element.state) then
        element:ClearModel()
        if (not element.fallback2DTexture) then
            element.fallback2DTexture = element:CreateTexture()
            element.fallback2DTexture:SetDrawLayer("ARTWORK")
            element.fallback2DTexture:SetAllPoints()
            element.fallback2DTexture:SetTexCoord(.1, .9, .1, .9)
        end
        SetPortraitTexture(element.fallback2DTexture, unit)
        element.fallback2DTexture:Show()
    else
        if (element.fallback2DTexture) then
            element.fallback2DTexture:Hide()
        end
        element.guid = guid
    end
end


-- Portrait
--------------------------------------------
local portraitFrame = CreateFrame("Frame", nil, self)
portraitFrame:SetFrameLevel(health:GetFrameLevel() - 2)
portraitFrame:SetAllPoints()

local portrait = CreateFrame("PlayerModel", nil, portraitFrame)
portrait:SetFrameLevel(portraitFrame:GetFrameLevel())
portrait:SetPoint(unpack(db.PortraitPosition))
portrait:SetSize(unpack(db.PortraitSize))
portrait:SetAlpha(db.PortraitAlpha)
portrait.showFallback2D = db.PortraitShowFallback2D

self.Portrait = portrait
self.Portrait.PostUpdate = Portrait_PostUpdate

local portraitBg = portraitFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
portraitBg:SetPoint(unpack(db.PortraitBackgroundPosition))
portraitBg:SetSize(unpack(db.PortraitBackgroundSize))
portraitBg:SetTexture(db.PortraitBackgroundTexture)
portraitBg:SetVertexColor(unpack(db.PortraitBackgroundColor))

self.Portrait.Bg = portraitBg

local portraitOverlayFrame = CreateFrame("Frame", nil, self)
portraitOverlayFrame:SetFrameLevel(health:GetFrameLevel() - 1)
portraitOverlayFrame:SetAllPoints()

local portraitShade = portraitOverlayFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
portraitShade:SetPoint(unpack(db.PortraitShadePosition))
portraitShade:SetSize(unpack(db.PortraitShadeSize))
portraitShade:SetTexture(db.PortraitShadeTexture)

self.Portrait.Shade = portraitShade

local portraitBorder = portraitOverlayFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
portraitBorder:SetPoint(unpack(db.PortraitBorderPosition))
portraitBorder:SetSize(unpack(db.PortraitBorderSize))

self.Portrait.Border = portraitBorder
