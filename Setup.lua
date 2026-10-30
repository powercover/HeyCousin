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
-- the steps: your crest, the alerts, the family map, and your guild's family (its guild master's)
local CREST, ALERTS, MAP, GUILD = 1, 2, 3, 4
local STEPS = { crest = CREST, alerts = ALERTS, map = MAP, guild = GUILD }
-- what the alerts and map steps set, kept as it was when the setup opened (Reset goes back to it)
local ALERT_KEYS = { "popup", "enemyAlerts", "chatCrest", "tooltipLine", "showMinimap", "sound", "chats" }
local MAP_KEYS = { "mapShow", "mapShare" }
local STEP_KEYS = { [ALERTS] = ALERT_KEYS, [MAP] = MAP_KEYS }

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

-- Your crest and motto: saved as you make them, so every crest on screen follows (and your
-- guild's, when you lead it as a family).
local function Save()
    Kin.SetCrest(draft, Utils.Trim(motto or ""))
    HC.Guild.CrestChanged()
end

-- Your guild's family, when you lead it: saved and shared with your guild once it's changed from
-- what was saved last.
local function SaveGuild()
    if session and session.guild and not HC.Guild.Equal(session.guild, session.saved) then
        HC.Guild.SetFamily(session.guild)
        session.saved = Copy(session.guild)
    end
end

-- Whether step `index` is changed from how it was when the setup opened.
local function Changed(index)
    if not session then
        return false
    end
    if index == CREST then
        return not Same(draft, session.start.crest) or Utils.Trim(motto or "") ~= Utils.Trim(session.start.motto)
    elseif index == GUILD then
        return not HC.Guild.Equal(session.guild, session.start.guild)
    end
    for _, key in ipairs(STEP_KEYS[index] or {}) do
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

local function Heading(parent, text, x, y)
    local heading = Theme.Text(parent, "Headline")
    heading:SetPoint("TOPLEFT", x, y)
    heading:SetText(text)
    return heading
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
        elseif key == "mapShow" or key == "mapShare" then
            HC.Map.Apply()
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
    Heading(p, L["On screen"], PAD, -60)
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
    Heading(p, L["Sound"], 322, -60)
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
    Heading(p, L["Learn from these chats"], 322, chatsY)
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

-- --- page 3: the family map --------------------------------------------------------------------

local function BuildMapPage(parent)
    local p = Page(parent)
    p.toggles = {}
    local function Row(label, note, key, default, y)
        local get, set = Setting(key, default)
        local row = Theme.ToggleRow(p, 286, label, note, get, set)
        row:SetPoint("TOPLEFT", PAD - 8, y)
        row.toggle:Refresh(true)
        p.toggles[#p.toggles + 1] = row.toggle
    end
    Heading(p, L["On your map"], PAD, -60)
    Row(L["Your family on the world map"], L["Cousins who share where they are."], "mapShow", true, -86)
    Heading(p, L["Where you are"], PAD, -150)
    Row(L["Share it with your guild"], L["Your guild sees you move."], "mapShare", false, -176)
    local note = Theme.Text(p, "Small", C.text3)
    note:SetPoint("TOPLEFT", PAD, -232)
    note:SetWidth(280)
    note:SetWordWrap(true)
    note:SetSpacing(2)
    note:SetText(L["Every few seconds while you move; never in a fight or a dungeon. A guild is one faction: the other side never sees you."])
    -- how it looks: a bit of map, with crests on it
    Heading(p, L["How it looks"], 322, -60)
    local look = CreateFrame("Frame", nil, p)
    look:SetSize(WIDTH - 322 - PAD, 236)
    look:SetPoint("TOPLEFT", 322, -86)
    Theme.Panel(look, "well")
    local land = Theme.Texture(look, "Interface\\Buttons\\WHITE8X8", "BORDER", 0, { 0.36, 0.43, 0.26 })
    land:SetPoint("TOPLEFT", 6, -6)
    land:SetPoint("BOTTOMRIGHT", -6, 6)
    local road = Theme.Texture(look, "Interface\\Buttons\\WHITE8X8", "BORDER", 1, { 0.58, 0.5, 0.34 })
    road:SetPoint("TOPLEFT", 6, -150)
    road:SetPoint("TOPRIGHT", -6, -150)
    road:SetHeight(4)
    p.crests = {}
    for index, spec in ipairs({ { "Mira", "MAGE", 0.28, 0.3 }, { "Lia", "PRIEST", 0.66, 0.46 }, { "Thane", "WARRIOR", 0.4, 0.72 } }) do
        local crest = Crest.Create(look, 28)
        crest:SetPoint("CENTER", look, "TOPLEFT", spec[3] * look:GetWidth(), -spec[4] * look:GetHeight())
        local color = Utils.ClassColor(spec[2])
        local bar = Theme.Texture(look, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 2, color)
        bar:SetSize(20, 3)
        bar:SetPoint("TOP", crest, "BOTTOM", 0, 1)
        local name = Theme.Text(look, "Tiny", color)
        name:SetPoint("TOP", crest, "BOTTOM", 0, -4)
        name:SetText(spec[1])
        p.crests[index] = crest
    end
    -- shows the settings as they are (after a Reset), and your crest as it is now
    function p.Refresh()
        for _, toggle in ipairs(p.toggles) do
            toggle:Refresh(true)
        end
        local _, surname = Kin.House()
        for _, crest in ipairs(p.crests) do
            crest:SetCrest(Kin.Crest(), surname)
        end
    end
    return p
end

-- --- page 4: your guild, when you lead it ------------------------------------------------------

local function BuildGuildPage(parent)
    local p = Page(parent)
    local name = HC.Guild.Mine()
    local title = Heading(p, name or L["Your guild"], PAD, -60)
    title:SetPoint("RIGHT", p, "LEFT", 300, 0)
    local metal = Theme.Metal()
    title:SetTextColor(metal[1], metal[2], metal[3])
    local row = Theme.ToggleRow(p, 286, L["Our guild is a family"], L["Everyone in it shows on the Tree tab."],
        function()
            -- (a new crest color repaints it, the setup open or not)
            return session ~= nil and session.guild ~= nil and session.guild.on
        end, function(value)
            session.guild.on = value
            p.Refresh()
            SaveGuild()
            UpdateReset()
        end)
    row:SetPoint("TOPLEFT", PAD - 8, -86)
    p.switch = row.toggle
    -- what the family is, while it is one
    local fields = CreateFrame("Frame", nil, p)
    fields:SetAllPoints()
    p.fields = fields
    local function Field(label, y, width, most, key)
        local text = Theme.Text(fields, "Small", C.text2)
        text:SetPoint("TOPLEFT", PAD, y)
        text:SetText(label)
        local box = Theme.EditBox(fields, width, nil, nil, most)
        box:SetPoint("TOPLEFT", PAD, y - 16)
        box.onChange = function(value)
            session.guild[key] = value
            UpdateReset()
        end
        -- saved when you're done typing
        box.edit:HookScript("OnEditFocusLost", SaveGuild)
        return box
    end
    p.surname = Field(L["Family name"], -146, 200, HC.Guild.NAME_MAX, "surname")
    p.welcome = Field(L["Welcome line"], -206, 278, HC.Guild.WELCOME_MAX, "welcome")
    p.welcome.hint:SetText(L["For new cousins, as they join"])
    p.crest = Crest.Create(fields, 56)
    p.crest:SetPoint("TOPLEFT", PAD, -270)
    local crestText = Theme.Text(fields, "Small", C.text3)
    crestText:SetPoint("TOPLEFT", PAD + 68, -280)
    crestText:SetWidth(210)
    crestText:SetWordWrap(true)
    crestText:SetSpacing(2)
    crestText:SetText(L["The family wears your crest, from the first step."])
    -- each rank with its word, the guild master's first
    Heading(fields, L["A word for each rank"], 322, -60)
    p.words = {}
    for index, rank in ipairs(HC.Guild.Ranks()) do
        local y = -86 - (index - 1) * 34
        local label = Theme.Text(fields, "Small", C.text2)
        label:SetPoint("TOPRIGHT", fields, "TOPLEFT", 416, y - 9)
        label:SetWidth(94)
        label:SetJustifyH("RIGHT")
        label:SetText(rank)
        local box = Theme.EditBox(fields, 174, HC.Guild.DefaultWord(index - 1), nil, HC.Guild.WORD_MAX)
        box:SetPoint("TOPLEFT", 424, y)
        box.onChange = function(value)
            session.guild.words[index] = value
            UpdateReset()
        end
        box.edit:HookScript("OnEditFocusLost", SaveGuild)
        p.words[index] = box
    end
    -- while it's no family
    p.off = Theme.Text(p, "Body", C.text3)
    p.off:SetPoint("TOPLEFT", 322, -90)
    p.off:SetWidth(270)
    p.off:SetWordWrap(true)
    p.off:SetSpacing(3)
    p.off:SetText(L["Turn it on to give your family a name, a word for each rank and a welcome line."])
    local note = Theme.Text(p, "Small", C.text3)
    note:SetPoint("TOPLEFT", PAD, -352)
    note:SetWidth(270)
    note:SetWordWrap(true)
    note:SetSpacing(2)
    note:SetText(L["Members with Hey Cousin! get all this from your addon, by themselves."]
        .. (HC.TestMode.active and ("\n" .. L["(Test mode: a made-up guild you lead.)"]) or ""))
    -- shows the family as it is in the draft (after a Reset)
    function p.Refresh()
        local family = session.guild
        p.switch:Refresh(true)
        fields:SetShown(family.on)
        p.off:SetShown(not family.on)
        p.surname.edit:SetText(family.surname)
        p.welcome.edit:SetText(family.welcome)
        for index, box in ipairs(p.words) do
            local word = family.words[index]
            box.edit:SetText(Utils.IsUsableString(word) and word or HC.Guild.DefaultWord(index - 1))
        end
        p.crest:SetCrest(Kin.Crest(), Utils.Trim(family.surname))
    end
    return p
end

-- --- the window --------------------------------------------------------------------------------

-- The step bar: the step you're on is lit, the ones you've been to have a check.
local function PaintSteps()
    -- (a step under the mouse gets OnLeave as the setup closes: it may be over by then)
    if not window or not session then
        return
    end
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
    -- the map's and the guild's steps show your crest as it is now
    if index == MAP or index == GUILD then
        pages[index].Refresh()
    end
    UpdateReset()
end

-- Goes to step `index`: what you made on this one stays.
local function Go(index)
    if index ~= page then
        Save()
        SaveGuild()
        ShowPage(index)
    end
end

-- The step you're on, as it was when the setup opened.
local function Reset()
    if page == CREST then
        draft = Copy(session.start.crest)
        motto = session.start.motto
        mottoBox.edit:SetText(motto)
        Edited()
    elseif page == GUILD then
        session.guild = Copy(session.start.guild)
        pages[GUILD].Refresh()
        SaveGuild()
    else
        for _, key in ipairs(STEP_KEYS[page]) do
            Settings()[key] = Copy(session.start.settings[key])
        end
        if HC.Minimap then
            HC.Minimap.Apply()
        end
        HC.Map.Apply()
        pages[page].Refresh()
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
        [CREST] = { name = L["Crest"], title = L["Your house"] },
        [ALERTS] = { name = L["Alerts"], title = L["Alerts"] },
        [MAP] = { name = L["Map"], title = L["The family map"] },
    }
    -- the guild's family is its guild master's to give, on a step with a row for each rank
    window.guild = session.guild ~= nil
    window.ranks = table.concat(HC.Guild.Ranks(), "\n")
    if window.guild then
        window.steps[GUILD] = { name = L["Guild"], title = L["Your guild"] }
    end
    window.title = Theme.Text(window, "Title")
    window.title:SetPoint("TOPLEFT", PAD, -20)
    local metal = Theme.Metal()
    window.title:SetTextColor(metal[1], metal[2], metal[3])
    BuildLook()
    BuildSteps()
    pages = { [CREST] = BuildCrestPage(window), [ALERTS] = BuildAlertsPage(window), [MAP] = BuildMapPage(window) }
    if window.guild then
        pages[GUILD] = BuildGuildPage(window)
    end
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
        SaveGuild()
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
    for _, keys in pairs(STEP_KEYS) do
        for _, key in ipairs(keys) do
            settings[key] = Copy(Settings()[key])
        end
    end
    session = { page = CREST, visited = {}, start = { crest = Copy(draft), motto = motto, settings = settings } }
end

-- Your guild's family in the setup, from when you lead your guild (the guild's step comes with it).
local function BeginGuild()
    if not session.guild and HC.Guild.Leads() then
        session.guild = HC.Guild.Draft()
        session.start.guild, session.saved = Copy(session.guild), Copy(session.guild)
    end
end

-- The setup built again (in a new look, or with the guild's step come or gone): the session stays.
local function Drop()
    rebuilding = true
    window:Hide()
    rebuilding = false
    window, pages, pickers, mottoBox, openPicker = nil, nil, nil, nil, nil
end

-- Opens the setup on `startPage` (a number, or "crest", "alerts", "map", "guild"): else an open
-- setup stays where it is, and a new one starts on the first step.
function Setup.Show(startPage)
    startPage = STEPS[startPage] or startPage
    if not session then
        Begin()
    end
    BeginGuild()
    -- built again when the guild's step came, or its ranks changed
    if window and (window.guild ~= (session.guild ~= nil)
        or window.guild and window.ranks ~= table.concat(HC.Guild.Ranks(), "\n")) then
        Drop()
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
    pages[ALERTS].Refresh()
    -- (a step that isn't there, as the guild's for a member: the first)
    ShowPage(pages[startPage or session.page] and (startPage or session.page) or CREST)
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
    Drop()
    if shown then
        Setup.Show()
    end
end)
