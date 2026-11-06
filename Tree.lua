local _, HC = ...

-- The window's Tree tab: your guild as a family tree (Guild.lua). Each generation is a level, the
-- top first, four to a line, and lines join each level to the next; a click on someone shows
-- their card under the tree.
HC.Tree = {}

local Tree = HC.Tree
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local PER_LINE = 4
local BOX_W, BOX_H, GAP = 106, 40, 8
-- the room for a box's second line (its word, and the level when it fits)
local LINE_W = BOX_W - 45
-- the room above and below a line's boxes, for the lines between the generations
local ABOVE, BELOW = 16, 14
local LINE = ABOVE + BOX_H + BELOW
local THICK = 2
-- where the tree starts, under the guild's name; the card's height under it
local TOP, CARD = 50, 92
local CREST = 36
local WHITE = "Interface\\Buttons\\WHITE8X8"

local tree, list, card, empty
-- whose card shows (their whole name): you, until you click someone else
local chosen

-- --- the boxes ---------------------------------------------------------------------------------

local function NewBox(row)
    local box = CreateFrame("Button", nil, row)
    box:SetSize(BOX_W, BOX_H)
    Theme.Panel(box, "tile")
    box.back = Theme.Texture(box, WHITE, "BORDER", 0, C.hover)
    box.back:SetPoint("TOPLEFT", 3, -3)
    box.back:SetPoint("BOTTOMRIGHT", -3, 3)
    local function SetBack(value)
        box.back:SetAlpha(value)
    end
    Theme.Jump(box.back, 0, SetBack)
    box.avatar = Theme.Skin().Avatar(box, 22)
    box.avatar:SetPoint("LEFT", 8, 0)
    box.name = Theme.Text(box, "Body")
    box.name:SetPoint("TOPLEFT", 37, -7)
    box.name:SetPoint("RIGHT", box, "RIGHT", -14, 0)
    box.line = Theme.Text(box, "Small", C.text2)
    box.line:SetPoint("TOPLEFT", box.name, "BOTTOMLEFT", 0, -3)
    box.line:SetPoint("RIGHT", box, "RIGHT", -8, 0)
    -- online now
    box.dot = Theme.Dot(box, 4, C.near, false)
    box.dot:SetPoint("TOPRIGHT", -6, -6)
    box:SetScript("OnEnter", function(self)
        if not self.chosen then
            Theme.Ease(self.back, 1, SetBack, 18)
        end
    end)
    box:SetScript("OnLeave", function(self)
        if not self.chosen then
            Theme.Ease(self.back, 0, SetBack, 18)
        end
    end)
    box:SetScript("OnClick", Utils.Protect("tree box", function(self)
        if self.member then
            chosen = self.member.full
            Tree.Paint(true)
        end
    end))
    function box:SetChosen(on)
        self.chosen = on
        local fill = on and C.selected or C.hover
        self.back:SetVertexColor(fill[1], fill[2], fill[3])
        Theme.Jump(self.back, on and 1 or 0, SetBack)
    end
    return box
end

-- Whether a member married in: a family guild member with another surname.
local function InLaw(member, family)
    return family.surname ~= nil and not Names.Same(member.surname, family.surname)
end

