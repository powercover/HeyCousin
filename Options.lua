local _, HC = ...

-- The settings: everything you can choose, by what it's for, in a window of their own. The setup
-- (Setup.lua) walks you through your crest and the main choices; these are all of them, and a
-- button runs the setup. Your crest and your guild's family are pages of their own in this window,
-- with a way back. The game's Options > AddOns has a page with a button to this window.
HC.Options = {}

local Options = HC.Options
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Kin = HC.Kin
local Locale = HC.Locale
local L = HC.L
local C = Theme.C

local WIDTH, HEIGHT = 680, 572
local PAD = 22
local NAV_W = 170
local PAGE_X = PAD + NAV_W + 22
local PAGE_W = WIDTH - PAGE_X - PAD
local TOP = 62
local ORDER = { "alerts", "family", "map", "plates", "game", "look", "about" }
-- the sample nameplates are drawn this many times bigger, to place the crest with care, and each has
-- this much room: as far as a crest can go from the plate, up and down
local PLATE_ZOOM = 1.5
local PLATE_STAGE_H = 150
-- the black sheep on the sample: made up
local SHEEP_FIRST = "Grom"

local window, main, pages, nav
local current = "alerts"
-- the crest's or the guild's page while it shows ("crest", "guild"), and the pages as they're built
local openSub
local subs = {}
local rebuilding = false
local bootLanguage
local bridge

-- What's new in this version: the version number's tooltip.
local function News()
    return {
        L["Family reunions: a banner when cousins are in your group. Try /cousin test reunion."],
        L["The family portrait shows who's online and the highest level, with a Take a picture button."],
        L["Mottos travel: cousins with the addon see yours, and you see theirs."],
        L["Tooltips show other houses: how many of each you've met."],
        L["Look up a family also finds players from other realms in your group."],
        L["Fixed: an error in dungeon fights, and surnames counted again after each login."],
    }
end

-- --- a page, from the top down ------------------------------------------------------------------

local function NewPage()
    local p = CreateFrame("Frame", nil, main)
    p:SetPoint("TOPLEFT", PAGE_X, -TOP)
    p:SetPoint("BOTTOMRIGHT", -PAD, 18)
    p.y, p.parts = 0, {}
    return p
end

local function Heading(p, text)
    if p.y < 0 then
        p.y = p.y - 8
    end
    local heading = Theme.Text(p, "Headline")
    heading:SetPoint("TOPLEFT", 0, p.y)
    heading:SetText(text)
    p.y = p.y - 24
end

