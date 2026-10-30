local _, HC = ...

HC.Crest = {}

local Crest = HC.Crest
local Theme = HC.Theme

Crest.SHAPES = { "Heater", "Round", "Kite", "Banner" }
Crest.DIVISIONS = { "Plain", "Pale", "Fess", "Bend", "Quarterly", "Chevron", "Cross" }

-- The symbols to bear, drawn for the addon (make_media.py) in every theme.
Crest.CHARGES = { "Heart", "Star", "Crown", "Tree", "Sword", "Key", "Moon", "Sun", "Flower", "Mushroom", "Skull",
    "Axe", "Tower", "Flame", "Bolt", "Anchor", "Cup", "Bell" }

-- Where the symbol sits on each shape: as a share of the crest from the top (Smooth), and in
-- art pixels of the 32-pixel crest (Pixel). The textures are drawn to these.
local SPOTS = {
    Heater = { y = 0.44, pixelY = 13 },
    Round = { y = 0.51, pixelY = 16 },
    Kite = { y = 0.40, pixelY = 12 },
    Banner = { y = 0.44, pixelY = 14 },
}
local DIVISION_SET, CHARGE_SET = {}, {}
for _, name in ipairs(Crest.DIVISIONS) do
    DIVISION_SET[name] = true
end
for _, name in ipairs(Crest.CHARGES) do
    CHARGE_SET[name] = true
end

-- Heraldry's colors and metals, bright enough for chunky art and dark screens.
Crest.TINCTURES = {
    { key = "gules", name = "Red", color = { 0.761, 0.231, 0.188 } },
    { key = "sanguine", name = "Wine", color = { 0.498, 0.165, 0.227 } },
    { key = "tenne", name = "Orange", color = { 0.851, 0.471, 0.180 } },
    { key = "or", name = "Gold", color = { 0.941, 0.765, 0.353 }, metal = true },
    { key = "vert", name = "Green", color = { 0.306, 0.604, 0.247 } },
    { key = "teal", name = "Teal", color = { 0.173, 0.604, 0.561 } },
    { key = "celeste", name = "Sky", color = { 0.412, 0.702, 0.878 } },
    { key = "azure", name = "Blue", color = { 0.200, 0.388, 0.722 } },
    { key = "purpure", name = "Purple", color = { 0.490, 0.298, 0.659 } },
    { key = "rose", name = "Rose", color = { 0.827, 0.365, 0.525 } },
    { key = "sable", name = "Black", color = { 0.165, 0.133, 0.141 } },
    { key = "argent", name = "Silver", color = { 0.847, 0.871, 0.890 }, metal = true },
}
local TINCTURE = {}
for _, tincture in ipairs(Crest.TINCTURES) do
    TINCTURE[tincture.key] = tincture
end

-- A new house's crest, as in the sketches: a red heater shield, a gold rim, the gold initial.
Crest.DEFAULT = { shape = "Heater", division = "Plain", field = "gules", second = "or", metal = "or", symbol = "initial" }

-- A clean copy of a saved crest: anything unknown takes the default.
function Crest.Normalize(crest)
    crest = type(crest) == "table" and crest or {}
    local d = Crest.DEFAULT
    local out = {
        shape = SPOTS[crest.shape] and crest.shape or d.shape,
        division = DIVISION_SET[crest.division] and crest.division or d.division,
        field = TINCTURE[crest.field] and crest.field or d.field,
        second = TINCTURE[crest.second] and crest.second or d.second,
        metal = TINCTURE[crest.metal] and crest.metal or d.metal,
        symbol = d.symbol,
    }
    if crest.symbol == "charge" and CHARGE_SET[crest.charge] then
        out.symbol, out.charge = "charge", crest.charge
    elseif crest.symbol == "none" then
        out.symbol = "none"
    end
    return out
end

