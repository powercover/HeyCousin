local _, HC = ...

-- The Together tab: where cousins help each other. A chip for each page: Groups (Groups.lua), a call
-- for help (Help.lua), who has an item (Stock.lua), who crafts what, and quest buddies (Share.lua).
HC.Together = {}

local Together = HC.Together
local Utils = HC.Utils
local Theme = HC.Theme
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local ROW = 44
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ORDER = { "groups", "help", "items", "crafts", "buddies" }

local panel, chips, pages
local current = "groups"

-- --- the rows ----------------------------------------------------------------------------------

-- A row: { first, full, class, level, line, tip = { title, line }, act = { label, fn } } each.
local function NewRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row.back = Theme.Texture(row, WHITE, "BACKGROUND", 0, C.hover)
    row.back:SetAllPoints()
    local function SetBack(value)
        row.back:SetAlpha(value)
    end
    Theme.Jump(row.back, 0, SetBack)
    row.rule = Theme.Texture(row, WHITE, "BACKGROUND", 1, C.line)
    row.rule:SetHeight(1)
    row.rule:SetPoint("BOTTOMLEFT", 8, 0)
    row.rule:SetPoint("BOTTOMRIGHT", -8, 0)
    row.avatar = Theme.Skin().Avatar(row, 28)
    row.avatar:SetPoint("LEFT", 10, 0)
    row.act = Theme.Button(row, "", "primary", 80, 26)
    row.act:SetPoint("RIGHT", -4, 0)
    Theme.OnClick(row.act, "together action", function(self)
        local item = self:GetParent().item
        if item and item.act then
            item.act.fn(item)
        end
    end)
    row.whisper = Theme.IconButton(row, "Whisper", 26, L["Whisper"])
    Theme.OnClick(row.whisper, "together whisper", function(self)
        local item = self:GetParent().item
        if item and HC.TestMode.active then
            Utils.Print(L["Test mode: made-up cousins can't hear you."])
        elseif item then
            HC.Window.Whisper(item.full)
        end
    end)
    row.name = Theme.Text(row, "Body")
    row.name:SetPoint("TOPLEFT", 48, -6)
    row.name:SetPoint("RIGHT", row.whisper, "LEFT", -6, 0)
    row.line = Theme.Text(row, "Small", C.text2)
    row.line:SetPoint("TOPLEFT", 48, -24)
    row.line:SetPoint("RIGHT", row.whisper, "LEFT", -6, 0)
    Theme.Tip(row, function(self)
        return self.item and self.item.tip and self.item.tip[1]
    end, function(self)
        return self.item and self.item.tip and self.item.tip[2]
    end)
    row:HookScript("OnEnter", function()
        Theme.Ease(row.back, 1, SetBack, 18)
    end)
    row:HookScript("OnLeave", function()
        Theme.Ease(row.back, 0, SetBack, 18)
    end)
    row:SetScript("OnClick", Utils.Protect("together row", function(self)
        local house = Kin.House()
        if self.item and house and house.relatives[self.item.first] then
            HC.Window.ShowRelative(self.item.first)
        end
    end))
    return row
end

local function PaintRow(row, item)
    local color = Utils.ClassColor(item.class)
    row.avatar.icon:SetShown(Utils.SetClassIcon(row.avatar.icon, item.class))
    row.avatar.ring:SetVertexColor(color[1], color[2], color[3], 0.9)
    row.name:SetText(item.level and (item.first .. "  " .. Theme.Paint(item.level, C.text3)) or item.first)
    row.name:SetTextColor(color[1], color[2], color[3])
    row.line:SetText(item.line or "")
    row.act:SetShown(item.act ~= nil)
    if item.act then
        row.act:SetText(item.act.label)
        Theme.Fit(row.act, 12, 72)
    end
    row.whisper:ClearAllPoints()
    if item.act then
        row.whisper:SetPoint("RIGHT", row.act, "LEFT", -4, 0)
    else
        row.whisper:SetPoint("RIGHT", -4, 0)
    end
end

-- A relative as a row's start: their name, class and level.
local function Row(first, relative, extra)
    local _, surname = Kin.House()
    local item = { first = first, full = Names.Full(first, surname), class = relative and relative.class,
        level = relative and relative.level }
    for key, value in pairs(extra or {}) do
        item[key] = value
    end
    return item
end

-- --- the pages ---------------------------------------------------------------------------------

