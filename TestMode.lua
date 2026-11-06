local _, HC = ...

-- Retail has no surnames, so there the addon runs in test mode with a made-up family: the
-- window, the pop-up and the crest can all be tried before WoW Forever opens. The family is never
-- saved. The crest and motto you make here are, and they wait for your Forever house.
HC.TestMode = { active = false, SURNAME = "Ashbrook", GUILD = "Ashbrook Kin" }

local TestMode = HC.TestMode
local Utils = HC.Utils
local Crest = HC.Crest
local L = HC.L

local MINUTE, HOUR, DAY = 60, 3600, 86400

-- first name, class, level, sex, "mine" or "other" faction, zone, last seen (seconds ago), met
local FAMILY = {
    { "Mira", "MAGE", 23, 3, "mine", "Elwynn Forest", 20, 4 },
    { "Thane", "WARRIOR", 41, 2, "mine", "Wetlands", 2 * HOUR, 7 },
    { "Bru", "DRUID", 12, 2, "other", "Mulgore", DAY, 1 },
    { "Lia", "PRIEST", 60, 3, "mine", "Stormwind City", 3 * DAY, 12 },
    { "Grom", "HUNTER", 8, 2, "other", "Durotar", 5 * DAY, 2 },
    { "Elowen", "PALADIN", 34, 3, "mine", "Redridge Mountains", 40, 3 },
    { "Fenn", "ROGUE", 27, 2, "mine", "Ironforge", 6 * HOUR, 5 },
    { "Hollis", "WARLOCK", 52, 2, "mine", "Burning Steppes", 9 * DAY, 2 },
    { "Wren", "SHAMAN", 19, 3, "other", "The Barrens", 12 * DAY, 1 },
    { "Odo", "MAGE", 45, 2, "mine", "Tanaris", 2 * DAY, 6 },
    { "Isla", "DRUID", 38, 3, "mine", "Ashenvale", 4 * HOUR, 9 },
    { "Bram", "WARRIOR", 60, 2, "mine", "Searing Gorge", 20 * DAY, 3 },
    { "Tamsin", "HUNTER", 30, 3, "mine", "Darkshore", 50 * MINUTE, 2 },
}
local RACES = {
    Alliance = { "Human", "Dwarf", "Gnome", "NightElf" },
    Horde = { "Orc", "Tauren", "Troll", "Scourge" },
}
local SURNAMES = { Stormhold = 34, Fairwind = 21, Ironvale = 17, Ashbrook = 13, Brightwater = 12, Duskmantle = 9,
    Greywood = 7 }

