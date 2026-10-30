local _, HC = ...

HC.Window = {}

local Window = HC.Window
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local WIDTH, HEIGHT = 500, 600
local PAD = 18
local ROW = 38
local CARD = 138
-- the list's columns from a row's left, and the room the seen column keeps at its right
local LEVEL_X, ZONE_X, SEEN_W = 206, 248, 76
local LIST_TOP = 166
local WHITE = "Interface\\Buttons\\WHITE8X8"

local window, list, card, stats, empty
local tabs, search, header
-- Each column has its natural order (newest first, A to Z, highest level first); a second click
-- on it turns the list around.
local sort = { key = "seen", reversed = false }
local selected
local query = ""
local ticker

-- --- the list ----------------------------------------------------------------------------------

local function Mine()
    local first = Names.Me()
    local _, class = Utils.Call(UnitClass, "player")
    return {
        first = first or L["You"], me = true,
        relative = {
            class = class, level = Utils.Call(UnitLevel, "player"), zone = Utils.Zone(), lastSeen = time(),
            faction = Utils.Call(UnitFactionGroup, "player"), sex = Utils.Call(UnitSex, "player"),
        },
    }
end

local SORTS = {
    name = function(a, b)
        return a.first < b.first
    end,
    level = function(a, b)
        local x, y = a.relative.level or 0, b.relative.level or 0
        if x ~= y then
            return x > y
        end
        return a.first < b.first
    end,
    zone = function(a, b)
        local x, y = a.relative.zone or "~", b.relative.zone or "~"
        if x ~= y then
            return x < y
        end
        return a.first < b.first
    end,
    seen = function(a, b)
        local x, y = Kin.IsNear(a.first), Kin.IsNear(b.first)
        if x ~= y then
            return x
        end
        local p, q = a.relative.lastSeen or 0, b.relative.lastSeen or 0
        if p ~= q then
            return p > q
        end
        return a.first < b.first
    end,
}

local function Matches(entry, text)
    if text == "" then
        return true
    end
    local relative = entry.relative
    for _, field in ipairs({ entry.first, relative.zone, Utils.ClassName(relative.class, relative.sex) }) do
        if type(field) == "string" and field:lower():find(text, 1, true) then
            return true
        end
    end
    return false
end

