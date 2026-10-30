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

local WIDTH, HEIGHT = 620, 584
local PAD = 22
-- the room the title and the step bar take: every page starts under it
local BAR = 44

-- Plain names for the shapes and patterns: heraldry's own words are hard.
local SHAPE_NAMES = { Heater = "Shield", Round = "Round", Kite = "Kite", Banner = "Banner" }
local PATTERN_NAMES = { Plain = "Plain", Pale = "Split", Fess = "Halves", Bend = "Diagonal", Quarterly = "Quarters",
    Chevron = "Chevron", Cross = "Cross" }
-- what the alerts step sets, kept as it was when the setup opened (Reset goes back to it)
local ALERT_KEYS = { "popup", "enemyAlerts", "chatCrest", "tooltipLine", "showMinimap", "sound", "chats" }

local window, pages, page
local draft, motto
local crestBig, ribbon, shapeText, patternText
local pickers, openPicker
local mottoBox
-- The setup while it's open: the step it's on, the steps you've been to, the open picker, and
-- every step as it was when the setup opened. A new look builds the window again and keeps it.
local session
local rebuilding = false

local function Settings()
    return HeyCousinDB
end

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, item in pairs(value) do
        copy[key] = Copy(item)
    end
    return copy
end

local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for key, item in pairs(a) do
        if not Same(item, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

-- Your crest and motto: saved as you make them, so every crest on screen follows.
local function Save()
    Kin.SetCrest(draft, Utils.Trim(motto or ""))
end

-- Whether step `index` is changed from how it was when the setup opened.
local function Changed(index)
    if not session then
        return false
    end
    if index == 1 then
        return not Same(draft, session.start.crest) or Utils.Trim(motto or "") ~= Utils.Trim(session.start.motto)
    end
    for _, key in ipairs(ALERT_KEYS) do
        if not Same(Settings()[key], session.start.settings[key]) then
            return true
        end
    end
    return false
end

-- Reset works only on a step that has changes.
local function UpdateReset()
    if window and session and page then
        window.reset:SetEnabled(Changed(page))
    end
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
    UpdateReset()
end

local function Edited()
    Save()
    Paint()
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

-- A page, under the title and the step bar.
local function Page(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetPoint("TOPLEFT", 0, -BAR)
    p:SetPoint("BOTTOMRIGHT")
    return p
end

local function Arrow(parent, direction, x, y, onClick)
    local arrow = Theme.Arrow(parent, direction, 44)
    arrow:SetPoint("CENTER", parent, "TOP", x, y)
    Theme.OnClick(arrow, "crest arrow", function()
        onClick(direction == "RIGHT" and 1 or -1)
        Edited()
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
    -- the color in a dark rim, so it shows on a button of its own color
    button.rim = Theme.Texture(button, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 0, C.ink)
    button.rim:SetSize(16, 16)
    button.rim:SetPoint("LEFT", 8, 0)
    button.chip = Theme.Texture(button, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 1)
    button.chip:SetSize(12, 12)
    button.chip:SetPoint("CENTER", button.rim, "CENTER")
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
            Edited()
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
            openPicker, session.picker = nil, nil
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
            Edited()
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

-- Opens a picker's strip (or closes it); one is open at a time.
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
    openPicker, session.picker = open and picker or nil, nil
    for index, other in ipairs(pickers) do
        if other == openPicker then
            session.picker = index
        end
    end
end

local function BuildCrestPage(parent)
    local p = Page(parent)
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
        Edited()
    end)
    local mottoLabel = Theme.Text(p, "Small", C.text2)
    mottoLabel:SetPoint("TOPLEFT", PAD + 30, -446)
    mottoLabel:SetText(L["Motto"])
    mottoBox = Theme.EditBox(p, 360, L["A few words for your family"], nil, 40)
    mottoBox:SetPoint("LEFT", mottoLabel, "RIGHT", 12, 0)
    mottoBox.onChange = function(text)
        motto = text
        UpdateReset()
    end
    -- the motto is saved when you're done typing it (and when the step or the setup closes)
    mottoBox.edit:HookScript("OnEditFocusLost", Save)
    return p
end

-- --- page 2: alerts ----------------------------------------------------------------------------

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
        UpdateReset()
    end
end

local function ChatSetting(kind)
    return function()
        return HC.Radar.Watches(kind)
    end, function(value)
        Settings().chats = type(Settings().chats) == "table" and Settings().chats or {}
        Settings().chats[kind] = value
        UpdateReset()
    end
end

local function BuildAlertsPage(parent)
    local p = Page(parent)
    p.toggles, p.chips = {}, {}
    local function Heading(text, x, y)
        local heading = Theme.Text(p, "Headline")
        heading:SetPoint("TOPLEFT", x, y)
        heading:SetText(text)
    end
    Heading(L["On screen"], PAD, -60)
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
        p.toggles[index] = row.toggle
    end
    -- chips in rows across the column, as many as fit on each; returns the y under the last row
    local function Rows(chips, y)
        local x = 322
        for _, chip in ipairs(chips) do
            if x > 322 and x + chip:GetWidth() > WIDTH - PAD then
                x, y = 322, y - 30
            end
            chip:SetPoint("TOPLEFT", x, y)
            x = x + chip:GetWidth() + 4
            p.chips[#p.chips + 1] = chip
        end
        return y - 30
    end
    Heading(L["Sound"], 322, -60)
    local sounds = { { "auto", L["Theme's"] }, { "chime", L["Chime"] }, { "bell", L["Bell"] }, { "boop", L["Boop"] },
        { "none", L["None"] } }
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
            UpdateReset()
        end)
        chips[#chips + 1] = chip
    end
    local chatsY = Rows(chips, -84) - 10
    Heading(L["Learn from these chats"], 322, chatsY)
    local chats = { { "say", L["Say and yell"] }, { "channel", L["Trade and general"] }, { "guild", L["Guild"] },
        { "group", L["Group"] }, { "whisper", L["Whispers"] } }
    local chatChips = {}
    for _, spec in ipairs(chats) do
        chatChips[#chatChips + 1] = Theme.Chip(p, spec[2], ChatSetting(spec[1]))
    end
    Rows(chatChips, chatsY - 24)
    -- shows the settings as they are (after a Reset)
    function p.Refresh()
        for _, toggle in ipairs(p.toggles) do
            toggle:Refresh(true)
        end
        for _, chip in ipairs(p.chips) do
            chip:Refresh()
        end
    end
    return p
end

-- --- the window --------------------------------------------------------------------------------

-- The step bar: the step you're on is lit, the ones you've been to have a check.
local function PaintSteps()
    for index, item in ipairs(window.stepBar) do
        local current = index == page
        local been = not current and session.visited[index] == true
        Theme.SetKind(item.node, current and "primary" or "secondary")
        item.node:SetText(been and "" or tostring(index))
        item.check:SetShown(been)
        local color = (current or item.hovered) and C.text or been and C.text2 or C.text3
        item.label:SetTextColor(color[1], color[2], color[3])
    end
end

local function ShowPage(index)
    page = index
    session.page, session.visited[index] = index, true
    for i, p in ipairs(pages) do
        p:SetShown(i == index)
    end
    window.title:SetText(window.steps[index].title)
    PaintSteps()
    local last = index == #pages
    window.back:SetShown(index > 1)
    -- the first time, the setup can wait; later the X closes it
    window.skip:SetShown(index == 1 and not Settings().setupDone)
    window.next:SetText(last and L["Done"] or L["Next"])
    Theme.SetArt(window.next.icon, Theme.Icon(last and "Check" or "ChevronRight"))
    Theme.Fit(window.next, 20, 110)
    UpdateReset()
end

-- Goes to step `index`: what you made on this one stays.
local function Go(index)
    if index ~= page then
        Save()
        ShowPage(index)
    end
end

-- The step you're on, as it was when the setup opened.
local function Reset()
    if page == 1 then
        draft = Copy(session.start.crest)
        motto = session.start.motto
        mottoBox.edit:SetText(motto)
        Edited()
    else
        for _, key in ipairs(ALERT_KEYS) do
            Settings()[key] = Copy(session.start.settings[key])
        end
        if HC.Minimap then
            HC.Minimap.Apply()
        end
        pages[2].Refresh()
    end
    UpdateReset()
end

local function Finish()
    Settings().setupDone = true
    window:Hide()
    -- a first look at a cousin
    if HC.TestMode.active then
        HC.TestMode.Pop()
    else
        HC.Alert.Preview()
    end
end

-- The look, on top of every step: the arrows flip through the themes, and the setup (with every
-- window) turns to the next one at once, keeping what you made.
local function BuildLook()
    local function Turn(delta)
        return Step(Theme.ORDER, Theme.Skin().key, delta)
    end
    local function Tip(delta)
        return function()
            return Theme.SKINS[Turn(delta)].name
        end, function()
            return Theme.SKINS[Turn(delta)].note
        end
    end
    local look = CreateFrame("Frame", nil, window)
    look:SetHeight(32)
    look:SetPoint("TOPRIGHT", -50, -9)
    local back = Theme.IconButton(look, "ChevronLeft", 26, Tip(-1))
    back:SetPoint("LEFT")
    local forward = Theme.IconButton(look, "ChevronRight", 26, Tip(1))
    forward:SetPoint("RIGHT")
    local preview = Theme.Texture(look, nil, "ARTWORK", 0)
    Theme.SetArt(preview, Theme.Art("Preview"), "LINEAR")
    preview:SetSize(64, 32)
    preview:SetPoint("LEFT", back, "RIGHT", 6, 0)
    local caption = Theme.Text(look, "Tiny", C.text3)
    caption:SetPoint("BOTTOMLEFT", preview, "RIGHT", 8, 1)
    caption:SetText(L["LOOK"])
    local name = Theme.Text(look, "Body", C.text)
    name:SetPoint("TOPLEFT", preview, "RIGHT", 8, -1)
    name:SetPoint("RIGHT", forward, "LEFT", -4, 0)
    -- as wide as the longest look's name, so the arrows stay put as you flip
    local widest = caption:GetStringWidth()
    for _, key in ipairs(Theme.ORDER) do
        name:SetText(Theme.SKINS[key].name)
        widest = math.max(widest, name:GetStringWidth())
    end
    look:SetWidth(26 + 6 + 64 + 8 + math.ceil(widest) + 4 + 26)
    name:SetText(Theme.Skin().name)
    Theme.OnClick(back, "look", function()
        Theme.SetSkin(Turn(-1))
    end)
    Theme.OnClick(forward, "look", function()
        Theme.SetSkin(Turn(1))
    end)
    window.look = { back = back, forward = forward, name = name }
end

local function BuildSteps()
    local bar = CreateFrame("Frame", nil, window)
    bar:SetHeight(28)
    bar:SetPoint("TOP", 0, -60)
    window.stepBar = {}
    local x = 0
    for index, step in ipairs(window.steps) do
        if index > 1 then
            local line = Theme.Texture(bar, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 0, C.text3, 0.5)
            line:SetSize(40, 2)
            line:SetPoint("LEFT", bar, "LEFT", x + 10, 0)
            x = x + 60
        end
        local item = CreateFrame("Button", nil, bar)
        item:SetHeight(28)
        item:SetPoint("LEFT", bar, "LEFT", x, 0)
        item.node = Theme.Button(item, tostring(index), "secondary", 26, 26)
        item.node:SetPoint("LEFT")
        item.node:EnableMouse(false)
        item.check = Theme.Texture(item.node, Theme.Icon("Check"), "ARTWORK", 2, C.near)
        item.check:SetSize(14, 14)
        item.check:SetPoint("CENTER")
        item.label = Theme.Text(item, "Body", C.text3)
        item.label:SetPoint("LEFT", item.node, "RIGHT", 8, 0)
        item.label:SetText(step.name)
        item:SetWidth(34 + math.ceil(item.label:GetStringWidth()))
        x = x + item:GetWidth()
        item.index = index
        item:SetScript("OnEnter", function(self)
            self.hovered, self.node.hovered = true, true
            Theme.PaintButton(self.node)
            PaintSteps()
        end)
        item:SetScript("OnLeave", function(self)
            self.hovered, self.node.hovered = false, false
            Theme.PaintButton(self.node)
            PaintSteps()
        end)
        Theme.OnClick(item, "setup step", function(self)
            Go(self.index)
        end)
        window.stepBar[index] = item
    end
    bar:SetWidth(x)
end

local function Build()
    window = Theme.Window("HeyCousinSetup", WIDTH, HEIGHT)
    window:SetFrameStrata("DIALOG")
    window.steps = {
        { name = L["Crest"], title = L["Your house"] },
        { name = L["Alerts"], title = L["Alerts"] },
    }
    window.title = Theme.Text(window, "Title")
    window.title:SetPoint("TOPLEFT", PAD, -20)
    local metal = Theme.Metal()
    window.title:SetTextColor(metal[1], metal[2], metal[3])
    BuildLook()
    BuildSteps()
    pages = { BuildCrestPage(window), BuildAlertsPage(window) }
    -- along the bottom: back (or skip, the first time), and reset beside next (done at the end)
    window.skip = Theme.Button(window, L["Skip for now"], "ghost", 120, 32)
    window.skip:SetPoint("BOTTOMLEFT", PAD, 18)
    Theme.Fit(window.skip, 14, 110)
    window.back = Theme.Button(window, L["Back"], "secondary", 100, 32)
    window.back:SetPoint("BOTTOMLEFT", PAD, 18)
    Theme.ButtonIcon(window.back, "ChevronLeft")
    Theme.Fit(window.back, 16, 100)
    window.next = Theme.Button(window, L["Next"], "primary", 120, 32)
    window.next:SetPoint("BOTTOMRIGHT", -PAD, 18)
    Theme.ButtonIcon(window.next, "ChevronRight", "RIGHT")
    window.reset = Theme.Button(window, L["Reset"], "secondary", 100, 32)
    window.reset:SetPoint("RIGHT", window.next, "LEFT", -8, 0)
    Theme.Fit(window.reset, 16, 96)
    Theme.Tip(window.reset, L["Reset this step"], L["Back to how it was when you opened the setup."])
    Theme.OnClick(window.skip, "setup skip", function()
        Settings().setupDone = true
        window:Hide()
    end)
    Theme.OnClick(window.back, "setup back", function()
        Go(page - 1)
    end)
    Theme.OnClick(window.reset, "setup reset", Reset)
    Theme.OnClick(window.next, "setup next", function()
        if page < #pages then
            Go(page + 1)
        else
            Finish()
        end
    end)
    -- closing keeps what you made; the setup is over unless a new look builds it again
    window:HookScript("OnHide", function()
        mottoBox.edit:ClearFocus()
        Save()
        if not rebuilding then
            session = nil
        end
    end)
end

-- A new setup: your crest, motto and settings as they are, kept for Reset.
local function Begin()
    local house = Kin.House()
    draft = Crest.Normalize(house and house.crest)
    motto = house and house.motto or ""
    -- a first Forever house takes the crest made in test mode, if there is one
    if not HC.TestMode.active and not Settings().setupDone and type(Settings().testCrest) == "table" then
        draft = Crest.Normalize(Settings().testCrest)
        motto = type(Settings().testMotto) == "string" and Settings().testMotto or motto
    end
    local settings = {}
    for _, key in ipairs(ALERT_KEYS) do
        settings[key] = Copy(Settings()[key])
    end
    session = { page = 1, visited = {}, start = { crest = Copy(draft), motto = motto, settings = settings } }
end

-- Opens the setup on `startPage`: else an open setup stays where it is, and a new one starts on
-- the first step.
function Setup.Show(startPage)
    if not session then
        Begin()
    end
    if not window then
        Build()
    end
    mottoBox.edit:SetText(motto)
    openPicker = nil
    for index, picker in ipairs(pickers) do
        local open = session.picker == index
        picker.strip:SetShown(open)
        Theme.SetKind(picker, open and "primary" or "secondary")
        openPicker = open and picker or openPicker
    end
    Paint()
    pages[2].Refresh()
    ShowPage(startPage or session.page)
    window:Show()
end

function Setup.Toggle()
    if window and window:IsShown() then
        window:Hide()
    else
        Setup.Show()
    end
end

-- A new look: the setup is built again in it, on the same step, with what you made.
Theme.OnSkin(function()
    if not window then
        return
    end
    local shown = window:IsShown()
    rebuilding = true
    window:Hide()
    rebuilding = false
    window, pages, pickers, mottoBox, openPicker = nil, nil, nil, nil, nil
    if shown then
        Setup.Show()
    end
end)
