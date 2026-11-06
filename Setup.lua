local _, HC = ...

-- The first setup: only what matters on day one. Your crest, because it's the fun of it and every
-- window wears it; then your family: who you hear about, and whether cousins can see where you are,
-- which is the one choice nobody should make for you. The rest has good defaults, and the settings
-- (Options.lua) have it all.
HC.Setup = {}

local Setup = HC.Setup
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local WIDTH, HEIGHT = 620, 584
local PAD = 22
-- the room the title and the step bar take: every page starts under it
local BAR = 44

-- the steps: your crest, your family
local CREST, FAMILY = 1, 2
local STEPS = { crest = CREST, family = FAMILY }
-- what the family step sets, kept as it was when the setup opened (Reset goes back to it)
local FAMILY_KEYS = { "popup", "mapShow", "presence", "mapShare" }

local window, pages, page, editor
-- The setup while it's open: the step it's on, the steps you've been to, your crest and motto as they
-- are, and every step as it was when the setup opened. A new look builds the window again and keeps it.
local session
local rebuilding = false
-- the setup opening by itself is starting (Setup.ShowFirst)
local first = false

local function Settings()
    return HeyCousinDB
end

-- Whether step `index` is changed from how it was when the setup opened.
local function Changed(index)
    if not session then
        return false
    end
    if index == CREST then
        return editor:Changed(session.start.crest, session.start.motto)
    end
    for _, key in ipairs(FAMILY_KEYS) do
        if not Utils.Same(Settings()[key], session.start.settings[key]) then
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

