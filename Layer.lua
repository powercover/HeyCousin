local _, HC = ...

-- Join a cousin's layer. The game puts a group on its leader's layer (once every 5 minutes, in
-- the same zone), so you ask your cousin for an invite: their Hey Cousin! shows the ask with one
-- Invite button, and the one invite you asked for is accepted by itself. Asks and answers travel
-- as addon messages. A layer is read from the NPCs around you: their GUIDs carry it (as AutoLayer
-- does on Forever). Launch day checks the name format addon whispers take.
HC.Layer = {}

local Layer = HC.Layer
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local PREFIX = "HeyCousin"
local ASK_GAP = 60      -- one ask per cousin a minute
local SWITCH_GAP = 300  -- the game moves you to another layer once every 5 minutes
local WAIT = 3          -- seconds for their addon to answer an ask
local QUERY_GAP = 60    -- how often a cousin's card asks their addon for their layer
local FRESH = 300       -- a cousin's layer is trusted this long
local RECENT = 600      -- automatic questions only go to cousins seen this recently (online)

local frame = CreateFrame("Frame")
local mine = { layer = nil, map = nil }
local theirs = {}   -- [first] = { layer, map, at }
local asked = {}    -- [first] = GetTime() of our last ask
local waiting = {}  -- [first] = true while an ask waits for an answer
local queried = {}  -- [first] = GetTime() of our last question
local quiet = {}    -- [full name] = GetTime(): an automatic question, its "not found" is hidden
local accept        -- { name, first, at }: the invite we asked for
local lastSwitch = 0
local before        -- the layer we were on when we asked
local ask, askStale, askFrom, askWaiting

-- --- reading layers ----------------------------------------------------------------------------

-- An NPC's GUID: Creature-0-server-instance-zone-npc-spawn; the zone part is the layer.
function Layer.FromGUID(guid)
    if not Utils.IsUsableString(guid) then
        return nil
    end
    local kind, zone = guid:match("^(%a+)%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind == "Creature" or kind == "Vehicle" then
        return tonumber(zone)
    end
    return nil
end

local function MyMap()
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        return Utils.Call(C_Map.GetBestMapForUnit, "player")
    end
    return nil
end

local function Read(unit)
    if Utils.Call(UnitIsPlayer, unit) ~= false then
        return
    end
    local layer = Layer.FromGUID(Utils.Call(UnitGUID, unit))
    if not layer then
        return
    end
    local changed = mine.layer ~= nil and mine.layer ~= layer
    mine.layer, mine.map = layer, MyMap()
    if changed and before and layer ~= before and accept then
        lastSwitch = GetTime()
        Utils.Print(string.format(L["You're on %s's layer now! Stay in the group, or leave it."], accept.name))
        before, accept = nil, nil
        Kin.Changed()
    end
end

-- --- messages ----------------------------------------------------------------------------------

local function Send(text, target)
    if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then
        return false
    end
    local ok = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, "WHISPER", target)
    return ok
end

local function Fresh(first)
    local house = Kin.House()
    local relative = house and house.relatives[first]
    return relative ~= nil and time() - (relative.lastSeen or 0) < RECENT
end

-- Asks a cousin's addon for their layer, now and then, when their card shows.
function Layer.Query(first, surname)
    if not Names.HaveSurnames() or not Fresh(first) then
        return
    end
    if queried[first] and GetTime() - queried[first] < QUERY_GAP then
        return
    end
    queried[first] = GetTime()
    local full = Names.Full(first, surname)
    quiet[full] = GetTime()
    Send("1:Q", full)
end

-- Your layer, as the NPCs around you tell it (nothing until one was seen).
function Layer.Current()
    return mine.layer
end

-- What a cousin's card says about their layer, if their addon told us.
function Layer.Status(first)
    local info = theirs[first]
    if not info or GetTime() - info.at > FRESH or not mine.layer then
        return nil
    end
    if info.map and mine.map and info.map ~= mine.map then
        return L["In another zone"]
    end
    if info.layer == mine.layer then
        return Theme.Paint(L["Same layer as you"], C.near)
    end
    return L["On another layer"]
end

