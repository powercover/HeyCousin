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
-- The surnames you meet: trimmed to the 200 met most once there are 400.
local SURNAMES_KEEP, SURNAMES_MAX = 200, 400

local near = {}    -- [first name] = GetTime() of the last sighting around you (this session)
local counted = {} -- [full name] = true: each player counts once a session among the surnames
local checked = {} -- [surname] = true: the saved house was checked this session
local listeners = {}

-- --- your house --------------------------------------------------------------------------------

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
    if type(motto) == "string" then
        house.motto = motto
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

-- A player with your surname was seen. `info`: first (their first name), class, level, race,
-- sex, faction, guild, zone, guid, near (seen around you, not only heard of), quiet (learned,
-- not met: the guild roster, trade chat), seenAt (when, if not now). Returns the relative,
-- whether you never met them before, and whether this counts as a new meeting.
function Kin.Seen(info)
    local house = Kin.House()
    if not house or not Utils.IsUsableString(info.first) then
        return nil
    end
    local now = time()
    local relative = house.relatives[info.first]
    local new = relative == nil
    if new then
        relative = { firstSeen = now, lastSeen = 0, met = 0 }
        house.relatives[info.first] = relative
    end
    local meeting = not info.quiet and now - (relative.lastMet or 0) >= MEETING_GAP
    if meeting then
        relative.met = (relative.met or 0) + 1
        relative.lastMet = now
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
    end
    if info.near then
        near[info.first] = GetTime()
    end
    Kin.Changed()
    return relative, new, meeting
end

-- Every player you see counts once a session toward the surnames you meet most.
function Kin.SawPlayer(first, surname)
    local full = first .. "\1" .. surname
    if counted[full] then
        return
    end
    counted[full] = true
    local surnames = HeyCousinDB.surnames
    if type(surnames) ~= "table" then
        surnames = {}
        HeyCousinDB.surnames = surnames
    end
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
        local kept = {}
        for i = 1, math.min(SURNAMES_KEEP, #list) do
            kept[list[i][1]] = list[i][2]
        end
        HeyCousinDB.surnames = kept
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

-- How many relatives, how many near you now, how many black sheep.
function Kin.Counts()
    local house = Kin.House()
    local total, nearby, sheep = 0, 0, 0
    if house then
        for first, relative in pairs(house.relatives) do
            total = total + 1
            if Kin.IsNear(first) then
                nearby = nearby + 1
            end
            if Kin.IsBlackSheep(relative) then
                sheep = sheep + 1
            end
        end
    end
    return total, nearby, sheep
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