-- A page: a line of words, maybe a box with a button, maybe a status line, and a list. The spec's
-- words are functions: they're read as the page is built, in the language chosen.
local function Page(x, top, bottom, spec)
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -top)
    page:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -x, bottom)
    page:Hide()
    page.note = Theme.Text(page, "Small", C.text2)
    page.note:SetPoint("TOPLEFT", 0, 0)
    page.note:SetPoint("RIGHT", page, "RIGHT", 0, 0)
    page.note:SetWordWrap(true)
    page.note:SetText(spec.note())
    -- each part under the one before, however many lines the words take in your language
    local above = page.note
    if spec.button then
        page.box = Theme.EditBox(page, 200, spec.hint(), nil, 100)
        page.box:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -8)
        page.send = Theme.Button(page, spec.button(), "primary", 90, 30)
        page.send:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -8)
        Theme.Fit(page.send, 12, 80)
        page.box:SetPoint("RIGHT", page.send, "LEFT", -6, 0)
        local function Go()
            page.box.edit:ClearFocus()
            spec.go(Utils.Trim(page.box.edit:GetText() or ""), page)
        end
        Theme.OnClick(page.send, "together send", Go)
        page.box.edit:SetScript("OnEnterPressed", Utils.Protect("together send", Go))
        page.box.onChange = function()
            if spec.typed then
                spec.typed(page)
            end
        end
        above = page.box
    end
    if spec.status then
        page.status = Theme.Text(page, "Small", C.text3)
        page.status:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -8)
        page.status:SetPoint("RIGHT", page, "RIGHT", 0, 0)
        above = page.status
    end
    page.list = Theme.List(page, ROW, NewRow, PaintRow)
    page.list:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -8)
    page.list:SetPoint("BOTTOMRIGHT", 0, 0)
    page.empty = Theme.Text(page, "Body", C.text2)
    page.empty:SetPoint("TOP", page.list, "TOP", 0, -40)
    page.empty:SetWidth(340)
    page.empty:SetWordWrap(true)
    page.empty:SetJustifyH("CENTER")
    page.spec = spec
    return page
end

local function Show(page, items, empty, keep)
    page.list:SetItems(items, keep)
    page.empty:SetText(empty)
    page.empty:SetShown(#items == 0)
end

-- A call for help.
local function HelpSend(page)
    local words = Utils.Trim(page.box.edit:GetText() or "")
    local up = HC.Help.Mine()
    local down = up ~= nil and up.words == words
    page.send:SetText(down and L["Take it down"] or L["Ask for help"])
    Theme.SetKind(page.send, down and "secondary" or "primary")
    Theme.Fit(page.send, 12, 80)
    page.send:SetEnabled(down or words ~= "")
end

local HELP = {
    note = function() return L["Stuck? Ask every cousin online who has the addon. They see where you are, and can follow an arrow to you."] end,
    button = function() return L["Ask for help"] end, hint = function() return L["Hogger, need one more"] end,
    go = function(words, page)
        local up = HC.Help.Mine()
        if up and up.words == words then
            HC.Help.Stop()
            page.box.edit:SetText("")
        else
            HC.Help.Ask(words)
        end
    end,
    typed = HelpSend,
    paint = function(page, keep)
        local up = HC.Help.Mine()
        if up and not page.box.edit:HasFocus() then
            page.box.edit:SetText(up.words)
        end
        HelpSend(page)
        local house = Kin.House()
        local items = {}
        for _, call in ipairs(HC.Help.List()) do
            local relative = house and house.relatives[call.first]
            items[#items + 1] = Row(call.first, relative, {
                line = call.zone and (call.words .. Theme.Sep() .. call.zone) or call.words,
                tip = { call.first, call.words },
                act = call.x and { label = L["Waypoint"], fn = function()
                    HC.Help.Waypoint(call)
                end } or nil,
            })
        end
        Show(page, items, HC.Family.Messages() and L["No cousin is asking for help right now."]
            or L["Family messages are off. They're in the settings, under Family."], keep)
    end,
}

