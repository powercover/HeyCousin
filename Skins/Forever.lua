local _, HC = ...

local Theme = HC.Theme
local C = Theme.C

local function RGB(r, g, b)
    return { r / 255, g / 255, b / 255 }
end

-- Forever: WoW Forever's own look, the classic game's windows: dark stone in carved bronze frames
-- with rivets at the corners, the game's red buttons with gold text, gold Morpheus titles and Friz
-- Quadrata for the rest. Its art (Media/Forever, drawn by make_media.py) is smooth; the crests,
-- symbols and icons are Smooth's.
local skin = {
    key = "forever", folder = "Forever", filter = "LINEAR", press = 1, iconButton = "secondary",
    letters = "font", crest = "smooth", sound = "bell", ribbonText = "gold", ribbonTextY = 0,
    badgeTint = { 0.72, 0.1, 0.06 },
    displayFiles = { roman = "Fonts\\MORPHEUS.TTF", russian = "Fonts\\MORPHEUS_CYR.TTF" },
    buttonText = { primary = "gold", secondary = "text", ghost = "text2" },
    colors = {
        ink = RGB(10, 9, 8), bg = RGB(17, 15, 13), surface = RGB(30, 26, 22), raised = RGB(40, 34, 28),
        hover = RGB(58, 48, 38), selected = RGB(70, 54, 30), line = RGB(62, 50, 34), gold = RGB(255, 209, 0),
        text = RGB(240, 234, 220), text2 = RGB(200, 188, 164), text3 = RGB(146, 136, 118),
        buttonText = RGB(255, 209, 0), near = RGB(64, 214, 92), enemy = RGB(232, 64, 44),
    },
    fonts = {
        Title = { height = 24, display = true },
        Headline = { height = 17, display = true },
        Big = { height = 30, display = true },
        Body = { height = 12 },
        Small = { height = 11 },
        Tiny = { height = 9 },
        Button = { height = 12 },
    },
}
skin.name = HC.L["Forever"]
skin.note = HC.L["The game's own classic look."]

local PANELS = {
    window = { file = "Panel", corner = 24, shadow = 0.6 },
    toast = { file = "Panel", corner = 22, shadow = 0.75 },
    card = { file = "Card", corner = 12 },
    tile = { file = "Tile", corner = 12 },
    well = { file = "Well", corner = 8 },
    frame = { file = "Frame", corner = 12 },
}

function skin.Panel(frame, style)
    local spec = PANELS[style] or PANELS.card
    if spec.shadow then
        frame.shadow = Theme.Slice(frame, Theme.Art("Shadow"), "BACKGROUND", -8, 16, 16)
        frame.shadow:SetColor(0, 0, 0, spec.shadow)
    end
    frame.body = Theme.Slice(frame, Theme.Art(spec.file), "BACKGROUND", -7, spec.corner)
end

-- the button faces by kind: normal, pointed at, pressed, turned off
local FACES = {
    primary = { "Button", "ButtonHover", "ButtonDown", "ButtonOff" },
    secondary = { "Dark", "DarkHover", "DarkDown", "DarkOff" },
    ghost = { false, "DarkHover", "DarkDown", false },
}
local STATES = { normal = 1, hover = 2, down = 3, off = 4 }

function skin.DecorateButton(button)
    button.face = Theme.Slice(button, nil, "BACKGROUND", 0, 8)
end

function skin.PaintButton(button, state)
    local faces = FACES[button.kind] or FACES.secondary
    local file = faces[STATES[state]]
    if file then
        button.face:SetFile(Theme.Art(file))
    end
    button.face:SetShown(file ~= false and file ~= nil)
    local color = state == "off" and C.text3 or C[skin.buttonText[button.kind] or "text"] or C.text
    button.label:SetTextColor(color[1], color[2], color[3])
end

function skin.DecorateArrow(button)
    button.art = Theme.Texture(button, nil, "ARTWORK", 0)
end

