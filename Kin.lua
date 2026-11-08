local _, HC = ...

HC.Kin = {}

local Kin = HC.Kin
local Utils = HC.Utils
local Names = HC.Names
local Crest = HC.Crest
local Theme = HC.Theme

-- Two sightings this far apart are two meetings.
local MEETING_GAP = 15 * 60
-- A relative counts as near this long after they were last seen around you.
local NEAR_FOR = 150
-- A relative found by a search counts as online this long after it.
local ONLINE_FOR = 5 * 60
-- The surnames you meet: trimmed to the 200 met most once there are 400. Each counts the players
-- you met with it, each once: up to 150 of them, then it counts no more.
local SURNAMES_KEEP, SURNAMES_MAX = 200, 400
local NAMES_MAX = 150
-- Each relative's meetings: the first one and the latest, this many in all (the count goes on).
local MEETINGS_KEEP = 100
-- what they said, when you met in /say: this long at most
local SAID_MAX = 90

local near = {}    -- [first name] = GetTime() of the last sighting around you (this session)
local online = {}  -- [first name] = GetTime() of the last search that found them (this session)
local counted = {} -- [full name] = true: each player counts once a session among the surnames
local checked = {} -- [surname] = true: the saved house was checked this session
local listeners = {}

-- --- your house --------------------------------------------------------------------------------

