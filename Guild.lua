local _, HC = ...

-- Your guild as a family: its members by rank, as a family tree (the window's Tree tab). A guild
-- where most members share one surname is a family by itself. Its guild master can give the
-- family a name, a word for each rank (Elder, Parent, Cousin, or their own) and a welcome line in
-- the settings: their addon shares them with every member's in guild addon messages, and the
-- family's crest is the guild master's.
HC.Guild = {}

local Guild = HC.Guild
local Utils = HC.Utils
local Names = HC.Names
local Crest = HC.Crest
local Kin = HC.Kin
local L = HC.L

local PREFIX = "HeyCousin"
-- the guild's ranks (the game has 10 at most)
local RANKS = 10
-- the family's settings, this many bytes in a message (a message takes 255 with its header)
local CHUNK = 200
-- the guild master's addon shares a burst of changes once, this long after; it answers hellos
-- once a minute at most; a part the game held back goes again this long after
local SHARE_WAIT, ANSWER_GAP, RETRY = 5, 60, 2
-- an open tree asks the game for the roster again this often (the game allows one in 10 seconds)
local ASK_GAP = 15
-- the longest family name, word for a rank and welcome line, in letters
Guild.NAME_MAX, Guild.WORD_MAX, Guild.WELCOME_MAX = 24, 20, 100

local frame = CreateFrame("Frame")
local members, byName, dirty = {}, {}, true
local asked, answered = -ASK_GAP, -ANSWER_GAP
local greeted       -- the guild your addon said hello to this session
local incoming = {} -- [sender] = { stamp, count, parts, have }: settings arriving in parts
local queue, pumping = {}, false -- the guild master's parts waiting to go
local testFamily    -- test mode: the made-up guild's family, never saved

-- (tier last: an older addon reads the fields it knows and lets it go by)
local CREST_FIELDS = { "shape", "division", "field", "second", "metal", "symbol", "charge", "tier" }

-- --- your guild --------------------------------------------------------------------------------

-- Your guild's name and your rank in it (0: you lead it); nothing outside a guild.
function Guild.Mine()
    if HC.TestMode.active then
        return HC.TestMode.GUILD, 0
    end
    if Utils.Call(IsInGuild) ~= true then
        return nil
    end
    local name, _, rank = Utils.Call(GetGuildInfo, "player")
    if not Utils.IsUsableString(name) then
        return nil
    end
    return name, Utils.IsUsableNumber(rank) and rank or nil
end

-- Whether you lead your guild (in test mode, the made-up guild is yours).
function Guild.Leads()
    if HC.TestMode.active then
        return true
    end
    return Guild.Mine() ~= nil and Utils.Call(IsGuildLeader) == true
end

-- Your guild's own names for its ranks, the guild master's first.
function Guild.Ranks()
    if HC.TestMode.active then
        return HC.TestMode.GuildRanks()
    end
    local ranks = {}
    local count = Utils.Call(GuildControlGetNumRanks)
    for index = 1, Utils.IsUsableNumber(count) and math.min(count, RANKS) or 0 do
        local name = Utils.Call(GuildControlGetRankName, index)
        ranks[index] = Utils.IsUsableString(name) and name or string.format(L["Rank %d"], index)
    end
    return ranks
end

-- The word for a rank (0: the guild master) until the guild master gives one: they're the Elder,
-- the next rank the Parents, everyone else a Cousin.
function Guild.DefaultWord(rank)
    if rank == 0 then
        return L["Elder"]
    elseif rank == 1 then
        return L["Parent"]
    end
    return L["Cousin"]
end

-- A true that's safe to read (a secret is never compared).
local function Flag(value)
    return not Utils.IsSecret(value) and value == true
end

local function Read()
    local list = {}
    if Utils.Call(IsInGuild) ~= true or type(GetGuildRosterInfo) ~= "function" then
        return list
    end
    local me, mine = Names.Me()
    local now = time()
    local count = Utils.Call(GetNumGuildMembers)
    for i = 1, Utils.IsUsableNumber(count) and count or 0 do
        local full, rankName, rank, level, _, zone, _, _, online, _, class, _, _, _, _, _, guid =
            Utils.Call(GetGuildRosterInfo, i)
        if Utils.IsUsableString(full) and Utils.IsUsableNumber(rank) then
            local first, surname = Names.Split(full)
            local member = {
                full = full, first = first, surname = surname, rank = rank, online = Flag(online),
                rankName = Utils.IsUsableString(rankName) and rankName or nil,
                level = Utils.IsUsableNumber(level) and level > 0 and level or nil,
                class = Utils.IsUsableString(class) and class or nil,
                guid = Utils.IsUsableString(guid) and guid or nil,
            }
            member.zone = member.online and Utils.IsUsableString(zone) and zone or nil
            if not member.online and type(GetGuildRosterLastOnline) == "function" then
                local years, months, days, hours = Utils.Call(GetGuildRosterLastOnline, i)
                if Utils.IsUsableNumber(years) then
                    local ago = ((years * 12 + (months or 0)) * 30 + (days or 0)) * 24 + (hours or 0)
                    member.seen = now - ago * 3600
                end
            end
            member.me = Names.Same(first, me) and (surname == nil or Names.Same(surname, mine))
            list[#list + 1] = member
        end
    end
    return list
end

-- A member's key by their names: the same letters, big or small (as Names.Same).
local function Key(first, surname)
    return first:lower() .. "\1" .. surname:lower()
end

-- Your guild's members, each: full, first, surname, rank (0: the guild master), rankName, level,
-- class, zone, online, seen (when they were last online), guid, me (you). Read again after the
-- game's roster changes.
function Guild.Members()
    if HC.TestMode.active then
        return HC.TestMode.Guild()
    end
    if dirty then
        dirty = false
        members, byName = Read(), {}
        for _, member in ipairs(members) do
            if member.first and member.surname then
                byName[Key(member.first, member.surname)] = member
            end
        end
    end
    return members
end

-- An open tree asks the game for the roster now and then: members come online and move on.
function Guild.Ask()
    if HC.TestMode.active or GetTime() - asked < ASK_GAP then
        return
    end
    asked = GetTime()
    if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
        pcall(C_GuildInfo.GuildRoster)
    elseif type(GuildRoster) == "function" then
        pcall(GuildRoster)
    end
end

-- --- the family --------------------------------------------------------------------------------

-- Text from the guild master (a message, a saved file) as it should be: one line, no codes in it.
-- (Only the control codes below 32: Lua's %c can take bytes of letters beyond A-Z, as Cyrillic's.)
local function Plain(text, most)
    if type(text) ~= "string" or Utils.IsSecret(text) then
        return ""
    end
    return Utils.Short(Utils.Trim((text:gsub("[\1-\31\127|]", ""))), most * 4)
end

-- A family's settings as they should be: a broken saved file or message loses only what's wrong
-- in it. `words`: one a rank, "" for its default; `off`: the guild master made it no family.
local function Clean(given)
    if type(given) ~= "table" or not Utils.IsUsableNumber(given.stamp) then
        return nil
    end
    local family = { stamp = given.stamp, words = {}, welcomed = given.welcomed == true, off = given.off == true }
    local surname = Plain(given.surname, Guild.NAME_MAX)
    family.surname = surname ~= "" and surname or nil
    family.welcome = HC.Words.Clean(Plain(given.welcome, Guild.WELCOME_MAX))
    family.crest = type(given.crest) == "table" and Crest.Normalize(given.crest) or nil
    for index = 1, RANKS do
        family.words[index] = Plain(type(given.words) == "table" and given.words[index], Guild.WORD_MAX)
    end
    return family
end

local function Saved(guild)
    if type(HeyCousinDB.guilds) ~= "table" then
        HeyCousinDB.guilds = {}
    end
    return HeyCousinDB.guilds[guild]
end

-- The family the guild master gave: theirs (or the made-up guild's in test mode), as saved.
local function Given(guild)
    if HC.TestMode.active then
        testFamily = testFamily or Clean(HC.TestMode.GuildFamily())
        return testFamily
    end
    return Clean(Saved(guild))
end

-- The surname most of the guild shares, when half or more of it do (three at least).
local function Shared(list)
    local counts, best, most = {}, nil, 0
    for _, member in ipairs(list) do
        if member.surname then
            local key = member.surname:lower()
            counts[key] = (counts[key] or 0) + 1
            if counts[key] > most then
                best, most = member.surname, counts[key]
            end
        end
    end
    if most >= 3 and most * 2 >= #list then
        return best
    end
end

-- Your guild's family: guild (its name), surname (nil: not a family), crest (the guild master's;
-- nil: yours), words (one a rank, defaults filled in), welcome, given (by the guild master) and
-- stamp. Nothing outside a guild.
function Guild.Family()
    local guild = Guild.Mine()
    if not guild then
        return nil
    end
    local saved = Given(guild)
    local given = saved and not saved.off and saved or nil
    -- a guild that shares a surname is a family by itself, until its guild master says
    local surname = given and given.surname or not saved and Shared(Guild.Members()) or nil
    local family = {
        guild = guild, surname = surname, welcome = given and given.welcome or "",
        given = given ~= nil, stamp = saved and saved.stamp or 0, words = {},
        -- yours is the family's when you lead it
        crest = Guild.Leads() and given and Kin.Crest() or given and given.crest or nil,
    }
    for index = 1, RANKS do
        local word = given and given.words[index]
        family.words[index] = Utils.IsUsableString(word) and word or Guild.DefaultWord(index - 1)
    end
    return family
end

-- A draft of the family, as the setup edits it: on (it's a family), surname, words (one a rank,
-- "" for the default) and welcome.
local function ToDraft(given)
    local draft = { on = given ~= nil and not given.off, surname = given and given.surname or "", words = {},
        welcome = given and given.welcome or "" }
    for index = 1, RANKS do
        draft.words[index] = given and given.words[index] or ""
    end
    return draft
end

-- The family as the guild master gave it, as a draft; before they gave it, as the guild is by
-- itself (the surname filled in).
function Guild.Draft()
    local guild = Guild.Mine()
    local saved = guild and Given(guild)
    local draft = ToDraft(saved)
    local family = guild and Guild.Family()
    if not saved then
        draft.on = family ~= nil and family.surname ~= nil
    end
    if draft.surname == "" then
        local _, mine = Names.Me()
        draft.surname = family and family.surname or mine or ""
    end
    return draft
end

-- A word for rank `index` (1: the guild master's) as it's kept: "" when it's the default.
local function Kept(word, index)
    word = Utils.Trim(word)
    return word == Guild.DefaultWord(index - 1) and "" or word
end

local function Order(a, b)
    if a.online ~= b.online then
        return a.online
    end
    if a.rank ~= b.rank then
        return a.rank < b.rank
    end
    if (a.level or 0) ~= (b.level or 0) then
        return (a.level or 0) > (b.level or 0)
    end
    return a.full < b.full
end

-- The family tree: its generations, the top first, each { word =, rank =, members = }. Ranks
-- with one word are one generation. A family guild shows everyone in it (in-laws too); another
-- guild only you and those who share your surname. Returns the family too.
function Guild.Tree()
    local family = Guild.Family()
    if not family then
        return {}, nil
    end
    local _, mine = Names.Me()
    local generations, byWord = {}, {}
    for _, member in ipairs(Guild.Members()) do
        if family.surname or member.me or Names.Same(member.surname, mine) then
            local word = family.words[member.rank + 1] or Guild.DefaultWord(member.rank)
            local generation = byWord[word]
            if not generation then
                generation = { word = word, rank = member.rank, members = {} }
                byWord[word] = generation
                generations[#generations + 1] = generation
            end
            generation.rank = math.min(generation.rank, member.rank)
            table.insert(generation.members, member)
        end
    end
    table.sort(generations, function(a, b)
        return a.rank < b.rank
    end)
    for _, generation in ipairs(generations) do
        table.sort(generation.members, Order)
    end
    return generations, family
end

-- --- messages ----------------------------------------------------------------------------------

-- What went out, for /cousin check: how many, and the last with the game's answer to it.
Guild.sentLog = { count = 0 }

-- A message to your guild's addons; false when the game held it back or refused it, to send again.
local function Send(text, channel, target)
    if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then
        return true
    end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, channel or "GUILD", target)
    local log = Guild.sentLog
    log.count = log.count + 1
    log.text, log.channel, log.target, log.ok, log.result = text, channel or "GUILD", target, ok, result
    if not ok then
        return false
    end
    -- (a client that answers with a code: anything but success didn't go; true or nothing: it did)
    local results = Enum and Enum.SendAddonMessageResult
    if results ~= nil and results.Success ~= nil and Utils.IsUsableNumber(result) then
        return result == results.Success
    end
    return result ~= false
end

-- The family's parts waiting to go, in turn: one the game holds back goes again a moment later.
local function Pump()
    pumping = false
    while queue[1] do
        if not Send(queue[1]) then
            pumping = true
            Utils.After(RETRY, "guild send", Pump)
            return
        end
        table.remove(queue, 1)
    end
end

-- A field in a message: its separators and "%" written as %XX.
local function Escape(text)
    return (text:gsub("[%%~^:]", function(letter)
        return string.format("%%%02X", letter:byte())
    end))
end

local function Unescape(text)
    return (text:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function CrestCode(crest)
    local fields = {}
    for index, key in ipairs(CREST_FIELDS) do
        fields[index] = crest and crest[key] or ""
    end
    return table.concat(fields, ".")
end

-- The family's settings in one line: the format, the surname, the crest, the words, the welcome,
-- and "o" when the guild master made it no family.
local function Pack(given)
    local words = {}
    for index = 1, RANKS do
        words[index] = Escape(given.words[index] or "")
    end
    return table.concat({ "1", Escape(given.surname or ""), CrestCode(given.crest), table.concat(words, "^"),
        Escape(given.welcome or ""), given.off and "o" or "" }, "~")
end

local function Unpack(text, stamp)
    local parts = {}
    for part in (text .. "~"):gmatch("([^~]*)~") do
        parts[#parts + 1] = part
    end
    if parts[1] ~= "1" or #parts < 5 then
        return nil
    end
    local family = { stamp = stamp, surname = Unescape(parts[2]), welcome = Unescape(parts[5]), words = {},
        off = parts[6] == "o" }
    local crest, index = {}, 0
    for value in (parts[3] .. "."):gmatch("([^.]*)%.") do
        index = index + 1
        if CREST_FIELDS[index] and value ~= "" then
            crest[CREST_FIELDS[index]] = value
        end
    end
    family.crest = crest.shape and crest or nil
    index = 0
    for word in (parts[4] .. "^"):gmatch("([^^]*)%^") do
        index = index + 1
        family.words[index] = Unescape(word)
    end
    return Clean(family)
end

-- `text` in parts of CHUNK bytes at most, never cut through a letter (UTF-8).
local function Parts(text)
    local parts, at = {}, 1
    while at <= #text do
        local stop = math.min(#text, at + CHUNK - 1)
        while stop < #text and stop > at and text:byte(stop + 1) >= 128 and text:byte(stop + 1) < 192 do
            stop = stop - 1
        end
        parts[#parts + 1] = text:sub(at, stop)
        at = stop + 1
    end
    return parts
end

-- The guild master's addon tells every member's the family's settings (in place of the parts of
-- an older share still waiting).
local function Share()
    local guild = Guild.Mine()
    local given = guild and not HC.TestMode.active and Guild.Leads() and Given(guild)
    if not given then
        return
    end
    local parts = Parts(Pack(given))
    queue = {}
    for index, part in ipairs(parts) do
        queue[index] = string.format("2:F:%d:%d:%d:%s", given.stamp, index, #parts, part)
    end
    if not pumping then
        Pump()
    end
end

local shareSoon = Utils.Debounce(SHARE_WAIT, "guild share", Share)

-- Once a session (and again in a new guild), your addon says which settings it has: the guild
-- master's answers when it has newer ones. The guild master's own tells the members online.
local function Hello()
    local guild = Guild.Mine()
    if not guild or greeted == guild or #Guild.Members() == 0 then
        return
    end
    greeted = guild
    local given = Given(guild)
    if Guild.Leads() then
        if given then
            shareSoon()
        end
        return
    end
    Send("2:H:" .. string.format("%d", given and given.stamp or 0))
end

-- The member of your guild who sent an addon message (Guild.Members's): their first name and
-- surname both match the roster's.
local function Sender(sender)
    local first, surname = Names.Split(sender)
    if not Utils.IsUsableString(first) or not Utils.IsUsableString(surname) then
        return nil
    end
    Guild.Members()
    return byName[Key(first, surname)]
end

-- (the family map's messages go the same way, from the same members)
Guild.Send, Guild.Sender, Guild.Plain = Send, Sender, Plain

-- A member's first settings from their guild master: the family greets them.
local function Welcome(family)
    Utils.Print(family.surname and string.format(L["Welcome to the %s family!"], family.surname)
        or L["Welcome to the family!"])
    if family.welcome ~= "" then
        Utils.Print("\226\128\156" .. family.welcome .. "\226\128\157")
    end
end

-- Settings from the guild master's addon, kept when they're newer than yours.
local function Take(family)
    local guild = Guild.Mine()
    if not family or not guild or Guild.Leads() then
        return
    end
    local saved = Clean(Saved(guild))
    if saved and saved.stamp >= family.stamp then
        return
    end
    family.welcomed = saved ~= nil and saved.welcomed
    HeyCousinDB.guilds[guild] = family
    -- the first family from your guild master greets you (a guild made no family doesn't)
    if not family.welcomed and not family.off then
        family.welcomed = true
        Welcome(family)
    end
    Kin.Changed()
end

local function Heard(text, sender)
    if not Utils.IsUsableString(text) or not Utils.IsUsableString(sender) then
        return
    end
    local kind, rest = text:match("^2:(%a):(.*)$")
    -- only your guild's members (and not your own, coming back)
    local member = kind and Sender(sender)
    if not member or member.me then
        return
    end
    if kind == "H" then
        local stamp = tonumber(rest)
        local guild = Guild.Mine()
        local given = guild and Guild.Leads() and Given(guild)
        -- one answer a minute at most, whoever asks
        if stamp and given and stamp < given.stamp and GetTime() - answered >= ANSWER_GAP then
            answered = GetTime()
            shareSoon()
        end
    elseif kind == "F" then
        local stamp, index, count, part = rest:match("^(%d+):(%d+):(%d+):(.*)$")
        stamp, index, count = tonumber(stamp), tonumber(index), tonumber(count)
        if not stamp or index < 1 or index > count or count > 20 or member.rank ~= 0 then
            return
        end
        local entry = incoming[sender]
        if not entry or entry.stamp ~= stamp or entry.count ~= count then
            entry = { stamp = stamp, count = count, parts = {}, have = 0 }
            incoming[sender] = entry
        end
        if not entry.parts[index] then
            entry.parts[index], entry.have = part, entry.have + 1
        end
        if entry.have == count then
            incoming[sender] = nil
            Take(Unpack(table.concat(entry.parts), stamp))
        end
    end
end

-- --- the guild master's ------------------------------------------------------------------------

-- The guild master gives the family its settings (a draft: Guild.Draft's): saved, and shared
-- with every member's addon.
function Guild.SetFamily(draft)
    local guild = Guild.Mine()
    if not guild or not Guild.Leads() then
        return
    end
    local old = Given(guild)
    local words = {}
    for index = 1, RANKS do
        words[index] = Kept(draft.words[index], index)
    end
    -- a family always has a name: the one most of the guild shares, else yours
    local surname = Utils.Trim(draft.surname)
    if surname == "" then
        local _, mine = Names.Me()
        surname = Shared(Guild.Members()) or mine
    end
    local family = Clean({
        stamp = math.max(time(), old and old.stamp + 1 or 0), surname = surname, words = words,
        welcome = draft.welcome, crest = Kin.Crest(), welcomed = true, off = not draft.on,
    })
    if HC.TestMode.active then
        testFamily = family
    else
        Saved(guild)
        HeyCousinDB.guilds[guild] = family
        shareSoon()
    end
    Kin.Changed()
end

-- Whether two drafts give the same family.
function Guild.Equal(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    if a.on ~= b.on or Utils.Trim(a.surname) ~= Utils.Trim(b.surname) or Utils.Trim(a.welcome) ~= Utils.Trim(b.welcome) then
        return false
    end
    for index = 1, RANKS do
        if Kept(a.words[index], index) ~= Kept(b.words[index], index) then
            return false
        end
    end
    return true
end

-- The guild master's crest is the family's: a new one goes to the members, once the changes stop.
local shareCrest = Utils.Debounce(SHARE_WAIT, "guild crest", function()
    local guild = Guild.Mine()
    local given = guild and Guild.Leads() and Given(guild)
    if given and not given.off and CrestCode(given.crest) ~= CrestCode(Kin.Crest()) then
        Guild.SetFamily(ToDraft(given))
    end
end)

function Guild.CrestChanged()
    if Guild.Leads() then
        shareCrest()
    end
end

-- --- events ------------------------------------------------------------------------------------

frame:SetScript("OnEvent", Utils.Protect("guild", function(_, event, ...)
    if event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        dirty = true
        Hello()
        Kin.Changed()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == PREFIX and channel == "GUILD" then
            Heard(text, sender)
        end
    end
end))

-- On Forever only: the family's settings travel between members' addons.
function Guild.Start()
    if Guild.started or not Names.HaveSurnames() then
        return
    end
    Guild.started = true
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    for _, event in ipairs({ "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "CHAT_MSG_ADDON" }) do
        frame:RegisterEvent(event)
    end
end
