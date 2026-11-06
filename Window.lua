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
-- a cousin's page: where it starts, its meetings' rows, the meeting shown in full
local PAGE_TOP, MEETING_ROW, DETAIL = 134, 32, 146
-- the list's columns from a row's left, and the room the seen column keeps at its right
local LEVEL_X, ZONE_X, SEEN_W = 206, 248, 76
local LIST_TOP = 166
local WHITE = "Interface\\Buttons\\WHITE8X8"

local window, list, page, stats, empty, tree
local tabs, search, header
-- Each column has its natural order (newest first, A to Z, highest level first); a second click
-- on it turns the list around.
local sort = { key = "seen", reversed = false }
-- the relative whose page is open (and the meeting shown in full), and the one last opened
local opened, shownMeeting
local selected
local query = ""
-- who looks like the eldest, as of the last repaint
local eldest
-- the Recruit page, over the family's list
local recruitPanel
local recruiting = false
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
        x, y = Kin.IsOnline(a.first), Kin.IsOnline(b.first)
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
        -- and your other characters under you
        for index, alt in ipairs(Kin.Alts()) do
            table.insert(items, index + 1, { first = alt.first, relative = alt.relative, alt = true })
        end
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
    -- the crown of who looks like the eldest
    row.crown = Theme.Texture(row, Theme.Icon("Crown"), "ARTWORK", 1, C.gold)
    row.crown:SetSize(14, 14)
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
        if self.item and not self.item.me and not self.item.alt then
            Window.Open(self.item.first)
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
    local ours = item.me or item.alt
    local sheep = not ours and Kin.IsBlackSheep(relative)
    local uses = not ours and not sheep and relative.usesAddon == true
    local tagged = ours or uses
    row.sheep:SetShown(sheep)
    row.tag:SetShown(tagged == true)
    row.tag:SetText(item.me and L["(you)"] or item.alt and L["(your character)"] or uses and L["(uses addon)"] or "")
    -- the name and its tag stay left of the level column; a long name ends in "..."
    local tag = sheep and row.sheep:GetWidth() + 8 or tagged and math.ceil(row.tag:GetStringWidth()) + 6 or 0
    local crowned = eldest ~= nil and item.first == eldest
    row.crown:SetShown(crowned)
    if crowned then
        tag = tag + 18
        row.crown:ClearAllPoints()
        row.crown:SetPoint("LEFT", sheep and row.sheep or tagged and row.tag or row.name, "RIGHT", 4, 0)
    end
    row.name:SetText(item.first)
    row.name:SetTextColor(color[1], color[2], color[3])
    row.name:SetWidth(math.min(LEVEL_X - 54 - tag, math.ceil(row.name:GetStringWidth()) + 2))
    if sheep then
        row.sheep:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    elseif tagged then
        row.tag:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    end
    row.level:SetText(relative.level and tostring(relative.level) or "")
    row.zone:SetText(relative.zone or "")
    local near = not item.me and Kin.IsNear(item.first)
    local online = not item.me and not near and Kin.IsOnline(item.first)
    if item.me then
        row.seen:SetText("")
    elseif near or online then
        row.seen:SetText(near and L["now"] or L["online"])
        row.seen:SetTextColor(C.near[1], C.near[2], C.near[3])
    else
        row.seen:SetText(Utils.Ago(relative.lastSeen))
        row.seen:SetTextColor(C.text3[1], C.text3[2], C.text3[3])
    end
    row.dot:SetShown(near or online)
    row.dot:SetPulse(near)
    row:SetChosen(item.first == selected and not item.me)
end

-- --- a cousin's page --------------------------------------------------------------------------

-- How you met, and how it was around you: a meeting's lines.
local HOW = {
    nameplate = "Seen near you", mouseover = "You pointed at them", target = "You targeted them",
    group = "In your group", say = "Talked near you", whisper = "Whispered you",
}
local INSTANCES = { party = "In a dungeon", raid = "In a raid", pvp = "In a battleground", arena = "In an arena",
    scenario = "In a scenario" }

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