local function Reason(first)
    if InCombatLockdown() then
        return L["Not during a fight."]
    end
    local inInstance = Utils.Call(IsInInstance)
    if inInstance then
        return L["Not in a dungeon or raid."]
    end
    if Utils.Call(IsInGroup) then
        return L["Leave your group first: the invite puts you in theirs."]
    end
    if asked[first] and GetTime() - asked[first] < ASK_GAP then
        return L["Asked a moment ago. Give them a minute."]
    end
    if GetTime() - lastSwitch < SWITCH_GAP then
        return L["The game lets you change layers once every 5 minutes."]
    end
    return nil
end

function Layer.CanAsk(first)
    return Reason(first) == nil
end

function Layer.Explain(first)
    return Reason(first) or L["Asks them for a group invite: in a group you move to the leader's layer. Same zone only."]
end

-- No Hey Cousin! answered: the whisper box opens with a friendly ask, for you to send.
local function AskInWords(full)
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if type(open) == "function" then
        open("/w " .. full .. " " .. L["Hey cousin! Could you invite me to your group? I'd like to join your layer."],
            DEFAULT_CHAT_FRAME)
    end
    Utils.Print(string.format(L["%s doesn't have Hey Cousin!: press Enter to ask in a whisper."], full))
end

-- Asks a cousin for an invite to their layer.
function Layer.Ask(first, surname)
    if not Layer.CanAsk(first) then
        Utils.Print(Layer.Explain(first))
        return
    end
    local full = Names.Full(first, surname)
    asked[first], waiting[first] = GetTime(), true
    before = mine.layer
    accept = { name = full, first = first, at = GetTime() }
    if not Send("1:A", full) then
        waiting[first] = nil
        AskInWords(full)
        return
    end
    Utils.Print(string.format(L["Asking %s for an invite..."], full))
    Utils.After(WAIT, "layer ask", function()
        if waiting[first] then
            waiting[first] = nil
            AskInWords(full)
        end
    end)
end

-- --- the ask, on your cousin's side ------------------------------------------------------------

local function BuildAsk()
    if ask then
        ask:Hide()
    end
    ask = CreateFrame("Frame", "HeyCousinAsk", UIParent)
    ask:SetSize(340, 124)
    ask:SetFrameStrata("DIALOG")
    ask:SetPoint("TOP", UIParent, "TOP", 0, -262)
    ask:SetClampedToScreen(true)
    ask:EnableMouse(true)
    ask:Hide()
    Theme.Panel(ask, "toast")
    ask.crest = Crest.Create(ask, 48)
    ask.crest:SetPoint("TOPLEFT", 16, -16)
    ask.title = Theme.Text(ask, "Headline")
    ask.title:SetPoint("TOPLEFT", ask.crest, "TOPRIGHT", 12, -2)
    ask.title:SetText(L["Hey, cousin!"])
    ask.text = Theme.Text(ask, "Small", C.text2)
    ask.text:SetPoint("TOPLEFT", ask.title, "BOTTOMLEFT", 0, -6)
    ask.text:SetPoint("RIGHT", ask, "RIGHT", -16, 0)
    ask.text:SetWordWrap(true)
    ask.text:SetSpacing(2)
    ask.yes = Theme.Button(ask, L["Invite"], "primary", 104, 30)
    ask.yes:SetPoint("BOTTOMRIGHT", -14, 14)
    Theme.ButtonIcon(ask.yes, "Invite")
    Theme.Fit(ask.yes, 12, 96)
    ask.no = Theme.Button(ask, L["Not now"], "secondary", 92, 30)
    ask.no:SetPoint("RIGHT", ask.yes, "LEFT", -6, 0)
    Theme.Fit(ask.no, 14, 84)
    Theme.OnClick(ask.yes, "layer invite", function()
        if askFrom then
            if C_PartyInfo and type(C_PartyInfo.InviteUnit) == "function" then
                C_PartyInfo.InviteUnit(askFrom)
            elseif type(InviteUnit) == "function" then
                InviteUnit(askFrom)
            end
        end
        ask:Hide()
    end)
    Theme.OnClick(ask.no, "layer no", function()
        ask:Hide()
    end)
    askStale = false
end