local function Items()
    local items = {}
    local text = query:lower()
    for _, entry in ipairs(Kin.List()) do
        if Matches(entry, text) then
            items[#items + 1] = entry
        end
    end
    table.sort(items, SORTS[sort.key] or SORTS.seen)
    if sort.reversed then
        for i = 1, math.floor(#items / 2) do
            items[i], items[#items + 1 - i] = items[#items + 1 - i], items[i]
        end
    end
    -- you, on top
    if text == "" then
        table.insert(items, 1, Mine())
    end
    return items
end

local function NewRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row.back = Theme.Texture(row, WHITE, "BACKGROUND", 0, C.hover)
    row.back:SetAllPoints()
    local function SetBack(value)
        row.back:SetAlpha(value)
    end
    Theme.Jump(row.back, 0, SetBack)
    row.line = Theme.Texture(row, WHITE, "BACKGROUND", 1, C.line)
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT", 8, 0)
    row.line:SetPoint("BOTTOMRIGHT", -8, 0)
    row.bar = Theme.Texture(row, WHITE, "ARTWORK", 0)
    row.bar:SetSize(3, ROW - 14)
    row.bar:SetPoint("LEFT", 2, 0)
    row.avatar = Theme.Skin().Avatar(row, 24)
    row.avatar:SetPoint("LEFT", 12, 0)
    row.name = Theme.Text(row, "Body")
    row.name:SetPoint("LEFT", 46, 0)
    row.tag = Theme.Text(row, "Tiny", C.text3)
    -- the black sheep's tag
    row.sheep = CreateFrame("Frame", nil, row)
    row.sheep:SetSize(92, 18)
    local sheepBack = Theme.Texture(row.sheep, WHITE, "BACKGROUND", 0, C.enemy, 0.18)
    sheepBack:SetAllPoints()
    local sheepIcon = Theme.Texture(row.sheep, Theme.Icon("Sheep"), "ARTWORK", 0, C.text)
    sheepIcon:SetSize(16, 16)
    sheepIcon:SetPoint("LEFT", 3, 0)
    local sheepText = Theme.Text(row.sheep, "Tiny", C.enemy)
    sheepText:SetPoint("LEFT", sheepIcon, "RIGHT", 2, 0)
    sheepText:SetText(L["Black sheep"])
    row.sheep:SetWidth(math.ceil(sheepText:GetStringWidth()) + 28)
    row.level = Theme.Text(row, "Body", C.text2)
    row.level:SetJustifyH("RIGHT")
    row.level:SetWidth(30)
    row.level:SetPoint("LEFT", LEVEL_X, 0)
    -- the zone takes the room up to the seen column; a long one ends in "..."
    row.zone = Theme.Text(row, "Small", C.text2)
    row.zone:SetPoint("LEFT", ZONE_X, 0)
    row.zone:SetPoint("RIGHT", -SEEN_W, 0)
    row.seen = Theme.Text(row, "Small", C.text3)
    row.seen:SetJustifyH("RIGHT")
    row.seen:SetPoint("RIGHT", -12, 0)
    row.dot = Theme.Dot(row, 6, C.near, true)
    row.dot:SetPoint("RIGHT", row.seen, "LEFT", -6, 0)
    row:SetScript("OnEnter", function(self)
        if not self.chosen then
            Theme.Ease(self.back, 1, SetBack, 18)
        end
    end)
    row:SetScript("OnLeave", function(self)
        if not self.chosen then
            Theme.Ease(self.back, 0, SetBack, 18)
        end
    end)
    row:SetScript("OnClick", Utils.Protect("row", function(self)
        if self.item and not self.item.me then
            Window.Select(self.item.first ~= selected and self.item.first or nil)
        end
    end))
    function row:SetChosen(chosen)
        self.chosen = chosen
        local fill = chosen and C.selected or C.hover
        self.back:SetVertexColor(fill[1], fill[2], fill[3])
        Theme.Jump(self.back, chosen and 1 or 0, SetBack)
        local color = Theme.Accent()
        self.bar:SetVertexColor(color[1], color[2], color[3])
        self.bar:SetShown(chosen)
    end
    return row
end

local function PaintRow(row, item)
    local relative = item.relative
    local color = Utils.ClassColor(relative.class)
    row.avatar.icon:SetShown(Utils.SetClassIcon(row.avatar.icon, relative.class))
    row.avatar.ring:SetVertexColor(color[1], color[2], color[3], 0.9)
    local sheep = not item.me and Kin.IsBlackSheep(relative)
    row.sheep:SetShown(sheep)
    row.tag:SetShown(item.me == true)
    row.tag:SetText(item.me and L["(you)"] or "")
    -- the name and its tag stay left of the level column; a long name ends in "..."
    local tag = sheep and row.sheep:GetWidth() + 8 or item.me and math.ceil(row.tag:GetStringWidth()) + 6 or 0
    row.name:SetText(item.first)
    row.name:SetTextColor(color[1], color[2], color[3])
    row.name:SetWidth(math.min(LEVEL_X - 54 - tag, math.ceil(row.name:GetStringWidth()) + 2))
    if sheep then
        row.sheep:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    elseif item.me then
        row.tag:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    end
    row.level:SetText(relative.level and tostring(relative.level) or "")
    row.zone:SetText(relative.zone or "")
    local near = not item.me and Kin.IsNear(item.first)
    if item.me then
        row.seen:SetText("")
    elseif near then
        row.seen:SetText(L["now"])
        row.seen:SetTextColor(C.near[1], C.near[2], C.near[3])
    else
        row.seen:SetText(Utils.Ago(relative.lastSeen))
        row.seen:SetTextColor(C.text3[1], C.text3[2], C.text3[3])
    end
    row.dot:SetShown(near)
    row.dot:SetPulse(near)
    row:SetChosen(item.first == selected and not item.me)
end

-- --- the card ----------------------------------------------------------------------------------

local function Whisper(full)
    local send = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
    if type(send) == "function" then
        -- the default chat frame given: the game's own way, no temporary window
        send(full, DEFAULT_CHAT_FRAME)
    end
end

local function Invite(full)
    if C_PartyInfo and type(C_PartyInfo.InviteUnit) == "function" then
        C_PartyInfo.InviteUnit(full)
    elseif type(InviteUnit) == "function" then
        InviteUnit(full)
    end
end

local function BuildCard()
    card = CreateFrame("Frame", nil, window)
    card:SetHeight(CARD)
    card:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PAD, 42)
    card:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 42)
    Theme.Panel(card, "card")
    card:Hide()
    local portrait = CreateFrame("Frame", nil, card)
    portrait:SetSize(72, 72)
    portrait:SetPoint("TOPLEFT", 14, -14)
    Theme.Panel(portrait, "frame")
    card.model = CreateFrame("PlayerModel", nil, portrait)
    card.model:SetPoint("TOPLEFT", 4, -4)
    card.model:SetPoint("BOTTOMRIGHT", -4, 4)
    card.model:SetScript("OnModelLoaded", function(self)
        self:SetPortraitZoom(0.85)
    end)
    card.crest = Crest.Create(portrait, 56)
    card.crest:SetPoint("CENTER")
    card.name = Theme.Text(card, "Headline")
    card.name:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 14, -4)
    card.name:SetPoint("RIGHT", card, "RIGHT", -40, 0)
    card.line = Theme.Text(card, "Small", C.text2)
    card.line:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -6)
    card.line:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    card.met = Theme.Text(card, "Small", C.text3)
    card.met:SetPoint("TOPLEFT", card.line, "BOTTOMLEFT", 0, -5)
    card.met:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    -- the buttons, in a row along the bottom, each as wide as its label
    card.whisper = Theme.Button(card, L["Whisper"], "secondary", 96, 30)
    card.whisper:SetPoint("BOTTOMLEFT", 14, 12)
    Theme.ButtonIcon(card.whisper, "Whisper")
    card.invite = Theme.Button(card, L["Invite"], "secondary", 90, 30)
    card.invite:SetPoint("LEFT", card.whisper, "RIGHT", 6, 0)
    Theme.ButtonIcon(card.invite, "Invite")
    card.layer = Theme.Button(card, L["Join their layer"], "primary", 140, 30)
    card.layer:SetPoint("LEFT", card.invite, "RIGHT", 6, 0)
    Theme.ButtonIcon(card.layer, "Portal")
    for _, button in ipairs({ card.whisper, card.invite, card.layer }) do
        Theme.Fit(button, 12, 84)
    end
    Theme.Tip(card.layer, L["Join their layer"], function()
        return HC.Layer and HC.Layer.Explain(card.first) or nil
    end)
    card.close = Theme.IconButton(card, "Close", 22)
    card.close:SetPoint("TOPRIGHT", -8, -8)
    Theme.OnClick(card.close, "card close", function()
        Window.Select(nil)
    end)
    local function Act(fn)
        return function()
            if not card.first then
                return
            end
            if HC.TestMode.active then
                Utils.Print(L["Test mode: made-up cousins can't hear you."])
                return
            end
            fn(card.first, card.surname)
        end
    end
    Theme.OnClick(card.whisper, "whisper", Act(function(first, surname)
        Whisper(Names.Full(first, surname))
    end))
    Theme.OnClick(card.invite, "invite", Act(function(first, surname)
        Invite(Names.Full(first, surname))
    end))
    Theme.OnClick(card.layer, "join their layer", Act(function(first, surname)
        HC.Layer.Ask(first, surname)
        Window.Refresh(true)
    end))
