local _, HC = ...

-- Retail has no surnames, so there the addon runs in test mode with a made-up family: the
-- window, the pop-up and the crest can all be tried before WoW Forever opens. The family is never
-- saved. The crest and motto you make here are, and they wait for your Forever house.
HC.TestMode = { active = false, SURNAME = "Ashbrook" }

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
        }
        if ago < 120 then
            HC.Kin.MarkNear(first, clock - ago)
        end
    end
    local saved = type(HeyCousinDB) == "table" and HeyCousinDB or {}
    return {
        crest = Crest.Normalize(saved.testCrest),
        motto = type(saved.testMotto) == "string" and saved.testMotto or L["Family first."],
        relatives = relatives,
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
