local _, HC = ...

HC.Setup = {}

local Setup = HC.Setup
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local WIDTH, HEIGHT = 620, 540
local PAD = 22

-- Plain names for the shapes and patterns: heraldry's own words are hard.
local SHAPE_NAMES = { Heater = "Shield", Round = "Round", Kite = "Kite", Banner = "Banner" }
local PATTERN_NAMES = { Plain = "Plain", Pale = "Split", Fess = "Halves", Bend = "Diagonal", Quarterly = "Quarters",
    Chevron = "Chevron", Cross = "Cross" }

local window, pages, page
local draft, motto
local crestBig, ribbon, shapeText, patternText
local pickers, openPicker
local mottoBox

local function Settings()
    return HeyCousinDB
end

-- --- page 1: your crest ------------------------------------------------------------------------

local function Paint()
    local _, surname = Kin.House()
    crestBig:SetCrest(draft, surname)
    ribbon.text:SetText(surname and string.format(L["House %s"], surname) or L["Your house"])
    shapeText:SetText(L[SHAPE_NAMES[draft.shape]])
    patternText:SetText(L[PATTERN_NAMES[draft.division]])
    for _, picker in ipairs(pickers) do
        picker:Paint()
    end
end

-- The next or previous of `list` after `value`.
local function Step(list, value, delta)
    local index = 1
    for i, item in ipairs(list) do
        if item == value then
            index = i
        end
    end
    return list[(index - 1 + delta) % #list + 1]
end

local function Arrow(parent, direction, x, y, onClick)
    local arrow = Theme.Arrow(parent, direction, 44)
    arrow:SetPoint("CENTER", parent, "TOP", x, y)
    Theme.OnClick(arrow, "crest arrow", function()
        onClick(direction == "RIGHT" and 1 or -1)
        Paint()
    end)
    return arrow
end

-- A strip of choices that opens under its button: the colors, or the symbols.
local function Strip(parent, rows)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetSize(WIDTH - PAD * 2, rows * 36 + 14)
    strip:SetPoint("TOP", parent, "TOP", 0, -338)
    Theme.Panel(strip, "well")
    strip:Hide()
    return strip
end

local function ColorPicker(parent, label, field, x)
    local button = Theme.Button(parent, label, "secondary", 116, 30)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -294)
    button.chip = Theme.Texture(button, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 1)
    button.chip:SetSize(12, 12)
    button.chip:SetPoint("LEFT", 10, 0)
    button.labelX = 8
    local strip = Strip(parent, 1)
    strip.swatches = {}
    local count = #Crest.TINCTURES
    local cell = math.floor((strip:GetWidth() - 16) / count)
    for index, tincture in ipairs(Crest.TINCTURES) do
        local swatch = Theme.Swatch(strip, tincture.color, 20)
        swatch:SetPoint("LEFT", strip, "LEFT", 8 + (index - 1) * cell + (cell - swatch:GetWidth()) / 2, 0)
        swatch.key = tincture.key
        Theme.Tip(swatch, L[tincture.name] or tincture.name)
        Theme.OnClick(swatch, "color", function(self)
            draft[field] = self.key
            Paint()
        end)
        strip.swatches[index] = swatch
    end
    function button:Paint()
        local color = Crest.Color(draft[field])
        self.chip:SetVertexColor(color[1], color[2], color[3])
        for _, swatch in ipairs(strip.swatches) do
            swatch:SetChosen(swatch.key == draft[field])
        end
        -- the second color only shows on a divided shield
        self:SetEnabled(field ~= "second" or draft.division ~= "Plain")
        if field == "second" and draft.division == "Plain" and openPicker == self then
            strip:Hide()
            openPicker = nil
        end
    end
    button.strip = strip
    Theme.PaintButton(button)
    return button
end

