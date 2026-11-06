local _, HC = ...

HC.Minimap = {}

local Minimap_ = HC.Minimap
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Kin = HC.Kin
local L = HC.L
local C = Theme.C


-- How far outside the minimap's edge the button's center sits: as LibDBIcon-1.0 places buttons
-- (most addons' minimap buttons), so ours lines up with theirs. Placement as Better Great
-- Vault's button.
local EDGE_OFFSET = 5
local FALLBACK_RADIUS = 80
local DEFAULT_ANGLE = 200

-- Which quarters of the minimap are round (GetMinimapShape, set by minimap addons): right-bottom,
-- left-bottom, right-top, left-top. In a square quarter the button follows the edges instead.
local MINIMAP_SHAPES = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local button

local function Place()
    if not button or button:GetParent() ~= Minimap then
        return
    end
    local angle = tonumber(HeyCousinDB.minimapAngle) or DEFAULT_ANGLE
    local rad = math.rad(angle)
    local x, y = math.cos(rad), math.sin(rad)
    local width, height = Minimap:GetWidth(), Minimap:GetHeight()
    local w = width and width > 0 and width / 2 + EDGE_OFFSET or FALLBACK_RADIUS
    local h = height and height > 0 and height / 2 + EDGE_OFFSET or FALLBACK_RADIUS
    local quarter = 1
    if x < 0 then
        quarter = quarter + 1
    end
    if y > 0 then
        quarter = quarter + 2
    end
    local shape = type(GetMinimapShape) == "function" and GetMinimapShape() or "ROUND"
    local round = MINIMAP_SHAPES[shape] or MINIMAP_SHAPES.ROUND
    if round[quarter] then
        x, y = x * w, y * h
    else
        x = math.max(-w, math.min(x * (math.sqrt(2 * w * w) - 10), w))
        y = math.max(-h, math.min(y * (math.sqrt(2 * h * h) - 10), h))
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function ShowTooltip(owner)
    local house, surname = Kin.House()
    local total, nearby = Kin.Counts()
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(L["Hey Cousin!"], C.tip[1], C.tip[2], C.tip[3])
    if house and surname then
        local metal = Theme.Metal()
        GameTooltip:AddLine(string.format(L["House %s"], surname), metal[1], metal[2], metal[3])
        local line = total == 1 and L["1 relative"] or string.format(L["%d relatives"], total)
        if nearby > 0 then
            line = line .. ", " .. string.format(L["%d near you now"], nearby)
        end
        GameTooltip:AddLine(line, C.tip2[1], C.tip2[2], C.tip2[3])
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L["Click"], L["Your family"], C.tip3[1], C.tip3[2], C.tip3[3], C.tip2[1], C.tip2[2],
        C.tip2[3])
    GameTooltip:AddDoubleLine(L["Right-click"], L["Settings"], C.tip3[1], C.tip3[2], C.tip3[3], C.tip2[1], C.tip2[2],
        C.tip2[3])
    GameTooltip:AddDoubleLine(L["Drag"], L["Move this button"], C.tip3[1], C.tip3[2], C.tip3[3], C.tip2[1],
        C.tip2[2], C.tip2[3])
    GameTooltip:Show()
end

local function RunClick(mouseButton)
    if mouseButton == "RightButton" then
        HC.Options.Show()
    else
        HC.Window.Toggle()
    end
end

-- The release that ends a drag isn't a click (Better Great Vault's rule): only a click from that
-- same release is ignored.
local function DragRelease(self)
    local stopped = self.dragStopped
    self.dragStopped = nil
    return self.dragging or (stopped ~= nil and GetTime() - stopped < 0.2)
end

-- The theme's plate and ring (Skins/*.lua), and its count badge; a theme change swaps them.
local function Decorate()
    for _, old in ipairs({ button.icon or false, button.ring or false }) do
        if old then
            old:Hide()
        end
    end
    button.ring = nil
    local skin = Theme.Skin()
    skin.Minimap(button)
    button.crest:ClearAllPoints()
    button.crest:SetPoint("CENTER", button.icon, "CENTER", 0, 0)
    Theme.SetArt(button.badge.back, Theme.Art("Badge"))
    local tint = skin.badgeTint or { 1, 1, 1 }
    button.badge.back:SetVertexColor(tint[1], tint[2], tint[3])