end

local function PaintCard()
    local house, surname = Kin.House()
    local relative = house and selected and house.relatives[selected]
    if not relative then
        card:Hide()
        return false
    end
    card.first, card.surname = selected, surname
    local color = Utils.ClassColor(relative.class)
    card.name:SetText(Names.Full(selected, surname))
    card.name:SetTextColor(color[1], color[2], color[3])
    local sheep = Kin.IsBlackSheep(relative)
    local parts = { sheep and Theme.Paint(L["Black sheep"], C.enemy) or L["Cousin"] }
    local className = Utils.ClassName(relative.class, relative.sex)
    if relative.level and className then
        parts[#parts + 1] = string.format(L["Level %d %s"], relative.level, className)
    end
    if relative.zone then
        parts[#parts + 1] = Kin.IsNear(selected) and string.format(L["%s, now"], relative.zone) or relative.zone
    end
    card.line:SetText(table.concat(parts, "  ·  "))
    local met = relative.met or 0
    local metText = met <= 0 and L["Not met yet: known from the guild"]
        or met == 1 and L["Met once"] or string.format(L["Met %d times"], met)
    if HC.Layer then
        HC.Layer.Query(selected, surname)
    end
    local layer = HC.Layer and HC.Layer.Status(selected)
    card.met:SetText(metText .. "  ·  " .. string.format(L["first seen %s"], Utils.Ago(relative.firstSeen))
        .. (layer and ("  ·  " .. layer) or ""))
    -- black sheep play on the other side: no layer of theirs to join
    card.layer:SetShown(not sheep)
    card.layer:SetEnabled(HC.Layer == nil or HC.Layer.CanAsk(selected))
    -- their face when the game can show them (near you), else the crest. The model loads once
    -- per relative: a refresh doesn't reload it.
    local unit = relative.guid and type(UnitTokenFromGUID) == "function" and Utils.Call(UnitTokenFromGUID, relative.guid)
    local live = unit and Utils.Call(UnitIsVisible, unit) and not Utils.UnitHidden(unit)
    local shown = live and selected or false
    if card.modelFor ~= shown then
        card.modelFor = shown
        card.model:ClearModel()
        if live then
            card.model:SetUnit(unit)
            card.model:SetPortraitZoom(0.85)
        end
    end
    card.model:SetShown(live == true)
    card.crest:SetShown(not live)
    if not live then
        card.crest:SetCrest(house.crest, surname, sheep)
    end
    card:Show()
    return true
end

-- --- stats -------------------------------------------------------------------------------------

local FACTION_COLORS = { Alliance = { 0.24, 0.45, 0.82 }, Horde = { 0.78, 0.22, 0.18 } }

local function BuildStats()
    stats = CreateFrame("Frame", nil, window)
    stats:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -(LIST_TOP - 28))
    stats:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 42)
    stats:Hide()
    stats.tiles = {}
    local tileWidth = (WIDTH - PAD * 2 - 16) / 3
    for index, label in ipairs({ L["Relatives"], L["Meetings"], L["Near you now"] }) do
        local tile = CreateFrame("Frame", nil, stats)
        tile:SetSize(tileWidth, 80)
        tile:SetPoint("TOPLEFT", (index - 1) * (tileWidth + 8), 0)
        Theme.Panel(tile, "tile")
        tile.value = Theme.Text(tile, "Big")
        tile.value:SetPoint("TOPLEFT", 14, -12)
        tile.label = Theme.Text(tile, "Small", C.text2)
        tile.label:SetPoint("BOTTOMLEFT", 14, 13)
        tile.label:SetText(label)
        stats.tiles[index] = tile
    end
    local function Heading(text, y, x)
        local heading = Theme.Text(stats, "Headline")
        heading:SetPoint("TOPLEFT", x or 2, y)
        heading:SetText(text)
        return heading
    end
    Heading(L["Both sides of the family"], -102)
    local bar = CreateFrame("Frame", nil, stats)
    bar:SetHeight(12)
    bar:SetPoint("TOPLEFT", 2, -130)
    bar:SetPoint("RIGHT", stats, "RIGHT", -2, 0)
    bar.back = Theme.Texture(bar, WHITE, "BACKGROUND", 0, C.ink)
    bar.back:SetPoint("TOPLEFT", -2, 2)
    bar.back:SetPoint("BOTTOMRIGHT", 2, -2)
    bar.mine = Theme.Texture(bar, WHITE, "ARTWORK", 0)
    bar.mine:SetPoint("TOPLEFT")
    bar.mine:SetPoint("BOTTOMLEFT")
    bar.other = Theme.Texture(bar, WHITE, "ARTWORK", 0)
    bar.other:SetPoint("TOPRIGHT")
    bar.other:SetPoint("BOTTOMRIGHT")
    stats.bar = bar
    stats.sidesText = Theme.Text(stats, "Small", C.text2)
    stats.sidesText:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -8)
    Heading(L["Met most"], -176)
    local right = (WIDTH - PAD * 2) / 2 + 8
    Heading(L["Surnames you meet most"], -176, right)
    stats.metRows, stats.nameRows = {}, {}
    for i = 1, 5 do
        local met = Theme.Text(stats, "Body")
        met:SetPoint("TOPLEFT", 2, -204 - (i - 1) * 26)
        met:SetWidth(200)
        stats.metRows[i] = met
        local nameRow = CreateFrame("Frame", nil, stats)
        nameRow:SetSize((WIDTH - PAD * 2) / 2 - 10, 20)
        nameRow:SetPoint("TOPLEFT", right, -202 - (i - 1) * 26)
        nameRow.fill = Theme.Texture(nameRow, WHITE, "BACKGROUND", 0)
        nameRow.fill:SetPoint("TOPLEFT")
        nameRow.fill:SetPoint("BOTTOMLEFT")
        nameRow.text = Theme.Text(nameRow, "Small")
        nameRow.text:SetPoint("LEFT", 6, 0)
        nameRow.count = Theme.Text(nameRow, "Small", C.text2)
        nameRow.count:SetPoint("RIGHT", -6, 0)
        stats.nameRows[i] = nameRow
    end