function skin.PaintArrow(button, state)
    Theme.SetArt(button.art, Theme.Art(state == "normal" and "Arrow" or "ArrowHover"))
    if button.direction == "RIGHT" then
        button.art:SetTexCoord(1, 0, 0, 1)
    else
        button.art:SetTexCoord(0, 1, 0, 1)
    end
    local press = state == "down" and 1 or 0
    button.art:ClearAllPoints()
    button.art:SetPoint("TOPLEFT", 0, -press)
    button.art:SetPoint("BOTTOMRIGHT", 0, -press)
end

-- a check box in a bronze rim, with a gold check
function skin.DecorateToggle(toggle)
    toggle:SetSize(22, 22)
    toggle.box = Theme.Texture(toggle, nil, "ARTWORK", 0)
    toggle.box:SetAllPoints()
end

function skin.PaintToggle(toggle, on)
    Theme.SetArt(toggle.box, Theme.Art(on and "CheckOn" or "CheckOff"))
end

function skin.DecorateSwatch(swatch, color, size)
    swatch.chip = Theme.Texture(swatch, Theme.Art("Swatch"), "ARTWORK", 0, color)
    swatch.chip:SetSize(size + 4, size + 4)
    swatch.chip:SetPoint("CENTER")
    swatch.pick = Theme.Texture(swatch, Theme.Art("SwatchPick"), "OVERLAY", 0, C.gold)
    swatch.pick:SetAllPoints()
end

function skin.PaintSwatch(swatch, chosen)
    swatch.pick:SetShown(chosen)
end

-- a gem that glows: a soft ring breathes out from it
function skin.Dot(parent, size, color, pulse)
    local dot = Theme.Texture(parent, Theme.Art("Dot"), "ARTWORK", 2, color)
    dot:SetSize(size + 2, size + 2)
    if pulse then
        local ring = Theme.Texture(parent, Theme.Art("Circle"), "ARTWORK", 1, color)
        ring:SetAlpha(0)
        ring:SetSize(size, size)
        ring:SetPoint("CENTER", dot, "CENTER")
        local group = ring:CreateAnimationGroup()
        group:SetLooping("REPEAT")
        local grow = group:CreateAnimation("Scale")
        grow:SetScaleFrom(1, 1)
        grow:SetScaleTo(2.4, 2.4)
        grow:SetDuration(1.4)
        grow:SetSmoothing("OUT")
        local fade = group:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.5)
        fade:SetToAlpha(0)
        fade:SetDuration(1.4)
        fade:SetSmoothing("OUT")
        dot.ring, dot.pulse = ring, group
    end
    function dot:SetPulse(on)
        if self.pulse then
            self.ring:SetShown(on)
            if on then
                self.pulse:Play()
            else
                self.pulse:Stop()
            end
        end
    end
    return dot
end

function skin.Ribbon(ribbon)
    Theme.Panel(ribbon, "card")
end

-- a class icon cut round, in a metal ring of the class color (as the game's portraits)
function skin.Avatar(parent, size)
    local avatar = CreateFrame("Frame", nil, parent)
    avatar:SetSize(size, size)
    avatar.icon = avatar:CreateTexture(nil, "ARTWORK", nil, 1)
    avatar.icon:SetPoint("TOPLEFT", 2, -2)
    avatar.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    if type(avatar.CreateMaskTexture) == "function" then
        local mask = avatar:CreateMaskTexture()
        mask:SetTexture(Theme.Art("Circle"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(avatar.icon)
        avatar.icon:AddMaskTexture(mask)
    end
    avatar.ring = Theme.Texture(avatar, Theme.Art("Ring"), "ARTWORK", 2)
    avatar.ring:SetPoint("TOPLEFT", -1, 1)
    avatar.ring:SetPoint("BOTTOMRIGHT", 1, -1)
    return avatar
end

-- the game's round bronze rim, as its own minimap buttons have
function skin.Minimap(button)
    button.icon = Theme.Texture(button, Theme.Art("Plate"), "BACKGROUND", 0)
    button.icon:SetAllPoints()
end

Theme.Register(skin)