-- A setting's two sides, and what it needs done at once.
local function Setting(key, default)
    return function()
        local value = Settings()[key]
        if value == nil then
            return default
        end
        return value
    end, function(value)
        -- (your post comes down while the family's channel is still there)
        if key == "familyMessages" and value == false then
            HC.Groups.Stop()
        end
        Settings()[key] = value
        if key == "showMinimap" and HC.Minimap then
            HC.Minimap.Apply()
        elseif key == "mapShow" or key == "mapShare" or key == "presence" or key == "familyNews" or key == "familyChat"
            or key == "familyGroups" or key == "familyMessages" then
            HC.Map.Apply()
        end
        UpdateReset()
    end
end

-- (the settings show the same choices)
Setup.Setting = Setting

-- --- page 2: your family -----------------------------------------------------------------------

local function BuildFamilyPage(parent)
    local p = Page(parent)
    p.toggles = {}
    local function Row(label, note, key, default, y)
        local get, set = Setting(key, default)
        local row = Theme.ToggleRow(p, 286, label, note, get, set)
        row:SetPoint("TOPLEFT", PAD - 8, y)
        row.toggle:Refresh(true)
        p.toggles[#p.toggles + 1] = row.toggle
    end
    Heading(p, L["Your cousins"], PAD, -60)
    Row(L["A pop-up when you first meet a cousin"], L["With a sound. Click it to target them."], "popup", true, -86)
    Row(L["Your family on the world map"], L["Cousins who share where they are."], "mapShow", true, -132)
    Row(L["Cousins coming online"], L["A line in chat. They see you too."], "presence", true, -178)
    Heading(p, L["Where you are"], PAD, -234)
    Row(L["Share it with your family"], L["Cousins and your guild see you move."], "mapShare", false, -260)
    local note = Theme.Text(p, "Small", C.text3)
    note:SetPoint("TOPLEFT", PAD, -310)
    note:SetWidth(280)
    note:SetWordWrap(true)
    note:SetSpacing(2)
    note:SetText(L["Every few seconds while you move; never in a fight or a dungeon. Anyone with your surname who runs Hey Cousin! can see you. The other faction can't."])
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
    -- all the rest is a click away, and says where
    local rest = Theme.Text(p, "Small", C.text2)
    rest:SetPoint("TOPLEFT", 322, -340)
    rest:SetWidth(WIDTH - 322 - PAD)
    rest:SetWordWrap(true)
    rest:SetSpacing(2)
    rest:SetText(L["Everything else is in the settings: the gear in your family window."])
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
    window.skip:SetShown(index == 1 and session.first == true)
    window.next:SetText(last and L["Done"] or L["Next"])
    Theme.SetArt(window.next.icon, Theme.Icon(last and "Check" or "ChevronRight"))
    Theme.Fit(window.next, 20, 110)
    -- the family's step shows your crest as it is now
    if index == FAMILY then
        pages[index].Refresh()
    end
    UpdateReset()
end

-- Goes to step `index`: what you made on this one stays.
local function Go(index)
    if index ~= page then
        editor:Save()
        ShowPage(index)
    end
end

-- The step you're on, as it was when the setup opened.
local function Reset()
    if page == CREST then
        editor:Load(session.start.crest, session.start.motto, editor:OpenPicker())
        editor:Save()
    else
        for _, key in ipairs(FAMILY_KEYS) do
            Settings()[key] = Utils.Copy(session.start.settings[key])
        end
        HC.Map.Apply()
        pages[page].Refresh()
    end
    UpdateReset()
end

local function Finish()
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
        local order, index = Theme.ORDER, 1
        for i, key in ipairs(order) do
            if key == Theme.Skin().key then
                index = i
            end
        end
        return order[(index - 1 + delta) % #order + 1]
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
        [FAMILY] = { name = L["Family"], title = L["Your family"] },
    }
    window.title = Theme.Text(window, "Title")
    window.title:SetPoint("TOPLEFT", PAD, -20)
    local metal = Theme.Title()
    window.title:SetTextColor(metal[1], metal[2], metal[3])
    BuildLook()
    BuildSteps()
    local crestPage = Page(window)
    editor = HC.CrestEditor.New(crestPage, UpdateReset)
    editor:SetPoint("TOPLEFT")
    pages = { [CREST] = crestPage, [FAMILY] = BuildFamilyPage(window) }
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
        editor:Blur()
        editor:Save()
        if not rebuilding then
            session = nil
        end
    end)
end

-- A new setup: your crest, motto and settings as they are, kept for Reset.
local function Begin()
    local house = Kin.House()
    local crest = Crest.Normalize(house and house.crest)
    local motto = house and house.motto or ""
    -- a first Forever house takes the crest made in test mode, if there is one
    if not HC.TestMode.active and first and type(Settings().testCrest) == "table" then
        crest = Crest.Normalize(Settings().testCrest)
        motto = type(Settings().testMotto) == "string" and Settings().testMotto or motto
    end
    local settings = {}
    for _, key in ipairs(FAMILY_KEYS) do
        settings[key] = Utils.Copy(Settings()[key])
    end
    session = { page = CREST, visited = {}, crest = crest, motto = motto, first = first,
        start = { crest = Utils.Copy(crest), motto = motto, settings = settings } }
end

-- Opens the setup on `startPage` (a number, or "crest", "family"): else an open setup stays where it
-- is, and a new one starts on the first step.
function Setup.Show(startPage)
    startPage = STEPS[startPage] or startPage
    -- (both show the same settings: one at a time)
    HC.Options.Hide()
    local fresh = not session
    if fresh then
        Begin()
    end
    if not window then
        Build()
        fresh = true
    end
    if fresh then
        editor:Load(session.crest, session.motto, session.picker)
    end
    pages[FAMILY].Refresh()
    ShowPage(pages[startPage or session.page] and (startPage or session.page) or CREST)
    window:Show()
end

-- The one time the setup opens by itself. It counts as seen from here, however it's closed (X, Escape,
-- a reload, logging out), and for every character on the account: it never opens by itself again.
function Setup.ShowFirst()
    Settings().setupDone = true
    first = true
    Setup.Show()
    first = false
end

function Setup.Hide()
    if window then
        window:Hide()
    end
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
    if session then
        session.crest, session.motto, session.picker = editor.draft, editor.motto, editor:OpenPicker()
    end
    rebuilding = true
    window:Hide()
    rebuilding = false
    window, pages, editor = nil, nil, nil
    if shown then
        Setup.Show()
    end
end)
