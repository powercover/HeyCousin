local _, HC = ...

-- The family's channel: a hidden chat channel for one surname and one faction, so cousins in any
-- guild can find each other's addons (the other side's addon never joins it). It's how you know who's
-- there: on Forever the game takes addon messages for a channel but doesn't deliver them (tested with
-- two players), so the messages go to each cousin on its list as an addon whisper. Each addon
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
-- (tier last: an older addon reads the fields it knows and lets it go by)
local CREST_FIELDS = { "shape", "division", "field", "second", "metal", "symbol", "charge", "tier" }
-- a cousin's level is news on every fifth one
local NEWS_EVERY = 5
-- who's in the channel: asked this often, and the game's answer comes within this long
local ROSTER_GAP, ROSTER_WAIT = 60, 2
local MEMBERS_MAX = 200
-- the game sends 10 of a prefix in a row, then one a second: a message for everyone goes out a few at a
-- time, and where you are (often, and soon old) to the next few in turn
local PUMP_BURST, PUMP_GAP, PUMP_TRIES, QUEUE_MAX = 3, 1, 10, 300
local SPREAD = 4
-- lines about cousins (online, a new level, a group): this many a minute at most, so a big family
-- doesn't fill your chat
local LINES_MAX, LINES_SPAN = 3, 60
-- "Hey cousin!" rests this long, so a double click isn't two
local HEY_REST = 10
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
local members = {}      -- the cousins in the channel: a list of whole names
local rosterKnown = false
local rosterAsking      -- while the game answers: { [whole name] = true }
local rosterShown = false  -- /cousin check shows the game's answer in chat
local rosterAskedAt = -ROSTER_GAP
local outbox = {}       -- { text, target } waiting to go
local pumping = false
local spreadAt = 0      -- where in the list the next position goes
local heyAt  -- GetTime() of your last "Hey cousin!"
local heard = {}  -- the last lines heard, as the game gave them (/cousin check)
local heardCount = 0
local echoes = {}  -- your own lines coming back, by how they came
local HEARD_KEEP = 8
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

-- In combat, a boss fight or a key, the game blocks an addon's channel calls (joining, leaving, who's
-- in it): they wait until it's over. In a dungeon, raid or battleground they wait too, to be safe: the
-- list from before stays, so family chat still reaches everyone on it.
local function Blocked()
    return Utils.Call(InCombatLockdown) == true or Utils.Call(IsEncounterInProgress) == true
        or Utils.Call(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) == true
        or Utils.Call(IsInInstance) == true
end

local keepLater = false  -- Keep came while blocked: the next tick does it

-- In it while anything of the family's wants it; a full channel list just means no channel.
function Family.Keep()
    if not ready then
        return
    end
    keepLater = Blocked()
    if keepLater then
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
        Family.AskRoster()
    elseif id and not wanted then
        Utils.Call(LeaveChannelByName, name)
        members, rosterKnown = {}, false
    end
end

