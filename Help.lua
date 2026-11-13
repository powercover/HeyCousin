local _, HC = ...

-- A call for help: stuck on an elite or a hard quest, you say what with one click, and every cousin
-- online who has the addon sees it with where you are, on the Together tab and as a line in chat. A
-- cousin can set the game's waypoint to you. One call every few minutes at most; it lasts ten.
HC.Help = {}

local Help = HC.Help
local Utils = HC.Utils
local Theme = HC.Theme
local Kin = HC.Kin
local L = HC.L

local LIVE = 10 * 60
local REST = 3 * 60
-- a cousin's addon that sends calls faster than this is let go by (a changed addon could)
local HEAR_GAP = 30
local WORDS_MAX = 50

local calls = {}  -- [first name] = { first, full, words, map, x, y, zone, at }
local mine        -- your call: { words, at }

-- Lines in chat about cousins' calls (a setting, on unless you say).
function Help.On()
    return HC.Family.Messages() and (type(HeyCousinDB) ~= "table" or HeyCousinDB.familyHelp ~= false)
end

-- (a burst of lines paints the window once)
local Changed = Utils.Debounce(0.3, "help", function()
    HC.Window.Refresh(true)
end)

local function Alive(call)
    return GetTime() - call.at < LIVE
end

function Help.Mine()
    if mine and not Alive(mine) then
        mine = nil
    end
    return mine
end

-- Where you are: the map and the spot on it (in thousandths), or nothing.
local function Here()
    local map = C_Map and Utils.Call(C_Map.GetBestMapForUnit, "player")
    if not Utils.IsUsableNumber(map) then
        return nil
    end
    local x, y = Utils.Call(function()
        return C_Map.GetPlayerMapPosition(map, "player"):GetXY()
    end)
    if not Utils.IsUsableNumber(x) or not Utils.IsUsableNumber(y) or (x <= 0 and y <= 0) then
        return map
    end
    return map, math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5)
end

-- Asks the family for help, with `text` and where you are.
function Help.Ask(text)
    local words = HC.Guild.Plain(text, WORDS_MAX)
    if words == "" then
        return
    end
    local now = GetTime()
    if mine and now - mine.at < REST then
        Utils.Print(L["You asked a moment ago. Wait a little before asking again."])
        return
    end
    if not HC.Family.Messages() then
        Utils.Print(L["Family messages are off. They're in the settings, under Family."])
        return
    end
    if HC.TestMode.active then
        Utils.Print(L["Test mode: made-up cousins can't hear you."])
    else
        local map, x, y = Here()
        if not HC.Family.Send("6:H:" .. (map or "") .. ":" .. (x or "") .. ":" .. (y or "") .. ":" .. words) then
            Utils.Print(L["The family's channel isn't ready yet. Try again in a moment."])
            return
        end
    end
    mine = { words = words, at = now }
    Changed()
end

-- Your call comes down: you got the help.
function Help.Stop()
    if not mine then
        return
    end
    mine = nil
    if not HC.TestMode.active then
        HC.Family.Send("6:Y")
    end
    Changed()
end

-- The calls that still stand, the newest first.
function Help.List()
    local list = {}
    for first, call in pairs(calls) do
        if Alive(call) then
            list[#list + 1] = call
        else
            calls[first] = nil
        end
    end
    table.sort(list, function(a, b)
        return a.at > b.at
    end)
    return list
end

-- The game's waypoint on a cousin's call, with its arrow.
function Help.Waypoint(call)
    if not call.map or not call.x or not UiMapPoint or type(UiMapPoint.CreateFromCoordinates) ~= "function" then
        return false
    end
    local point = Utils.Call(UiMapPoint.CreateFromCoordinates, call.map, call.x / 1000, call.y / 1000)
    if not point then
        return false
    end
    Utils.Call(C_Map and C_Map.SetUserWaypoint, point)
    Utils.Call(C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    Utils.Print(string.format(L["Waypoint set on %s: follow the arrow."], call.full))
    return true
end

-- A call (H) or its end (Y), from a cousin (Share.Heard has checked who it's from).
function Help.Heard(kind, rest, member)
    if kind == "Y" then
        calls[member.first] = nil
        Changed()
        return
    end
    local old = calls[member.first]
    if old and GetTime() - old.at < HEAR_GAP then
        return
    end
    local map, x, y, said = rest:match("^(%d*):(%d*):(%d*):(.*)$")
    local words = said and HC.Words.Clean(HC.Guild.Plain(said, WORDS_MAX)) or ""
    if words == "" then
        return
    end
    map, x, y = tonumber(map), tonumber(x), tonumber(y)
    local info = map and C_Map and Utils.Call(C_Map.GetMapInfo, map)
    local zone = type(info) == "table" and Utils.IsUsableString(info.name) and info.name or nil
    calls[member.first] = { first = member.first, full = member.full, words = words, map = map,
        x = x and math.min(x, 1000), y = y and math.min(y, 1000), zone = zone, at = GetTime() }
    local relative = Kin.Seen({ first = member.first, faction = Utils.Call(UnitFactionGroup, "player"), quiet = true,
        online = true, usesAddon = true })
    if Help.On() and not (old and old.words == words) then
        local color = Utils.ClassColor(relative and relative.class, true)
        HC.Family.Tell(string.format(L["%s needs help: %s"], Theme.Paint(member.full, color), words)
            .. (zone and (" (" .. zone .. ")") or ""))
    end
    Changed()
end
