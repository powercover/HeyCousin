local _, HC = ...

-- Recruit: the cousins known to have no guild, each with one Invite button and a ready welcome. It
-- gathers a family: Find my family finds them, this brings them in. Invite runs the game's /ginvite,
-- then opens your whisper box with the welcome, for you to send. A whisper is never sent by itself.
-- The game keeps the invite call to itself (a blocked call raises no error: the game just shows its
-- "blocked" window), and only a secure button may run /ginvite. So one such button lies over the Invite
-- your mouse is on. It's on UIParent, not in the window: a secure button in the window would keep the
-- window from closing in a fight. In a fight it can't move: the chat box gets /ginvite, for Enter.
HC.Recruit = {}

local Recruit = HC.Recruit
local Utils = HC.Utils
local Theme = HC.Theme
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local ROW = 38
-- the list's columns from a row's left
local LEVEL_X, ZONE_X = 150, 192
local TOP = 118
-- after an invite, the button rests this long: nobody wants two
local INVITE_AGAIN = 60 * 60
local WELCOME_MAX = 200
local WHITE = "Interface\\Buttons\\WHITE8X8"

local panel, list, empty

local function IsOnline(first)
    return Kin.IsOnline(first) or Kin.IsNear(first)
end

-- The cousins on your side known to have no guild: the ones online first, then the highest level.
function Recruit.List()
    local house = Kin.House()
    local items = {}
    if not house then
        return items
    end
    for first, relative in pairs(house.relatives) do
        if relative.noGuild and not Kin.IsBlackSheep(relative) then
            items[#items + 1] = { first = first, relative = relative }
        end
    end
    table.sort(items, function(a, b)
        local x, y = IsOnline(a.first), IsOnline(b.first)
        if x ~= y then
            return x
        end
        local p, q = a.relative.level or 0, b.relative.level or 0
        if p ~= q then
            return p > q
        end
        return a.first < b.first
    end)
    return items
end

-- Your guild's name, and whether your rank may invite; nothing without a guild.
local function Rights()
    local guild = HC.Guild.Mine()
    if not guild then
        return nil, false
    end
    if HC.TestMode.active then
        return guild, true
    end
    -- (a client without the question: the game itself will say no)
    return guild, type(CanGuildInvite) ~= "function" or Utils.Call(CanGuildInvite) == true
end

local function Welcome()
    local house = Kin.House()
    local mine = house and house.welcome
    return Utils.IsUsableString(mine) and mine or L["Hey cousin! We share a surname. Want to join the family?"]
end

local function OpenChat(text)
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if type(open) == "function" then
        open(text, DEFAULT_CHAT_FRAME)
    end
end
Recruit.OpenChat = OpenChat

local function FullName(first)
    return Names.Full(first, (select(2, Names.Me())))
end

-- Your whisper box, open with the welcome: yours to send, or to change first.
function Recruit.Whisper(first)
    if HC.TestMode.active then
        Utils.Print(L["Test mode: made-up cousins can't hear you."])
        return
    end
    OpenChat("/w " .. FullName(first) .. " " .. Welcome())
end

-- A click on Invite that the secure button couldn't take (a fight): /ginvite, for Enter.
function Recruit.Invite(first, relative)
    if HC.TestMode.active then
        Utils.Print(L["Test mode: made-up cousins can't hear you."])
        return
    end
    local full = FullName(first)
    relative.invited = time()
    Kin.Changed()
    OpenChat("/ginvite " .. full)
    Utils.Print(string.format(L["Press Enter to invite %s."], full))
end

-- --- the secure button over Invite --------------------------------------------------------------

local gate

local function InviteTip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(L["Invite"], C.tip[1], C.tip[2], C.tip[3])
    GameTooltip:AddLine(L["Invites them to your guild, then opens a whisper with your welcome."], C.tip2[1], C.tip2[2], C.tip2[3], true)
    GameTooltip:Show()
end

-- The Invite under it looks hovered and pressed as usual.
local function Paint(hovered, pressed)
    local owner = gate.owner
    if owner then
        owner.hovered, owner.pressed = hovered, pressed
        Theme.PaintButton(owner)
    end
end

local function Close()
    if gate and gate:IsShown() and not Utils.Call(InCombatLockdown) then
        Paint(false, false)
        gate:Hide()
    end
end
-- (a fight is about to start: only now can it still go)
Recruit.HideForCombat = Close

local function BuildGate()
    gate = CreateFrame("Button", "HeyCousinRecruitInvite", UIParent, "SecureActionButtonTemplate")
    gate:SetFrameStrata("FULLSCREEN_DIALOG")
    gate:RegisterForClicks("AnyUp", "AnyDown")
    gate:SetAttribute("useOnKeyDown", false)
    gate:SetAttribute("type1", "macro")
    gate:Hide()
    gate:SetScript("OnEnter", function(self)
        Paint(true, false)
        if self.owner then
            InviteTip(self.owner)
        end
    end)
    gate:SetScript("OnLeave", function()
        GameTooltip:Hide()
        Close()
    end)
    gate:SetScript("OnMouseDown", function()
        Paint(true, true)
    end)
    gate:SetScript("OnMouseUp", function()
        Paint(true, false)
    end)
    -- /ginvite has run: the row rests, and the welcome is yours to send
    gate:SetScript("PostClick", Utils.Protect("recruit invite", function(self, button, down)
        local item = self.item
        if down or button ~= "LeftButton" or not item then
            return
        end
        item.relative.invited = time()
        Kin.Changed()
        OpenChat("/w " .. FullName(item.first) .. " " .. Welcome())
    end))
    -- the window closed, the list scrolled, or the row changed under it: never a click on something else
    gate:SetScript("OnUpdate", Utils.Protect("recruit invite", function(self)
        local owner = self.owner
        local row = owner and owner:GetParent()
        if not owner or not owner:IsVisible() or owner.barred or not row.item or row.item.first ~= self.item.first then
            GameTooltip:Hide()
            Close()
        end
    end))
end

-- The mouse came on an Invite: the secure button lies over it.
local function Offer(invite)
    local item = invite:GetParent().item
    if not item or invite.barred or HC.TestMode.active or Utils.Call(InCombatLockdown) then
        return
    end
    if not gate then
        BuildGate()
    end
    gate.owner, gate.item = invite, item
    gate:SetAttribute("macrotext1", "/ginvite " .. FullName(item.first))
    local scale = invite:GetEffectiveScale() / UIParent:GetEffectiveScale()
    gate:ClearAllPoints()
    gate:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", invite:GetLeft() * scale, invite:GetBottom() * scale)
    gate:SetSize(invite:GetWidth() * scale, invite:GetHeight() * scale)
    gate:Show()
end

-- Why Invite is off for a row, or nothing when it's on.
local function Barred(first, relative)
    local guild, can = Rights()
    if not guild then
        return L["You have no guild."]
    elseif not can then
        return L["Your rank can't invite."]
    elseif not IsOnline(first) then
        return L["Not seen online in the last few minutes. Click Find my family."]
    elseif Utils.IsUsableNumber(relative.invited) and time() - relative.invited < INVITE_AGAIN then
        return L["Invited"]
    end
    return nil
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
    row.avatar = Theme.Skin().Avatar(row, 24)
    row.avatar:SetPoint("LEFT", 12, 0)
    row.name = Theme.Text(row, "Body")
    row.name:SetPoint("LEFT", 46, 0)
    row.name:SetWidth(LEVEL_X - 46)
    row.level = Theme.Text(row, "Body", C.text2)
    row.level:SetJustifyH("RIGHT")
    row.level:SetWidth(30)
    row.level:SetPoint("LEFT", LEVEL_X, 0)
    row.invite = Theme.Button(row, L["Invite"], "primary", 90, 26)
    row.invite:SetPoint("RIGHT", -4, 0)
    Theme.Tip(row.invite, L["Invite"], function(self)
        return self.barred or L["Invites them to your guild, then opens a whisper with your welcome."]
    end)
    Theme.OnClick(row.invite, "recruit invite", function(self)
        local item = self:GetParent().item
        if item then
            Recruit.Invite(item.first, item.relative)
        end
    end)
    row.invite:HookScript("OnEnter", Utils.Protect("recruit invite", Offer))
    row.whisper = Theme.IconButton(row, "Whisper", 26, L["Whisper"], L["Opens a whisper with your welcome, for you to send."])
    row.whisper:SetPoint("RIGHT", row.invite, "LEFT", -4, 0)
    Theme.OnClick(row.whisper, "recruit whisper", function(self)
        local item = self:GetParent().item
        if item then
            Recruit.Whisper(item.first)
        end
    end)
    row.zone = Theme.Text(row, "Small", C.text2)
    row.zone:SetPoint("LEFT", ZONE_X, 0)
    row.zone:SetPoint("RIGHT", row.whisper, "LEFT", -6, 0)
    row.dot = Theme.Dot(row, 6, C.near, false)
    row.dot:SetPoint("RIGHT", row.name, "LEFT", -2, 8)
    row:SetScript("OnEnter", function()
        Theme.Ease(row.back, 1, SetBack, 18)
    end)
    row:SetScript("OnLeave", function()
        Theme.Ease(row.back, 0, SetBack, 18)
    end)
    row:SetScript("OnClick", Utils.Protect("recruit row", function(self)
        if self.item then
            HC.Window.Open(self.item.first)
        end
    end))
    return row
end

local function PaintRow(row, item)
    local relative = item.relative
    local color = Utils.ClassColor(relative.class)
    row.avatar.icon:SetShown(Utils.SetClassIcon(row.avatar.icon, relative.class))
    row.avatar.ring:SetVertexColor(color[1], color[2], color[3], 0.9)
    row.name:SetText(item.first)
    row.name:SetTextColor(color[1], color[2], color[3])
    row.level:SetText(relative.level and tostring(relative.level) or "")
    row.zone:SetText(relative.zone or "")
    row.dot:SetShown(IsOnline(item.first))
    local barred = Barred(item.first, relative)
    row.invite.barred = barred
    row.invite:SetEnabled(barred == nil)
    row.invite:SetText(barred == L["Invited"] and L["Invited"] or L["Invite"])
    Theme.Fit(row.invite, 12, 80)
end

-- --- the page ----------------------------------------------------------------------------------

-- The page, under the window's tabs: `x` and `top` from the window's corner, `bottom` from its foot.
function Recruit.Build(window, x, top, bottom)
    panel = CreateFrame("Frame", nil, window)
    panel:SetPoint("TOPLEFT", window, "TOPLEFT", x, -top)
    panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -x, bottom)
    panel:Hide()
    panel.back = Theme.IconButton(panel, "ChevronLeft", 26, L["All your cousins"])
    panel.back:SetPoint("TOPLEFT", 0, -2)
    Theme.OnClick(panel.back, "back to the family", function()
        HC.Window.Recruit(false)
    end)
    panel.title = Theme.Text(panel, "Headline")
    panel.title:SetPoint("LEFT", panel.back, "RIGHT", 10, 0)
    panel.title:SetText(L["Recruit"])
    panel.note = Theme.Text(panel, "Small", C.text2)
    panel.note:SetPoint("TOPLEFT", 0, -36)
    panel.note:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    panel.note:SetWordWrap(true)
    panel.welcome = Theme.EditBox(panel, window:GetWidth() - x * 2, L["Your welcome"], nil, WELCOME_MAX)
    panel.welcome:SetPoint("TOPLEFT", 0, -72)
    panel.welcome.onChange = function(text, user)
        local house = Kin.House()
        if user and house then
            house.welcome = Utils.Trim(text)
        end
    end
    list = Theme.List(panel, ROW, NewRow, PaintRow)
    list:SetPoint("TOPLEFT", 0, -TOP)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    empty = Theme.Text(panel, "Body", C.text2)
    empty:SetPoint("TOP", list, "TOP", 0, -40)
    empty:SetWidth(340)
    empty:SetWordWrap(true)
    empty:SetJustifyH("CENTER")
    empty:SetText(L["Nobody yet: click Find my family to look for cousins with no guild."])
    return panel
end

function Recruit.Paint(keep)
    local guild, can = Rights()
    if not guild then
        panel.note:SetText(L["You have no guild yet. You can still whisper them."])
    elseif not can then
        panel.note:SetText(string.format(L["Your rank in %s can't invite. You can still whisper them."], guild))
    else
        panel.note:SetText(string.format(L["Cousins with no guild. Invite them to %s."], guild))
    end
    -- what you wrote, or the welcome as it is; never over what you're typing
    if not panel.welcome.edit:HasFocus() then
        panel.welcome.edit:SetText(Welcome())
    end
    local items = Recruit.List()
    list:SetItems(items, keep)
    empty:SetShown(#items == 0)
end