-- A crest picked at random (the dice in the setup): a color and a metal that tell apart.
function Crest.Random()
    local colors, metals = {}, {}
    for _, tincture in ipairs(Crest.TINCTURES) do
        local list = tincture.metal and metals or colors
        list[#list + 1] = tincture.key
    end
    local function Pick(list, but)
        local key
        repeat
            key = list[math.random(#list)]
        until key ~= but or #list == 1
        return key
    end
    local field = Pick(colors)
    local second = math.random() < 0.5 and Pick(metals) or Pick(colors, field)
    local crest = {
        shape = Crest.SHAPES[math.random(#Crest.SHAPES)],
        division = Crest.DIVISIONS[math.random(#Crest.DIVISIONS)],
        field = field, second = second, metal = Pick(metals),
        symbol = math.random() < 0.3 and "initial" or "charge",
        charge = Crest.CHARGES[math.random(#Crest.CHARGES)],
    }
    return Crest.Normalize(crest)
end

function Crest.Color(key)
    return (TINCTURE[key] or TINCTURE.gules).color
end

function Crest.IsMetal(key)
    return TINCTURE[key] ~= nil and TINCTURE[key].metal == true
end

local function Luma(color)
    return 0.2126 * color[1] + 0.7152 * color[2] + 0.0722 * color[3]
end

local function Scaled(color, factor)
    return { math.min(1, color[1] * factor), math.min(1, color[2] * factor), math.min(1, color[3] * factor) }
end

-- The windows' accent from a crest: its first color that isn't a metal (the field, else the
-- second), kept between too dark to see and too light for light text on it.
function Crest.Accent(crest)
    local key = Crest.IsMetal(crest.field) and crest.second or crest.field
    if Crest.IsMetal(key) then
        key = "gules"
    end
    local color = Crest.Color(key)
    local luma = Luma(color)
    if luma < 0.06 then
        local fallback = not Crest.IsMetal(crest.second) and crest.second ~= key and Crest.Color(crest.second)
        color = fallback and Luma(fallback) >= 0.06 and fallback or Crest.Color("sanguine")
        luma = Luma(color)
    end
    if luma > 0.32 then
        color = Scaled(color, 0.32 / luma)
    end
    return color
end

-- The windows' metal (edges, highlights): the crest's, unless it's too dark to show on dark.
function Crest.Metal(crest)
    local color = Crest.Color(crest.metal)
    if Luma(color) < 0.3 then
        return Theme.C.gold
    end
    return color
end

-- The color a one-tint crest takes in chat: its brightest of field, second and metal that reads
-- on a dark chat window.
function Crest.ChatTint(crest)
    for _, key in ipairs({ crest.field, crest.second, crest.metal }) do
        local color = Crest.Color(key)
        if Luma(color) >= 0.12 then
            return color
        end
    end
    return Theme.C.gold
end

-- The symbol's color: the metal, or what stands out most from the field when the metal is too
-- close to it (a gold symbol on a gold field).
function Crest.SymbolColor(crest)
    local field, metal = Crest.Color(crest.field), Crest.Color(crest.metal)
    if math.abs(Luma(field) - Luma(metal)) >= 0.18 then
        return metal
    end
    local best, gap = metal, -1
    for _, key in ipairs({ "or", "argent", "sable" }) do
        local color = Crest.Color(key)
        local d = math.abs(Luma(field) - Luma(color))
        if d > gap then
            best, gap = color, d
        end
    end
    return best
end

-- The first letter of a surname (a whole UTF-8 character).
function Crest.Initial(surname)
    if type(surname) ~= "string" then
        return ""
    end
    return surname:match("^[%z\1-\127\194-\244][\128-\191]*") or ""
end

-- The crest in a chat line or a tooltip: one texture in one tint, as tall as the text.
-- `enemy` paints it the black sheep's red.
function Crest.ChatIcon(crest, enemy)
    crest = Crest.Normalize(crest)
    local tint = enemy and Theme.C.enemy or Crest.ChatTint(crest)
    return string.format("|T%sCrest\\Chat%s:0:0:0:-1:64:64:0:64:0:64:%d:%d:%d|t", Theme.Folder(), crest.shape,
        math.floor(tint[1] * 255 + 0.5), math.floor(tint[2] * 255 + 0.5), math.floor(tint[3] * 255 + 0.5))
end

-- --- the crest frame ---------------------------------------------------------------------------

local function SetColor(texture, color, alpha)
    texture:SetVertexColor(color[1], color[2], color[3], alpha or 1)
end

-- The initial, drawn as pixel art (A to Z) or in a font: Morpheus in Smooth, and in Pixel for a
-- letter the art doesn't have (Cyrillic, Korean...).
local function PaintInitial(self, crest, surname, size, y, enemy, filter)
    local initial = Crest.Initial(surname)
    if initial == "" then
        return
    end
    local color = enemy and Theme.C.text or Crest.SymbolColor(crest)
    local skin = Theme.Skin()
    if skin.letters == "pixel" and initial:match("^%a$") then
        Theme.SetArt(self.symbol, Theme.Folder() .. "Letter\\" .. initial:upper(), filter)
        SetColor(self.symbol, color)
        self.symbol:SetSize(size / 2, size / 2)
        self.symbol:ClearAllPoints()
        self.symbol:SetPoint("CENTER", self, "CENTER", 0, y)
        self.symbol:Show()
        return
    end
    self.letter:SetFontObject(Theme.DisplayFont(size * 0.42, size >= 30 and "OUTLINE" or nil))
    self.letter:SetText(initial)
    self.letter:SetTextColor(color[1], color[2], color[3])
    self.letter:ClearAllPoints()
    self.letter:SetPoint("CENTER", self, "CENTER", 0, y - size * 0.015)
    self.letter:Show()
end

-- Paints `crest` (a saved crest) with `surname`'s initial in the theme in use; `enemy` paints the
-- black sheep's red.
local function SetCrest(self, crest, surname, enemy)
    crest = Crest.Normalize(crest)
    self.crest, self.surname = crest, surname
    local size, shape = self.size, crest.shape
    local pixel = Theme.Skin().crest == "pixel"
    -- pixel art stays sharp once it's big; small, it reads better smoothed
    local filter = pixel and size >= 48 and "NEAREST" or "LINEAR"
    local folder = Theme.Folder() .. "Crest\\" .. shape
    Theme.SetArt(self.shadow, folder .. "Shadow", filter)
    SetColor(self.shadow, pixel and Theme.C.ink or { 0, 0, 0 }, pixel and 0.55 or 0.75)
    Theme.SetArt(self.fill, folder .. "Fill", filter)
    SetColor(self.fill, enemy and Theme.C.enemy or Crest.Color(crest.field))
    if crest.division ~= "Plain" and not enemy then
        Theme.SetArt(self.division, folder .. crest.division, filter)
        SetColor(self.division, Crest.Color(crest.second))
        self.division:Show()
    else
        self.division:Hide()
    end
    Theme.SetArt(self.shine, folder .. "Shine", filter)
    Theme.SetArt(self.rim, folder .. (pixel and "Frame" or "Rim"), filter)
    SetColor(self.rim, enemy and Theme.C.text3 or Crest.Color(crest.metal))
    local spot = SPOTS[shape]
    local y = pixel and (16 - spot.pixelY) * size / 32 or (0.5 - spot.y) * size
    self.symbol:Hide()
    self.letter:Hide()
    if size < 18 then
        return
    end
    if crest.symbol == "charge" then
        Theme.SetArt(self.symbol, Theme.Folder() .. "Charge\\" .. crest.charge, filter)
        SetColor(self.symbol, enemy and Theme.C.text or Crest.SymbolColor(crest))
        self.symbol:SetSize(size / 2, size / 2)
        self.symbol:ClearAllPoints()
        self.symbol:SetPoint("CENTER", self, "CENTER", 0, y)
        self.symbol:Show()
    elseif crest.symbol == "initial" then
        PaintInitial(self, crest, surname, size, y, enemy, filter)
    end
end

-- Repaints the crest as it was last painted (a new theme).
local function Repaint(self)
    SetCrest(self, self.crest, self.surname)
end

-- A crest frame, `size` px square. :SetCrest(crest, surname, enemy) paints it.
function Crest.Create(parent, size)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    frame.size = size
    local function Layer(layer, sublevel)
        local texture = frame:CreateTexture(nil, layer, nil, sublevel)
        texture:SetAllPoints()
        return texture
    end
    frame.shadow = Layer("BACKGROUND", 1)
    frame.fill = Layer("ARTWORK", 0)
    frame.division = Layer("ARTWORK", 1)
    frame.shine = Layer("ARTWORK", 3)
    frame.rim = Layer("OVERLAY", 0)
    frame.symbol = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    frame.letter = frame:CreateFontString(nil, "OVERLAY")
    frame.letter:SetDrawLayer("OVERLAY", 3)
    frame.letter:SetShadowColor(0, 0, 0, 0.8)
    frame.letter:SetShadowOffset(1, -1)
    frame.SetCrest, frame.Repaint = SetCrest, Repaint
    SetCrest(frame, Crest.DEFAULT, nil)
    return frame
end
