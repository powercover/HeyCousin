local _, HC = ...

-- Family groups: say what you're looking for ("Deadmines, need a healer") and every cousin online who
-- has the addon sees it, here and as a line in chat. Their Join asks you for an invite, with one
-- button (Layer.ShowAsk); the invite stays your click. A post lasts half an hour, and one comes along
-- for a cousin who logs in meanwhile.
HC.Groups = {}

local Groups = HC.Groups
local Utils = HC.Utils
local Theme = HC.Theme
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local ROW = 44
local LIVE = 30 * 60
local ASK_AGAIN = 60
-- letters, as family chat: it has to fit an addon message
local WORDS_MAX = 50
local WHITE = "Interface\\Buttons\\WHITE8X8"

local posts = {}  -- [first name] = { first, full, words, at, asked }
local mine        -- your post: { words, at }
local panel, list, empty, box, send

local function Alive(post)
    return GetTime() - post.at < LIVE
end

-- The posts that still stand, the newest first.
function Groups.List()
    local items = {}
    for first, post in pairs(posts) do
        if Alive(post) then
            items[#items + 1] = post
        else
            posts[first] = nil
        end
    end
    if HC.TestMode.active then
        for _, post in ipairs(HC.TestMode.Groups()) do
            items[#items + 1] = post
        end
    end
    table.sort(items, function(a, b)
        if a.at ~= b.at then
            return a.at > b.at
        end
        return a.first < b.first
    end)
    return items
end

-- Your post, while it stands.
function Groups.Mine()
    if mine and not Alive(mine) then
        mine = nil
    end
    return mine
end

local function Changed()
    HC.Window.Refresh(true)
end

-- What you're looking for, to the family; again with new words replaces it.
function Groups.Post(text)
    local words = HC.Guild.Plain(text, WORDS_MAX)
    if words == "" then
        return
    end
    if not HC.TestMode.active and not HC.Family.Send("5:G:" .. words) then
        Utils.Print(L["The family's channel isn't ready yet. Try again in a moment."])
        return
    end
    mine = { words = words, at = GetTime() }
    Changed()
end

-- Your post comes down.
function Groups.Stop()
    if not mine then
        return
    end
    mine = nil
    if not HC.TestMode.active then
        HC.Family.Send("5:X")
    end
    Changed()
end

-- A cousin just logged in: they get your post too.
function Groups.Greet(full)
    if Groups.Mine() then
        HC.Guild.Send("5:G:" .. mine.words, "WHISPER", full)
    end
end

-- Asks a cousin for an invite to the group they posted.
function Groups.Join(post)
    post.asked = GetTime()
    if post.test then
        Utils.Print(L["Test mode: made-up cousins can't hear you."])
    else
        HC.Guild.Send("5:J", "WHISPER", post.full)
        Utils.Print(string.format(L["Asking %s for an invite..."], post.full))
    end
    Changed()
end

-- A line from a cousin (Family.lua has checked who it's from).
function Groups.Heard(kind, rest, member)
    if kind == "G" then
        local words = HC.Guild.Plain(rest, WORDS_MAX)
        if words == "" then
            return
        end
        local old = posts[member.first]
        posts[member.first] = { first = member.first, full = member.full, words = words, at = GetTime(),
            asked = old and old.asked or nil }
        local relative = Kin.Seen({ first = member.first, faction = Utils.Call(UnitFactionGroup, "player"), quiet = true,
            online = true, usesAddon = true })
        if HeyCousinDB.familyGroups ~= false and not (old and old.words == words) then
            local color = Utils.ClassColor(relative and relative.class, true)
            Utils.Print(string.format(L["%s looks for a group: %s"], Theme.Paint(member.full, color), words))
        end
        Changed()
    elseif kind == "X" then
        posts[member.first] = nil
        Changed()
    elseif kind == "J" and Groups.Mine() then
        HC.Layer.ShowAsk(member.full, false, string.format(L["%s wants to join your group."], member.full))
    end
end

-- --- the rows ----------------------------------------------------------------------------------

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
    row.avatar = Theme.Skin().Avatar(row, 28)
    row.avatar:SetPoint("LEFT", 10, 0)
    row.join = Theme.Button(row, L["Join"], "primary", 80, 26)
    row.join:SetPoint("RIGHT", -4, 0)
    Theme.Tip(row.join, L["Join"], L["Asks them for an invite."])
    Theme.OnClick(row.join, "group join", function(self)
        local post = self:GetParent().item
        if post then
            Groups.Join(post)
        end
    end)
    row.whisper = Theme.IconButton(row, "Whisper", 26, L["Whisper"])
    row.whisper:SetPoint("RIGHT", row.join, "LEFT", -4, 0)
    Theme.OnClick(row.whisper, "group whisper", function(self)
        local post = self:GetParent().item
        if post and post.test then
            Utils.Print(L["Test mode: made-up cousins can't hear you."])
        elseif post then
            HC.Recruit.OpenChat("/w " .. post.full .. " ")
        end
    end)
    row.name = Theme.Text(row, "Body")
    row.name:SetPoint("TOPLEFT", 48, -6)
    row.name:SetPoint("RIGHT", row.whisper, "LEFT", -6, 0)
    row.words = Theme.Text(row, "Small", C.text2)
    row.words:SetPoint("TOPLEFT", 48, -24)
    row.words:SetPoint("RIGHT", row.whisper, "LEFT", -6, 0)
    -- (a long post is cut on the row: all of it on the mouse)
    Theme.Tip(row, function(self)
        return self.item and self.item.first
    end, function(self)
        return self.item and self.item.words
    end)
    row:HookScript("OnEnter", function()
        Theme.Ease(row.back, 1, SetBack, 18)
    end)
    row:HookScript("OnLeave", function()
        Theme.Ease(row.back, 0, SetBack, 18)
    end)
    row:SetScript("OnClick", Utils.Protect("group row", function(self)
        if self.item then
            HC.Window.ShowRelative(self.item.first)
        end
    end))
    return row
end

local function PaintRow(row, post)
    local house = Kin.House()
    local relative = house and house.relatives[post.first]
    local class = post.class or (relative and relative.class)
    local level = post.level or (relative and relative.level)
    local color = Utils.ClassColor(class)
    row.avatar.icon:SetShown(Utils.SetClassIcon(row.avatar.icon, class))
    row.avatar.ring:SetVertexColor(color[1], color[2], color[3], 0.9)
    row.name:SetText(level and (post.first .. "  " .. Theme.Paint(level, C.text3)) or post.first)
    row.name:SetTextColor(color[1], color[2], color[3])
    row.words:SetText(post.words)
    local asked = post.asked and GetTime() - post.asked < ASK_AGAIN
    row.join:SetEnabled(not asked)
    row.join:SetText(asked and L["Asked"] or L["Join"])
    Theme.Fit(row.join, 12, 72)
end

-- --- the page ----------------------------------------------------------------------------------

-- The button beside the box: Post, or Take it down when the box shows the post that's up.
local function PaintSend()
    local words = Utils.Trim(box.edit:GetText() or "")
    local up = Groups.Mine()
    local down = up ~= nil and up.words == words
    send:SetText(down and L["Take it down"] or L["Post"])
    Theme.SetKind(send, down and "secondary" or "primary")
    Theme.Fit(send, 12, 76)
    send:SetEnabled(down or words ~= "")
end

local function PostOrStop()
    local up = Groups.Mine()
    local words = Utils.Trim(box.edit:GetText() or "")
    box.edit:ClearFocus()
    if up and up.words == words then
        Groups.Stop()
        box.edit:SetText("")
    else
        Groups.Post(words)
    end
end

-- The page, under the window's tabs: `x` and `top` from the window's corner, `bottom` from its foot.
function Groups.Build(window, x, top, bottom)
    panel = CreateFrame("Frame", nil, window)
    panel:SetPoint("TOPLEFT", window, "TOPLEFT", x, -top)
    panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -x, bottom)
    panel:Hide()
    local note = Theme.Text(panel, "Small", C.text2)
    note:SetPoint("TOPLEFT", 0, 0)
    note:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    note:SetWordWrap(true)
    note:SetText(L["What are you looking for? Every cousin online who has the addon sees it."])
    send = Theme.Button(panel, L["Post"], "primary", 76, 30)
    send:SetPoint("TOPRIGHT", 0, -22)
    Theme.OnClick(send, "group post", PostOrStop)
    box = Theme.EditBox(panel, window:GetWidth() - x * 2 - 130, L["Deadmines, need a healer"], nil, WORDS_MAX * 2)
    box:SetPoint("TOPLEFT", 0, -22)
    -- (up to the button, whose words change)
    box:SetPoint("RIGHT", send, "LEFT", -6, 0)
    box.onChange = PaintSend
    box.edit:SetScript("OnEnterPressed", Utils.Protect("group post", PostOrStop))
    list = Theme.List(panel, ROW, NewRow, PaintRow)
    list:SetPoint("TOPLEFT", 0, -62)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    empty = Theme.Text(panel, "Body", C.text2)
    empty:SetPoint("TOP", list, "TOP", 0, -40)
    empty:SetWidth(340)
    empty:SetWordWrap(true)
    empty:SetJustifyH("CENTER")
    empty:SetText(L["No cousin is looking for a group right now."])
    return panel
end

function Groups.Paint(keep)
    -- your post in the box; never over what you're typing
    local up = Groups.Mine()
    if up and not box.edit:HasFocus() then
        box.edit:SetText(up.words)
    end
    PaintSend()
    local items = Groups.List()
    list:SetItems(items, keep)
    empty:SetShown(#items == 0)
end

-- The box loses what you typed when the window goes.
function Groups.Blur()
    if box then
        box.edit:ClearFocus()
    end
end

-- A new look builds the window again: the page's parts go with it.
Theme.OnSkin(function()
    panel, list, empty, box, send = nil, nil, nil, nil, nil
end)
