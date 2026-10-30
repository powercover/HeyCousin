local _, HC = ...

local Theme = HC.Theme
local C = Theme.C

local function Hex(value)
    return { tonumber(value:sub(1, 2), 16) / 255, tonumber(value:sub(3, 4), 16) / 255, tonumber(value:sub(5, 6), 16) / 255 }
end

-- Smooth: warm darks, parchment text, one gold; rounded corners, hairline edges, soft shadows,
-- the game's Morpheus for titles. The primary color is your crest's.
local skin = {
    key = "smooth", folder = "Smooth", filter = "LINEAR", press = 1, iconButton = "round",
    letters = "font", crest = "smooth", sound = "chime", ribbonText = "gold", ribbonTextY = 0,
    badgeTint = { 0.78, 0.2, 0.17 },
    buttonText = { primary = "text", secondary = "text", ghost = "text2", round = "text2" },
    colors = {
        ink = Hex("0E0B09"), bg = Hex("14110E"), surface = Hex("1D1813"), raised = Hex("262019"), hover = Hex("30281F"),
        selected = Hex("2F271E"), line = Hex("3A3026"), gold = Hex("D9AE54"), text = Hex("F2E8D8"),
        text2 = Hex("B8AC98"), text3 = Hex("82776A"), buttonText = Hex("F2E8D8"), near = Hex("5BD17A"),
        enemy = Hex("E0533D"),
    },
    fonts = {
        Title = { height = 22, display = true },
        Headline = { height = 17, display = true },
        Big = { height = 30, display = true },
        Body = { height = 12 },
        Small = { height = 11 },
        Tiny = { height = 9 },
        Button = { height = 12 },
    },
}
skin.name = HC.L["Smooth"]
skin.note = HC.L["Dark and gold, with soft edges."]

local PANELS = {
    window = { fill = "surface", edge = "gold", edgeAlpha = 0.32, shadow = 0.6, corner = 10 },
    toast = { fill = "bg", edge = "gold", edgeAlpha = 0.55, shadow = 0.75, corner = 10 },
    card = { fill = "raised", edge = "gold", edgeAlpha = 0.28, corner = 8 },
    tile = { fill = "raised", edge = "line", edgeAlpha = 1, corner = 8 },
    well = { fill = "bg", edge = "line", edgeAlpha = 1, corner = 6 },
    frame = { fill = "surface", edge = "gold", edgeAlpha = 0.45, corner = 8 },
}

function skin.Panel(frame, style)
    local spec = PANELS[style] or PANELS.card
    if spec.shadow then
        frame.shadow = Theme.Slice(frame, Theme.Art("Shadow"), "BACKGROUND", -8, 16, 16)
        frame.shadow:SetColor(0, 0, 0, spec.shadow)
    end
    local fill, edge = C[spec.fill], C[spec.edge]
    frame.body = Theme.Slice(frame, Theme.Art("Round"), "BACKGROUND", -7, spec.corner)
    frame.body:SetColor(fill[1], fill[2], fill[3], 1)
    frame.edge = Theme.Slice(frame, Theme.Art("RoundLine"), "BORDER", -7, spec.corner)
    frame.edge:SetColor(edge[1], edge[2], edge[3], spec.edgeAlpha)
end

function skin.DecorateButton(button)
    button.fill = Theme.Slice(button, Theme.Art("Round"), "BACKGROUND", 0, 6)
    button.edge = Theme.Slice(button, Theme.Art("RoundLine"), "BORDER", 0, 6)
end

local function Lit(color, factor)
    return math.min(1, color[1] * factor), math.min(1, color[2] * factor), math.min(1, color[3] * factor)
end

function skin.PaintButton(button, state)
    local kind = button.kind
    local hover = state == "hover" or state == "down"
    local text = C.text
    if kind == "primary" then
        local a, m = Theme.Accent(), Theme.Metal()
        local r, g, b = Lit(a, state == "down" and 0.85 or hover and 1.18 or 1)
        button.fill:SetColor(r, g, b, 1)
        button.edge:SetColor(m[1], m[2], m[3], 0.55)
    elseif kind == "secondary" then
        local fill = hover and C.hover or C.raised
        button.fill:SetColor(fill[1], fill[2], fill[3], 1)
        button.edge:SetColor(C.line[1], C.line[2], C.line[3], 1)
    else
        button.fill:SetColor(C.hover[1], C.hover[2], C.hover[3], hover and 1 or 0)
        button.edge:SetColor(0, 0, 0, 0)
        text = C.text2
    end
    if state == "off" then
        text = C.text3
    end
    button.label:SetTextColor(text[1], text[2], text[3])
    button:SetAlpha(state == "off" and 0.5 or 1)
end