-- Asks the game who's in the channel; its answer comes as chat lines, kept out of your chat.
function Family.AskRoster(shown)
    local id, name = Family.Channel()
    if not id or rosterAsking or Blocked() then
        return
    end
    rosterAskedAt = GetTime()
    rosterAsking, rosterShown = {}, shown == true
    Utils.Call(ListChannelByName, name)
    Utils.After(ROSTER_WAIT, "family roster", function()
        local gathered = rosterAsking
        rosterAsking, rosterShown = nil, false
        -- (no answer at all: what's known stays)
        if gathered and gathered.answered then
            gathered.answered = nil
            members = {}
            for full in pairs(gathered) do
                members[#members + 1] = full
            end
            rosterKnown = true
        end
    end)
end

-- Someone you heard from is there, whatever the list says.
local function AddMember(full)
    for _, known in ipairs(members) do
        if known == full then
            return
        end
    end
    if #members < MEMBERS_MAX then
        members[#members + 1] = full
    end
end

-- One whisper to a cousin's addon; whether the game took it. The game's "no player named" for someone
-- just gone isn't news to you.
function Family.Whisper(text, full)
    HC.Layer.Quiet(full)
    return HC.Guild.Send(text, "WHISPER", full)
end

-- The waiting messages, a few at a time; one the game holds back goes again a moment later.
local function Pump()
    for _ = 1, PUMP_BURST do
        local item = outbox[1]
        if not item then
            break
        end
        if Family.Whisper(item.text, item.target) then
            table.remove(outbox, 1)
        else
            -- (held back, it goes again; refused every time, it doesn't hold up the rest)
            item.tries = (item.tries or 0) + 1
            if item.tries >= PUMP_TRIES then
                table.remove(outbox, 1)
            end
            break
        end
    end
    if outbox[1] then
        pumping = true
        Utils.After(PUMP_GAP, "family send", Pump)
    else
        pumping = false
    end
end

-- A message to every cousin in the channel; false when it can't go yet (the list isn't known yet: try
-- again in a moment).
function Family.Send(text)
    if not Family.Channel() then
        return false
    end
    if not rosterKnown then
        Family.AskRoster()
        return false
    end
    for _, full in ipairs(members) do
        if #outbox < QUEUE_MAX then
            outbox[#outbox + 1] = { text = text, target = full }
        end
    end
    if not pumping then
        Pump()
    end
    return true
end

-- A message to the next few cousins in turn: where you are, often and soon old.
function Family.Spread(text)
    if not Family.Channel() then
        return false
    end
    if not rosterKnown then
        Family.AskRoster()
        return false
    end
    for _ = 1, math.min(SPREAD, #members) do
        spreadAt = spreadAt % #members + 1
        Family.Whisper(text, members[spreadAt])
    end
    return true
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

-- "Hey cousin Mira!": you wave and say it out loud, for everyone around. Only ever from a click of
-- yours (`unit`: them, when the game can see them; you wave at nobody otherwise).
function Family.Hey(first, unit)
    if HC.TestMode.active then
        Utils.Print(L["Test mode: made-up cousins can't hear you."])
        return
    end
    local now = GetTime()
    if heyAt and now - heyAt < HEY_REST then
        return
    end
    heyAt = now
    Utils.Call(DoEmote, "WAVE", unit or "none")
    Utils.Call((C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage, string.format(L["Hey cousin %s!"], first), "SAY")
    HC.Badges.Earn("hey")
end

-- The game's answer to who's in the channel: "[7. Name] First Surname, *First Surname" in chat. Stays
-- out of your chat unless you asked. A long list comes in several lines.
local function IsRoster(label, base)
    local name = select(2, Family.Channel())
    if not rosterAsking or not name then
        return false
    end
    for _, text in ipairs({ label or "", base or "" }) do
        if type(text) == "string" and not Utils.IsSecret(text) and text:lower():find(name:lower(), 1, true) then
            return true
        end
    end
    return false
end

local function HideRoster(_, _, _, _, _, label, _, _, _, _, base)
    return IsRoster(label, base) and not rosterShown
end

local function ReadRoster(text)
    rosterAsking.answered = true
    for chunk in text:gmatch("[^,]+") do
        -- (* the channel's owner, @ a moderator)
        local member = Family.Cousin((Utils.Trim(chunk):gsub("^[%*@%+#]+", "")))
        if member then
            rosterAsking[member.full] = true
        end
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

-- Your motto, for cousins' addons (M): nothing when you have none. Older addons let it go by.
local MOTTO_MAX = 40
local function MottoLine()
    local house = Kin.House()
    local words = HC.Guild.Plain(house and house.motto, MOTTO_MAX)
    return words ~= "" and ("4:M:" .. words) or nil
end

-- What else goes after your hello: fn(target) sends it, to everyone (no target: Family.Send) or to the
-- cousin whose hello you answer.
local helloHooks = {}
function Family.OnHello(fn)
    helloHooks[#helloHooks + 1] = fn
end

local function AfterHello(target)
    for _, fn in ipairs(helloHooks) do
        local ok, problem = pcall(fn, target)
        if not ok then
            Utils.NoteError("family hello", problem)
        end
    end
end

-- Your motto changed: cousins online hear it now.
function Family.ShareMotto()
    local line = MottoLine()
    if line and Family.On() and Family.Channel() and not HC.TestMode.active then
        Family.Send(line)
    end
end

local function Tick()
    if keepLater then
        Family.Keep()
    end
    if GetTime() - rosterAskedAt >= ROSTER_GAP then
        Family.AskRoster()
    end
    if not Family.On() or not Family.Channel() or Utils.Call(InCombatLockdown) == true then
        return
    end
    local now = GetTime()
    if not greeted then
        if Family.Send(Line("H")) then
            greeted, lastTold, quietUntil, levelled = true, now, now + QUIET, false
            local motto = MottoLine()
            if motto then
                Family.Send(motto)
            end
            AfterHello(nil)
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

-- A cousin's motto (M): kept with them, shown on their page and tooltip.
local function HeardMotto(said, sender)
    local member = Family.Cousin(sender)
    if not member then
        return
    end
    local relative = Kin.Seen({ first = member.first, faction = Utils.Call(UnitFactionGroup, "player"), quiet = true,
        online = true, usesAddon = true })
    if relative then
        local words = HC.Guild.Plain(said, MOTTO_MAX)
        relative.motto = words ~= "" and words or nil
        Kin.Changed()
    end
end

local function Heard(text, sender)
    local said = text:match("^4:M:(.*)$")
    if said then
        HeardMotto(said, sender)
        return
    end
    local kind, class, level, code = text:match("^4:(%u):(%u*):(%d*):?(.*)$")
    if kind ~= "H" and kind ~= "S" and kind ~= "A" and kind ~= "L" then
        return
    end
    local member = Family.Cousin(sender)
    if not member then
        return
    end
    local wasOnline = Kin.IsOnline(member.first) or Kin.IsNear(member.first)
    local house = Kin.House()
    local before = house and house.relatives[member.first] and house.relatives[member.first].level
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
        local mine = Utils.Call(UnitLevel, "player") or 0
        if Family.NewsOn() and relative.level and before and before <= mine and relative.level > mine then
            Family.Tell(string.format(L["%s just passed you in the family race!"], Theme.Paint(member.full, color)))
        elseif Family.NewsOn() and relative.level and relative.level % NEWS_EVERY == 0 then
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
            Family.Whisper(Line("A"), member.full)
            local motto = MottoLine()
            if motto then
                Family.Whisper(motto, member.full)
            end
            AfterHello(member.full)
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
        HC.Badges.Earn("fam")
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
        if prefix == PREFIX and Utils.IsUsableString(text) then
            local talker = channel == "WHISPER" and text:find("^[3456]:") and Family.Cousin(sender)
            if talker then
                AddMember(talker.full)
            end
            if Names.Same((Names.Split(sender)), (Names.Me())) then
                echoes[channel] = (echoes[channel] or 0) + 1
            else
                heardCount = heardCount + 1
                table.insert(heard, 1, { text = text:sub(1, 12), channel = channel, sender = sender, localID = localID,
                    channelName = channelName, at = GetTime() })
                heard[HEARD_KEEP + 1] = nil
            end
        end
        if prefix ~= PREFIX or not Utils.IsUsableString(text) or not text:find("^[456]:") then
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
        elseif mine and text:find("^6:") then
            -- (playing together: Share.lua, who has it, calls for help)
            if Family.Messages() then
                HC.Share.Heard(text, sender)
            end
        elseif mine then
            HeardWords(text, sender)
        end
    elseif event == "CHAT_MSG_CHANNEL_LIST" then
        local text, _, _, label, _, _, _, _, base = ...
        if Utils.IsUsableString(text) and IsRoster(label, base) then
            ReadRoster(text)
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

-- /cousin check: what goes out and what comes in, as the game gives it, to find why two cousins don't
-- see each other. It sends one word now, and asks the game who's in the channel. English only: it's for
-- reading out when something is wrong.
function Family.Check()
    local first, surname = Names.Me()
    local id, name = Family.Channel()
    Utils.Print("Check: you are " .. tostring(first) .. " " .. tostring(surname) .. ", "
        .. tostring(Utils.Call(UnitFactionGroup, "player")) .. ", on " .. tostring(Utils.Call(function()
            return UnitGUID("player")
        end)))
    Utils.Print("Check: family channel " .. tostring(name) .. ": " .. (id and ("in it, number " .. id) or "NOT in it")
        .. (ready and "" or " (still waiting after login)"))
    Utils.Print("Check: sharing where you are: " .. tostring(HeyCousinDB.mapShare == true)
        .. ", your family on the map: " .. tostring(HeyCousinDB.mapShow ~= false)
        .. ", family messages: " .. tostring(Family.Messages()))
    local spoken = id and Family.Send(Line("S"))
    Utils.Print("Check: a word sent just now: " .. tostring(spoken))
    local log = HC.Guild.sentLog
    Utils.Print("Check: sent " .. log.count .. " in all. Last: " .. tostring(log.text and log.text:sub(1, 12)) .. " on "
        .. tostring(log.channel) .. " " .. tostring(log.target) .. ", call ok " .. tostring(log.ok) .. ", game's answer "
        .. tostring(log.result))
    Utils.Print("Check: cousins it sends to: " .. #members .. (rosterKnown and "" or " (list not known yet)") .. ": "
        .. table.concat(members, ", ") .. ". Time since login: " .. math.floor(GetTime() - (Family.startedAt or GetTime())) .. "s")
    Utils.Print("Check: heard " .. heardCount .. " from others." .. (heardCount > 0 and " Newest first:" or ""))
    local now = GetTime()
    for _, line in ipairs(heard) do
        local cousin = Family.Cousin(line.sender)
        Utils.Print(string.format("  %ds ago: %s, %s, from [%s], channel %s %s, cousin: %s", math.floor(now - line.at), line.text,
            tostring(line.channel), tostring(line.sender), tostring(line.localID), tostring(line.channelName),
            cousin and "yes" or "no"))
    end
    if id then
        Utils.Print("Check: who's in the channel, from the game:")
        Family.AskRoster(true)
        -- (already asking: it shows what comes)
        rosterShown = rosterAsking ~= nil
    end
end

-- On Forever only: surnames are what it's for.
function Family.Start()
    if Family.started or not Names.HaveSurnames() then
        return
    end
    Family.started = true
    Family.startedAt = GetTime()
    for _, event in ipairs({ "CHAT_MSG_ADDON", "CHAT_MSG_CHANNEL_LIST", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP" }) do
        frame:RegisterEvent(event)
    end
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if type(add) == "function" then
        local filter = Utils.Protect("family channel", HideNotice)
        local rosterFilter = Utils.Protect("family roster", HideRoster)
        for event, fn in pairs({ CHAT_MSG_CHANNEL_NOTICE = filter, CHAT_MSG_CHANNEL_NOTICE_USER = filter,
            CHAT_MSG_CHANNEL_LIST = rosterFilter }) do
            -- through securecall, as the chat crests are
            if type(securecall) == "function" then
                securecall(add, event, fn)
            else
                add(event, fn)
            end
        end
    end
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(TICK, Utils.Protect("family tick", Tick))
    end
end
