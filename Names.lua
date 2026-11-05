local _, HC = ...

HC.Names = {}

local Names = HC.Names
local Utils = HC.Utils

-- The game's mark between a first name and a surname ("Mira Ashbrook"). Forever keeps it in
-- Constants.CharacterNameSeparatorConsts; it's a space.
function Names.Separator()
    local consts = Constants and Constants.CharacterNameSeparatorConsts
    local separator = consts and consts.CHARACTERNAME_SURNAME_SEPARATOR
    if Utils.IsUsableString(separator) then
        return separator
    end
    return " "
end

-- "First Surname", as the game writes it and as /targetexact, whispers and invites take it.
function Names.Full(first, surname)
    if Utils.IsUsableString(surname) then
        return first .. Names.Separator() .. surname
    end
    return first
end

-- Two surnames are one family: the same letters, big or small.
function Names.Same(a, b)
    if not Utils.IsUsableString(a) or not Utils.IsUsableString(b) then
        return false
    end
    return a == b or a:lower() == b:lower()
end

-- `first` without `surname` at its end: some units carry the whole name in the first value.
local function Bare(first, surname)
    local tail = Names.Separator() .. surname
    if #first > #tail and first:sub(-#tail) == tail then
        return first:sub(1, -#tail - 1)
    end
    return first
end

-- Whether names here come with surnames: WoW Forever (names unique in the region). Elsewhere
-- UnitName's second value is a realm.
function Names.HaveSurnames()
    if not HC.IsForever then
        return false
    end
    local regional = Utils.Call(RegionalUniqueNamesEnabled)
    return regional ~= false
end

-- A player unit's first name and surname, or nothing: not a player, hidden from addons right
-- now, or no surname. Forever's UnitName gives the two as its two values.
function Names.Unit(unit)
    if Utils.UnitHidden(unit) then
        return
    end
    local ok, first, surname = pcall(UnitName, unit)
    if not ok or not Utils.IsUsableString(first) or not Utils.IsUsableString(surname) then
        return
    end
    return Bare(first, surname), surname
end

-- A player's names and looks from their GUID (a chat line's). Forever's GetPlayerInfoByGUID gives
-- the whole name ("Mira Ashbrook"), then a real realm: a code ("CAMWOWEU4Realm4PvP"), empty for your
-- own. Never take that for a surname. The game knows a GUID once it has seen the player.
function Names.FromGUID(guid)
    if not Utils.IsUsableString(guid) or type(GetPlayerInfoByGUID) ~= "function" then
        return
    end
    local ok, _, class, _, race, sex, name = pcall(GetPlayerInfoByGUID, guid)
    if not ok then
        return
    end
    local first, surname = Names.Split(name)
    if not Utils.IsUsableString(surname) then
        return
    end
    return first, surname, class, race, sex
end

-- "First Surname" (or "First-Surname") taken apart; a plain first name comes back alone. A realm
-- after it ("First Surname-Realm") is dropped: names are letters only, so a dash starts a realm.
function Names.Split(full)
    if not Utils.IsUsableString(full) then
        return
    end
    local separator = Names.Separator()
    local at = full:find(separator, 1, true)
    if at then
        return full:sub(1, at - 1), (full:sub(at + #separator):gsub("%-.*$", ""))
    end
    local first, rest = full:match("^([^%-]+)%-(.+)$")
    if first then
        return first, rest
    end
    return full
end

-- This character's first name and surname. In test mode: your name and the made-up family's.
-- Kept once the game has given both: a name doesn't change while you play.
local myFirst, mySurname

function Names.Me()
    local test = HC.TestMode
    if test and test.active then
        return test.Me()
    end
    if myFirst then
        return myFirst, mySurname
    end
    local get = UnitNameUnmodified or UnitName
    local ok, first, surname = pcall(get, "player")
    if not ok or not Utils.IsUsableString(first) then
        return
    end
    if not Utils.IsUsableString(surname) then
        return first
    end
    myFirst, mySurname = Bare(first, surname), surname
    return myFirst, mySurname
end