-- Shows "X wants to join your layer" (after a fight, if one is on). `test` shows it in test mode.
function Layer.ShowAsk(full, test)
    if InCombatLockdown() then
        askWaiting = full
        return
    end
    if not ask or askStale then
        BuildAsk()
    end
    askFrom = not test and full or nil
    local house, surname = Kin.House()
    ask.crest:SetCrest(house and house.crest, surname)
    ask.text:SetText(string.format(L["%s wants to join your layer."], full)
        .. (test and ("\n" .. L["(Test mode: the button does nothing.)"]) or ""))
    ask:Show()
    Theme.Ease(ask, 1, function(value)
        ask:SetAlpha(value)
    end, 12, 0)
    if HC.Alert and HC.Alert.SoundKey() ~= "none" then
        HC.Alert.PlaySound()
    end
    Utils.After(30, "layer ask timeout", function()
        if ask and ask:IsShown() and askFrom == full then
            ask:Hide()
        end
    end)
end

local function Heard(text, sender)
    if not Utils.IsUsableString(text) or not Utils.IsUsableString(sender) then
        return
    end
    local first, surname = Names.Split(sender)
    local me, mySurname = Names.Me()
    if not first or not Names.Same(surname, mySurname) or Names.Same(first, me) then
        -- only family asks
        return
    end
    local full = Names.Full(first, surname)
    local kind, a = text:match("^1:(%a)(.*)")
    if kind == "Q" then
        Send(string.format("1:L:%s:%s", tostring(mine.layer or 0), tostring(mine.map or 0)), full)
    elseif kind == "L" then
        local layer, map = (a or ""):match("^:(%d+):(%d+)")
        layer, map = tonumber(layer), tonumber(map)
        theirs[first] = { layer = layer ~= 0 and layer or nil, map = map ~= 0 and map or nil, at = GetTime() }
        Kin.Changed()
    elseif kind == "A" then
        Send("1:Y", full)
        Layer.ShowAsk(full)
    elseif kind == "Y" then
        waiting[first] = nil
        Utils.Print(string.format(L["%s got your ask. Their invite comes in a moment."], full))
    end
end

-- --- events ------------------------------------------------------------------------------------

-- the game's "no player named X" for an automatic question: not news to you
local function HideNotFound(_, _, message, ...)
    if type(message) ~= "string" or Utils.IsSecret(message) or not ERR_CHAT_PLAYER_NOT_FOUND_S then
        return false
    end
    for full, at in pairs(quiet) do
        if GetTime() - at > 10 then
            quiet[full] = nil
        elseif message == ERR_CHAT_PLAYER_NOT_FOUND_S:format(full) then
            return true
        end
    end
    return false
end

frame:SetScript("OnEvent", Utils.Protect("layer", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == PREFIX and channel == "WHISPER" then
            Heard(text, sender)
        end
    elseif event == "PARTY_INVITE_REQUEST" then
        local inviter = ...
        if accept and GetTime() - accept.at < 120 and Utils.IsUsableString(inviter) then
            local first = Names.Split(inviter)
            if first and Names.Same(first, accept.first) then
                -- the invite you asked for
                if type(AcceptGroup) == "function" and pcall(AcceptGroup) and type(StaticPopup_Hide) == "function" then
                    StaticPopup_Hide("PARTY_INVITE")
                end
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if askWaiting then
            local full = askWaiting
            askWaiting = nil
            Layer.ShowAsk(full)
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        Read((...))
    elseif event == "PLAYER_TARGET_CHANGED" then
        Read("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Read("mouseover")
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        mine.layer, mine.map = nil, MyMap()
    end
end))

-- On Forever only: layers and asks need names with surnames.
function Layer.Start()
    if Layer.started or not Names.HaveSurnames() then
        return
    end
    Layer.started = true
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    for _, event in ipairs({ "CHAT_MSG_ADDON", "PARTY_INVITE_REQUEST", "PLAYER_REGEN_ENABLED", "NAME_PLATE_UNIT_ADDED",
        "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "ZONE_CHANGED_NEW_AREA" }) do
        frame:RegisterEvent(event)
    end
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if type(add) == "function" then
        add("CHAT_MSG_SYSTEM", Utils.Protect("layer quiet", HideNotFound))
    end
end

Theme.OnSkin(function()
    askStale = true
    if ask and ask:IsShown() then
        ask:Hide()
    end
end)
