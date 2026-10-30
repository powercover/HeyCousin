local addonName, HC = ...

HC.Theme = {}

local Theme = HC.Theme
local Utils = HC.Utils

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
Theme.MEDIA = MEDIA
Theme.SKINS, Theme.ORDER = {}, {}
Theme.DEFAULT = "pixel"

local skin
local listeners = {}

-- --- colors ------------------------------------------------------------------------------------

-- The colors every theme gives: filled in place when a theme is taken up, so the tables the
-- other files hold (Theme.C.text) always have the theme's.
local C = {}
for _, key in ipairs({ "ink", "bg", "surface", "raised", "hover", "selected", "line", "gold", "text", "text2", "text3",
    "buttonText", "near", "enemy" }) do
    C[key] = { 1, 1, 1 }
end
Theme.C = C

function Theme.Hex(color)
    return string.format("%02x%02x%02x", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5),
        math.floor(color[3] * 255 + 0.5))
end

-- `text` in `color`, for chat and tooltips.
function Theme.Paint(text, color)
    return "|cff" .. Theme.Hex(color) .. tostring(text) .. "|r"
end

local accent = { 0.761, 0.231, 0.188 }
local metal = { 0.941, 0.765, 0.353 }
local painters = {}

function Theme.Accent()
    return accent
end

function Theme.Metal()
    return metal
end