-- Their made-up meetings: places on each side (zone, subzone, and whether it's a town), what
-- they said, and starter gear every version of the game has (robes, trousers, boots, weapons).
local PLACES = {
    Alliance = { { "Elwynn Forest", "Goldshire", true }, { "Westfall", "Sentinel Hill" },
        { "Redridge Mountains", "Lakeshire", true }, { "Duskwood", "Darkshire" }, { "Wetlands", "Menethil Harbor" },
        { "Stormwind City", "Trade District", true }, { "Ironforge", "The Commons", true }, { "Loch Modan", "Thelsamar" } },
    Horde = { { "Durotar", "Razor Hill" }, { "Mulgore", "Bloodhoof Village", true }, { "The Barrens", "The Crossroads" },
        { "Orgrimmar", "Valley of Strength", true }, { "Tirisfal Glades", "Brill", true }, { "Ashenvale", "Splintertree Post" } },
}
local SAID = { "Hey cousin!", "Same surname, same family!", "Need a hand with that quest?",
    "Family dinner in Goldshire at 8.", "Wait, we're related?", "For the family!" }
local WAYS = { "nameplate", "mouseover", "target", "group", "say", "nameplate" }
local ROBES, TROUSERS, BOOTS, WEAPONS = { 56, 57, 6098 }, { 39, 44, 48, 52 }, { 40, 43, 47, 51, 55 },
    { 25, 35, 36, 37, 2092, 2361 }

-- The made-up guild you lead: its ranks, and who's in it by rank (0: the guild master, you). A
-- relative from the family above comes as they are; the others are known only from the guild,
-- and one of them is an in-law (another surname).
local GUILD_RANKS = { "Guild Master", "Officer", "Member", "Initiate" }
local GUILD = {
    { first = "Lia", rank = 1 }, { first = "Thane", rank = 1 }, { first = "Isla", rank = 1 },
    { first = "Mira", rank = 2 }, { first = "Elowen", rank = 2 }, { first = "Fenn", rank = 2 }, { first = "Odo", rank = 2 },
    { first = "Tamsin", rank = 2 }, { first = "Hollis", rank = 2 }, { first = "Bram", rank = 2 },
    { first = "Corin", rank = 2, surname = "Fairwind", class = "HUNTER", level = 18, ago = 3 * HOUR },
    { first = "Pip", rank = 3, class = "ROGUE", level = 9, ago = 2 * DAY },
    { first = "Juniper", rank = 3, class = "PRIEST", level = 14, ago = 20 * MINUTE, zone = "Stormwind City" },
}

-- The same made-up numbers every time for a name: the pictures (screens.py) stay the same.
local function Dice(name)
    local state = 7
    for i = 1, #name do
        state = (state * 31 + name:byte(i)) % 2147483647
    end
    return function(sides)
        state = (state * 48271) % 2147483647
        return state % sides + 1
    end
end

local function History(first, relative, ago)
    local roll = Dice(first)
    local places = PLACES[relative.faction] or PLACES.Alliance
    local myLevel = Utils.Call(UnitLevel, "player") or 20
    local meetings = {}
    for i = 1, relative.met do
        local back = relative.met - i
        local at = relative.lastSeen - back * (2 * DAY + roll(20) * HOUR)
        local place = places[roll(#places)]
        local meeting = {
            at = at, last = at + (roll(6) - 1) * 9 * MINUTE, zone = place[1], sub = place[2], rest = place[3],
            x = 20 + roll(600) / 10, y = 20 + roll(600) / 10, level = math.max(1, relative.level - back * roll(3)),
            myLevel = math.max(1, myLevel - back), how = WAYS[roll(#WAYS)], night = roll(3) == 1 or nil,
        }
        meeting.group = meeting.how == "group" or roll(5) == 1 or nil
        if meeting.how == "say" then
            meeting.said = SAID[roll(#SAID)]
        end
        if roll(2) == 1 then
            meeting.gear = { 0, 0, 0, 0, ROBES[roll(#ROBES)], 0, 0, 0, TROUSERS[roll(#TROUSERS)], BOOTS[roll(#BOOTS)],
                0, 0, 0, 0, WEAPONS[roll(#WEAPONS)], 0, 0 }
            meeting.ilvl = math.floor(meeting.level * 1.5) + 4
        end
        meetings[i] = meeting
    end
    -- the latest meeting is where they are now (a moment ago for the ones near you)
    local latest = meetings[#meetings]
    latest.zone, latest.sub, latest.rest = relative.zone, nil, nil
    latest.level, latest.at = relative.level, relative.lastSeen
    latest.last = ago < 120 and time() or latest.last
    return meetings
end

local house

local function Factions()
    local mine = Utils.Call(UnitFactionGroup, "player")
    if mine ~= "Horde" then
        mine = "Alliance"
    end
    return mine, mine == "Horde" and "Alliance" or "Horde"
end

local function Build()
    local mine, other = Factions()
    local relatives = {}
    local now, clock = time(), GetTime()
    for index, row in ipairs(FAMILY) do
        local first, class, level, sex, side, zone, ago, met = unpack(row)
        local faction = side == "mine" and mine or other
        local races = RACES[faction]
        relatives[first] = {
            class = class, level = level, sex = sex, faction = faction, zone = zone,
            race = races[(index - 1) % #races + 1],
            firstSeen = now - ago - met * 3 * DAY, lastSeen = now - ago, met = met,
            -- (Lia, the made-up family's eldest, has the lowest character number)
            guid = string.format("Player-1-%06X", first == "Lia" and 1000 or 200000 + index * 7000),
        }
        relatives[first].meetings = History(first, relatives[first], ago)
        if ago < 120 then
            HC.Kin.MarkNear(first, clock - ago)
        end
    end
    local saved = type(HeyCousinDB) == "table" and HeyCousinDB or {}
    return {
        crest = Crest.Normalize(saved.testCrest),
        motto = type(saved.testMotto) == "string" and saved.testMotto or L["Family first."],
        relatives = relatives,
        -- your other character with this surname
        mine = { Wynn = { class = "PRIEST", level = 14, sex = 3, faction = mine, zone = "Westfall", lastSeen = now - 2 * DAY,
            guid = "Player-1-3D0000" } },
    }
end

-- Test mode on (Retail).
function TestMode.Start()
    TestMode.active = true
    house = Build()
end

function TestMode.House()
    if not house then
        house = Build()
    end
    return house
end

-- Your own first name, with the made-up surname.
function TestMode.Me()
    local ok, first = pcall(UnitName, "player")
    return ok and Utils.IsUsableString(first) and first or L["You"], TestMode.SURNAME
end

-- The crest and motto made in test mode are kept: they wait for your Forever house.
function TestMode.Keep(crest, motto)
    HeyCousinDB.testCrest = crest
    HeyCousinDB.testMotto = motto
end

function TestMode.Surnames()
    return SURNAMES
end

function TestMode.GuildRanks()
    return { unpack(GUILD_RANKS) }
end

-- The made-up guild's members, as Guild.Members gives a real guild's: online when seen within the
-- hour.
function TestMode.Guild()
    local relatives = TestMode.House().relatives
    local now = time()
    local first = TestMode.Me()
    local _, class = Utils.Call(UnitClass, "player")
    local members = { {
        full = HC.Names.Full(first, TestMode.SURNAME), first = first, surname = TestMode.SURNAME, rank = 0,
        rankName = GUILD_RANKS[1], level = Utils.Call(UnitLevel, "player"), class = class, zone = Utils.Zone(),
        online = true, me = true,
    } }
    for _, row in ipairs(GUILD) do
        local relative = relatives[row.first]
        local seen = relative and relative.lastSeen or now - row.ago
        local member = {
            first = row.first, surname = row.surname or TestMode.SURNAME, rank = row.rank, rankName = GUILD_RANKS[row.rank + 1],
            class = relative and relative.class or row.class, level = relative and relative.level or row.level,
            online = now - seen < HOUR,
        }
        member.full = HC.Names.Full(member.first, member.surname)
        member.zone = member.online and (relative and relative.zone or row.zone) or nil
        member.seen = not member.online and seen or nil
        members[#members + 1] = member
    end
    return members
end

-- The made-up answer to Find my family, as the game's /who lists it: cousins online, one you never
-- met, and two whose surnames only have yours inside (the search leaves them out).
function TestMode.Who()
    local rows = {}
    for _, row in ipairs(FAMILY) do
        local first, class, level, _, side, zone, ago = unpack(row)
        if side == "mine" and ago < HOUR then
            rows[#rows + 1] = { fullName = HC.Names.Full(first, TestMode.SURNAME), filename = class, level = level,
                area = zone, fullGuildName = TestMode.GUILD }
        end
    end
    rows[#rows + 1] = { fullName = HC.Names.Full("Perrin", TestMode.SURNAME), filename = "ROGUE", level = 16,
        area = Utils.Zone() or "Westfall", fullGuildName = "" }
    rows[#rows + 1] = { fullName = "Nell Washbrook", filename = "PRIEST", level = 22, area = "Duskwood", fullGuildName = "" }
    rows[#rows + 1] = { fullName = "Gus Ashbrooke", filename = "MAGE", level = 31, area = "Wetlands", fullGuildName = "" }
    return rows
end

-- The made-up guild's family, as you (its guild master) gave it: its Initiates are Little cousins.
function TestMode.GuildFamily()
    return { stamp = 1, surname = TestMode.SURNAME, words = { "", "", "", L["Little cousin"] },
        welcome = L["Welcome home, cousin! Ask a Parent if you need a hand."] }
end

-- A pop-up with a made-up cousin, round after round: one near you, a new one, a black sheep, and
-- a cousin who wants to join your layer.
local turn = 0
function TestMode.Pop()
    local kinds = { { "Mira", false }, { "Tamsin", true }, { "Bru", false }, { "Elowen", "layer" } }
    turn = turn % #kinds + 1
    local first, new = kinds[turn][1], kinds[turn][2]
    if new == "layer" then
        HC.Layer.ShowAsk(HC.Names.Full(first, TestMode.SURNAME), true)
        return
    end
    local relative = TestMode.House().relatives[first]
    HC.Kin.MarkNear(first)
    HC.Alert.Show({
        first = first, relative = relative, new = new, unit = "player", test = true,
    })
end