end

local function PaintStats()
    local data = Kin.Stats(5)
    local total, nearby = Kin.Counts()
    local metal, accent = Theme.Metal(), Theme.Accent()
    for index, value in ipairs({ total, data.meetings, nearby }) do
        local tile = stats.tiles[index]
        tile.value:SetText(tostring(value))
        tile.value:SetTextColor(metal[1], metal[2], metal[3])
    end
    local mineFaction = Utils.Call(UnitFactionGroup, "player")
    local otherFaction = mineFaction == "Horde" and "Alliance" or "Horde"
    local width = stats.bar:GetWidth()
    local all = data.mine + data.other
    local share = all > 0 and data.mine / all or 1
    local a, b = FACTION_COLORS[mineFaction] or accent, FACTION_COLORS[otherFaction] or C.enemy
    stats.bar.mine:SetVertexColor(a[1], a[2], a[3])
    stats.bar.other:SetVertexColor(b[1], b[2], b[3])
    stats.bar.mine:SetWidth(math.max(0.01, width * share))
    stats.bar.other:SetWidth(math.max(0.01, width * (1 - share)))
    stats.bar.other:SetShown(data.other > 0)
    local mineName = _G["FACTION_" .. (mineFaction or ""):upper()] or mineFaction or ""
    local otherName = _G["FACTION_" .. otherFaction:upper()] or otherFaction
    stats.sidesText:SetText(string.format(L["%d on your side (%s) · %d black sheep (%s)"], data.mine, mineName,
        data.other, otherName))
    for i = 1, 5 do
        local entry = data.mostMet[i]
        local row = stats.metRows[i]
        if entry then
            local color = Utils.ClassColor(entry.relative.class)
            local times = (entry.relative.met or 0) == 1 and L["once"]
                or string.format(L["%d times"], entry.relative.met or 0)
            row:SetText(Theme.Paint(i .. ".  ", C.text3) .. Theme.Paint(entry.first, color) .. "  "
                .. Theme.Paint(times, C.text3))
        else
            row:SetText("")
        end
        local name = data.surnames[i]
        local nameRow = stats.nameRows[i]
        if name then
            local top = data.surnames[1].count
            nameRow.fill:SetVertexColor(accent[1], accent[2], accent[3], 0.6)
            nameRow.fill:SetWidth(math.max(4, nameRow:GetWidth() * name.count / top))
            nameRow.text:SetText(name.name)
            nameRow.count:SetText(tostring(name.count))
            nameRow:Show()
        else
            nameRow:Hide()
        end
    end