end

local function Build()
    button = CreateFrame("Button", "HeyCousinMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    -- the theme's plate under your crest; the plate is the button's icon, so minimap button
    -- addons that crop or move icons find one
    button.glow = Theme.Texture(button, Theme.Shared("Glow"), "BACKGROUND", -1)
    button.glow:SetPoint("TOPLEFT", -10, 10)
    button.glow:SetPoint("BOTTOMRIGHT", 10, -10)
    button.glow:SetBlendMode("ADD")
    local function SetGlow(value)
        button.glow:SetAlpha(value)
    end
    Theme.Jump(button.glow, 0, SetGlow)
    button.crest = Crest.Create(button, 22)
    -- how many relatives, as in the sketch
    local badge = CreateFrame("Frame", nil, button)
    badge:SetSize(16, 16)
    badge:SetPoint("CENTER", button, "TOPRIGHT", -4, -4)
    badge:SetFrameLevel(button:GetFrameLevel() + 4)
    badge.back = Theme.Texture(badge, nil, "ARTWORK", 0)
    badge.back:SetAllPoints()
    badge.text = Theme.Text(badge, "Tiny", C.text)
    badge.text:SetPoint("CENTER", 0, 0)
    button.badge = badge

    button:SetScript("OnMouseDown", function(self)
        self.crest:SetPoint("CENTER", self.icon, "CENTER", 0, -1)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.crest:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
    end)
    button:SetScript("OnClick", Utils.Protect("minimap click", function(self, mouseButton)
        if DragRelease(self) then
            return
        end
        GameTooltip:Hide()
        RunClick(mouseButton)
    end))
    button:SetScript("OnEnter", Utils.Protect("minimap hover", function(self)
        local accent = Theme.Accent()
        self.glow:SetVertexColor(accent[1], accent[2], accent[3])
        Theme.Ease(self.glow, 0.7, SetGlow, 14)
        ShowTooltip(self)
    end))
    button:SetScript("OnLeave", function(self)
        Theme.Ease(self.glow, 0, SetGlow, 14)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStart", function(self)
        if HeyCousinDB.lockMinimap then
            return
        end
        GameTooltip:Hide()
        self.dragging = true
        self:SetScript("OnUpdate", function(frame)
            if not frame.dragging then
                frame:SetScript("OnUpdate", nil)
                return
            end
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            if not mx or not scale or scale == 0 or frame:GetParent() ~= Minimap then
                return
            end
            HeyCousinDB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            Place()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self.dragging = false
        self.dragStopped = GetTime()
        self:SetScript("OnUpdate", nil)
    end)
    Minimap:HookScript("OnSizeChanged", function()
        Place()
    end)
    Decorate()
end

-- A new theme: the same button, in the new theme's plate.
Theme.OnSkin(function()
    if button then
        Decorate()
        Minimap_.Refresh()
    end
end)

-- Your crest and the count, after any change.
function Minimap_.Refresh()
    if not button then
        return
    end
    local house, surname = Kin.House()
    button.crest:SetCrest(house and house.crest, surname)
    local total = Kin.Counts()
    button.badge:SetShown(total > 0)
    button.badge.text:SetText(total > 99 and "99+" or tostring(total))
    button.badge:SetWidth(math.max(16, math.ceil(button.badge.text:GetStringWidth()) + 8))
end

-- Shows or hides the button as the settings say.
function Minimap_.Apply()
    if not Minimap then
        return
    end
    if HeyCousinDB.showMinimap == false then
        if button then
            button:Hide()
        end
        return
    end
    if not button then
        Build()
    end
    Place()
    Minimap_.Refresh()
    button:Show()
end

Kin.OnChange(Minimap_.Refresh)

-- The addon compartment (the game's addon menu by the minimap), named in the TOC.
HeyCousin_OnAddonCompartmentClick = Utils.Protect("addon menu", function(_, mouseButton)
    RunClick(mouseButton)
end)

HeyCousin_OnAddonCompartmentEnter = Utils.Protect("addon menu", function(_, menuButton)
    if menuButton then
        ShowTooltip(menuButton)
    end
end)

HeyCousin_OnAddonCompartmentLeave = function()
    GameTooltip:Hide()
end