local ITEMS = {
    note = function() return L["Who in your family has an item? Cousins online with the addon answer how many they have."] end,
    button = function() return L["Search"] end, hint = function() return L["Linen Cloth"] end, status = true,
    go = function(text, page)
        if text == "" then
            return
        end
        local ok, why = HC.Stock.Ask(text)
        -- (a problem shows for a moment, then the search's own words again)
        page.problem, page.problemAt = not ok and why or nil, GetTime()
        if page.problem then
            Utils.After(3.2, "who has it", function()
                Together.Paint(true)
            end)
        end
        Together.Paint(true)
    end,
    paint = function(page, keep)
        local asking = HC.Stock.Current()
        local answers = HC.Stock.Answers()
        if page.problem and GetTime() - (page.problemAt or 0) > 3 then
            page.problem = nil
        end
        local status
        if page.problem == "unknown" then
            status = L["The game doesn't know that item yet. Check its name."]
        elseif page.problem == "wait" then
            status = L["One search at a time: wait a moment."]
        elseif page.problem == "off" then
            status = L["Family messages are off. They're in the settings, under Family."]
        elseif page.problem == "channel" then
            status = L["The family's channel isn't ready yet. Try again in a moment."]
        elseif asking and not asking.done and #answers == 0 then
            status = L["Looking..."]
        elseif asking then
            status = #answers > 0 and string.format(L["%s: %d cousins have it"], asking.name, #answers)
                or string.format(L["No cousin online has %s."], asking.name)
        else
            status = ""
        end
        page.status:SetText(status)
        local house = Kin.House()
        local items = {}
        for _, answer in ipairs(answers) do
            items[#items + 1] = Row(answer.first, house and house.relatives[answer.first],
                { line = string.format(L["Has %d"], answer.count) })
        end
        Show(page, items, "", keep)
    end,
}

local CRAFTS = {
    note = function() return L["What your cousins with the addon can make. Whisper one to ask."] end,
    paint = function(page, keep)
        local items = {}
        for _, entry in ipairs(HC.Share.Crafters()) do
            items[#items + 1] = Row(entry.first, entry.relative, { line = entry.craft.name .. "  " .. entry.craft.rank })
        end
        Show(page, items, L["No cousin has shared their professions yet. Cousins with the addon share theirs."], keep)
    end,
}

local BUDDIES = {
    note = function() return L["Cousins online within 3 levels of you, the ones in your zone first."] end,
    paint = function(page, keep)
        local items = {}
        for _, entry in ipairs(HC.Share.Buddies()) do
            local same = HC.Share.SameQuests(entry.relative)
            local titles = {}
            for _, quest in ipairs(same) do
                titles[#titles + 1] = quest.title
            end
            local line = entry.relative.zone or ""
            if #same > 0 then
                line = (line ~= "" and (line .. Theme.Sep()) or "") .. string.format(L["%d same quests"], #same)
            end
            items[#items + 1] = Row(entry.first, entry.relative, {
                line = line,
                tip = #titles > 0 and { L["On the same quests"], table.concat(titles, "\n") } or nil,
                act = { label = L["Invite"], fn = function(item)
                    if HC.TestMode.active then
                        Utils.Print(L["Test mode: made-up cousins can't hear you."])
                    else
                        HC.Window.Invite(item.full)
                    end
                end },
            })
        end
        Show(page, items, L["No cousin online is near your level right now."], keep)
    end,
}

local SPECS = { help = HELP, items = ITEMS, crafts = CRAFTS, buddies = BUDDIES }
local LABELS = {
    groups = function() return L["Groups"] end,
    help = function() return L["Help"] end,
    items = function() return L["Who has it?"] end,
    crafts = function() return L["Crafters"] end,
    buddies = function() return L["Quest buddies"] end,
}

-- The tab, under the window's tabs: `x` and `top` from the window's corner, `bottom` from its foot.
function Together.Build(window, x, top, bottom)
    panel = CreateFrame("Frame", nil, window)
    panel:SetSize(window:GetWidth(), window:GetHeight())
    panel:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    panel:Hide()
    chips, pages = {}, {}
    local left = x
    for _, key in ipairs(ORDER) do
        local chip = Theme.Chip(panel, LABELS[key](), function()
            return current == key
        end, function()
            current = key
            Together.Paint()
        end)
        chip:SetPoint("TOPLEFT", left, -top)
        left = left + chip:GetWidth() + 4
        chips[#chips + 1] = chip
    end
    pages.groups = HC.Groups.Build(panel, x, top + 34, bottom)
    for key, spec in pairs(SPECS) do
        pages[key] = Page(x, top + 34, bottom, spec)
    end
    return panel
end

function Together.Paint(keep)
    if not panel then
        return
    end
    for _, chip in ipairs(chips) do
        chip:Refresh()
    end
    for key, page in pairs(pages) do
        page:SetShown(key == current)
    end
    if current == "groups" then
        HC.Groups.Paint(keep)
    else
        SPECS[current].paint(pages[current], keep)
    end
end

-- Opens one page ("groups", "help", "items", "crafts", "buddies").
function Together.Open(key)
    if SPECS[key] or key == "groups" then
        current = key
    end
    Together.Paint()
end

-- The boxes lose what you typed when the window goes.
function Together.Blur()
    HC.Groups.Blur()
    for key in pairs(SPECS) do
        local page = pages and pages[key]
        if page and page.box then
            page.box.edit:ClearFocus()
        end
    end
end

-- A new look builds the window again: the tab's parts go with it.
Theme.OnSkin(function()
    panel, chips, pages = nil, nil, nil
end)