local function SymbolPicker(parent, x)
    local button = Theme.Button(parent, L["Symbol"], "secondary", 116, 30)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -294)
    local strip = Strip(parent, 2)
    strip.cells = {}
    local choices = { { symbol = "initial" } }
    for _, key in ipairs(Crest.CHARGES) do
        choices[#choices + 1] = { symbol = "charge", charge = key }
    end
    choices[#choices + 1] = { symbol = "none" }
    local perRow = 10
    local cell = math.floor((strip:GetWidth() - 16) / perRow)
    for index, choice in ipairs(choices) do
        local b = Theme.Button(strip, "", "secondary", cell - 6, 30)
        local column, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
        b:SetPoint("TOPLEFT", strip, "TOPLEFT", 8 + column * cell + 3, -7 - row * 36)
        if choice.symbol == "charge" then
            b.icon = Theme.Texture(b, Theme.Folder() .. "Charge\\" .. choice.charge, "ARTWORK", 1, C.text)
            b.icon:SetSize(22, 22)
            Theme.Tip(b, L[choice.charge] or choice.charge)
        elseif choice.symbol == "initial" then
            local _, surname = Kin.House()
            b:SetText(Crest.Initial(surname) ~= "" and Crest.Initial(surname) or "A")
            Theme.Tip(b, L["Your initial"])
        else
            b:SetText("-")
            Theme.Tip(b, L["No symbol"])
        end
        Theme.PaintButton(b)
        b.choice = choice
        Theme.OnClick(b, "symbol", function(self)
            draft.symbol, draft.charge = self.choice.symbol, self.choice.charge
            Paint()
        end)
        strip.cells[index] = b
    end
    function button:Paint()
        for _, b in ipairs(strip.cells) do
            local chosen = b.choice.symbol == draft.symbol and (b.choice.symbol ~= "charge" or b.choice.charge == draft.charge)
            Theme.SetKind(b, chosen and "primary" or "secondary")
        end
    end
    button.strip = strip
    return button
end

local function Toggle(picker)
    for _, other in ipairs(pickers) do
        if other ~= picker then
            other.strip:Hide()
            Theme.SetKind(other, "secondary")
        end
    end
    local open = not picker.strip:IsShown()
    picker.strip:SetShown(open)
    Theme.SetKind(picker, open and "primary" or "secondary")
    openPicker = open and picker or nil
end

local function BuildCrestPage(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()
    local subtitle = Theme.Text(p, "Body", C.text2)
    subtitle:SetPoint("TOPLEFT", PAD, -54)
    subtitle:SetText(L["The crest your family wears. Flip through with the arrows."])
    crestBig = Crest.Create(p, 160)
    crestBig:SetPoint("TOP", p, "TOP", 0, -78)
    Arrow(p, "LEFT", -140, -112, function(delta)
        draft.shape = Step(Crest.SHAPES, draft.shape, delta)
    end)
    Arrow(p, "RIGHT", 140, -112, function(delta)
        draft.shape = Step(Crest.SHAPES, draft.shape, delta)
    end)
    Arrow(p, "LEFT", -140, -188, function(delta)
        draft.division = Step(Crest.DIVISIONS, draft.division, delta)
    end)
    Arrow(p, "RIGHT", 140, -188, function(delta)
        draft.division = Step(Crest.DIVISIONS, draft.division, delta)
    end)
    local function Caption(text, y)
        local caption = Theme.Text(p, "Tiny", C.text3)
        caption:SetPoint("RIGHT", p, "TOP", -172, y + 8)
        caption:SetJustifyH("RIGHT")
        caption:SetText(text)
        local value = Theme.Text(p, "Small", C.text2)
        value:SetPoint("RIGHT", p, "TOP", -172, y - 8)
        value:SetJustifyH("RIGHT")
        return value
    end
    shapeText = Caption(L["SHAPE"], -112)
    patternText = Caption(L["PATTERN"], -188)
    ribbon = Theme.Ribbon(p, 280, 32)
    ribbon:SetPoint("TOP", p, "TOP", 0, -244)
    pickers = {
        ColorPicker(p, L["Main"], "field", 52),
        ColorPicker(p, L["Second"], "second", 176),
        ColorPicker(p, L["Rim"], "metal", 300),
        SymbolPicker(p, 424),
    }
    for _, picker in ipairs(pickers) do
        Theme.OnClick(picker, "picker", function(self)
            Toggle(self)
        end)
    end
    local dice = Theme.IconButton(p, "Dice", 30, L["Surprise me"], L["A random crest. Click again for another."])
    dice:SetPoint("LEFT", pickers[4], "RIGHT", 10, 0)
    Theme.OnClick(dice, "dice", function()
        draft = Crest.Random()
        Paint()
    end)
    local mottoLabel = Theme.Text(p, "Small", C.text2)
    mottoLabel:SetPoint("TOPLEFT", PAD + 30, -446)
    mottoLabel:SetText(L["Motto"])
    mottoBox = Theme.EditBox(p, 360, L["A few words for your family"], nil, 40)
    mottoBox:SetPoint("LEFT", mottoLabel, "RIGHT", 12, 0)
    mottoBox.onChange = function(text)
        motto = text
    end
    return p
end

-- --- page 2: alerts and look -------------------------------------------------------------------

local function Setting(key, default)
    return function()
        local value = Settings()[key]
        if value == nil then
            return default
        end
        return value
    end, function(value)
        Settings()[key] = value
        if key == "showMinimap" and HC.Minimap then
            HC.Minimap.Apply()
        end
    end
end

local function ChatSetting(kind)
    return function()
        return HC.Radar.Watches(kind)
    end, function(value)
        Settings().chats = type(Settings().chats) == "table" and Settings().chats or {}
        Settings().chats[kind] = value
    end
end

local function ThemeCard(parent, key, y)
    local skin = Theme.SKINS[key]
    local card = Theme.Button(parent, "", "secondary", 276, 72)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 322, y)
    card.preview = Theme.Texture(card, Theme.MEDIA .. skin.folder .. "\\UI\\Preview", "ARTWORK", 1)
    card.preview:SetSize(96, 48)
    card.preview:SetPoint("LEFT", 10, 0)
    card.name = Theme.Text(card, "Headline")
    card.name:SetPoint("TOPLEFT", card.preview, "TOPRIGHT", 12, -4)
    card.name:SetText(skin.name)
    card.note = Theme.Text(card, "Small", C.text3)
    card.note:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -5)
    card.note:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    card.note:SetWordWrap(true)
    card.note:SetText(skin.note or "")
    card.key = key
    Theme.SetKind(card, Theme.Skin().key == key and "primary" or "secondary")
    if Theme.Skin().key == key then
        card.name:SetTextColor(C.buttonText[1], C.buttonText[2], C.buttonText[3])
        card.note:SetTextColor(C.buttonText[1], C.buttonText[2], C.buttonText[3])
    end
    Theme.OnClick(card, "theme", function(self)
        Theme.SetSkin(self.key)
    end)
    return card
end

local function BuildAlertsPage(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()
    local function Heading(text, x, y)
        local heading = Theme.Text(p, "Headline")
        heading:SetPoint("TOPLEFT", x, y)
        heading:SetText(text)
    end
    Heading(L["Alerts"], PAD, -60)
    local rows = {
        { L["A pop-up when a cousin is near"], L["With a sound. Click it to target them."], "popup", true },
        { L["Black sheep too"], L["Cousins from the other faction."], "enemyAlerts", true },
        { L["Your crest in chat"], L["At the start of a relative's message."], "chatCrest", true },
        { L["A family line in tooltips"], L["\"Family: Ashbrook (cousin)\""], "tooltipLine", true },
        { L["The minimap crest"], L["Click it for your family."], "showMinimap", true },
    }
    for index, spec in ipairs(rows) do
        local get, set = Setting(spec[3], spec[4])
        local row = Theme.ToggleRow(p, 286, spec[1], spec[2], get, set)
        row:SetPoint("TOPLEFT", PAD - 8, -86 - (index - 1) * 46)
        row.toggle:Refresh(true)
    end
    Heading(L["Look"], 322, -60)
    for index, key in ipairs(Theme.ORDER) do
        ThemeCard(p, key, -86 - (index - 1) * 80)
    end
    local soundsY = -86 - #Theme.ORDER * 80 - 6
    Heading(L["Sound"], 322, soundsY)
    local sounds = { { "auto", L["Theme's"] }, { "chime", L["Chime"] }, { "bell", L["Bell"] }, { "boop", L["Boop"] },
        { "none", L["None"] } }
    local x = 322
    local chips = {}
    for _, spec in ipairs(sounds) do
        local chip = Theme.Chip(p, spec[2], function()
            return (Settings().sound or "auto") == spec[1]
        end, function()
            Settings().sound = spec[1]
            for _, other in ipairs(chips) do
                other:Refresh()
            end
            if spec[1] ~= "none" then
                HC.Alert.PlaySound()
            end
        end)
        chip:SetPoint("TOPLEFT", x, soundsY - 24)
        x = x + chip:GetWidth() + 4
        chips[#chips + 1] = chip
    end
    local chatsY = soundsY - 64
    Heading(L["Learn from these chats"], 322, chatsY)
    local chats = { { "say", L["Say and yell"] }, { "channel", L["Trade and general"] }, { "guild", L["Guild"] },
        { "group", L["Group"] }, { "whisper", L["Whispers"] } }
    x = 322
    local y = chatsY - 24
    for _, spec in ipairs(chats) do
        local chip = Theme.Chip(p, spec[2], ChatSetting(spec[1]))
        if x + chip:GetWidth() > WIDTH - PAD then
            x, y = 322, y - 30
        end
        chip:SetPoint("TOPLEFT", x, y)
        x = x + chip:GetWidth() + 4
    end
    return p
end

-- --- the window --------------------------------------------------------------------------------

local function Save()
    Kin.SetCrest(draft, Utils.Trim(motto or ""))
end

local function ShowPage(index)
    page = index
    for i, p in ipairs(pages) do
        p:SetShown(i == index)
    end
    window.title:SetText(index == 1 and L["Your house"] or L["Alerts and look"])
    for i, step in ipairs(window.steps) do
        local color = i == index and C.text or C.text3
        step:SetTextColor(color[1], color[2], color[3])
    end
    window.back:SetShown(index > 1)
    window.skip:SetShown(index == 1)
    window.next:SetText(index == #pages and L["Done"] or L["Next"])
    Theme.Fit(window.next, 20, 110)
end

local function Finish()
    Save()
    Settings().setupDone = true
    window:Hide()
    -- a first look at a cousin
    if HC.TestMode.active then
        HC.TestMode.Pop()
    else
        HC.Alert.Preview()
    end
end

local function Build()
    window = Theme.Window("HeyCousinSetup", WIDTH, HEIGHT)
    window:SetFrameStrata("DIALOG")
    window.title = Theme.Text(window, "Title")
    window.title:SetPoint("TOPLEFT", PAD, -20)
    local metal = Theme.Metal()
    window.title:SetTextColor(metal[1], metal[2], metal[3])
    window.steps = {}
    local stepNames = { L["1  Crest"], L["2  Alerts and look"] }
    local x = -48
    for i = #stepNames, 1, -1 do
        local step = Theme.Text(window, "Small", C.text3)
        step:SetPoint("TOPRIGHT", window, "TOPRIGHT", x, -24)
        step:SetText(stepNames[i])
        x = x - step:GetStringWidth() - 16
        window.steps[i] = step
    end
    pages = { BuildCrestPage(window), BuildAlertsPage(window) }
    window.skip = Theme.Button(window, L["Skip for now"], "ghost", 120, 32)
    window.skip:SetPoint("BOTTOMLEFT", PAD, 18)
    Theme.Fit(window.skip, 14, 110)
    window.back = Theme.Button(window, L["Back"], "secondary", 100, 32)
    window.back:SetPoint("BOTTOMLEFT", PAD, 18)
    Theme.Fit(window.back, 16, 100)
    window.next = Theme.Button(window, L["Next"], "primary", 120, 32)
    window.next:SetPoint("BOTTOMRIGHT", -PAD, 18)
    Theme.OnClick(window.skip, "setup skip", function()
        Settings().setupDone = true
        window:Hide()
    end)
    Theme.OnClick(window.back, "setup back", function()
        ShowPage(page - 1)
    end)
    Theme.OnClick(window.next, "setup next", function()
        if page < #pages then
            Save()
            ShowPage(page + 1)
        else
            Finish()
        end
    end)
    window:HookScript("OnHide", function()
        mottoBox.edit:ClearFocus()
    end)
end

-- Opens the setup on `page` (default: the first), with your crest and motto as they are.
function Setup.Show(startPage)
    if not window then
        Build()
    end
    local house = Kin.House()
    draft = Crest.Normalize(house and house.crest)
    motto = house and house.motto or ""
    -- a first Forever house takes the crest made in test mode, if there is one
    if not HC.TestMode.active and not Settings().setupDone and type(Settings().testCrest) == "table" then
        draft = Crest.Normalize(Settings().testCrest)
        motto = type(Settings().testMotto) == "string" and Settings().testMotto or motto
    end
    mottoBox.edit:SetText(motto)
    for _, picker in ipairs(pickers) do
        picker.strip:Hide()
        Theme.SetKind(picker, "secondary")
    end
    openPicker = nil
    Paint()
    ShowPage(startPage or 1)
    window:Show()
end

function Setup.Toggle()
    if window and window:IsShown() then
        window:Hide()
    else
        Setup.Show()
    end
end

-- A new theme (picked on page 2): the setup is built again in it, on the same page.
Theme.OnSkin(function()
    if not window then
        return
    end
    local shown, at = window:IsShown(), page
    window:Hide()
    window, pages, pickers, mottoBox = nil, nil, nil, nil
    if shown then
        Setup.Show(at)
    end
end)