end

-- --- the window --------------------------------------------------------------------------------

local function HeaderButton(key, label)
    local button = CreateFrame("Button", nil, window)
    button:SetHeight(20)
    button.label = Theme.Text(button, "Tiny", C.text3)
    button.label:SetPoint("LEFT")
    button.label:SetText(label)
    button.arrow = Theme.Texture(button, Theme.Icon("ChevronDown"), "ARTWORK", 0, C.text3)
    button.arrow:SetSize(10, 10)
    button.arrow:SetPoint("LEFT", button.label, "RIGHT", 3, 0)
    button:SetWidth(math.ceil(button.label:GetStringWidth()) + 16)
    button.key = key
    button:SetScript("OnClick", Utils.Protect("sort", function(self)
        if sort.key == self.key then
            sort.reversed = not sort.reversed
        else
            sort.key, sort.reversed = self.key, false
        end
        Window.Refresh()
    end))
    button:SetScript("OnEnter", function(self)
        self.label:SetTextColor(C.text[1], C.text[2], C.text[3])
    end)
    button:SetScript("OnLeave", function(self)
        local color = sort.key == self.key and C.text2 or C.text3
        self.label:SetTextColor(color[1], color[2], color[3])
    end)
    return button
end

local function Build()
    window = Theme.Window("HeyCousinWindow", WIDTH, HEIGHT)

    -- your house
    header = {}
    header.crest = Crest.Create(window, 64)
    header.crest:SetPoint("TOPLEFT", PAD, -16)
    header.title = Theme.Text(window, "Title")
    header.title:SetPoint("TOPLEFT", header.crest, "TOPRIGHT", 14, -6)
    header.title:SetPoint("RIGHT", window, "RIGHT", -88, 0)
    header.sub = Theme.Text(window, "Small", C.text2)
    header.sub:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -7)
    header.sub:SetPoint("RIGHT", window, "RIGHT", -PAD, 0)
    header.motto = Theme.Text(window, "Small", C.text3)
    header.motto:SetPoint("TOPLEFT", header.sub, "BOTTOMLEFT", 0, -5)
    header.motto:SetPoint("RIGHT", window, "RIGHT", -PAD, 0)
    local gear = Theme.IconButton(window, "Gear", 26, L["Setup"], L["Your crest, motto, alerts and look."])
    gear:SetPoint("RIGHT", window.close, "LEFT", -6, 0)
    Theme.OnClick(gear, "setup", function()
        if HC.Setup then
            HC.Setup.Show()
        end
    end)

    tabs = Theme.Tabs(window, { { key = "family", label = L["Family"] }, { key = "stats", label = L["Stats"] } },
        function()
            Window.Refresh()
        end, 200, 30)
    tabs:SetPoint("TOPLEFT", PAD, -96)
    search = Theme.EditBox(window, 190, L["Search"], "Search", 24)
    search:SetPoint("TOPRIGHT", -PAD, -96)
    search.onChange = function(text)
        query = Utils.Trim(text)
        Window.Refresh()
    end

    -- the columns
    local columns = {
        HeaderButton("name", L["Name"]), HeaderButton("level", L["Lvl"]),
        HeaderButton("zone", L["Zone"]), HeaderButton("seen", L["Seen"]),
    }
    columns[1]:SetPoint("TOPLEFT", PAD + 46, -142)
    columns[2]:SetPoint("TOPLEFT", PAD + LEVEL_X + 10, -142)
    columns[3]:SetPoint("TOPLEFT", PAD + ZONE_X, -142)
    columns[4]:SetPoint("TOPRIGHT", -PAD - 12, -142)
    window.columns = columns

    list = Theme.List(window, ROW, NewRow, PaintRow)
    list:SetPoint("TOPLEFT", PAD, -LIST_TOP)
    list:SetPoint("BOTTOMRIGHT", -PAD, 42)

    -- nobody yet
    empty = CreateFrame("Frame", nil, window)
    empty:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -ROW)
    empty:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT")
    empty.crest = Crest.Create(empty, 96)
    empty.crest:SetPoint("TOP", 0, -36)
    empty.crest:SetAlpha(0.55)
    empty.title = Theme.Text(empty, "Headline")
    empty.title:SetPoint("TOP", empty.crest, "BOTTOM", 0, -14)
    empty.title:SetText(L["No cousins yet"])
    empty.text = Theme.Text(empty, "Body", C.text2)
    empty.text:SetPoint("TOP", empty.title, "BOTTOM", 0, -10)
    empty.text:SetWidth(320)
    empty.text:SetWordWrap(true)
    empty.text:SetJustifyH("CENTER")
    empty.text:SetSpacing(3)
    empty.text:SetText(L["Hey Cousin! spots players with your surname around you, in chat and in your guild. Go say hi!"])
    empty:Hide()

    BuildCard()
    BuildStats()

    -- the line along the bottom
    window.footer = Theme.Text(window, "Small", C.text3)
    window.footer:SetPoint("BOTTOMLEFT", PAD, 17)
    window.badge = CreateFrame("Frame", nil, window)
    window.badge:SetSize(84, 22)
    window.badge:SetPoint("BOTTOMRIGHT", -PAD, 12)
    Theme.Panel(window.badge, "well")
    local badgeText = Theme.Text(window.badge, "Tiny", C.gold)
    badgeText:SetPoint("CENTER")
    badgeText:SetText(L["TEST MODE"])
    window.badge:SetWidth(math.ceil(badgeText:GetStringWidth()) + 20)
    window.badge:EnableMouse(true)
    Theme.Tip(window.badge, L["Test mode"], L["Retail has no surnames, so this is a made-up family. Type /cousin test for a pop-up."])

    window:HookScript("OnShow", function()
        Window.Refresh()
        if not ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
            -- "now" and "2 min" change by themselves
            ticker = C_Timer.NewTicker(20, Utils.Protect("window tick", function()
                Window.Refresh(true)
            end))
        end
    end)
    window:HookScript("OnHide", function()
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
        search.edit:ClearFocus()
        -- a model drops while hidden: load it again next time
        card.modelFor = nil
    end)
    tabs:Select("family")
