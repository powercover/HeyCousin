local _, HC = ...

-- The family's channel: a hidden chat channel for one surname and one faction, so cousins in any
-- guild can reach each other's addons (the other side's addon never joins it). Over it each addon
-- says hello when you log in, with your class, level and crest, and a word now and then while you
-- play: nothing the game's /who doesn't already show, but that you run Hey Cousin!. So your cousins'
-- addons know who uses it, who's online without a click, and what their crests look like. The family's
-- news (a cousin's round levels) and chat (/fam) go the same way.
HC.Family = {}

local Family = HC.Family
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L

local PREFIX = "HeyCousin"
-- the channel waits this long after you log in, so the game's own channels keep /1, /2...
local JOIN_WAIT = 15
local TICK = 5
-- a word this often while you play: a cousin counts as online for a little longer (Kin.lua)
local STILL_GAP = 4 * 60
-- answers to a hello come spread over this many seconds, once a minute per cousin
local ANSWER_WITHIN, ANSWER_GAP = 6, 60
-- the answers right after your own hello are one line in chat, not one each
local QUIET = 30
local CREST_FIELDS = { "shape", "division", "field", "second", "metal", "symbol", "charge" }
-- a cousin's level is news on every fifth one
local NEWS_EVERY = 5
-- lines about cousins (online, a new level, a group): this many a minute at most, so a big family
-- doesn't fill your chat
local LINES_MAX, LINES_SPAN = 3, 60
-- family chat: this many letters at most (it has to fit an addon message), and one line a moment
local WORDS_MAX = 50
local WORDS_GAP = 0.5

local frame = CreateFrame("Frame")
local ready = false  -- the wait after you log in is over
local greeted = false
local lastTold = 0
local quietUntil = 0
local answered = {}  -- [full name] = GetTime() of the last answer to their hello
local levelled = false  -- you've levelled up: it goes with the next tick
local linesFrom, linesCount = 0, 0
local spoke = {}  -- [first name] = GetTime() of their last line in family chat

-- --- the channel -------------------------------------------------------------------------------

-- The one switch for all the family's messages, both ways: off, nothing below goes or shows. The map
-- isn't a message: it has its own switches.
function Family.Messages()
    return HeyCousinDB.familyMessages ~= false
end

-- Whether you tell cousins you're online, and hear when they are (a setting, on unless you say).
function Family.On()
    return Family.Messages() and HeyCousinDB.presence ~= false
end

-- Whether you see a cousin's round levels (a setting, on unless you say).
function Family.NewsOn()
    return Family.Messages() and HeyCousinDB.familyNews ~= false
end

-- Whether you're in family chat (a setting, on unless you say).
function Family.ChatOn()
    return Family.Messages() and HeyCousinDB.familyChat ~= false
end

-- Whether a line tells you a cousin looks for a group (a setting, on unless you say).
function Family.GroupsOn()
    return Family.Messages() and HeyCousinDB.familyGroups ~= false
end

local function ChannelName()
    local _, surname = Names.Me()
    local faction = Utils.Call(UnitFactionGroup, "player")
    if not Utils.IsUsableString(surname) or (faction ~= "Horde" and faction ~= "Alliance") then
        return nil
    end
    return "HC" .. surname:lower() .. faction:sub(1, 1)
end

-- The channel's number once you're in it, and its name.
function Family.Channel()
    local name = ChannelName()
    local id = name and Utils.Call(GetChannelName, name)
    return Utils.IsUsableNumber(id) and id > 0 and id or nil, name
end

-- In it while anything of the family's wants it; a full channel list just means no channel.
function Family.Keep()
    if not ready then
        return
    end
    local id, name = Family.Channel()
    if not name then
        return
    end
    local wanted = Family.On() or Family.NewsOn() or Family.ChatOn() or Family.GroupsOn()
        or HeyCousinDB.mapShow ~= false or HeyCousinDB.mapShare == true
    if wanted and not id then
        Utils.Call(JoinTemporaryChannel, name)
    elseif id and not wanted then
        Utils.Call(LeaveChannelByName, name)
    end
end

-- A message to every cousin in the channel; whether it went.
function Family.Send(text)
    local id = Family.Channel()
    return id ~= nil and HC.Guild.Send(text, "CHANNEL", id)
end

-- Who a line on the channel is from: a cousin with your surname, not you, nobody else, and nobody
-- you've put on the game's ignore list.
function Family.Cousin(sender)
    local first, surname = Names.Split(sender)
    local me, mine = Names.Me()
    if not first or not Names.Same(surname, mine) or Names.Same(first, me) then
        return nil
    end
    local full = Names.Full(first, surname)
    if Utils.Call(C_FriendList and C_FriendList.IsIgnored, full) == true then
        return nil
    end
    return { first = first, surname = surname, full = full }
end

-- A line about a cousin, if this minute has room for it.
function Family.Tell(text)
    local now = GetTime()
    if now - linesFrom >= LINES_SPAN then
        linesFrom, linesCount = now, 0
    end
    if linesCount < LINES_MAX then
        linesCount = linesCount + 1
        Utils.Print(text)
    end
end

-- The channel's "joined" and "left" lines stay out of your chat.
local function HideNotice(_, _, _, _, _, shown, _, _, _, _, base)
    local name = ChannelName()
    if not name then
        return false
    end
    for _, text in ipairs({ shown or "", base or "" }) do
        if Utils.IsUsableString(text) and text:lower():find(name:lower(), 1, true) then
            return true
        end
    end
    return false
end

-- --- saying hello ------------------------------------------------------------------------------

local function CrestCode(crest)
    local fields = {}
    for index, key in ipairs(CREST_FIELDS) do
        fields[index] = crest[key] or ""
    end
    return table.concat(fields, ".")
end

-- A crest from a message, made safe (Crest.Normalize keeps only what exists); nothing without one.
local function CrestFrom(code)
    if not Utils.IsUsableString(code) then
        return nil
    end
    local crest, index = {}, 0
    for value in (code .. "."):gmatch("([^.]*)%.") do
        index = index + 1
        if CREST_FIELDS[index] and value ~= "" then
            crest[CREST_FIELDS[index]] = value
        end
    end
    return crest.shape and Crest.Normalize(crest) or nil
end

-- About you: H (hello), S (still here), A (an answer to a hello) or L (a new level), your class,
-- level and crest.
local function Line(kind)
    local _, class = Utils.Call(UnitClass, "player")
    return string.format("4:%s:%s:%d:%s", kind, Utils.IsUsableString(class) and class or "",
        Utils.Call(UnitLevel, "player") or 0, CrestCode(Kin.Crest()))
end

local function Tick()
    if not Family.On() or not Family.Channel() or Utils.Call(InCombatLockdown) == true then
        return
    end
    local now = GetTime()
    if not greeted then
        if Family.Send(Line("H")) then
            greeted, lastTold, quietUntil, levelled = true, now, now + QUIET, false
            Family.quietCount = 0
            Utils.After(QUIET, "family hello", function()
                if (Family.quietCount or 0) > 0 and Family.On() then
                    Utils.Print(string.format(L["Family online now: %d"], Family.quietCount))
                end
            end)
        end
    elseif levelled then
        if Family.Send(Line("L")) then
            levelled, lastTold = false, now
        end
    elseif now - lastTold >= STILL_GAP and Family.Send(Line("S")) then
        lastTold = now
    end
end

-- --- hearing it --------------------------------------------------------------------------------

local function Heard(text, sender)
    local kind, class, level, code = text:match("^4:(%u):(%u*):(%d*):?(.*)$")
    if kind ~= "H" and kind ~= "S" and kind ~= "A" and kind ~= "L" then
        return
    end
    local member = Family.Cousin(sender)
    if not member then
        return
    end
    local wasOnline = Kin.IsOnline(member.first) or Kin.IsNear(member.first)
    class = class ~= "" and class or nil
    local relative = Kin.Seen({
        first = member.first, class = class, level = tonumber(level), faction = Utils.Call(UnitFactionGroup, "player"),
        quiet = true, online = true, usesAddon = true, crest = CrestFrom(code),
    })
    -- (one of your own characters on another account's login, say: nothing to tell)
    if not relative then
        return
    end
    if kind == "L" then
        local color = Utils.ClassColor(relative.class, true)
        if Family.NewsOn() and relative.level and relative.level % NEWS_EVERY == 0 then
            Family.Tell(string.format(L["%s reached level %d!"], Theme.Paint(member.full, color), relative.level))
        end
        return
    end
    if not Family.On() then
        return
    end
    local now = GetTime()
    if not wasOnline then
        if now < quietUntil then
            Family.quietCount = (Family.quietCount or 0) + 1
        else
            local color = Utils.ClassColor(relative.class, true)
            Family.Tell(string.format(L["%s is online."], Theme.Paint(member.full, color)))
        end
    end
    -- they've just come: tell them you're here, by yourself, a moment later
    if kind == "H" and (not answered[member.full] or now - answered[member.full] >= ANSWER_GAP) then
        answered[member.full] = now
        Utils.After(math.random(1, ANSWER_WITHIN), "family answer", function()
            HC.Guild.Send(Line("A"), "WHISPER", member.full)
            HC.Groups.Greet(member.full)
        end)
    end
end

-- --- family chat -------------------------------------------------------------------------------

-- A line in family chat. The name is theirs alone: everyone here shares the surname.
local function ChatLine(first, class, words)
    local name = Theme.Paint(first, Utils.ClassColor(class, true))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("[%s] %s: %s", L["Family"], name, words), 0.55, 0.9, 0.6)
end

-- Your words to every cousin online who has the addon (/fam).
function Family.Say(text)
    local words = HC.Guild.Plain(text, WORDS_MAX)
    if words == "" then
        Utils.Print("/fam ... - " .. L["talk to every cousin online who has the addon"])
    elseif not Family.ChatOn() then
        Utils.Print(L["Family chat is off. It's in the settings, under Family."])
    elseif HC.TestMode.active then
        Utils.Print(L["Test mode: made-up cousins can't hear you."])
    elseif Family.Send("5:C:" .. words) then
        local _, class = Utils.Call(UnitClass, "player")
        ChatLine(Names.Me(), class, words)
    else
        Utils.Print(L["The family's channel isn't ready yet. Try again in a moment."])
    end
end

-- A cousin's words: no codes get through (a link, a picture), and no flood. Lines about groups go to
-- Groups.lua.
local function HeardWords(text, sender)
    local member = Family.Cousin(sender)
    local kind, rest = text:match("^5:(%u):?(.*)$")
    if not member or not kind then
        return
    elseif kind ~= "C" then
        HC.Groups.Heard(kind, rest, member)
        return
    elseif not Family.ChatOn() then
        return
    end
    local words = HC.Guild.Plain(rest, WORDS_MAX)
    local now = GetTime()
    if words == "" or (spoke[member.first] and now - spoke[member.first] < WORDS_GAP) then
        return
    end
    spoke[member.first] = now
    local relative = Kin.Seen({ first = member.first, faction = Utils.Call(UnitFactionGroup, "player"), quiet = true,
        online = true, usesAddon = true })
    ChatLine(member.first, relative and relative.class, words)
end

frame:SetScript("OnEvent", Utils.Protect("family", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender, _, _, localID, channelName = ...
        if prefix ~= PREFIX or not Utils.IsUsableString(text) or not text:find("^[45]:") then
            return
        end
        local mine = channel == "WHISPER"
        if channel == "CHANNEL" then
            -- only your family's channel
            local id, name = Family.Channel()
            mine = name and ((id and localID == id) or channelName == name)
        end
        if mine and text:find("^4:") then
            Heard(text, sender)
        elseif mine then
            HeardWords(text, sender)
        end
    elseif event == "PLAYER_LEVEL_UP" then
        levelled = true
    elseif not ready and not frame.joining then
        -- the first time in the world
        frame.joining = true
        Utils.After(JOIN_WAIT, "family channel", function()
            ready = true
            Family.Keep()
        end)
    end
end))

-- On Forever only: surnames are what it's for.
function Family.Start()
    if Family.started or not Names.HaveSurnames() then
        return
    end
    Family.started = true
    for _, event in ipairs({ "CHAT_MSG_ADDON", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP" }) do
        frame:RegisterEvent(event)
    end
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if type(add) == "function" then
        local filter = Utils.Protect("family channel", HideNotice)
        for _, event in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER" }) do
            -- through securecall, as the chat crests are
            if type(securecall) == "function" then
                securecall(add, event, filter)
            else
                add(event, filter)
            end
        end
    end
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(TICK, Utils.Protect("family tick", Tick))
    end
end