-- (the Tree tab's card has these buttons too)
Window.Whisper, Window.Invite = Whisper, Invite

-- Where a meeting was: "Goldshire, Elwynn Forest".
local function Place(meeting)
    local zone = Utils.IsUsableString(meeting.zone) and meeting.zone or nil
    local sub = Utils.IsUsableString(meeting.sub) and meeting.sub or nil
    if sub and zone then
        return sub .. ", " .. zone
    end
    return sub or zone or L["Somewhere"]
end

-- How long a meeting went on ("12 min", "2 h"), or nil for a moment.
local function Lasted(meeting)
    local seconds = Utils.IsUsableNumber(meeting.last) and meeting.last - meeting.at or 0
    if seconds < 60 then
        return nil
    elseif seconds < 3600 then
        return string.format(L["%d min"], math.floor(seconds / 60 + 0.5))
    end
    return string.format(L["%d h"], math.floor(seconds / 3600 + 0.5))
end

local function NewMeetingRow(parent)
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
    row.bar:SetSize(3, MEETING_ROW - 12)
    row.bar:SetPoint("LEFT", 2, 0)
    row.when = Theme.Text(row, "Small", C.text2)
    row.when:SetPoint("LEFT", 12, 0)
    row.when:SetWidth(118)
    row.place = Theme.Text(row, "Body")
    row.place:SetPoint("LEFT", 136, 0)
    row.place:SetPoint("RIGHT", -54, 0)
    row.level = Theme.Text(row, "Small", C.text3)
    row.level:SetJustifyH("RIGHT")
    row.level:SetPoint("RIGHT", -12, 0)
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
    row:SetScript("OnClick", Utils.Protect("meeting", function(self)
        if self.item then
            shownMeeting = self.item.meeting
            Window.Refresh(true)
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

local function PaintMeetingRow(row, item)
    local meeting = item.meeting
    row.when:SetText(Utils.When(meeting.at))
    row.place:SetText(Place(meeting))
    row.level:SetText(Utils.IsUsableNumber(meeting.level) and string.format(L["Lv %d"], meeting.level) or "")
    row:SetChosen(meeting == item.shown)
end

-- One meeting in full: when and how long, where, how you met, both levels, what they said, and
-- their gear.
local function BuildDetail(parent)
    local detail = CreateFrame("Frame", nil, parent)
    detail:SetHeight(DETAIL)
    detail:SetPoint("BOTTOMLEFT")
    detail:SetPoint("BOTTOMRIGHT")
    Theme.Panel(detail, "card")
    local above
    local function Line(font, color)
        local text = Theme.Text(detail, font, color)
        if above then
            text:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -5)
        else
            text:SetPoint("TOPLEFT", 14, -12)
        end
        text:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
        above = text
        return text
    end
    detail.when = Line("Body", C.text)
    detail.place = Line("Body", C.text2)
    detail.how = Line("Small", C.text2)
    detail.levels = Line("Small", C.text2)
    detail.said = Line("Small", C.text3)
    -- their gear then: the item level, and an icon for each item (its tooltip on the mouse)
    detail.gear = Theme.Text(detail, "Small", C.text3)
    detail.gear:SetPoint("BOTTOMLEFT", 14, 15)
    detail.icons = {}
    for index = 1, #HC.Gear.SLOTS do
        local icon = CreateFrame("Button", nil, detail)
        icon:SetSize(18, 18)
        icon.back = Theme.Texture(icon, WHITE, "BACKGROUND", 0, C.ink)
        icon.back:SetAllPoints()
        icon.art = icon:CreateTexture(nil, "ARTWORK")
        icon.art:SetPoint("TOPLEFT", 1, -1)
        icon.art:SetPoint("BOTTOMRIGHT", -1, 1)
        icon.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetScript("OnEnter", function(self)
            if self.id then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetItemByID(self.id)
                GameTooltip:Show()
            end
        end)
        icon:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        icon:Hide()
        detail.icons[index] = icon
    end
    return detail
end

local function PaintGear(detail, meeting)
    local gear = type(meeting.gear) == "table" and meeting.gear or {}
    local count = 0
    for index, icon in ipairs(detail.icons) do
        local art = HC.Gear.Icon(gear[index])
        icon.id = art and gear[index] or nil
        if art then
            -- in a row after the label, empty slots left out
            count = count + 1
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", detail.gear, "RIGHT", 8 + (count - 1) * 20, 0)
            icon.art:SetTexture(art)
        end
        icon:SetShown(art ~= nil)
    end
    if Utils.IsUsableNumber(meeting.ilvl) then
        detail.gear:SetText(string.format(L["Item level %d"], meeting.ilvl))
    else
        detail.gear:SetText(count > 0 and L["Gear"] or L["Gear: not seen up close"])
    end
end

local function PaintMeeting(meeting, first)
    local detail = page.detail
    local lasted = Lasted(meeting)
    detail.when:SetText(Utils.When(meeting.at)
        .. (lasted and Theme.Paint("  ·  " .. string.format(L["%s together"], lasted), C.text3) or ""))
    local place = Place(meeting)
    if Utils.IsUsableNumber(meeting.x) and Utils.IsUsableNumber(meeting.y) then
        place = place .. Theme.Paint(string.format("  ·  %.1f, %.1f", meeting.x, meeting.y), C.text3)
    end
    detail.place:SetText(place)
    local how = {}
    if HOW[meeting.how] then
        how[#how + 1] = L[HOW[meeting.how]]
    end
    if meeting.group == true and meeting.how ~= "group" then
        how[#how + 1] = L["In your group"]
    end
    if INSTANCES[meeting.instance] then
        how[#how + 1] = L[INSTANCES[meeting.instance]]
    elseif meeting.rest == true then
        how[#how + 1] = L["In a town"]
    end
    if meeting.night == true then
        how[#how + 1] = L["At night"]
    end
    detail.how:SetText(table.concat(how, "  ·  "))
    local levels = {}
    if Utils.IsUsableNumber(meeting.level) then
        levels[#levels + 1] = string.format(L["%s: level %d"], first, meeting.level)
    end
    if Utils.IsUsableNumber(meeting.myLevel) then
        levels[#levels + 1] = string.format(L["you: level %d"], meeting.myLevel)
    end
    if Utils.IsUsableString(meeting.guild) then
        levels[#levels + 1] = "<" .. meeting.guild .. ">"
    end
    detail.levels:SetText(table.concat(levels, "  ·  "))
    detail.said:SetText(Utils.IsUsableString(meeting.said) and ("\226\128\156" .. meeting.said .. "\226\128\157") or "")
    PaintGear(detail, meeting)
end

local function BuildPage()
    page = CreateFrame("Frame", nil, window)
    page:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -PAGE_TOP)
    page:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 42)
    page:Hide()
    page.back = Theme.IconButton(page, "ChevronLeft", 26, L["All your cousins"])
    page.back:SetPoint("TOPLEFT", 0, -2)
    Theme.OnClick(page.back, "back to the family", function()
        Window.Open(nil)
    end)
    local portrait = CreateFrame("Frame", nil, page)
    portrait:SetSize(64, 64)
    portrait:SetPoint("TOPLEFT", 36, 0)
    Theme.Panel(portrait, "frame")
    page.model = CreateFrame("PlayerModel", nil, portrait)
    page.model:SetPoint("TOPLEFT", 4, -4)
    page.model:SetPoint("BOTTOMRIGHT", -4, 4)
    page.model:SetScript("OnModelLoaded", function(self)
        self:SetPortraitZoom(0.85)
    end)
    page.crest = Crest.Create(portrait, 50)
    page.crest:SetPoint("CENTER")
    page.name = Theme.Text(page, "Headline")
    page.name:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 14, -2)
    page.name:SetPoint("RIGHT", page, "RIGHT", 0, 0)
    page.line = Theme.Text(page, "Small", C.text2)
    page.line:SetPoint("TOPLEFT", page.name, "BOTTOMLEFT", 0, -6)
    page.line:SetPoint("RIGHT", page, "RIGHT", 0, 0)
    page.met = Theme.Text(page, "Small", C.text3)
    page.met:SetPoint("TOPLEFT", page.line, "BOTTOMLEFT", 0, -5)
    page.met:SetPoint("RIGHT", page, "RIGHT", 0, 0)
    -- the buttons, in a row under them, each as wide as its label: from the page's left edge, as
    -- the pixel font is wide
    page.whisper = Theme.Button(page, L["Whisper"], "secondary", 96, 30)
    page.whisper:SetPoint("TOPLEFT", 0, -74)
    Theme.ButtonIcon(page.whisper, "Whisper")
    page.invite = Theme.Button(page, L["Invite"], "secondary", 90, 30)
    page.invite:SetPoint("LEFT", page.whisper, "RIGHT", 6, 0)
    Theme.ButtonIcon(page.invite, "Invite")
    page.layer = Theme.Button(page, L["Join their layer"], "primary", 140, 30)
    page.layer:SetPoint("LEFT", page.invite, "RIGHT", 6, 0)
    Theme.ButtonIcon(page.layer, "Portal")
    for _, button in ipairs({ page.whisper, page.invite, page.layer }) do
        Theme.Fit(button, 12, 84)
    end
    Theme.Tip(page.layer, L["Join their layer"], function()
        return HC.Layer and HC.Layer.Explain(page.first) or nil
    end)
    local function Act(fn)
        return function()
            if not page.first then
                return
            end
            if HC.TestMode.active then
                Utils.Print(L["Test mode: made-up cousins can't hear you."])
                return
            end
            fn(page.first, page.surname)
        end
    end
    Theme.OnClick(page.whisper, "whisper", Act(function(first, surname)
        Whisper(Names.Full(first, surname))
    end))
    Theme.OnClick(page.invite, "invite", Act(function(first, surname)
        Invite(Names.Full(first, surname))
    end))
    Theme.OnClick(page.layer, "join their layer", Act(function(first, surname)
        HC.Layer.Ask(first, surname)
        Window.Refresh(true)
    end))
    -- every meeting, the newest first; a click shows it in full below
    page.heading = Theme.Text(page, "Headline")
    page.heading:SetPoint("TOPLEFT", 0, -118)
    page.list = Theme.List(page, MEETING_ROW, NewMeetingRow, PaintMeetingRow)
    page.list:SetPoint("TOPLEFT", 0, -144)
    page.list:SetPoint("BOTTOMRIGHT", 0, DETAIL + 8)
    page.none = Theme.Text(page, "Small", C.text3)
    page.none:SetPoint("TOPLEFT", 4, -150)
    page.none:SetPoint("RIGHT", page, "RIGHT", -4, 0)
    page.none:SetWordWrap(true)
    page.detail = BuildDetail(page)
end

-- The page of the relative opened (Window.Open); false when there's none to show.
local function PaintPage(keep)
    local house, surname = Kin.House()
    local relative = house and opened and house.relatives[opened]
    if not relative then
        opened = nil
        page:Hide()
        return false
    end
    page.first, page.surname = opened, surname
    local color = Utils.ClassColor(relative.class)
    page.name:SetText(Names.Full(opened, surname))
    page.name:SetTextColor(color[1], color[2], color[3])
    local sheep = Kin.IsBlackSheep(relative)
    local parts = { sheep and Theme.Paint(L["Black sheep"], C.enemy) or opened == eldest and Theme.Paint(L["Eldest cousin"], C.gold)
        or L["Cousin"] }
    local className = Utils.ClassName(relative.class, relative.sex)
    if relative.level and className then
        parts[#parts + 1] = string.format(L["Level %d %s"], relative.level, className)
    end
    if relative.zone then
        parts[#parts + 1] = (Kin.IsNear(opened) or Kin.IsOnline(opened)) and string.format(L["%s, now"], relative.zone)
            or relative.zone
    end
    if Utils.IsUsableString(relative.guild) then
        parts[#parts + 1] = "<" .. relative.guild .. ">"
    end
    page.line:SetText(table.concat(parts, "  ·  "))
    local met = relative.met or 0
    local notMet = relative.found and L["Not met yet: found by searching"]
        or relative.shared and L["Not met yet: they share their place on the map"] or L["Not met yet: known from the guild"]
    local metText = met <= 0 and notMet or met == 1 and L["Met once"] or string.format(L["Met %d times"], met)
    if HC.Layer then
        HC.Layer.Query(opened, surname)
    end
    local layer = HC.Layer and HC.Layer.Status(opened)
    page.met:SetText(metText .. "  ·  " .. string.format(L["first seen: %s"], Utils.When(relative.firstSeen))
        .. (layer and ("  ·  " .. layer) or "") .. (relative.usesAddon and ("  ·  " .. L["(uses addon)"]) or ""))
    -- black sheep play on the other side: no layer of theirs to join
    page.layer:SetShown(not sheep)
    page.layer:SetEnabled(HC.Layer == nil or HC.Layer.CanAsk(opened))
    -- their face when the game can show them (near you), else the crest. The model loads once
    -- per relative: a refresh doesn't reload it.
    local unit = relative.guid and type(UnitTokenFromGUID) == "function" and Utils.Call(UnitTokenFromGUID, relative.guid)
    local live = unit and Utils.Call(UnitIsVisible, unit) and not Utils.UnitHidden(unit)
    local shownFor = live and opened or false
    if page.modelFor ~= shownFor then
        page.modelFor = shownFor
        page.model:ClearModel()
        if live then
            page.model:SetUnit(unit)
            page.model:SetPortraitZoom(0.85)
        end
    end
    page.model:SetShown(live == true)
    page.crest:SetShown(not live)
    if not live then
        page.crest:SetCrest(Kin.CrestOf(opened), surname, sheep)
    end
    -- the meetings: the one you clicked shows in full, else the newest
    local meetings = Kin.Meetings(relative)
    local shown = meetings[1]
    for _, meeting in ipairs(meetings) do
        if meeting == shownMeeting then
            shown = meeting
        end
    end
    local items = {}
    for _, meeting in ipairs(meetings) do
        items[#items + 1] = { meeting = meeting, shown = shown }
    end
    page.heading:SetText(met > 0 and string.format(L["Meetings (%d)"], met) or L["Meetings"])
    page.list:SetItems(items, keep and page.listFor == opened)
    page.listFor = opened
    page.none:SetShown(#meetings == 0)
    page.none:SetText(met > 0 and L["Meetings are kept from now on: the next one shows here."] or notMet)
    page.detail:SetShown(shown ~= nil)
    if shown then
        PaintMeeting(shown, opened)
    end
    page:Show()
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
    local metal, accent = Theme.Title(), Theme.Accent()
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
    -- the addon's core: the one big button, on every tab
    header.find = Theme.Button(window, L["Find my family"], "primary", 150, 28)
    header.find:SetPoint("TOPRIGHT", -PAD, -54)
    Theme.ButtonIcon(header.find, "Search")
    Theme.Tip(header.find, L["Find my family"],
        L["One click searches the game's /who for your surname and lists everyone online with it."])
    Theme.OnClick(header.find, "find my family", function()
        -- (on the Recruit page, you stay there and see who it finds)
        local stay = recruiting
        Window.Show("family")
        Window.Open(nil)
        Window.Recruit(stay)
        HC.Find.Start()
    end)
    window.find = header.find
    header.sub = Theme.Text(window, "Small", C.text2)
    header.sub:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -7)
    header.sub:SetPoint("RIGHT", header.find, "LEFT", -8, 0)
    header.motto = Theme.Text(window, "Small", C.text3)
    header.motto:SetPoint("TOPLEFT", header.sub, "BOTTOMLEFT", 0, -5)
    header.motto:SetPoint("RIGHT", header.find, "LEFT", -8, 0)
    local gear = Theme.IconButton(window, "Gear", 26, L["Settings"], L["Alerts, your family, the map, the look and more."])
    gear:SetPoint("RIGHT", window.close, "LEFT", -6, 0)
    Theme.OnClick(gear, "settings", function()
        HC.Options.Show()
    end)

    tabs = Theme.Tabs(window, { { key = "family", label = L["Family"] }, { key = "tree", label = L["Tree"] },
        { key = "stats", label = L["Stats"] } }, function()
            recruiting = false
            Window.Refresh()
        end, 282, 30)
    tabs:SetPoint("TOPLEFT", PAD, -96)
    search = Theme.EditBox(window, 168, L["Search"], "Search", 24)
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

    BuildPage()
    BuildStats()
    tree = HC.Tree.Build(window, PAD, LIST_TOP - 28, 42)
    recruitPanel = HC.Recruit.Build(window, PAD, LIST_TOP - 28, 42)

    -- the line along the bottom
    window.footer = Theme.Text(window, "Small", C.text3)
    window.footer:SetPoint("BOTTOMLEFT", PAD, 17)
    window.badge = CreateFrame("Frame", nil, window)
    window.badge:SetSize(84, 22)
    window.badge:SetPoint("BOTTOMRIGHT", -PAD, 12)
    window.recruit = Theme.Button(window, L["Recruit"], "secondary", 100, 26)
    Theme.OnClick(window.recruit, "recruit", function()
        Window.Recruit(true)
    end)
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
        page.modelFor = nil
        window:SetFrameStrata("HIGH")
    end)
    tabs:Select("family")
end

local function PaintHeader()
    local house, surname = Kin.House()
    local first = Names.Me()
    local total, nearby, sheep, online = Kin.Counts()
    header.find:SetText(HC.Find.Label())
    Theme.Fit(header.find, 12, 120)
    header.find:SetEnabled(HC.Find.Ready())
    header.crest:SetCrest(house and house.crest, surname)
    local metal = Theme.Title()
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
    if online > 0 then
        parts[#parts + 1] = Theme.Paint(string.format(L["%d online"], online), C.near)
    end
    if eldest then
        parts[#parts + 1] = Theme.Paint(string.format(L["Eldest we know: %s"], eldest), C.gold)
    end
    if sheep > 0 then
        parts[#parts + 1] = sheep == 1 and L["1 black sheep"] or string.format(L["%d black sheep"], sheep)
    end
    window.badge:SetShown(HC.TestMode.active)
    -- the way to the Recruit page, under the family's list
    local showRecruit = tabs.selected == "family" and opened == nil and not recruiting
    window.recruit:SetShown(showRecruit)
    if showRecruit then
        window.recruit:SetText(string.format(L["Recruit (%d)"], #HC.Recruit.List()))
        Theme.Fit(window.recruit, 10, 90)
        window.recruit:ClearAllPoints()
        if HC.TestMode.active then
            window.recruit:SetPoint("RIGHT", window.badge, "LEFT", -6, 0)
        else
            window.recruit:SetPoint("BOTTOMRIGHT", -PAD, 10)
        end
    end
    -- as many as fit, in that order: long words in some languages, and the badge and button take room
    local room = WIDTH - PAD * 2 - (HC.TestMode.active and window.badge:GetWidth() + 10 or 0)
        - (showRecruit and window.recruit:GetWidth() + 10 or 0)
    repeat
        window.footer:SetText(table.concat(parts, Theme.Paint("  ·  ", C.text3)))
        local fits = #parts <= 1 or window.footer:GetStringWidth() <= room
        if not fits then
            parts[#parts] = nil
        end
    until fits
end

-- Repaints what shows; `keep` keeps the list's scroll where it is.
function Window.Refresh(keep)
    if not window or not window:IsShown() then
        return
    end
    eldest = Kin.Eldest()
    PaintHeader()
    local onStats, onTree = tabs.selected == "stats", tabs.selected == "tree"
    local onPage = tabs.selected == "family" and opened ~= nil and PaintPage(keep)
    if not onPage then
        page:Hide()
    end
    local onRecruit = tabs.selected == "family" and not onPage and recruiting
    recruitPanel:SetShown(onRecruit)
    if onRecruit then
        HC.Recruit.Paint(keep)
    end
    local onList = tabs.selected == "family" and not onPage and not recruiting
    search:SetShown(onList)
    for _, column in ipairs(window.columns) do
        column:SetShown(onList)
        local color = sort.key == column.key and C.text2 or C.text3
        column.label:SetTextColor(color[1], color[2], color[3])
        column.arrow:SetShown(sort.key == column.key)
    end
    tree:SetShown(onTree)
    if onTree then
        HC.Tree.Paint(keep)
    end
    if not onList then
        list:Hide()
        empty:Hide()
        stats:SetShown(onStats)
        if onStats then
            PaintStats()
        end
        return
    end
    stats:Hide()
    list:Show()
    local items = Items()
    list:SetItems(items, keep)
    -- the "Seen" heading moves with the rows when the scroll bar takes room
    window.columns[4]:SetPoint("TOPRIGHT", list.bar:IsShown() and (-PAD - 22) or (-PAD - 12), -142)
    empty:SetShown(#items <= 1 and query == "")
    if empty:IsShown() then
        local house, surname = Kin.House()
        empty.crest:SetCrest(house and house.crest, surname)
    end
end

-- Opens a relative's page: every meeting (nil: back to the family, as you left it).
function Window.Open(first)
    if first ~= opened then
        shownMeeting = nil
    end
    -- (a cousin's page leaves the Recruit page; its back arrow goes to the family)
    if first then
        recruiting = false
    end
    opened = first
    selected = first or selected
    Window.Refresh(true)
end

Window.Select = Window.Open

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

-- The Recruit page on, or back to the family.
function Window.Recruit(on)
    recruiting = on == true
    Window.Refresh(true)
end

-- Over the world map, which may fill the screen, until the window closes (a crest's click).
function Window.Raise()
    if window then
        window:SetFrameStrata("FULLSCREEN_DIALOG")
    end
end

-- Opens the family on one relative's page (the pop-up's right-click, a crest's click).
function Window.ShowRelative(first)
    Window.Show("family")
    query = ""
    search.edit:SetText("")
    Window.Open(first)
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
    window, list, page, stats, empty, tree, tabs, search, header, recruitPanel = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
    if shown then
        Window.Show()
    end
end)