-- A frame that wears your crest's colors registers a painter; a new crest repaints them all.
-- A painter belongs to the theme its frame was built in: a new theme builds new frames, and the
-- old ones' painters are dropped.
function Theme.OnAccent(painter)
    painters[#painters + 1] = { paint = painter, skin = skin }
    painter(accent, metal)
end

function Theme.SetAccent(newAccent, newMetal)
    accent, metal = newAccent, newMetal
    for _, entry in ipairs(painters) do
        local ok, err = pcall(entry.paint, accent, metal)
        if not ok then
            Utils.NoteError("accent", err)
        end
    end
end

local function DropOldPainters()
    local kept = {}
    for _, entry in ipairs(painters) do
        if entry.skin == skin then
            kept[#kept + 1] = entry
        end
    end
    painters = kept
end

-- --- fonts -------------------------------------------------------------------------------------

-- Each font is a family with one font per alphabet, as Blizzard's are, so every language shows.
-- The text fonts are the game's own; a theme brings its display font (titles, buttons) for the
-- alphabets it draws (Skins/*.lua: displayFiles), and the game's fonts draw the rest. Korean and
-- Chinese read small: a little taller.
local FONT_KEYS = { "Title", "Headline", "Big", "Body", "Small", "Tiny", "Button" }
local ALPHABETS = { "roman", "russian", "korean", "simplifiedchinese", "traditionalchinese" }
local CJK = { korean = 2, simplifiedchinese = 2, traditionalchinese = 2 }
local fonts = {}

local function DisplayFile(alphabet)
    local files = skin and skin.displayFiles
    return files and files[alphabet] or nil
end

local function GameFile(alphabet)
    local template = GameFontHighlight
    if not template then
        return nil
    end
    local source = template
    if type(template.GetFontObjectForAlphabet) == "function" then
        source = template:GetFontObjectForAlphabet(alphabet) or template
    end
    return (source:GetFont())
end

local function Members(font)
    local list = {}
    for _, alphabet in ipairs(ALPHABETS) do
        local member = type(font.GetFontObjectForAlphabet) == "function" and font:GetFontObjectForAlphabet(alphabet)
        if member then
            list[#list + 1] = { member, alphabet }
        end
    end
    if #list == 0 then
        list[1] = { font, "roman" }
    end
    return list
end

local function Shape(font, spec, height)
    for _, entry in ipairs(Members(font)) do
        local member, alphabet = entry[1], entry[2]
        local file = spec.display and DisplayFile(alphabet) or GameFile(alphabet) or "Fonts\\FRIZQT__.TTF"
        member:SetFont(file, height + (CJK[alphabet] or 0), spec.flags or "")
        -- a file the game doesn't have leaves the font empty: the game's own then, never no text
        if not member:GetFont() then
            member:SetFont(GameFile(alphabet) or "Fonts\\FRIZQT__.TTF", height + (CJK[alphabet] or 0), spec.flags or "")
        end
        if spec.shadow == false then
            member:SetShadowOffset(0, 0)
        else
            member:SetShadowColor(0, 0, 0, 0.75)
            member:SetShadowOffset(1, -1)
        end
    end
end

local function MakeFont(name)
    local members = {}
    for _, alphabet in ipairs(ALPHABETS) do
        local file = GameFile(alphabet)
        if file then
            members[#members + 1] = { alphabet = alphabet, file = file, height = 12, flags = "" }
        end
    end
    if type(CreateFontFamily) == "function" and #members > 0 then
        local ok, family = pcall(CreateFontFamily, name, members)
        if ok and family then
            return family
        end
    end
    if type(CreateFont) == "function" then
        local font = CreateFont(name)
        if GameFontHighlight then
            font:CopyFontObject(GameFontHighlight)
        end
        return font
    end
    return GameFontHighlight
end

-- The font object for `key` (Title, Headline, Big, Body, Small, Tiny, Button).
function Theme.Font(key)
    local font = fonts[key]
    if not font then
        font = MakeFont("HeyCousinFont" .. key)
        fonts[key] = font
        local spec = skin and skin.fonts[key] or { height = 12 }
        Shape(font, spec, spec.height)
    end
    return font
end

-- The theme's display font at any height (a crest's initial), made once per height and theme.
function Theme.DisplayFont(height, flags)
    height = math.max(6, math.floor(height + 0.5))
    local key = (skin and skin.key or "") .. "Display" .. height .. (flags or "")
    local font = fonts[key]
    if not font then
        font = MakeFont("HeyCousinFont" .. key)
        fonts[key] = font
        Shape(font, { display = true, flags = flags }, height)
    end
    return font
end

function Theme.Text(parent, font, color, layer)
    local text = parent:CreateFontString(nil, layer or "OVERLAY")
    text:SetFontObject(Theme.Font(font or "Body"))
    color = color or C.text
    text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

-- --- themes ------------------------------------------------------------------------------------

-- A theme (Skins/*.lua) gives colors, fonts and an art folder, and draws panels, buttons, toggles,
-- swatches, dots, arrows and the ribbon. Every theme keeps the same layout, so one only changes
-- the look.
function Theme.Register(definition)
    Theme.SKINS[definition.key] = definition
    Theme.ORDER[#Theme.ORDER + 1] = definition.key
end

-- The theme after `key`, round and round (/cousin theme).
function Theme.Next(key)
    for index, name in ipairs(Theme.ORDER) do
        if name == key then
            return Theme.ORDER[index % #Theme.ORDER + 1]
        end
    end
    return Theme.DEFAULT
end

function Theme.Skin()
    return skin
end

local function Take(key)
    skin = Theme.SKINS[key] or Theme.SKINS[Theme.DEFAULT] or Theme.SKINS[Theme.ORDER[1]]
    for name, color in pairs(skin.colors) do
        local target = C[name]
        if target then
            target[1], target[2], target[3], target[4] = color[1], color[2], color[3], color[4]
        end
    end
    for _, name in ipairs(FONT_KEYS) do
        if fonts[name] then
            local spec = skin.fonts[name] or { height = 12 }
            Shape(fonts[name], spec, spec.height)
        end
    end
end

-- The saved theme, before anything is built (ADDON_LOADED).
function Theme.Use(key)
    Take(key)
end

-- Another theme, now: the addon's frames are built again in it.
function Theme.SetSkin(key)
    if not Theme.SKINS[key] or (skin and skin.key == key) then
        return
    end
    HeyCousinDB.skin = key
    Take(key)
    DropOldPainters()
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, skin)
        if not ok then
            Utils.NoteError("theme", err)
        end
    end
end

-- `fn(skin)` runs when the theme changes: a file rebuilds its frames there.
function Theme.OnSkin(fn)
    listeners[#listeners + 1] = fn
end

-- The theme's art: Media/<theme>/UI/<name>, and the art every theme shares.
function Theme.Art(name)
    return MEDIA .. skin.folder .. "\\UI\\" .. name
end

function Theme.Folder()
    return MEDIA .. skin.folder .. "\\"
end

function Theme.Shared(name)
    return MEDIA .. "UI\\" .. name
end

function Theme.Icon(name)
    return Theme.Art("Icon" .. name)
end

-- Sets a texture's file with the theme's filtering: pixel art stays sharp.
function Theme.SetArt(texture, file, filter)
    texture:SetTexture(file, "CLAMP", "CLAMP", filter or skin.filter or "LINEAR")
end

function Theme.Texture(parent, file, layer, sublevel, color, alpha)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    if file then
        Theme.SetArt(texture, file)
    end
    if color then
        texture:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
    end
    return texture
end

-- --- motion ------------------------------------------------------------------------------------

-- Every eased animation runs here: a value moves toward its target a little each frame, and
-- set(value) shows it. The driver's OnUpdate runs only while something moves.
local driver = CreateFrame("Frame")
local tweens = {}
local values = setmetatable({}, { __mode = "k" })
local stepping = {}

-- Two passes: the values move first, then the setters run. A setter may start or stop other
-- animations (a pop-up that fades out shows the next), which must not happen while the first pass
-- walks the table.
local function Step(_, elapsed)
    local count = 0
    for key, tween in pairs(tweens) do
        local value = tween.value + (tween.target - tween.value) * math.min(1, elapsed * tween.speed)
        if math.abs(tween.target - value) < 0.002 then
            value = tween.target
            tween.done = true
        end
        tween.value = value
        count = count + 1
        stepping[count] = key
    end
    for i = 1, count do
        local key = stepping[i]
        stepping[i] = nil
        local tween = tweens[key]
        if tween then
            values[key] = tween.value
            if tween.done then
                tweens[key] = nil
            end
            tween.set(tween.value)
        end
    end
    if next(tweens) == nil then
        driver:SetScript("OnUpdate", nil)
    end
end

local protectedStep = Utils.Protect("motion", Step)

-- Eases `key`'s value toward `target` at `speed` (14 takes about a quarter of a second), calling
-- set(value) each frame. It moves on from where the key last was (Theme.Jump sets that), or from
-- `from` when given.
function Theme.Ease(key, target, set, speed, from)
    local tween = tweens[key]
    if not tween then
        local value = from
        if value == nil then
            value = values[key]
        end
        if value == nil then
            value = target
        end
        tween = { value = value }
        tweens[key] = tween
    elseif from ~= nil then
        tween.value = from
    end
    tween.target, tween.set, tween.speed, tween.done = target, set, speed or 14, nil
    driver:SetScript("OnUpdate", protectedStep)
end

-- Jumps `key` to `value` (no motion), as if it had eased there.
function Theme.Jump(key, value, set)
    tweens[key] = nil
    values[key] = value
    if set then
        set(value)
    end
end

-- --- slices ------------------------------------------------------------------------------------

-- A panel from one square texture cut in nine: the corners keep their size, the edges and the
-- middle stretch. `corner` is the corner's size on screen, `outset` grows it past the frame's
-- edges, (dx, dy) moves it (a hard shadow).
local Slice = {}
Slice.__index = Slice
local CUT = 16 / 64

function Slice:SetColor(r, g, b, a)
    for _, part in ipairs(self) do
        part:SetVertexColor(r, g, b, a or 1)
    end
end

function Slice:SetShown(shown)
    for _, part in ipairs(self) do
        part:SetShown(shown)
    end
end

function Slice:SetAlpha(alpha)
    for _, part in ipairs(self) do
        part:SetAlpha(alpha)
    end
end

function Slice:SetFile(file)
    if self.file == file then
        return
    end
    self.file = file
    for i, part in ipairs(self) do
        Theme.SetArt(part, file)
        part:SetTexCoord(self.coords[i][1], self.coords[i][2], self.coords[i][3], self.coords[i][4])
    end
end

function Theme.Slice(frame, file, layer, sublevel, corner, outset, dx, dy)
    corner, outset, dx, dy = corner or 8, outset or 0, dx or 0, dy or 0
    local slice = setmetatable({ coords = {} }, Slice)
    local function Part(left, right, top, bottom)
        local part = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
        slice[#slice + 1] = part
        slice.coords[#slice] = { left, right, top, bottom }
        return part
    end
    local a, z = CUT, 1 - CUT
    local tl, tr = Part(0, a, 0, a), Part(z, 1, 0, a)
    local bl, br = Part(0, a, z, 1), Part(z, 1, z, 1)
    for _, part in ipairs({ tl, tr, bl, br }) do
        part:SetSize(corner, corner)
    end
    tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset + dx, outset + dy)
    tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", outset + dx, outset + dy)
    bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -outset + dx, -outset + dy)
    br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset + dx, -outset + dy)
    local top, bottom = Part(a, z, 0, a), Part(a, z, z, 1)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local left, right = Part(0, a, a, z), Part(z, 1, a, z)
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    local middle = Part(a, z, a, z)
    middle:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT")
    middle:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    if file then
        slice:SetFile(file)
    end
    return slice
end

-- A strip cut in three (the ribbon): the ends keep their shape, the middle stretches. `cut` is
-- the share of the texture's width each end takes; `ends` their width on screen.
function Theme.Strip(frame, file, layer, cut, ends)
    local parts = {}
    for i, coords in ipairs({ { 0, cut }, { cut, 1 - cut }, { 1 - cut, 1 } }) do
        local part = frame:CreateTexture(nil, layer or "BACKGROUND")
        Theme.SetArt(part, file)
        part:SetTexCoord(coords[1], coords[2], 0, 1)
        parts[i] = part
    end
    parts[1]:SetPoint("TOPLEFT")
    parts[1]:SetPoint("BOTTOMLEFT")
    parts[1]:SetWidth(ends)
    parts[3]:SetPoint("TOPRIGHT")
    parts[3]:SetPoint("BOTTOMRIGHT")
    parts[3]:SetWidth(ends)
    parts[2]:SetPoint("TOPLEFT", parts[1], "TOPRIGHT")
    parts[2]:SetPoint("BOTTOMRIGHT", parts[3], "BOTTOMLEFT")
    return parts
end

-- A panel in the theme's style: "window", "toast", "card", "tile", "well" or "frame".
function Theme.Panel(frame, style)
    skin.Panel(frame, style or "card")
    return frame
end

-- --- tooltips ----------------------------------------------------------------------------------

-- Points at `frame` show a tooltip: a title and an optional line (either can be a function).
function Theme.Tip(frame, title, line)
    frame:HookScript("OnEnter", function(self)
        local heading = type(title) == "function" and title(self) or title
        if not heading then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(heading, C.text[1], C.text[2], C.text[3])
        local text = type(line) == "function" and line(self) or line
        if text then
            GameTooltip:AddLine(text, C.text2[1], C.text2[2], C.text2[3], true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Sets what a click does; errors in it are caught and noted, never shown.
function Theme.OnClick(frame, label, fn)
    frame:SetScript("OnClick", Utils.Protect(label, fn))
end

-- --- buttons -----------------------------------------------------------------------------------

local function ButtonText(self, text)
    self.label:SetText(text or "")
end

local function ButtonGetText(self)
    return self.label:GetText()
end

local function State(button)
    if not button:IsEnabled() then
        return "off"
    elseif button.pressed then
        return "down"
    elseif button.hovered then
        return "hover"
    end
    return "normal"
end

function Theme.PaintButton(button)
    local state = State(button)
    skin.PaintButton(button, state)
    local press = state == "down" and (skin.press or 1) or 0
    button.label:SetPoint("CENTER", button.labelX or 0, (button.labelY or 0) - press)
    if button.icon then
        button.icon:SetPoint("CENTER", button.iconX or 0, -press)
    end
end

-- A button: "primary" (wood in Pixel, your crest's color in Smooth), "secondary" or "ghost". The
-- label is a plain font string, as Better Great Vault's: in the game, a button's own text showed
-- Cyrillic as boxes where plain font strings didn't.
function Theme.Button(parent, text, kind, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 120, height or 30)
    button.kind = kind or "secondary"
    skin.DecorateButton(button)
    button.label = Theme.Text(button, "Button")
    button.label:SetJustifyH("CENTER")
    button.SetText, button.GetText = ButtonText, ButtonGetText
    button:SetText(text)
    button:SetScript("OnEnter", function(self)
        self.hovered = true
        Theme.PaintButton(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.hovered, self.pressed = false, false
        Theme.PaintButton(self)
    end)
    button:SetScript("OnMouseDown", function(self)
        self.pressed = true
        Theme.PaintButton(self)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.pressed = false
        Theme.PaintButton(self)
    end)
    button:SetScript("OnEnable", Theme.PaintButton)
    button:SetScript("OnDisable", Theme.PaintButton)
    Theme.PaintButton(button)
    if button.kind == "primary" then
        Theme.OnAccent(function()
            Theme.PaintButton(button)
        end)
    end
    return button
end

-- Another kind for a button (a tab chosen, a chip turned on).
function Theme.SetKind(button, kind)
    if button.kind ~= kind then
        button.kind = kind
        Theme.PaintButton(button)
    end
end

-- Width to fit the label, at least `min`.
function Theme.Fit(button, padding, min)
    local extra = button.icon and 22 or 0
    button:SetWidth(math.max(min or 0, math.ceil(button.label:GetStringWidth() + extra + (padding or 16) * 2)))
end

-- An icon on a button, left of its label (`side` "RIGHT": right of it, as on a Next button).
function Theme.ButtonIcon(button, icon, side)
    button.icon = Theme.Texture(button, Theme.Icon(icon), "ARTWORK", 1)
    button.icon:SetSize(14, 14)
    local textColor = C[skin.buttonText and skin.buttonText[button.kind] or "text"] or C.text
    button.icon:SetVertexColor(textColor[1], textColor[2], textColor[3])
    button.icon:ClearAllPoints()
    if side == "RIGHT" then
        button.labelX, button.iconX = -9, 0
        button.icon:SetPoint("LEFT", button.label, "RIGHT", 6, 0)
    else
        button.labelX, button.iconX = 9, 0
        button.icon:SetPoint("RIGHT", button.label, "LEFT", -6, 0)
    end
    Theme.PaintButton(button)
end

-- A small square button with an icon only (close, setup), with an optional tooltip.
function Theme.IconButton(parent, icon, size, title, line)
    size = size or 26
    local button = Theme.Button(parent, "", skin.iconButton or "secondary", size, size)
    button.icon = Theme.Texture(button, Theme.Icon(icon), "ARTWORK", 1, C.text2)
    button.icon:SetSize(math.floor(size * 0.6), math.floor(size * 0.6))
    Theme.PaintButton(button)
    button:HookScript("OnEnter", function(self)
        self.icon:SetVertexColor(C.text[1], C.text[2], C.text[3])
    end)
    button:HookScript("OnLeave", function(self)
        self.icon:SetVertexColor(C.text2[1], C.text2[2], C.text2[3])
    end)
    if title then
        Theme.Tip(button, title, line)
    end
    return button
end

-- An arrow to flip through choices, "LEFT" or "RIGHT".
function Theme.Arrow(parent, direction, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size or 40, size or 40)
    button.direction = direction
    skin.DecorateArrow(button, direction)
    local function Paint(self)
        skin.PaintArrow(self, self.pressed and "down" or self.hovered and "hover" or "normal")
    end
    button:SetScript("OnEnter", function(self)
        self.hovered = true
        Paint(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.hovered, self.pressed = false, false
        Paint(self)
    end)
    button:SetScript("OnMouseDown", function(self)
        self.pressed = true
        Paint(self)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.pressed = false
        Paint(self)
    end)
    Paint(button)
    return button
end

-- --- tabs, toggles, chips, swatches ------------------------------------------------------------

-- A row of tabs: the chosen one is a primary button. `items` = { { key =, label = } }.
function Theme.Tabs(parent, items, onSelect, width, height)
    local tabs = CreateFrame("Frame", nil, parent)
    height = height or 30
    tabs:SetSize(width or 240, height)
    tabs.buttons = {}
    local gap = 6
    local each = ((width or 240) - gap * (#items - 1)) / #items
    for index, item in ipairs(items) do
        local button = Theme.Button(tabs, item.label, "secondary", each, height)
        button:SetPoint("TOPLEFT", (index - 1) * (each + gap), 0)
        button.key = item.key
        button:SetScript("OnClick", Utils.Protect("tab", function(self)
            tabs:Select(self.key)
        end))
        tabs.buttons[index] = button
    end
    function tabs:Select(key)
        for _, button in ipairs(self.buttons) do
            Theme.SetKind(button, button.key == key and "primary" or "secondary")
        end
        local changed = self.selected ~= key
        self.selected = key
        if changed and onSelect then
            onSelect(key)
        end
    end
    return tabs
end

-- An on/off control (a check box in Pixel, a switch in Smooth).
function Theme.Toggle(parent, get, set)
    local toggle = CreateFrame("Button", nil, parent)
    skin.DecorateToggle(toggle)
    function toggle:Refresh(instant)
        skin.PaintToggle(self, get() == true, instant)
    end
    toggle:SetScript("OnClick", Utils.Protect("toggle", function(self)
        set(not get())
        self:Refresh()
        if self.onChange then
            self.onChange()
        end
    end))
    Theme.OnAccent(function()
        toggle:Refresh(true)
    end)
    return toggle
end

-- A row for one on/off setting: a label, a short note under it, the toggle on the right. The
-- whole row is the toggle's click.
function Theme.ToggleRow(parent, width, label, note, get, set)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, note and 42 or 30)
    row.back = Theme.Texture(row, "Interface\\Buttons\\WHITE8X8", "BACKGROUND", 0, C.hover)
    row.back:SetAllPoints()
    local function SetBack(value)
        row.back:SetAlpha(value)
    end
    Theme.Jump(row.back, 0, SetBack)
    row.label = Theme.Text(row, "Body")
    row.label:SetPoint("TOPLEFT", 10, note and -6 or -8)
    row.label:SetPoint("RIGHT", row, "RIGHT", -56, 0)
    row.label:SetText(label)
    if note then
        row.note = Theme.Text(row, "Small", C.text3)
        row.note:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
        row.note:SetPoint("RIGHT", row, "RIGHT", -56, 0)
        row.note:SetText(note)
    end
    row.toggle = Theme.Toggle(row, get, set)
    row.toggle:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row:SetScript("OnClick", function()
        row.toggle:Click()
    end)
    row:SetScript("OnEnter", function()
        Theme.Ease(row.back, 0.6, SetBack, 18)
    end)
    row:SetScript("OnLeave", function()
        Theme.Ease(row.back, 0, SetBack, 18)
    end)
    return row
end

-- A small button that turns on and off (a chat to watch).
function Theme.Chip(parent, label, get, set)
    local chip = Theme.Button(parent, label, "secondary", 60, 26)
    chip.label:SetFontObject(Theme.Font("Small"))
    Theme.Fit(chip, 12)
    function chip:Refresh()
        Theme.SetKind(self, get() == true and "primary" or "secondary")
    end
    chip:SetScript("OnClick", Utils.Protect("chip", function(self)
        set(not get())
        self:Refresh()
    end))
    chip:Refresh()
    return chip
end

-- A color to pick; :SetChosen marks the chosen one.
function Theme.Swatch(parent, color, size)
    local swatch = CreateFrame("Button", nil, parent)
    size = size or 22
    swatch:SetSize(size + 6, size + 6)
    skin.DecorateSwatch(swatch, color, size)
    function swatch:SetChosen(chosen)
        skin.PaintSwatch(self, chosen)
    end
    swatch:SetChosen(false)
    return swatch
end

-- --- text boxes --------------------------------------------------------------------------------

-- A one-line text box with a hint while empty, an optional icon on the left, and an X that
-- empties it.
function Theme.EditBox(parent, width, hint, icon, maxLetters)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(width, 30)
    Theme.Panel(box, "well")
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetFontObject(Theme.Font("Body"))
    edit:SetTextColor(C.text[1], C.text[2], C.text[3])
    edit:SetAutoFocus(false)
    if maxLetters then
        edit:SetMaxLetters(maxLetters)
    end
    local left = 10
    if icon then
        box.icon = Theme.Texture(box, Theme.Icon(icon), "ARTWORK", 0, C.text3)
        box.icon:SetSize(14, 14)
        box.icon:SetPoint("LEFT", 9, 0)
        left = 29
    end
    edit:SetPoint("TOPLEFT", left, -5)
    edit:SetPoint("BOTTOMRIGHT", -26, 5)
    box.hint = Theme.Text(box, "Body", C.text3)
    box.hint:SetPoint("LEFT", edit, "LEFT", 0, 0)
    box.hint:SetText(hint or "")
    local clear = CreateFrame("Button", nil, box)
    clear:SetSize(18, 18)
    clear:SetPoint("RIGHT", -6, 0)
    clear.icon = Theme.Texture(clear, Theme.Icon("Close"), "ARTWORK", 0, C.text3)
    clear.icon:SetAllPoints()
    clear:Hide()
    clear:SetScript("OnClick", function()
        edit:SetText("")
        edit:ClearFocus()
    end)
    local function Update()
        local text = edit:GetText() or ""
        box.hint:SetShown(text == "" and not edit:HasFocus())
        clear:SetShown(text ~= "")
    end
    edit:SetScript("OnTextChanged", Utils.Protect("text box", function(self, user)
        Update()
        if box.onChange then
            box.onChange(self:GetText() or "", user)
        end
    end))
    edit:SetScript("OnEditFocusGained", Update)
    edit:SetScript("OnEditFocusLost", Update)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnEnterPressed", edit.ClearFocus)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function()
        edit:SetFocus()
    end)
    box.edit = edit
    return box
end

-- --- lists -------------------------------------------------------------------------------------

-- A list that makes only the rows it shows and reuses them while it scrolls (smoothly, with the
-- wheel or the thin bar). newRow(list) makes a row; paintRow(row, item, index) fills it.
function Theme.List(parent, rowHeight, newRow, paintRow)
    local list = CreateFrame("Frame", nil, parent)
    list:SetClipsChildren(true)
    list:EnableMouseWheel(true)
    list.rows, list.items, list.offset, list.target = {}, {}, 0, 0
    local bar = CreateFrame("Frame", nil, list)
    bar:SetWidth(6)
    bar:SetPoint("TOPRIGHT", -2, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)
    local thumb = CreateFrame("Button", nil, bar)
    thumb:SetWidth(6)
    thumb.fill = Theme.Texture(thumb, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 0, C.text3, 0.7)
    thumb.fill:SetAllPoints()
    list.bar, list.thumb = bar, thumb

    local function MaxOffset()
        return math.max(0, #list.items * rowHeight - list:GetHeight())
    end

    local function Layout()
        local height = list:GetHeight()
        if height <= 0 then
            return
        end
        local needed = math.ceil(height / rowHeight) + 1
        while #list.rows < needed do
            local row = newRow(list)
            row:SetHeight(rowHeight)
            list.rows[#list.rows + 1] = row
        end
        local first = math.floor(list.offset / rowHeight)
        local shift = list.offset - first * rowHeight
        local barShown = MaxOffset() > 0
        for i, row in ipairs(list.rows) do
            local index = first + i
            local item = list.items[index]
            if item and i <= needed then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -((i - 1) * rowHeight - shift))
                row:SetPoint("RIGHT", list, "RIGHT", barShown and -10 or 0, 0)
                if row.item ~= item or row.index ~= index or list.dirty then
                    row.item, row.index = item, index
                    paintRow(row, item, index)
                end
                row:Show()
            else
                row.item = nil
                row:Hide()
            end
        end
        list.dirty = false
        bar:SetShown(barShown)
        if barShown then
            local share = height / (#list.items * rowHeight)
            local thumbHeight = math.max(24, (height - 4) * share)
            thumb:SetHeight(thumbHeight)
            local travel = height - 4 - thumbHeight
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", bar, "TOP", 0, -travel * (list.offset / MaxOffset()))
        end
    end

    local function SetOffset(value)
        list.offset = value
        Layout()
    end

    function list:ScrollTo(target, instant)
        self.target = math.max(0, math.min(MaxOffset(), target))
        if instant then
            Theme.Jump(self, self.target, SetOffset)
        else
            Theme.Ease(self, self.target, SetOffset, 16, self.offset)
        end
    end

    -- New items, painted at once; `keep` keeps the scroll where it is.
    function list:SetItems(items, keep)
        self.items = items or {}
        self.dirty = true
        self:ScrollTo(keep and self.target or 0, true)
        Layout()
    end

    function list:Repaint()
        self.dirty = true
        Layout()
    end

    list:SetScript("OnMouseWheel", Utils.Protect("list", function(self, delta)
        self:ScrollTo(self.target - delta * rowHeight * 3)
    end))
    list:SetScript("OnSizeChanged", Utils.Protect("list", function(self)
        self.dirty = true
        self:ScrollTo(self.target, true)
    end))
    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnDragStart", function(self)
        local _, y = GetCursorPosition()
        self.dragFrom, self.dragOffset = y / self:GetEffectiveScale(), list.offset
        self:SetScript("OnUpdate", function(drag)
            local _, now = GetCursorPosition()
            now = now / drag:GetEffectiveScale()
            local travel = list:GetHeight() - 4 - drag:GetHeight()
            if travel > 0 then
                list:ScrollTo(drag.dragOffset + (drag.dragFrom - now) / travel * MaxOffset(), true)
            end
        end)
    end)
    thumb:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    return list
end

-- --- dots and ribbons --------------------------------------------------------------------------

-- A small dot ("near you now"); `pulse` makes it breathe (the game animates it, no Lua per frame).
-- :SetPulse(on) starts and stops it.
function Theme.Dot(parent, size, color, pulse)
    return skin.Dot(parent, size, color, pulse)
end

-- A ribbon for a motto or a house's name; .text is its label.
function Theme.Ribbon(parent, width, height)
    local ribbon = CreateFrame("Frame", nil, parent)
    ribbon:SetSize(width, height or 32)
    skin.Ribbon(ribbon)
    ribbon.text = Theme.Text(ribbon, "Small", skin.ribbonText and C[skin.ribbonText] or C.text)
    ribbon.text:SetPoint("CENTER", 0, skin.ribbonTextY or 1)
    return ribbon
end

-- --- windows -----------------------------------------------------------------------------------

-- A floating window: moved by dragging, closed with Escape, kept where it was left
-- (HeyCousinDB.windows), and placed there as it's made (a frame with no place never shows). It
-- fades in.
function Theme.Window(name, width, height)
    local window = CreateFrame("Frame", name, UIParent)
    window:SetSize(width, height)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:Hide()
    Theme.Panel(window, "window")
    if type(UISpecialFrames) == "table" then
        local known = false
        for _, entry in ipairs(UISpecialFrames) do
            known = known or entry == name
        end
        if not known then
            table.insert(UISpecialFrames, name)
        end
    end
    local function Saved()
        HeyCousinDB.windows = type(HeyCousinDB.windows) == "table" and HeyCousinDB.windows or {}
        return HeyCousinDB.windows
    end
    function window:Restore()
        local place = Saved()[name]
        self:ClearAllPoints()
        if type(place) == "table" and type(place.x) == "number" and type(place.y) == "number" then
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", place.x, place.y)
        else
            self:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        end
    end
    window:Restore()
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local scale = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if x and y then
            Saved()[name] = { x = x * scale, y = y * scale }
        end
    end)
    window:HookScript("OnShow", function(self)
        Theme.Ease(self, 1, function(value)
            self:SetAlpha(value)
        end, 14, 0)
    end)
    window.close = Theme.IconButton(window, "Close", 26)
    window.close:SetPoint("TOPRIGHT", -12, -12)
    window.close:SetScript("OnClick", function()
        window:Hide()
    end)
    return window
end