end

local function PaintHeader()
    local house, surname = Kin.House()
    local first = Names.Me()
    local total, nearby, sheep = Kin.Counts()
    header.crest:SetCrest(house and house.crest, surname)
    local metal = Theme.Metal()
    header.title:SetTextColor(metal[1], metal[2], metal[3])
    if surname then
        header.title:SetText(string.format(L["House %s"], surname))
        local _, class = Utils.Call(UnitClass, "player")
        local count = total == 1 and L["1 relative"] or string.format(L["%d relatives"], total)
        header.sub:SetText(Theme.Paint(Names.Full(first or "", surname), Utils.ClassColor(class))
            .. Theme.Paint("  ·  " .. count, C.text2))
    else
        header.title:SetText(L["Hey Cousin!"])
        header.sub:SetText(L["Your surname isn't known yet."])
    end
    local motto = house and house.motto or ""
    header.motto:SetText(motto ~= "" and ("\226\128\156" .. motto .. "\226\128\157") or "")
    local parts = { total == 1 and L["1 relative"] or string.format(L["%d relatives"], total) }
    if nearby > 0 then
        parts[#parts + 1] = Theme.Paint(string.format(L["%d near you now"], nearby), C.near)
    end
    if sheep > 0 then
        parts[#parts + 1] = sheep == 1 and L["1 black sheep"] or string.format(L["%d black sheep"], sheep)
    end
    window.footer:SetText(table.concat(parts, Theme.Paint("  ·  ", C.text3)))
    window.badge:SetShown(HC.TestMode.active)
end

-- Repaints what shows; `keep` keeps the list's scroll where it is.
function Window.Refresh(keep)
    if not window or not window:IsShown() then
        return
    end
    PaintHeader()
    local onStats = tabs.selected == "stats"
    search:SetShown(not onStats)
    for _, column in ipairs(window.columns) do
        column:SetShown(not onStats)
        local color = sort.key == column.key and C.text2 or C.text3
        column.label:SetTextColor(color[1], color[2], color[3])
        column.arrow:SetShown(sort.key == column.key)
    end
    if onStats then
        list:Hide()
        empty:Hide()
        card:Hide()
        stats:Show()
        PaintStats()
        return
    end
    stats:Hide()
    list:Show()
    local items = Items()
    local hasCard = PaintCard()
    list:SetPoint("BOTTOMRIGHT", -PAD, hasCard and (42 + CARD + 10) or 42)
    list:SetItems(items, keep)
    -- the "Seen" heading moves with the rows when the scroll bar takes room
    window.columns[4]:SetPoint("TOPRIGHT", list.bar:IsShown() and (-PAD - 22) or (-PAD - 12), -142)
    empty:SetShown(#items <= 1 and query == "")
    if empty:IsShown() then
        local house, surname = Kin.House()
        empty.crest:SetCrest(house and house.crest, surname)
    end
end

function Window.Select(first)
    selected = first
    Window.Refresh(true)
end

function Window.Show(tab)
    if not window then
        Build()
    end
    window:Show()
    if tab then
        tabs:Select(tab)
    end
end

function Window.Toggle()
    if window and window:IsShown() then
        window:Hide()
    else
        Window.Show()
    end
end

-- Opens the family on one relative (the pop-up's right-click).
function Window.ShowRelative(first)
    Window.Show("family")
    query = ""
    search.edit:SetText("")
    Window.Select(first)
    for index, item in ipairs(list.items) do
        if item.first == first then
            list:ScrollTo((index - 2) * ROW, true)
            break
        end
    end
end

Kin.OnChange(function()
    Window.Refresh(true)
end)

-- A new theme: the window is built again in it (open again if it was open).
Theme.OnSkin(function()
    if not window then
        return
    end
    local shown = window:IsShown()
    window:Hide()
    window, list, card, stats, empty, tabs, search, header = nil, nil, nil, nil, nil, nil, nil, nil
    if shown then
        Window.Show()
    end
end)