local function Toggle(p, label, note, key, default)
    local get, set = HC.Setup.Setting(key, default)
    -- (a row's text starts 10 in: it lines up with the headings)
    local row = Theme.ToggleRow(p, PAGE_W + 10, label, note, get, set)
    row:SetPoint("TOPLEFT", -10, p.y)
    p.parts[#p.parts + 1] = row.toggle
    p.y = p.y - 46
    return row
end

-- Chips in rows across the page, as many as fit on each.
local function Chips(p, chips)
    local x = 0
    for _, chip in ipairs(chips) do
        if x > 0 and x + chip:GetWidth() > PAGE_W then
            x, p.y = 0, p.y - 30
        end
        chip:SetPoint("TOPLEFT", x, p.y)
        x = x + chip:GetWidth() + 4
        p.parts[#p.parts + 1] = chip
    end
    p.y = p.y - 30
end

local function Note(p, text, color)
    local note = Theme.Text(p, "Small", color or C.text3)
    note:SetPoint("TOPLEFT", 0, p.y)
    note:SetWidth(PAGE_W)
    note:SetWordWrap(true)
    note:SetSpacing(2)
    note:SetText(text)
    p.y = p.y - math.ceil(note:GetStringHeight()) - 8
    return note
end

local function Action(parent, label, onClick)
    local button = Theme.Button(parent, label, "secondary", 120, 30)
    Theme.Fit(button, 16, 120)
    Theme.OnClick(button, "settings button", onClick)
    return button
end

-- A setup step: the settings close first, so they aren't left behind it.
local function OpenSetup(step)
    return function()
        window:Hide()
        HC.Setup.Show(step)
    end
end

-- The version, underlined: a click shows what's new, until the mouse leaves it.
local function VersionLink(parent)
    local link = CreateFrame("Button", nil, parent)
    link.skin = Theme.Skin()
    link.text = Theme.Text(link, "Small", C.text2)
    link.text:SetPoint("LEFT")
    link.text:SetText(string.format(L["Version %s"], HC.VERSION))
    link:SetSize(math.ceil(link.text:GetStringWidth()) + 2, 18)
    link.line = Theme.Texture(link, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 0, C.text3)
    link.line:SetHeight(1)
    link.line:SetPoint("BOTTOMLEFT", 0, 1)
    link.line:SetPoint("BOTTOMRIGHT", 0, 1)
    link:SetScript("OnEnter", function(self)
        self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
    end)
    link:SetScript("OnLeave", function(self)
        -- (the mouse was on it as a new look came: that look's colors are in C now)
        self.text:SetTextColor(C.text2[1], C.text2[2], C.text2[3])
        GameTooltip:Hide()
    end)
    Theme.OnClick(link, "what's new", function(self)
        local title = Theme.Metal()
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(string.format(L["What's new in %s"], HC.VERSION), title[1], title[2], title[3])
        for _, line in ipairs(News()) do
            GameTooltip:AddLine("- " .. line, C.tip2[1], C.tip2[2], C.tip2[3], true)
        end
        GameTooltip:Show()
    end)
    return link
end

-- The sounds to choose from, as chips.
local function SoundChips(parent)
    local sounds = { { "auto", L["Theme's"] }, { "chime", L["Chime"] }, { "bell", L["Bell"] }, { "boop", L["Boop"] },
        { "none", L["None"] } }
    local chips = {}
    for _, spec in ipairs(sounds) do
        chips[#chips + 1] = Theme.Chip(parent, spec[2], function()
            return (HeyCousinDB.sound or "auto") == spec[1]
        end, function()
            HeyCousinDB.sound = spec[1]
            for _, other in ipairs(chips) do
                other:Refresh()
            end
            if spec[1] ~= "none" then
                HC.Alert.PlaySound()
            end
        end)
    end
    return chips
end

-- The chats to learn from, as chips.
local function ChatChips(parent)
    local chats = { { "say", L["Say and yell"] }, { "channel", L["Trade and general"] }, { "guild", L["Guild"] },
        { "group", L["Group"] }, { "whisper", L["Whispers"] } }
    local chips = {}
    for _, spec in ipairs(chats) do
        chips[#chips + 1] = Theme.Chip(parent, spec[2], function()
            return HC.Radar.Watches(spec[1])
        end, function(value)
            HeyCousinDB.chats = type(HeyCousinDB.chats) == "table" and HeyCousinDB.chats or {}
            HeyCousinDB.chats[spec[1]] = value
        end)
    end
    return chips
end

-- --- the pages ----------------------------------------------------------------------------------

local function BuildAlerts()
    local p = NewPage()
    Heading(p, L["On screen"])
    Toggle(p, L["A pop-up when you first meet a cousin"], L["With a sound. Click it to target them."], "popup", true)
    Toggle(p, L["Every time you meet"], L["Not only the first time."], "popupEvery", false)
    Toggle(p, L["Black sheep too"], L["Cousins from the other faction."], "enemyAlerts", true)
    Toggle(p, L["Family reunions"], L["A banner when cousins are in your group."], "reunion", true)
    Toggle(p, L["Achievements in chat"], L["One quiet line when you earn one. No pop-ups, no sounds."], "badgeLines", true)
    Heading(p, L["Sound"])
    Chips(p, SoundChips(p))
    return p
end

local function BuildFamily()
    local p = NewPage()
    Heading(p, L["Your house"])
    local crest = Crest.Create(p, 64)
    crest:SetPoint("TOPLEFT", 0, p.y)
    local house = Theme.Text(p, "Body")
    house:SetPoint("TOPLEFT", 76, p.y - 2)
    house:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    local motto = Theme.Text(p, "Small", C.text2)
    motto:SetPoint("TOPLEFT", 76, p.y - 20)
    motto:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    local change = Action(p, L["Change your crest"], function()
        Options.Show("crest")
    end)
    change:SetPoint("TOPLEFT", 76, p.y - 38)
    -- the guild's family is its guild master's to give
    local guild = Action(p, L["Your guild"], function()
        Options.Show("guild")
    end)
    guild:SetPoint("LEFT", change, "RIGHT", 6, 0)
    p.y = p.y - 76
    p.parts[#p.parts + 1] = {
        Refresh = function()
            local home, surname = Kin.House()
            crest:SetCrest(Kin.Crest(), surname)
            house:SetText(surname and string.format(L["House %s"], surname) or L["Your house"])
            motto:SetText(home and home.motto or "")
            guild:SetShown(HC.Guild.Leads() == true)
        end,
    }
    Heading(p, L["Your cousins"])
    -- one switch for them all; the ones under it wait, as they were, while it's off
    local all = Toggle(p, L["Family messages"], L["Chat, news, online lines and groups. The map has its own switches."],
        "familyMessages", true)
    local rows = {
        Toggle(p, L["Cousins coming online"], L["A line in chat. They see you too."], "presence", true),
        Toggle(p, L["Family news"], L["A line in chat when a cousin reaches a round level."], "familyNews", true),
        Toggle(p, L["Family chat"], L["/fam talks to every cousin online who has the addon."], "familyChat", true),
        Toggle(p, L["Family groups"], L["A line in chat when a cousin looks for a group."], "familyGroups", true),
    }
    local function PaintRows()
        for _, row in ipairs(rows) do
            row:SetShown(HC.Family.Messages())
        end
    end
    all.toggle.onChange = PaintRows
    p.parts[#p.parts + 1] = { Refresh = PaintRows }
    return p
end

local function BuildMap()
    local p = NewPage()
    Heading(p, L["On your map"])
    Toggle(p, L["Your family on the world map"], L["Cousins who share where they are."], "mapShow", true)
    Toggle(p, L["Your family on the minimap"], L["At its edge, faded, when they're further away."], "minimapCousins", true)
    Heading(p, L["Where you are"])
    Toggle(p, L["Share it with your family"], L["Cousins and your guild see you move."], "mapShare", false)
    Note(p, L["Every few seconds while you move; never in a fight or a dungeon. Anyone with your surname who runs Hey Cousin! can see you. The other faction can't."])
    p.y = p.y - 6
    local try = Action(p, L["Try it on your map"], function()
        HC.Map.Preview()
    end)
    try:SetPoint("TOPLEFT", 0, p.y)
    return p
end

-- Two samples, a friendly player's plate and an enemy player's, as the game's settings say they look
-- (often a friendly player is only a name), with the crest where it goes: drag either, scroll to resize.
-- The game won't let an addon read where a plate's parts are, so a sample can't copy your nameplate addon.
-- The real plates around you are the exact check: while this page is open they show the crest (Plates.lua).
local function BuildPlates()
    local p = NewPage()
    local Plates = HC.Plates
    Heading(p, L["Nameplates"])
    Toggle(p, L["Crests on your cousins' nameplates"], L["Made to work with any nameplate addon."], "plateCrest", true)
    Note(p, L["Drag the crest to place it, and scroll on it to resize it. Cousins on your side need the game's friendly nameplates on. In dungeons the game keeps those to itself."])
    Note(p, L["While this page is open, the real plates around you show the crest too."])
    p.y = p.y - 2
    local size = Theme.Text(p, "Body", C.text2)
    local reset
    local samples = {}
    -- shows the crests where it's saved
    local function Show()
        local x, y, scale = Plates.Position()
        local default = Plates.DEFAULT
        for _, sample in ipairs(samples) do
            sample.crest:SetScale(scale)
            sample.crest:ClearAllPoints()
            sample.crest:SetPoint("CENTER", sample.stage, "CENTER", x * PLATE_ZOOM / scale, y * PLATE_ZOOM / scale)
        end
        size:SetText(string.format("%d%%", math.floor(scale * 100 + 0.5)))
        reset:SetEnabled(x ~= default.x or y ~= default.y or scale ~= default.scale)
    end
    local function Resize(delta)
        local _, _, scale = Plates.Position()
        Plates.Move(nil, nil, scale + delta * Plates.SCALE_STEP)
        Show()
    end
    -- a sample: a bar and a name, or only a name, and a crest to drag
    local function Sample(word, wordColor, name, color, enemy)
        local stage = CreateFrame("Frame", nil, p)
        stage:SetSize(PAGE_W, PLATE_STAGE_H)
        stage:SetPoint("TOPLEFT", 0, p.y)
        stage:SetClipsChildren(true)
        Theme.Panel(stage, "well")
        p.y = p.y - PLATE_STAGE_H - 6
        local label = Theme.Text(stage, "Tiny", wordColor)
        label:SetPoint("TOPLEFT", 8, -6)
        label:SetText(word)
        local back = Theme.Texture(stage, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 0, C.ink)
        back:SetSize(154, 14)
        back:SetPoint("CENTER")
        local bar = Theme.Texture(stage, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 1, color)
        bar:SetSize(150, 10)
        bar:SetPoint("CENTER")
        -- (a name alone is the game's own font: drawn bigger, as the crest is)
        local nameFrame = CreateFrame("Frame", nil, stage)
        nameFrame:SetSize(1, 1)
        nameFrame:SetPoint("CENTER")
        local shown = Theme.Text(nameFrame, "Body", Theme.Readable(color))
        local crest = Crest.Create(stage, Plates.SIZE * PLATE_ZOOM)
        crest:EnableMouse(true)
        -- (above the name)
        crest:SetFrameLevel(stage:GetFrameLevel() + 10)
        -- the drag: from where the mouse went down, in the stage's own points
        local function Stop()
            crest:SetScript("OnUpdate", nil)
        end
        crest:SetScript("OnMouseDown", function()
            local mouseX, mouseY = GetCursorPosition()
            local fromX, fromY = Plates.Position()
            local ratio = stage:GetEffectiveScale() * PLATE_ZOOM
            crest:SetScript("OnUpdate", Utils.Protect("nameplate drag", function()
                local nowX, nowY = GetCursorPosition()
                Plates.Move(fromX + (nowX - mouseX) / ratio, fromY + (nowY - mouseY) / ratio)
                Show()
            end))
        end)
        crest:SetScript("OnMouseUp", Stop)
        crest:SetScript("OnHide", Stop)
        for _, target in ipairs({ stage, crest }) do
            target:EnableMouseWheel(true)
            target:SetScript("OnMouseWheel", Utils.Protect("nameplate size", function(_, delta)
                Resize(delta)
            end))
        end
        samples[#samples + 1] = { crest = crest, stage = stage, enemy = enemy, Repaint = function()
            local nameOnly = not enemy and Utils.Call(GetCVar, "nameplateShowOnlyNameForFriendlyPlayerUnits") == "1"
            local white = nameOnly and Utils.Call(GetCVar, "nameplateUseClassColorForFriendlyPlayerUnitNames") == "0"
            local tint = white and { 1, 1, 1 } or Theme.Readable(color)
            back:SetShown(not nameOnly)
            bar:SetShown(not nameOnly)
            nameFrame:SetScale(nameOnly and PLATE_ZOOM or 1)
            shown:SetText("")
            shown:SetFontObject(nameOnly and _G.SystemFont_NamePlate or Theme.Font("Body"))
            shown:ClearAllPoints()
            if nameOnly then
                shown:SetPoint("CENTER", nameFrame, "CENTER", 0, 0)
            else
                shown:SetPoint("BOTTOM", bar, "TOP", 0, 4)
            end
            shown:SetTextColor(tint[1], tint[2], tint[3])
            shown:SetText(name)
        end }
    end
    local _, class = Utils.Call(UnitClass, "player")
    local first, surname = HC.Names.Me()
    Sample(L["Cousin"], C.text2, HC.Names.Full(first or "", surname), Utils.ClassColor(class), false)
    Sample(L["Black sheep"], C.enemy, HC.Names.Full(SHEEP_FIRST, surname), C.enemy, true)
    p.y = p.y - 2
    -- open, the real plates around you show the crest
    p:SetScript("OnShow", function()
        Plates.Preview(true)
    end)
    p:SetScript("OnHide", function()
        Plates.Preview(false)
    end)
    -- the same by button
    local smaller = Theme.Button(p, "-", "secondary", 32, 28)
    smaller:SetPoint("TOPLEFT", 0, p.y)
    Theme.OnClick(smaller, "nameplate size", function()
        Resize(-1)
    end)
    size:SetPoint("LEFT", smaller, "RIGHT", 8, 0)
    size:SetWidth(44)
    size:SetJustifyH("CENTER")
    local bigger = Theme.Button(p, "+", "secondary", 32, 28)
    bigger:SetPoint("LEFT", size, "RIGHT", 8, 0)
    Theme.OnClick(bigger, "nameplate size", function()
        Resize(1)
    end)
    reset = Theme.Button(p, L["Reset"], "secondary", 90, 28)
    reset:SetPoint("LEFT", bigger, "RIGHT", 12, 0)
    Theme.Fit(reset, 12, 84)
    Theme.Tip(reset, L["Reset"], L["Back to where it starts."])
    Theme.OnClick(reset, "nameplate reset", function()
        local default = Plates.DEFAULT
        Plates.Move(default.x, default.y, default.scale)
        Show()
    end)
    p.parts[#p.parts + 1] = {
        Refresh = function()
            local _, last = HC.Names.Me()
            if p:IsVisible() then
                Plates.Preview(true)
            end
            for _, sample in ipairs(samples) do
                sample.Repaint()
                sample.crest:SetCrest(Kin.Crest(), last, sample.enemy)
            end
            Show()
        end,
    }
    return p
end

local function BuildGame()
    local p = NewPage()
    Heading(p, L["In chat"])
    Toggle(p, L["Your crest in chat"], L["At the start of a relative's message."], "chatCrest", true)
    Note(p, L["Learn from these chats"], C.text2)
    p.y = p.y + 2
    Chips(p, ChatChips(p))
    Heading(p, L["In tooltips"])
    Toggle(p, L["A family line in tooltips"], L["\"Family: Ashbrook (cousin)\""], "tooltipLine", true)
    Toggle(p, L["Other houses too"], L["\"House Stone: met 3\""], "houseLine", true)
    Heading(p, L["On the minimap"])
    Toggle(p, L["The minimap crest"], L["Click it for your family."], "showMinimap", true)
    Toggle(p, L["Lock the button"], L["Dragging it won't move it."], "lockMinimap", false)
    return p
end

local function BuildLook()
    local p = NewPage()
    Heading(p, L["Look"])
    local looks = {}
    for _, key in ipairs(Theme.ORDER) do
        looks[#looks + 1] = Theme.Chip(p, Theme.SKINS[key].name, function()
            return Theme.Skin().key == key
        end, function()
            -- (this window is built again in the new look, on this page)
            Theme.SetSkin(key)
        end)
    end
    Chips(p, looks)
    Note(p, Theme.Skin().note)
    Heading(p, L["Language"])
    local choices = { { "auto", L["The game's"] } }
    for _, language in ipairs(Locale.LANGUAGES) do
        -- each in its own words: "Deutsch (German)" reads "Deutsch"
        choices[#choices + 1] = { language.code, language.name:match("^(.-) %(") or language.name }
    end
    local reload
    local chips = {}
    for index, choice in ipairs(choices) do
        chips[index] = Theme.Chip(p, choice[2], function()
            return Locale.Choice() == choice[1]
        end, function()
            HeyCousinDB.language = choice[1]
            for _, other in ipairs(chips) do
                other:Refresh()
            end
            reload:Refresh()
        end)
    end
    Chips(p, chips)
    p.y = p.y - 6
    reload = Action(p, L["Reload to show it"], function()
        if type(ReloadUI) == "function" then
            ReloadUI()
        end
    end)
    reload:SetPoint("TOPLEFT", 0, p.y)
    -- (a language takes hold when the interface loads: Locale.Apply)
    function reload:Refresh()
        self:SetShown(Locale.Choice() ~= (bootLanguage or Locale.Choice()))
    end
    p.parts[#p.parts + 1] = reload
    return p
end

local function BuildAbout()
    local p = NewPage()
    local name = Theme.Text(p, "Headline")
    name:SetPoint("TOPLEFT", 0, 0)
    name:SetText(L["Hey Cousin!"])
    local title = Theme.Title()
    name:SetTextColor(title[1], title[2], title[3])
    local link = VersionLink(p)
    link:SetPoint("TOPLEFT", 0, -22)
    local author = Theme.Text(p, "Small", C.text3)
    author:SetPoint("LEFT", link, "RIGHT", 8, 0)
    author:SetText(string.format(L["by %s"], HC.AUTHOR))
    p.y = -48
    Note(p, L["Finds the players who share your surname, and makes your family visible."], C.text2)
    Heading(p, L["The setup"])
    Note(p, L["Your crest and the choices that matter most, step by step."])
    p.y = p.y + 2
    local setup = Action(p, L["Open the setup"], OpenSetup())
    setup:SetPoint("TOPLEFT", 0, p.y)
    -- everything the addon keeps, as a line of text to keep safe
    local backup = Action(p, L["Backup"], function()
        window:Hide()
        HC.Backup.Show()
    end)
    backup:SetPoint("LEFT", setup, "RIGHT", 6, 0)
    p.y = p.y - 34
    Heading(p, L["Chat commands"])
    for _, command in ipairs(HC.Commands()) do
        local line = Theme.Text(p, "Small", C.text2)
        line:SetPoint("TOPLEFT", 0, p.y)
        line:SetPoint("RIGHT", p, "RIGHT", 0, 0)
        line:SetText(command)
        p.y = p.y - 15
    end
    return p
end

-- --- the window ---------------------------------------------------------------------------------

local function HideSubs()
    openSub = nil
    for _, sub in pairs(subs) do
        sub:Hide()
    end
end

local function ShowPage(key)
    current = key
    HideSubs()
    main:Show()
    for name, page in pairs(pages) do
        page:SetShown(name == key)
    end
    for name, button in pairs(nav) do
        Theme.SetKind(button, name == key and "primary" or "secondary")
    end
    -- what the page shows, as it is now
    for _, part in ipairs(pages[key].parts) do
        part:Refresh(true)
    end
end

-- A page of its own over the whole window: its title on top, Back and Reset along the bottom.
local function NewSub(title)
    local p = CreateFrame("Frame", nil, window)
    p:SetAllPoints()
    p:Hide()
    local heading = Theme.Text(p, "Title")
    heading:SetPoint("TOPLEFT", PAD, -20)
    heading:SetPoint("RIGHT", window.close, "LEFT", -8, 0)
    heading:SetText(title)
    local metal = Theme.Title()
    heading:SetTextColor(metal[1], metal[2], metal[3])
    local back = Theme.Button(p, L["Back"], "secondary", 100, 32)
    back:SetPoint("BOTTOMLEFT", PAD, 18)
    Theme.ButtonIcon(back, "ChevronLeft")
    Theme.Fit(back, 16, 100)
    Theme.OnClick(back, "settings back", function()
        ShowPage(current)
    end)
    p.reset = Theme.Button(p, L["Reset"], "secondary", 100, 32)
    p.reset:SetPoint("BOTTOMRIGHT", -PAD, 18)
    Theme.Fit(p.reset, 16, 96)
    Theme.Tip(p.reset, L["Reset"], L["Back to how it was when you opened this page."])
    return p
end

-- Your crest and motto: the same maker as the setup's.
local function BuildCrestPage()
    local p = NewSub(L["Your house"])
    local start
    local editor
    local function Paint()
        p.reset:SetEnabled(editor:Changed(start.crest, start.motto))
    end
    editor = HC.CrestEditor.New(p, function()
        if start then
            Paint()
        end
    end)
    editor:SetPoint("TOP", 0, -8)
    function p.Open()
        local house = Kin.House()
        start = { crest = Crest.Normalize(house and house.crest), motto = house and house.motto or "" }
        editor:Load(start.crest, start.motto)
        Paint()
    end
    function p.Blur()
        editor:Blur()
    end
    Theme.OnClick(p.reset, "crest reset", function()
        editor:Load(start.crest, start.motto, editor:OpenPicker())
        editor:Save()
        Paint()
    end)
    return p
end

-- Your guild's family, when you lead it: saved and shared with your guild once it's changed from what
-- was saved last. It has a row for each rank, so it's built again when the ranks change.
local function BuildGuildPage()
    local p = NewSub(L["Your guild"])
    p.ranks = table.concat(HC.Guild.Ranks(), "\n")
    -- (the fields go by these places, a bit below the title)
    local body = CreateFrame("Frame", nil, p)
    body:SetPoint("TOPLEFT", 0, -6)
    body:SetPoint("BOTTOMRIGHT", 0, 60)
    local draft, saved, start
    local function PaintReset()
        p.reset:SetEnabled(not HC.Guild.Equal(draft, start))
    end
    local function Save()
        if draft and not HC.Guild.Equal(draft, saved) then
            HC.Guild.SetFamily(draft)
            saved = Utils.Copy(draft)
        end
    end
    local name = Theme.Text(body, "Headline", Theme.Title())
    name:SetPoint("TOPLEFT", PAD, -60)
    name:SetPoint("RIGHT", body, "LEFT", 300, 0)
    name:SetText(HC.Guild.Mine() or L["Your guild"])
    local row = Theme.ToggleRow(body, 286, L["Our guild is a family"], L["Everyone in it shows on the Tree tab."],
        function()
            -- (a new crest color repaints it, the page open or not)
            return draft ~= nil and draft.on
        end, function(value)
            draft.on = value
            p.Refresh()
            Save()
            PaintReset()
        end)
    row:SetPoint("TOPLEFT", PAD - 8, -86)
    local fields = CreateFrame("Frame", nil, body)
    fields:SetAllPoints()
    local function Field(label, y, width, most, key)
        local text = Theme.Text(fields, "Small", C.text2)
        text:SetPoint("TOPLEFT", PAD, y)
        text:SetText(label)
        local box = Theme.EditBox(fields, width, nil, nil, most)
        box:SetPoint("TOPLEFT", PAD, y - 16)
        box.onChange = function(value)
            draft[key] = value
            PaintReset()
        end
        -- saved when you're done typing
        box.edit:HookScript("OnEditFocusLost", Save)
        return box
    end
    local surname = Field(L["Family name"], -146, 200, HC.Guild.NAME_MAX, "surname")
    local welcome = Field(L["Welcome line"], -206, 278, HC.Guild.WELCOME_MAX, "welcome")
    welcome.hint:SetText(L["For new cousins, as they join"])
    local crest = Crest.Create(fields, 56)
    crest:SetPoint("TOPLEFT", PAD, -270)
    local crestText = Theme.Text(fields, "Small", C.text3)
    crestText:SetPoint("TOPLEFT", PAD + 68, -280)
    crestText:SetWidth(210)
    crestText:SetWordWrap(true)
    crestText:SetSpacing(2)
    crestText:SetText(L["The family wears your crest."])
    -- each rank with its word, the guild master's first
    local words = Theme.Text(fields, "Headline")
    words:SetPoint("TOPLEFT", 322, -60)
    words:SetText(L["A word for each rank"])
    local boxes = {}
    for index, rank in ipairs(HC.Guild.Ranks()) do
        local y = -86 - (index - 1) * 34
        local label = Theme.Text(fields, "Small", C.text2)
        label:SetPoint("TOPRIGHT", fields, "TOPLEFT", 416, y - 9)
        label:SetWidth(94)
        label:SetJustifyH("RIGHT")
        label:SetText(rank)
        local box = Theme.EditBox(fields, WIDTH - PAD - 424, HC.Guild.DefaultWord(index - 1), nil, HC.Guild.WORD_MAX)
        box:SetPoint("TOPLEFT", 424, y)
        box.onChange = function(value)
            draft.words[index] = value
            PaintReset()
        end
        box.edit:HookScript("OnEditFocusLost", Save)
        boxes[index] = box
    end
    -- while it's no family
    local off = Theme.Text(body, "Body", C.text3)
    off:SetPoint("TOPLEFT", 322, -90)
    off:SetWidth(WIDTH - PAD - 322)
    off:SetWordWrap(true)
    off:SetSpacing(3)
    off:SetText(L["Turn it on to give your family a name, a word for each rank and a welcome line."])
    local note = Theme.Text(body, "Small", C.text3)
    note:SetPoint("TOPLEFT", PAD, -352)
    note:SetWidth(270)
    note:SetWordWrap(true)
    note:SetSpacing(2)
    note:SetText(L["Members with Hey Cousin! get all this from your addon, by themselves."]
        .. (HC.TestMode.active and ("\n" .. L["(Test mode: a made-up guild you lead.)"]) or ""))
    -- shows the family as it is in the draft (after a Reset)
    function p.Refresh()
        row.toggle:Refresh(true)
        fields:SetShown(draft.on)
        off:SetShown(not draft.on)
        surname.edit:SetText(draft.surname)
        welcome.edit:SetText(draft.welcome)
        for index, box in ipairs(boxes) do
            local word = draft.words[index]
            box.edit:SetText(Utils.IsUsableString(word) and word or HC.Guild.DefaultWord(index - 1))
        end
        crest:SetCrest(Kin.Crest(), Utils.Trim(draft.surname))
    end
    function p.Open()
        draft = HC.Guild.Draft()
        saved, start = Utils.Copy(draft), Utils.Copy(draft)
        p.Refresh()
        PaintReset()
    end
    function p.Blur()
        surname.edit:ClearFocus()
        welcome.edit:ClearFocus()
        for _, box in ipairs(boxes) do
            box.edit:ClearFocus()
        end
    end
    Theme.OnClick(p.reset, "guild reset", function()
        draft = Utils.Copy(start)
        p.Refresh()
        Save()
        PaintReset()
    end)
    return p
end

local function ShowSub(key)
    -- (a guild's page needs a guild you lead, with these ranks)
    if key == "guild" and subs.guild and subs.guild.ranks ~= table.concat(HC.Guild.Ranks(), "\n") then
        subs.guild:Hide()
        subs.guild = nil
    end
    HideSubs()
    main:Hide()
    subs[key] = subs[key] or (key == "crest" and BuildCrestPage() or BuildGuildPage())
    openSub = key
    subs[key]:Show()
    subs[key].Open()
end

local function Build()
    window = Theme.Window("HeyCousinOptions", WIDTH, HEIGHT)
    window:SetFrameStrata("DIALOG")
    main = CreateFrame("Frame", nil, window)
    main:SetAllPoints()
    local heading = Theme.Text(main, "Title")
    heading:SetPoint("TOPLEFT", PAD, -20)
    heading:SetText(L["Settings"])
    local title = Theme.Title()
    heading:SetTextColor(title[1], title[2], title[3])
    local labels = { alerts = L["Alerts"], family = L["Family"], map = L["Map"], plates = L["Nameplates"], game = L["In the game"],
        look = L["Look & language"], about = L["About"] }
    nav = {}
    for index, key in ipairs(ORDER) do
        local button = Theme.Button(main, labels[key], "secondary", NAV_W, 32)
        button:SetPoint("TOPLEFT", PAD, -TOP - (index - 1) * 38)
        Theme.OnClick(button, "settings page", function()
            ShowPage(key)
        end)
        nav[key] = button
    end
    local link = VersionLink(main)
    link:SetPoint("BOTTOMLEFT", PAD, 18)
    pages = { alerts = BuildAlerts(), family = BuildFamily(), map = BuildMap(), plates = BuildPlates(), game = BuildGame(), look = BuildLook(),
        about = BuildAbout() }
    window:HookScript("OnHide", function()
        GameTooltip:Hide()
        -- done typing: it's saved. Next time the window opens on its main pages, unless a new look
        -- is building it again.
        for _, sub in pairs(subs) do
            sub.Blur()
        end
        if not rebuilding then
            HideSubs()
        end
    end)
end

-- Opens the settings on page `key` ("alerts", "family", "map", "plates", "game", "look", "about"), on your crest
-- ("crest") or on your guild's family ("guild", if you lead it), else on the one you left.
function Options.Show(key)
    -- (both show the same settings: one at a time)
    HC.Setup.Hide()
    if not window then
        Build()
    end
    if key == "guild" and not HC.Guild.Leads() then
        key = "family"
    end
    if key == "crest" or key == "guild" then
        -- its Back goes to the page it belongs to
        current = "family"
        ShowSub(key)
    elseif openSub and not key then
        ShowSub(openSub)
    else
        ShowPage(pages[key] and key or current)
    end
    window:Show()
end

function Options.Hide()
    if window then
        window:Hide()
    end
end

function Options.Toggle()
    if window and window:IsShown() then
        window:Hide()
    else
        Options.Show()
    end
end

-- A new look: the settings are built again in it, on the same page.
Theme.OnSkin(function()
    if not window then
        return
    end
    local shown = window:IsShown()
    rebuilding = true
    window:Hide()
    rebuilding = false
    window, main, pages, nav = nil, nil, nil, nil
    subs = {}
    if shown then
        Options.Show()
    end
end)

-- --- the game's Options > AddOns ----------------------------------------------------------------

-- The game's panel closed, unless settings changed elsewhere in it wait to be applied: then it stays
-- open for its own buttons.
local function CloseGamePanel()
    if not (SettingsPanel and SettingsPanel:IsShown()) then
        return
    end
    if type(SettingsPanel.HasUnappliedSettings) == "function" and SettingsPanel:HasUnappliedSettings() then
        return
    end
    if type(HideUIPanel) == "function" then
        HideUIPanel(SettingsPanel)
    else
        SettingsPanel:Hide()
    end
end

-- A short page there: its text is in the tooltips' colors, light in every look (the panel is dark).
-- Built when it shows, and again after a new look.
local function BuildBridge(panel)
    local page = CreateFrame("Frame", nil, panel)
    page:SetAllPoints()
    page.skin = Theme.Skin()
    local name = Theme.Text(page, "Title", C.tip)
    name:SetPoint("TOPLEFT", 16, -16)
    name:SetText(L["Hey Cousin!"])
    local note = Theme.Text(page, "Body", C.tip2)
    note:SetPoint("TOPLEFT", 16, -48)
    note:SetText(L["The settings have a window of their own."])
    local open = Action(page, L["Open the settings"], function()
        CloseGamePanel()
        Options.Show()
    end)
    open:SetPoint("TOPLEFT", 16, -74)
    return page
end

-- Once, as you log in; a game without this panel just has no page there.
function Options.Start()
    bootLanguage = Locale.Choice()
    if bridge or not (Settings and type(Settings.RegisterCanvasLayoutCategory) == "function"
        and type(Settings.RegisterAddOnCategory) == "function") then
        return
    end
    local panel = CreateFrame("Frame")
    panel:Hide()
    panel:SetScript("OnShow", function(self)
        if self.page and self.page.skin ~= Theme.Skin() then
            self.page:Hide()
            self.page = nil
        end
        self.page = self.page or BuildBridge(self)
    end)
    bridge = Settings.RegisterCanvasLayoutCategory(panel, L["Hey Cousin!"])
    Settings.RegisterAddOnCategory(bridge)
end
