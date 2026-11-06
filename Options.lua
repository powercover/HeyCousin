local _, HC = ...

-- The settings: everything you can choose, by what it's for, in a window of their own. The setup
-- (Setup.lua) walks you through your crest and the main choices; these are all of them, and a
-- button runs the setup. The game's Options > AddOns has a page with a button to this window.
HC.Options = {}

local Options = HC.Options
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
local ORDER = { "alerts", "family", "map", "game", "look", "about" }

local window, pages, nav
local current = "alerts"
local bootLanguage
local bridge

-- What's new in this version: the version number's tooltip.
local function News()
    return {
        L["Settings: every choice in one place, by what it's for."],
        L["Family chat: /fam talks to every cousin online who has the addon."],
        L["Family news: a line in chat when a cousin reaches a round level."],
        L["\"(uses addon)\" marks the cousins who run Hey Cousin!, and a line tells you when they come online."],
        L["Recruit: invite the cousins who have no guild."],
        L["Your other characters show in your family, and a crown marks the eldest."],
    }
end

-- --- a page, from the top down ------------------------------------------------------------------

local function NewPage()
    local p = CreateFrame("Frame", nil, window)
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

-- --- the pages ----------------------------------------------------------------------------------

local function BuildAlerts()
    local p = NewPage()
    Heading(p, L["On screen"])
    Toggle(p, L["A pop-up when you first meet a cousin"], L["With a sound. Click it to target them."], "popup", true)
    Toggle(p, L["Every time you meet"], L["Not only the first time."], "popupEvery", false)
    Toggle(p, L["Black sheep too"], L["Cousins from the other faction."], "enemyAlerts", true)
    Heading(p, L["Sound"])
    Chips(p, HC.Setup.SoundChips(p))
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
    local change = Action(p, L["Change your crest"], OpenSetup("crest"))
    change:SetPoint("TOPLEFT", 76, p.y - 38)
    -- the guild's family is its guild master's to give
    local guild = Action(p, L["Your guild"], OpenSetup("guild"))
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
    Toggle(p, L["Cousins coming online"], L["A line in chat. They see when you're online too."], "presence", true)
    Toggle(p, L["Family news"], L["A line in chat when a cousin reaches a round level."], "familyNews", true)
    Toggle(p, L["Family chat"], L["/fam talks to every cousin online who has the addon."], "familyChat", true)
    return p
end

local function BuildMap()
    local p = NewPage()
    Heading(p, L["On your map"])
    Toggle(p, L["Your family on the world map"], L["Cousins who share where they are."], "mapShow", true)
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

local function BuildGame()
    local p = NewPage()
    Heading(p, L["In chat"])
    Toggle(p, L["Your crest in chat"], L["At the start of a relative's message."], "chatCrest", true)
    Note(p, L["Learn from these chats"], C.text2)
    p.y = p.y + 2
    Chips(p, HC.Setup.ChatChips(p))
    Heading(p, L["In tooltips"])
    Toggle(p, L["A family line in tooltips"], L["\"Family: Ashbrook (cousin)\""], "tooltipLine", true)
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
    Note(p, L["Your crest, your alerts and the family map, step by step."])
    p.y = p.y + 2
    local setup = Action(p, L["Open the setup"], OpenSetup())
    setup:SetPoint("TOPLEFT", 0, p.y)
    p.y = p.y - 34
    Heading(p, L["Chat commands"])
    for _, command in ipairs(HC.Commands()) do
        local line = Theme.Text(p, "Small", C.text2)
        line:SetPoint("TOPLEFT", 0, p.y)
        line:SetPoint("RIGHT", p, "RIGHT", 0, 0)
        line:SetText(command)
        p.y = p.y - 17
    end
    return p
end

-- --- the window ---------------------------------------------------------------------------------

local function ShowPage(key)
    current = key
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

local function Build()
    window = Theme.Window("HeyCousinOptions", WIDTH, HEIGHT)
    window:SetFrameStrata("DIALOG")
    local heading = Theme.Text(window, "Title")
    heading:SetPoint("TOPLEFT", PAD, -20)
    heading:SetText(L["Settings"])
    local title = Theme.Title()
    heading:SetTextColor(title[1], title[2], title[3])
    local labels = { alerts = L["Alerts"], family = L["Family"], map = L["The family map"], game = L["In the game"],
        look = L["Look & language"], about = L["About"] }
    nav = {}
    for index, key in ipairs(ORDER) do
        local button = Theme.Button(window, labels[key], "secondary", NAV_W, 32)
        button:SetPoint("TOPLEFT", PAD, -TOP - (index - 1) * 38)
        Theme.OnClick(button, "settings page", function()
            ShowPage(key)
        end)
        nav[key] = button
    end
    local link = VersionLink(window)
    link:SetPoint("BOTTOMLEFT", PAD, 18)
    pages = { alerts = BuildAlerts(), family = BuildFamily(), map = BuildMap(), game = BuildGame(), look = BuildLook(),
        about = BuildAbout() }
    window:HookScript("OnHide", function()
        GameTooltip:Hide()
    end)
end

-- Opens the settings on page `key` ("alerts", "family", "map", "game", "look", "about"), else on the
-- one you left.
function Options.Show(key)
    -- (both show the same settings: one at a time)
    HC.Setup.Hide()
    if not window then
        Build()
    end
    ShowPage(pages[key] and key or current)
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
    window:Hide()
    window, pages, nav = nil, nil, nil
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
