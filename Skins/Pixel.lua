local _, HC = ...

local Theme = HC.Theme
local C = Theme.C

local function RGB(r, g, b)
    return { r / 255, g / 255, b / 255 }
end

-- Pixel: chunky dark outlines, flat shading, warm wood colors, a hard cartoon shadow. Its art
-- (Media/Pixel, drawn by make_media.py on a small grid) shows sharp; the colors here match
-- make_media.py's palette.
local skin = {
    key = "pixel", folder = "Pixel", filter = "NEAREST", press = 2, iconButton = "secondary",
    letters = "pixel", crest = "pixel", sound = "boop", ribbonText = "buttonText", ribbonTextY = 2,
    buttonText = { primary = "buttonText", secondary = "text", ghost = "text2" },
    colors = {
        ink = RGB(28, 19, 20), bg = RGB(44, 31, 31), surface = RGB(60, 43, 42), raised = RGB(72, 52, 50),
        hover = RGB(82, 60, 56), selected = RGB(104, 70, 52), line = RGB(36, 25, 25),
        gold = RGB(240, 195, 90), text = RGB(244, 228, 196), text2 = RGB(205, 180, 151), text3 = RGB(150, 126, 108),
        buttonText = RGB(44, 27, 22), near = RGB(116, 208, 99), enemy = RGB(226, 78, 60),
    },
    fonts = {
        Title = { height = 19, flags = "OUTLINE" },
        Headline = { height = 14, flags = "OUTLINE" },
        Big = { height = 24, flags = "OUTLINE" },
        Body = { height = 12 },
        Small = { height = 11 },
        Tiny = { height = 10 },
        Button = { height = 12, shadow = false },
    },
}
skin.name = HC.L["Pixel"]
skin.note = HC.L["Chunky and cartoonish."]

local PANELS = {
    window = { file = "Panel", shadow = 0.55 },
    toast = { file = "Panel", shadow = 0.55 },
    card = { file = "Card" },
    tile = { file = "Card" },
    well = { file = "Well" },
    frame = { file = "Frame" },
}

function skin.Panel(frame, style)
    local spec = PANELS[style] or PANELS.card
    if spec.shadow then
        frame.shadow = Theme.Slice(frame, Theme.Art("Shadow"), "BACKGROUND", -8, 8, 0, 4, -4)
        frame.shadow:SetColor(C.ink[1], C.ink[2], C.ink[3], spec.shadow)
    end
    frame.body = Theme.Slice(frame, Theme.Art(spec.file), "BACKGROUND", -7, 8)
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
    local press = state == "down" and 2 or 0
    button.art:ClearAllPoints()
    button.art:SetPoint("TOPLEFT", 0, -press)
    button.art:SetPoint("BOTTOMRIGHT", 0, -press)
end

function skin.DecorateToggle(toggle)
    toggle:SetSize(24, 24)
    toggle.box = Theme.Texture(toggle, nil, "ARTWORK", 0)
    toggle.box:SetAllPoints()
end

function skin.PaintToggle(toggle, on)
    Theme.SetArt(toggle.box, Theme.Art(on and "CheckOn" or "CheckOff"))
end

function skin.DecorateSwatch(swatch, color, size)
    swatch.chip = Theme.Texture(swatch, Theme.Art("Swatch"), "ARTWORK", 0, color)
    swatch.chip:SetSize(size * 1.6, size * 1.6)
    swatch.chip:SetPoint("CENTER")
    swatch.pick = Theme.Texture(swatch, Theme.Art("SwatchPick"), "OVERLAY", 0, C.text)
    swatch.pick:SetSize(size + 6, size + 6)
    swatch.pick:SetPoint("CENTER")
end

function skin.PaintSwatch(swatch, chosen)
    swatch.pick:SetShown(chosen)
end

-- a square dot that blinks, like an old screen
function skin.Dot(parent, size, color, pulse)
    local dot = Theme.Texture(parent, Theme.Art("Dot"), "ARTWORK", 2, color)
    dot:SetSize(size * 2, size * 2)
    if pulse then
        local group = dot:CreateAnimationGroup()
        group:SetLooping("BOUNCE")
        local fade = group:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0.3)
        fade:SetDuration(0.55)
        dot.pulse = group
    end
    function dot:SetPulse(on)
        if self.pulse then
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
    Theme.Strip(ribbon, Theme.Art("Ribbon"), "ARTWORK", 0.25, ribbon:GetHeight() / 2)
end

-- a class icon in a square, outlined in ink
function skin.Avatar(parent, size)
    local avatar = CreateFrame("Frame", nil, parent)
    avatar:SetSize(size, size)
    avatar.back = Theme.Texture(avatar, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 0, C.ink)
    avatar.back:SetAllPoints()
    avatar.icon = avatar:CreateTexture(nil, "ARTWORK", nil, 1)
    avatar.icon:SetPoint("TOPLEFT", 2, -2)
    avatar.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    avatar.ring = Theme.Texture(avatar, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 2)
    avatar.ring:SetPoint("BOTTOMLEFT", 2, 2)
    avatar.ring:SetPoint("BOTTOMRIGHT", -2, 2)
    avatar.ring:SetHeight(2)
    return avatar
end

function skin.Minimap(button)
    button.icon = Theme.Texture(button, Theme.Art("Plate"), "BACKGROUND", 0)
    button.icon:SetAllPoints()
end

Theme.Register(skin)