function skin.DecorateArrow(button)
    button.back = Theme.Texture(button, Theme.Art("Circle"), "BACKGROUND", 0, C.raised)
    button.back:SetAllPoints()
    button.ring = Theme.Texture(button, Theme.Art("CircleLine"), "BORDER", 0, C.line)
    button.ring:SetAllPoints()
    button.art = Theme.Texture(button, Theme.Icon(button.direction == "RIGHT" and "ChevronRight" or "ChevronLeft"),
        "ARTWORK", 0, C.text2)
    button.art:SetSize(button:GetWidth() * 0.5, button:GetHeight() * 0.5)
    button.art:SetPoint("CENTER")
end

function skin.PaintArrow(button, state)
    local fill = state == "normal" and C.raised or C.hover
    button.back:SetVertexColor(fill[1], fill[2], fill[3])
    local text = state == "normal" and C.text2 or C.text
    button.art:SetVertexColor(text[1], text[2], text[3])
    local m = Theme.Metal()
    if state == "normal" then
        button.ring:SetVertexColor(C.line[1], C.line[2], C.line[3])
    else
        button.ring:SetVertexColor(m[1], m[2], m[3], 0.8)
    end
end

-- a switch: the knob slides, the track takes your crest's color when on
function skin.DecorateToggle(toggle)
    toggle:SetSize(34, 18)
    toggle.track = Theme.Slice(toggle, Theme.Art("Round"), "BACKGROUND", 0, 9)
    toggle.knob = Theme.Texture(toggle, Theme.Art("Circle"), "ARTWORK", 0, C.text)
    toggle.knob:SetSize(14, 14)
end

function skin.PaintToggle(toggle, on, instant)
    local color = on and Theme.Accent() or C.line
    toggle.track:SetColor(color[1], color[2], color[3], 1)
    local function Place(x)
        toggle.knob:SetPoint("LEFT", toggle, "LEFT", x, 0)
    end
    local x = on and 18 or 2
    if instant then
        Theme.Jump(toggle.knob, x, Place)
    else
        Theme.Ease(toggle.knob, x, Place, 16)
    end
end

function skin.DecorateSwatch(swatch, color, size)
    swatch.chip = Theme.Texture(swatch, Theme.Art("Circle"), "ARTWORK", 0, color)
    swatch.chip:SetSize(size, size)
    swatch.chip:SetPoint("CENTER")
    swatch.pick = Theme.Texture(swatch, Theme.Art("CircleLine"), "OVERLAY", 0, C.text)
    swatch.pick:SetAllPoints()
end

function skin.PaintSwatch(swatch, chosen)
    swatch.pick:SetShown(chosen)
end

-- a round dot with a soft ring that breathes out from it
function skin.Dot(parent, size, color, pulse)
    local dot = Theme.Texture(parent, Theme.Art("Circle"), "ARTWORK", 2, color)
    dot:SetSize(size, size)
    if pulse then
        local ring = Theme.Texture(parent, Theme.Art("Circle"), "ARTWORK", 1, color)
        ring:SetAlpha(0)
        ring:SetSize(size, size)
        ring:SetPoint("CENTER", dot, "CENTER")
        local group = ring:CreateAnimationGroup()
        group:SetLooping("REPEAT")
        local grow = group:CreateAnimation("Scale")
        grow:SetScaleFrom(1, 1)
        grow:SetScaleTo(2.6, 2.6)
        grow:SetDuration(1.4)
        grow:SetSmoothing("OUT")
        local fade = group:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.55)
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

-- a class icon in a circle, ringed in the class color
function skin.Avatar(parent, size)
    local avatar = CreateFrame("Frame", nil, parent)
    avatar:SetSize(size, size)
    avatar.icon = avatar:CreateTexture(nil, "ARTWORK", nil, 1)
    avatar.icon:SetAllPoints()
    if type(avatar.CreateMaskTexture) == "function" then
        local mask = avatar:CreateMaskTexture()
        mask:SetTexture(Theme.Art("Circle"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(avatar.icon)
        avatar.icon:AddMaskTexture(mask)
    end
    avatar.ring = Theme.Texture(avatar, Theme.Art("CircleLine"), "ARTWORK", 2)
    avatar.ring:SetPoint("TOPLEFT", -2, 2)
    avatar.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    return avatar
end

function skin.Minimap(button)
    button.icon = Theme.Texture(button, Theme.Art("Circle"), "BACKGROUND", 0, C.bg)
    button.icon:SetAllPoints()
    button.ring = Theme.Texture(button, Theme.Art("CircleLine"), "OVERLAY", 0)
    button.ring:SetAllPoints(button.icon)
    Theme.OnAccent(function(_, metal)
        button.ring:SetVertexColor(metal[1], metal[2], metal[3], 0.9)
    end)
end

Theme.Register(skin)