-- A relative's saved meetings as they should be: a broken or old saved file loses only what's
-- wrong in it.
local function CleanMeetings(relative)
    if type(relative.meetings) ~= "table" then
        relative.meetings = nil
        return
    end
    local kept = {}
    for _, meeting in ipairs(relative.meetings) do
        if type(meeting) == "table" and Utils.IsUsableNumber(meeting.at) then
            kept[#kept + 1] = meeting
        end
    end
    relative.meetings = #kept > 0 and kept or nil
end

local function SavedHouse(surname)
    if type(HeyCousinDB.houses) ~= "table" then
        HeyCousinDB.houses = {}
    end
    local house = HeyCousinDB.houses[surname]
    if type(house) ~= "table" then
        house = {}
        HeyCousinDB.houses[surname] = house
        checked[surname] = nil
    end
    if not checked[surname] then
        house.crest = Crest.Normalize(house.crest)
        house.relatives = type(house.relatives) == "table" and house.relatives or {}
        house.motto = type(house.motto) == "string" and house.motto or ""
        house.mine = type(house.mine) == "table" and house.mine or {}
        for first, character in pairs(house.mine) do
            if type(character) ~= "table" then
                house.mine[first] = nil
            end
        end
        for first, relative in pairs(house.relatives) do
            if type(relative) == "table" then
                CleanMeetings(relative)
            else
                house.relatives[first] = nil
            end
        end
        checked[surname] = true
    end
    return house
end

-- Your house and its surname: the saved one for your surname (in test mode the made-up
-- family's). Nothing while your surname isn't known.
function Kin.House()
    local test = HC.TestMode
    if test and test.active then
        return test.House(), test.SURNAME
    end
    local _, surname = Names.Me()
    if not Utils.IsUsableString(surname) or type(HeyCousinDB) ~= "table" then
        return nil
    end
    return SavedHouse(surname), surname
end

function Kin.Crest()
    local house = Kin.House()
    return house and house.crest or Crest.Normalize(nil)
end

-- A cousin's own crest if their addon told it; your house's for the others.
function Kin.CrestOf(first)
    local house = Kin.House()
    local relative = house and house.relatives[first]
    return relative and type(relative.crest) == "table" and Crest.Normalize(relative.crest) or Kin.Crest()
end

-- The windows take your crest's colors.
function Kin.ApplyAccent()
    local crest = Kin.Crest()
    Theme.SetAccent(Crest.Accent(crest), Crest.Metal(crest))
end

-- A new crest (and motto) for your house; every crest on screen follows.
function Kin.SetCrest(crest, motto)
    local house = Kin.House()
    if not house then
        return
    end
    house.crest = Crest.Normalize(crest)
    local newMotto = type(motto) == "string" and motto ~= house.motto
    if type(motto) == "string" then
        house.motto = motto
    end
    if newMotto and HC.Family and HC.Family.ShareMotto then
        HC.Family.ShareMotto()
    end
    local test = HC.TestMode
    if test and test.active then
        test.Keep(house.crest, house.motto)
    end
    Kin.ApplyAccent()
    Kin.Changed()
end

-- --- relatives ---------------------------------------------------------------------------------

local function MyFaction()
    local faction = Utils.Call(UnitFactionGroup, "player")
    return Utils.IsUsableString(faction) and faction or nil
end

-- A relative from the other faction: the family's black sheep.
function Kin.IsBlackSheep(relative)
    local mine = MyFaction()
    return relative ~= nil and mine ~= nil and relative.faction ~= nil and relative.faction ~= mine
        and relative.faction ~= "Neutral"
end

function Kin.IsNear(first)
    local at = near[first]
    return at ~= nil and GetTime() - at < NEAR_FOR
end

function Kin.IsOnline(first)
    local at = online[first]
    return at ~= nil and GetTime() - at < ONLINE_FOR
end

-- Where you are and how it is around you: a meeting's place (your map coordinates: they're near
-- you) and conditions.
local function Here()
    local here = { zone = Utils.Zone(), myLevel = Utils.Call(UnitLevel, "player") }
    local sub = Utils.Call(GetSubZoneText)
    if Utils.IsUsableString(sub) and sub ~= here.zone then
        here.sub = sub
    end
    local map = C_Map and Utils.Call(C_Map.GetBestMapForUnit, "player")
    if Utils.IsUsableNumber(map) then
        here.map = map
        local x, y = Utils.Call(function()
            return C_Map.GetPlayerMapPosition(map, "player"):GetXY()
        end)
        if Utils.IsUsableNumber(x) and Utils.IsUsableNumber(y) and (x > 0 or y > 0) then
            here.x, here.y = math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
        end
    end
    local inside, kind = Utils.Call(IsInInstance)
    if inside and Utils.IsUsableString(kind) and kind ~= "none" then
        here.instance = kind
    end
    if Utils.Call(IsResting) == true then
        here.rest = true
    end
    local hour = Utils.Call(GetGameTime)
    if Utils.IsUsableNumber(hour) and (hour >= 21 or hour < 6) then
        here.night = true
    end
    return here
end

-- What a sighting adds to the meeting it's part of: how you met, their level and guild then,
-- whether they were in your group, the first thing they said.
local function Note(meeting, info, now)
    meeting.last = now
    meeting.how = meeting.how or info.how
    if Utils.IsUsableNumber(info.level) and info.level > 0 then
        meeting.level = info.level
    end
    if Utils.IsUsableString(info.guild) then
        meeting.guild = info.guild
    end
    if info.group then
        meeting.group = true
    end
    if Utils.IsUsableString(info.said) and not meeting.said then
        meeting.said = Utils.Short(info.said, SAID_MAX)
    end
end

-- A player with your surname was seen. `info`: first (their first name), class, level, race,
-- sex, faction, guild, zone, guid, near (seen around you, not only heard of), quiet (learned,
-- not met: the guild roster, trade chat), online and found (a search found them), shared (they share
-- their place on the map), usesAddon and crest (their addon said so), seenAt (when, if not now), and
-- for the meeting: how (nameplate, mouseover, target, group, say, whisper), group
-- (they're in yours), said. Returns the
-- relative, whether you never met them before, and whether this counts as a new meeting.
function Kin.Seen(info)
    local house = Kin.House()
    if not house or not Utils.IsUsableString(info.first) then
        return nil
    end
    -- your own characters aren't your cousins
    if type(house.mine) == "table" and house.mine[info.first] then
        return nil
    end
    local now = time()
    local relative = house.relatives[info.first]
    local new = relative == nil
    if new then
        relative = { firstSeen = now, lastSeen = 0, met = 0 }
        house.relatives[info.first] = relative
    end
    -- a meeting goes on while you keep seeing them: a 15-minute gap starts a new one
    local meetings = relative.meetings
    local current = meetings and meetings[#meetings]
    local lastNear = current and (current.last or current.at) or relative.lastMet or 0
    local meeting = not info.quiet and now - lastNear >= MEETING_GAP
    if meeting then
        relative.met = (relative.met or 0) + 1
        relative.lastMet = now
        current = Here()
        current.at = now
        meetings = meetings or {}
        meetings[#meetings + 1] = current
        if #meetings > MEETINGS_KEEP then
            table.remove(meetings, 2)
        end
        relative.meetings = meetings
    end
    if current and not info.quiet then
        Note(current, info, now)
    end
    local seen = Utils.IsUsableNumber(info.seenAt) and math.min(now, info.seenAt) or now
    relative.lastSeen = math.max(relative.lastSeen or 0, seen)
    if Utils.IsUsableString(info.class) then
        relative.class = info.class
    end
    if Utils.IsUsableNumber(info.level) and info.level > 0 then
        relative.level = info.level
    end
    if Utils.IsUsableString(info.race) then
        relative.race = info.race
    end
    if Utils.IsUsableNumber(info.sex) then
        relative.sex = info.sex
    end
    if Utils.IsUsableString(info.faction) then
        relative.faction = info.faction
    end
    if Utils.IsUsableString(info.zone) then
        relative.zone = info.zone
    end
    if Utils.IsUsableString(info.guid) then
        relative.guid = info.guid
    end
    if info.guild ~= nil then
        relative.guild = Utils.IsUsableString(info.guild) and info.guild or nil
        -- (known to have none, for Recruit: nil means we never learned)
        relative.noGuild = relative.guild == nil or nil
    end
    if info.near then
        near[info.first] = GetTime()
    end
    if info.online then
        online[info.first] = GetTime()
    end
    if info.found then
        relative.found = true
    end
    if info.shared then
        relative.shared = true
    end
    if info.usesAddon then
        relative.usesAddon = true
    end
    if type(info.crest) == "table" then
        relative.crest = info.crest
    end
    Kin.Changed()
    return relative, new, meeting
end

-- The meeting going on with `first`, if there is one (the latest, while you keep seeing them).
local function Current(first)
    local house = Kin.House()
    local relative = house and house.relatives[first]
    local meetings = relative and relative.meetings
    local current = meetings and meetings[#meetings]
    if current and time() - (current.last or current.at) < MEETING_GAP then
        return current
    end
end

-- Whether a look at their gear would add to the meeting going on (Gear.lua looks once a meeting).
function Kin.WantsGear(first)
    local current = Current(first)
    return current ~= nil and current.gear == nil
end

-- Their gear, from a look up close: `items` in Gear.SLOTS's order (0: nothing there), and their
-- item level. Kept with the meeting going on.
function Kin.SawGear(first, items, level)
    local current = Current(first)
    if not current then
        return
    end
    current.gear = items
    if Utils.IsUsableNumber(level) and level > 0 then
        current.ilvl = math.floor(level + 0.5)
    end
    Kin.Changed()
end

-- A relative's meetings, the newest first.
function Kin.Meetings(relative)
    local list = {}
    local meetings = type(relative) == "table" and type(relative.meetings) == "table" and relative.meetings or {}
    for i = #meetings, 1, -1 do
        list[#list + 1] = meetings[i]
    end
    return list
end

-- The first builds took realm codes for surnames: they go from the saved counts. Builds before 1.1.2
-- counted a player again each session: those counts start over, now one a player.
function Kin.ForgetRealms()
    if type(HeyCousinDB.surnameNames) ~= "table" then
        HeyCousinDB.surnames, HeyCousinDB.surnameCount, HeyCousinDB.surnameNames = {}, 0, {}
    end
    local surnames = HeyCousinDB.surnames
    if type(surnames) ~= "table" then
        return
    end
    for name in pairs(surnames) do
        if name:find("^CAMWOW") then
            surnames[name] = nil
            HeyCousinDB.surnameCount = math.max((HeyCousinDB.surnameCount or 1) - 1, 0)
        end
    end
end

-- Every player you see counts once toward the surnames you meet most.
function Kin.SawPlayer(first, surname)
    local full = first .. "\1" .. surname
    if counted[full] then
        return
    end
    counted[full] = true
    local surnames, names = HeyCousinDB.surnames, HeyCousinDB.surnameNames
    if type(surnames) ~= "table" or type(names) ~= "table" then
        surnames, names = {}, {}
        HeyCousinDB.surnames, HeyCousinDB.surnameCount, HeyCousinDB.surnameNames = surnames, 0, names
    end
    local known = names[surname]
    if type(known) ~= "table" then
        known = {}
        names[surname] = known
    end
    local key = first:lower()
    if known[key] or (surnames[surname] or 0) >= NAMES_MAX then
        return
    end
    known[key] = true
    if surnames[surname] == nil then
        HeyCousinDB.surnameCount = (HeyCousinDB.surnameCount or 0) + 1
    end
    surnames[surname] = (surnames[surname] or 0) + 1
    if (HeyCousinDB.surnameCount or 0) > SURNAMES_MAX then
        local list = {}
        for name, count in pairs(surnames) do
            list[#list + 1] = { name, count }
        end
        table.sort(list, function(a, b)
            return a[2] > b[2]
        end)
        local kept, keptNames = {}, {}
        for i = 1, math.min(SURNAMES_KEEP, #list) do
            kept[list[i][1]] = list[i][2]
            keptNames[list[i][1]] = names[list[i][1]]
        end
        HeyCousinDB.surnames, HeyCousinDB.surnameNames = kept, keptNames
        HeyCousinDB.surnameCount = math.min(SURNAMES_KEEP, #list)
    end
end

-- Your relatives as a list: { first =, relative = } each.
function Kin.List()
    local house = Kin.House()
    local list = {}
    if house then
        for first, relative in pairs(house.relatives) do
            list[#list + 1] = { first = first, relative = relative }
        end
    end
    return list
end

-- How many relatives, how many near you now, how many black sheep, how many a search found online.
function Kin.Counts()
    local house = Kin.House()
    local total, nearby, sheep, found = 0, 0, 0, 0
    if house then
        for first, relative in pairs(house.relatives) do
            total = total + 1
            if Kin.IsNear(first) then
                nearby = nearby + 1
            end
            if Kin.IsOnline(first) then
                found = found + 1
            end
            if Kin.IsBlackSheep(relative) then
                sheep = sheep + 1
            end
        end
    end
    return total, nearby, sheep, found
end

-- A character's number, from the last part of their GUID: it grows as characters are made (seen on
-- two characters in one server group, 2026-11-06). The groups' counters are only roughly alike, so
-- this is a good guess, never a fact.
local function CharacterNumber(guid)
    local number = Utils.IsUsableString(guid) and guid:match("^Player%-%d+%-(%x+)$")
    return number and tonumber(number, 16) or nil
end

-- The first name of who looks like the eldest of the cousins you know a GUID for, you among them;
-- nothing until there are two to compare.
function Kin.Eldest()
    local house = Kin.House()
    if not house then
        return nil
    end
    local eldest, lowest, known = nil, nil, 0
    local function Compare(first, guid)
        local number = CharacterNumber(guid)
        if number then
            known = known + 1
            if not lowest or number < lowest then
                eldest, lowest = first, number
            end
        end
    end
    local test = HC.TestMode
    if not (test and test.active) then
        Compare((Names.Me()), Utils.Call(UnitGUID, "player"))
    end
    for first, relative in pairs(house.relatives) do
        Compare(first, relative.guid)
    end
    for _, alt in ipairs(Kin.Alts()) do
        Compare(alt.first, alt.relative.guid)
    end
    return known >= 2 and eldest or nil
end

-- --- your own characters ---------------------------------------------------------------------

-- This character, as your others see it: kept when you log in and log out (the saved file is the
-- account's, so every character with this surname finds the others there). Never in test mode.
function Kin.NoteMe()
    local test = HC.TestMode
    if test and test.active then
        return
    end
    local first, surname = Names.Me()
    local house = Utils.IsUsableString(surname) and Kin.House()
    if not house or not Utils.IsUsableString(first) then
        return
    end
    local _, class = Utils.Call(UnitClass, "player")
    house.mine[first] = {
        class = class, level = Utils.Call(UnitLevel, "player"), zone = Utils.Zone(), sex = Utils.Call(UnitSex, "player"),
        faction = MyFaction(), guid = Utils.Call(UnitGUID, "player"), lastSeen = time(),
    }
    -- you may have been noted as a cousin, on another character or before this was here
    house.relatives[first] = nil
    Kin.Changed()
end

-- Your other characters with this surname, the last played first: { first =, relative = } each.
function Kin.Alts()
    local house = Kin.House()
    local me = Names.Me()
    local list = {}
    if house and type(house.mine) == "table" then
        for first, character in pairs(house.mine) do
            if first ~= me then
                list[#list + 1] = { first = first, relative = character }
            end
        end
    end
    table.sort(list, function(a, b)
        local x, y = a.relative.lastSeen or 0, b.relative.lastSeen or 0
        if x ~= y then
            return x > y
        end
        return a.first < b.first
    end)
    return list
end

-- Takes a deleted character off the list; its name as saved, or nothing if there's none like it.
function Kin.ForgetCharacter(name)
    for _, alt in ipairs(Kin.Alts()) do
        if Names.Same(alt.first, name) then
            Kin.House().mine[alt.first] = nil
            Kin.Changed()
            return alt.first
        end
    end
end

-- Takes a cousin off your family, with every meeting; their name as saved, or nothing if there's none
-- like it. Seen again, they're a new cousin, first pop-up and all.
function Kin.DeleteCousin(name)
    local house = Kin.House()
    local wanted = Names.Split(name)
    for first, relative in pairs(house and house.relatives or {}) do
        if Names.Same(first, wanted) then
            house.relatives[first] = nil
            near[first], online[first] = nil, nil
            HC.Radar.LookAgain(relative.guid)
            Kin.Changed()
            return first
        end
    end
end

-- The family stats: meetings, the relatives met most, the surnames met most (top `limit`).
function Kin.Stats(limit)
    limit = limit or 5
    local stats = { meetings = 0, mine = 0, other = 0, mostMet = {}, surnames = {} }
    for _, entry in ipairs(Kin.List()) do
        local relative = entry.relative
        stats.meetings = stats.meetings + (relative.met or 0)
        if Kin.IsBlackSheep(relative) then
            stats.other = stats.other + 1
        else
            stats.mine = stats.mine + 1
        end
        stats.mostMet[#stats.mostMet + 1] = entry
    end
    table.sort(stats.mostMet, function(a, b)
        return (a.relative.met or 0) > (b.relative.met or 0)
    end)
    for i = #stats.mostMet, limit + 1, -1 do
        stats.mostMet[i] = nil
    end
    local test = HC.TestMode
    local surnames = test and test.active and test.Surnames() or HeyCousinDB.surnames
    for name, count in pairs(type(surnames) == "table" and surnames or {}) do
        stats.surnames[#stats.surnames + 1] = { name = name, count = count }
    end
    table.sort(stats.surnames, function(a, b)
        return a.count > b.count
    end)
    for i = #stats.surnames, limit + 1, -1 do
        stats.surnames[i] = nil
    end
    return stats
end

-- --- listeners ---------------------------------------------------------------------------------

-- `fn` runs a moment after the family changes (a burst of sightings runs it once).
function Kin.OnChange(fn)
    listeners[#listeners + 1] = fn
end

Kin.Changed = Utils.Debounce(0.3, "family changed", function()
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn)
        if not ok then
            Utils.NoteError("family changed", err)
        end
    end
end)

-- Marks a relative as near (test mode, and the pop-up's preview).
function Kin.MarkNear(first, at)
    near[first] = at or GetTime()
end