local function PaintBox(box, member, word)
    box.member = member
    local color = Utils.ClassColor(member.class)
    box.avatar.icon:SetShown(Utils.SetClassIcon(box.avatar.icon, member.class))
    box.avatar.ring:SetVertexColor(color[1], color[2], color[3], 0.9)
    -- everyone by their first name (an in-law's whole name is on their card)
    box.name:SetText(member.first or member.full)
    box.name:SetTextColor(color[1], color[2], color[3])
    -- their word, and their level (or "you") when there's room for it
    local after = member.me and L["you"] or member.level and tostring(member.level)
    box.line:SetText(after and (word .. " · " .. after) or word)
    if after and box.line:GetStringWidth() > LINE_W then
        box.line:SetText(word)
    end
    box.dot:SetShown(member.online)
    box:SetChosen(member.full == chosen)
end

-- --- the levels --------------------------------------------------------------------------------

local function NewLevel(parent)
    local row = CreateFrame("Frame", nil, parent)
    local function Line()
        return Theme.Texture(row, WHITE, "BACKGROUND", 0, C.text3, 0.7)
    end
    row.boxes, row.drops, row.rises = {}, {}, {}
    for index = 1, PER_LINE do
        row.boxes[index] = NewBox(row)
        row.drops[index], row.rises[index] = Line(), Line()
    end
    row.upStem, row.upBar, row.downBar, row.downStem = Line(), Line(), Line(), Line()
    -- the family's crest, beside the top of the tree
    row.crest = Crest.Create(row, CREST)
    return row
end

-- One of the lines between the generations: at x, y from the row's top left, w by h; hidden when
-- not `on`.
local function Place(row, texture, on, x, y, w, h)
    texture:SetShown(on == true)
    if on then
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", row, "TOPLEFT", x, y)
        texture:SetSize(w, h)
    end
end

-- A line of the tree: its boxes in the middle; the first line of a generation hangs from a bar
-- the one above comes down to, and the last one of a generation holds the bar for the next.
local function PaintLevel(row, item)
    local count = #item.members
    local left = math.floor((item.width - (count * BOX_W + (count - 1) * GAP)) / 2)
    local first, last
    for index, box in ipairs(row.boxes) do
        local member = item.members[index]
        local x = left + (index - 1) * (BOX_W + GAP)
        local center = x + BOX_W / 2
        box:SetShown(member ~= nil)
        if member then
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", row, "TOPLEFT", x, -ABOVE)
            PaintBox(box, member, item.word)
            first, last = first or center, center
        end
        Place(row, row.drops[index], member ~= nil and item.top, center - 1, -ABOVE / 2, THICK, ABOVE / 2)
        Place(row, row.rises[index], member ~= nil and item.bottom, center - 1, -(ABOVE + BOX_H), THICK, BELOW / 2)
    end
    local middle = math.floor(item.width / 2)
    local bar = -(ABOVE + BOX_H + BELOW / 2)
    Place(row, row.upStem, item.top, middle - 1, 0, THICK, ABOVE / 2)
    Place(row, row.upBar, item.top, first - 1, 1 - ABOVE / 2, last - first + THICK, THICK)
    Place(row, row.downBar, item.bottom, first - 1, bar + 1, last - first + THICK, THICK)
    Place(row, row.downStem, item.bottom, middle - 1, bar, THICK, BELOW / 2)
    -- the crest by the top, where there's room for it
    local crest = item.crest ~= nil and left >= CREST + 12
    row.crest:SetShown(crest)
    if crest then
        row.crest:ClearAllPoints()
        row.crest:SetPoint("RIGHT", row, "TOPLEFT", left - 8, -(ABOVE + BOX_H / 2))
        row.crest:SetCrest(item.crest, item.family.surname or select(2, Names.Me()))
    end
end

-- --- the card ----------------------------------------------------------------------------------

local function BuildCard(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetHeight(CARD)
    c:SetPoint("BOTTOMLEFT")
    c:SetPoint("BOTTOMRIGHT")
    Theme.Panel(c, "card")
    c.avatar = Theme.Skin().Avatar(c, 40)
    c.avatar:SetPoint("TOPLEFT", 14, -14)
    c.name = Theme.Text(c, "Headline")
    c.name:SetPoint("TOPLEFT", 68, -12)
    c.name:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    c.line = Theme.Text(c, "Small", C.text2)
    c.line:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -5)
    c.line:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    -- the buttons, in a row under them, each as wide as its label
    c.whisper = Theme.Button(c, L["Whisper"], "secondary", 96, 30)
    c.whisper:SetPoint("BOTTOMLEFT", 68, 12)
    Theme.ButtonIcon(c.whisper, "Whisper")
    c.invite = Theme.Button(c, L["Invite"], "secondary", 90, 30)
    c.invite:SetPoint("LEFT", c.whisper, "RIGHT", 6, 0)
    Theme.ButtonIcon(c.invite, "Invite")
    c.page = Theme.Button(c, L["Their page"], "primary", 120, 30)
    c.page:SetPoint("LEFT", c.invite, "RIGHT", 6, 0)
    Theme.ButtonIcon(c.page, "ChevronRight", "RIGHT")
    for _, button in ipairs({ c.whisper, c.invite, c.page }) do
        Theme.Fit(button, 12, 84)
    end
    local function Act(fn)
        return function()
            if not c.member then
                return
            end
            if HC.TestMode.active then
                Utils.Print(L["Test mode: made-up cousins can't hear you."])
                return
            end
            fn(c.member.full)
        end
    end
    Theme.OnClick(c.whisper, "tree whisper", Act(function(full)
        HC.Window.Whisper(full)
    end))
    Theme.OnClick(c.invite, "tree invite", Act(function(full)
        HC.Window.Invite(full)
    end))
    -- a relative's page: every time you met
    Theme.OnClick(c.page, "tree page", function()
        if c.member then
            HC.Window.ShowRelative(c.member.first)
        end
    end)
    return c
end

-- When someone was last online: the roster tells it by the hour.
local function LastOnline(seen)
    if time() - seen < 3600 then
        return L["Last online less than an hour ago"]
    end
    return string.format(L["Last online %s ago"], Utils.Ago(seen))
end

local function PaintCard(member, family)
    card.member = member
    local color = Utils.ClassColor(member.class)
    card.avatar.icon:SetShown(Utils.SetClassIcon(card.avatar.icon, member.class))
    card.avatar.ring:SetVertexColor(color[1], color[2], color[3], 0.9)
    card.name:SetText(member.full)
    card.name:SetTextColor(color[1], color[2], color[3])
    local word = family.words[member.rank + 1] or HC.Guild.DefaultWord(member.rank)
    local parts = { word }
    if member.rankName and member.rankName ~= word then
        parts[#parts + 1] = member.rankName
    end
    if InLaw(member, family) then
        parts[#parts + 1] = L["In-law"]
    end
    local className = Utils.ClassName(member.class)
    if member.level and className then
        parts[#parts + 1] = string.format(L["Level %d %s"], member.level, className)
    end
    if member.online then
        parts[#parts + 1] = member.zone and string.format(L["%s, now"], member.zone) or L["Online"]
    elseif member.seen then
        parts[#parts + 1] = LastOnline(member.seen)
    end
    card.line:SetText(table.concat(parts, "  ·  "))
    -- nothing to send yourself; a whisper or an invite only reaches someone online
    local other = not member.me
    card.whisper:SetShown(other)
    card.invite:SetShown(other)
    card.whisper:SetEnabled(member.online)
    card.invite:SetEnabled(member.online)
    local house, surname = Kin.House()
    local relative = house and other and Names.Same(member.surname, surname) and house.relatives[member.first]
    card.page:SetShown(type(relative) == "table")
end

-- --- the tab -----------------------------------------------------------------------------------

-- The tree, in `window` from `left`, `top` and `bottom` in (its frame).
function Tree.Build(window, left, top, bottom)
    tree = CreateFrame("Frame", nil, window)
    tree:SetPoint("TOPLEFT", window, "TOPLEFT", left, -top)
    tree:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -left, bottom)
    tree:Hide()
    -- the guild, how many are in it, and its welcome line
    tree.title = Theme.Text(tree, "Headline")
    tree.title:SetPoint("TOPLEFT", 2, 0)
    tree.title:SetPoint("RIGHT", tree, "RIGHT", -190, 0)
    tree.count = Theme.Text(tree, "Small", C.text2)
    tree.count:SetJustifyH("RIGHT")
    tree.count:SetPoint("TOPRIGHT", -2, -5)
    tree.welcome = Theme.Text(tree, "Small", C.text3)
    tree.welcome:SetPoint("TOPLEFT", 2, -28)
    tree.welcome:SetPoint("RIGHT", tree, "RIGHT", -2, 0)
    -- the guild master gives the family its words in the setup
    tree.setup = Theme.Button(tree, "", "ghost", 120, 24)
    tree.setup:SetPoint("TOPRIGHT", 0, -22)
    tree.setup.label:SetFontObject(Theme.Font("Small"))
    tree.setup:SetText(L["Family words"])
    Theme.ButtonIcon(tree.setup, "Crown")
    Theme.Fit(tree.setup, 10, 80)
    Theme.Tip(tree.setup, L["Your guild's family"], L["Its name, a word for each rank and a welcome line."])
    Theme.OnClick(tree.setup, "family words", function()
        HC.Setup.Show("guild")
    end)
    list = Theme.List(tree, LINE, NewLevel, PaintLevel)
    list:SetPoint("TOPLEFT", 0, -TOP)
    list:SetPoint("BOTTOMRIGHT", 0, CARD + 8)
    card = BuildCard(tree)
    -- no guild, or no cousins in it
    empty = CreateFrame("Frame", nil, tree)
    empty:SetPoint("TOPLEFT", 0, -TOP)
    empty:SetPoint("BOTTOMRIGHT")
    empty.crest = Crest.Create(empty, 96)
    empty.crest:SetPoint("TOP", 0, -36)
    empty.crest:SetAlpha(0.55)
    empty.title = Theme.Text(empty, "Headline")
    empty.title:SetPoint("TOP", empty.crest, "BOTTOM", 0, -14)
    empty.text = Theme.Text(empty, "Body", C.text2)
    empty.text:SetPoint("TOP", empty.title, "BOTTOM", 0, -10)
    empty.text:SetWidth(340)
    empty.text:SetWordWrap(true)
    empty.text:SetJustifyH("CENTER")
    empty.text:SetSpacing(3)
    empty:Hide()
    return tree
end

local function PaintHeader(family, total, online)
    local metal = Theme.Title()
    tree.title:SetTextColor(metal[1], metal[2], metal[3])
    tree.title:SetText(family and family.guild or "")
    tree.count:SetText(family and (string.format(L["%d in the family"], total) .. "  ·  "
        .. Theme.Paint(string.format(L["%d online"], online), C.near)) or "")
    local leads = family ~= nil and HC.Guild.Leads()
    tree.setup:SetShown(leads)
    tree.welcome:SetPoint("RIGHT", tree, "RIGHT", leads and -(tree.setup:GetWidth() + 8) or -2, 0)
    local text = ""
    if family and family.welcome ~= "" then
        text = "\226\128\156" .. family.welcome .. "\226\128\157"
    elseif family and family.surname then
        text = string.format(L["The %s family"], family.surname)
    elseif family then
        text = L["Your relatives in this guild"]
    end
    tree.welcome:SetText(text)
end

-- Repaints the tree; `keep` keeps its scroll where it is.
function Tree.Paint(keep)
    if not tree or not tree:IsShown() then
        return
    end
    HC.Guild.Ask()
    local generations, family = HC.Guild.Tree()
    local total, online, mine, shown = 0, 0, nil, nil
    for _, generation in ipairs(generations) do
        for _, member in ipairs(generation.members) do
            total = total + 1
            online = online + (member.online and 1 or 0)
            mine = member.me and member or mine
            shown = member.full == chosen and member or shown
        end
    end
    PaintHeader(family, total, online)
    -- nobody but you yet
    local alone = total <= 1
    empty:SetShown(alone)
    list:SetShown(not alone)
    card:SetShown(not alone)
    if alone then
        local house, surname = Kin.House()
        empty.crest:SetCrest(house and house.crest, surname)
        empty.title:SetText(family and L["No cousins in your guild yet"] or L["No guild yet"])
        empty.text:SetText(family
            and L["When most of a guild shares one surname, it's a family. Its guild master can make it one in the setup, too."]
            or L["A guild that shares your surname is a family: its tree grows here, everyone by rank."])
        return
    end
    -- the one you clicked while they're in the tree, else you
    if not shown then
        shown = mine or generations[1].members[1]
        chosen = shown.full
    end
    local crest = family.crest or Kin.Crest()
    local items = {}
    for index, generation in ipairs(generations) do
        local lines = math.ceil(#generation.members / PER_LINE)
        for line = 1, lines do
            local members = {}
            for i = (line - 1) * PER_LINE + 1, math.min(line * PER_LINE, #generation.members) do
                members[#members + 1] = generation.members[i]
            end
            items[#items + 1] = {
                members = members, word = generation.word, family = family, crest = index == 1 and line == 1 and crest or nil,
                top = index > 1 and line == 1, bottom = index < #generations and line == lines,
            }
        end
    end
    -- the boxes stay in the middle when the scroll bar takes its room
    local width = list:GetWidth() - (#items * LINE > list:GetHeight() and 10 or 0)
    for _, item in ipairs(items) do
        item.width = width
    end
    list:SetItems(items, keep)
    PaintCard(shown, family)
end
