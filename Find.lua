local _, HC = ...

-- Find my family: one click asks the game's /who for everyone online with your surname. Forever
-- reads n-"First Surname" in two parts, so n-" Surname" looks at surnames only, but finds the
-- letters anywhere in them ("Washbrook" for "Ashbrook"): only the exact ones are kept. They join your family,
-- learned, not met. It lists 50 people at most: when that's full, each next click looks at one band
-- of levels, which gets past the limit. Each search needs a click of its own.
HC.Find = {}

local Find = HC.Find
local Utils = HC.Utils
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L

local LIMIT = 50
local WAIT = 6 -- the game takes one search every few seconds
local TEST_WAIT = 1
local BANDS = { { 1, 9 }, { 10, 19 }, { 20, 29 }, { 30, 39 }, { 40, 49 }, { 50, 59 }, { 60, 99 } }
local NAMEPLATES = 40

local frame = CreateFrame("Frame")
-- the search waiting for its answer, and the next band of levels when one list wasn't enough
local waiting, band

local function Changed()
    HC.Window.Refresh(true)
    HC.Lookup.Changed()
end

-- The game opens its own window (Looking For Group) on a /who answer. While our search waits, the
-- frames listening for that answer don't hear it, as /who addons have long done; a window you opened
-- yourself keeps hearing it. If one opens anyway, the answer closes it again, never in a fight.
local muted, closed = {}, {}

local function Top(frame)
    local parent = Utils.Call(frame.GetParent, frame)
    while parent and parent ~= UIParent do
        frame = parent
        parent = Utils.Call(frame.GetParent, frame)
    end
    return frame
end

local function Mute()
    muted, closed = {}, {}
    for _, listener in ipairs({ Utils.Call(GetFramesRegisteredForEvent, "WHO_LIST_UPDATE") }) do
        if listener ~= frame and Utils.Call(listener.IsVisible, listener) ~= true then
            local top = Top(listener)
            -- only what's closed now: a window open on another of its pages stays open
            if Utils.Call(top.IsShown, top) ~= true then
                closed[top] = true
            end
            if pcall(listener.UnregisterEvent, listener, "WHO_LIST_UPDATE") then
                muted[#muted + 1] = listener
            end
        end
    end
end

local function Unmute()
    for _, listener in ipairs(muted) do
        pcall(listener.RegisterEvent, listener, "WHO_LIST_UPDATE")
    end
    muted = {}
    if not InCombatLockdown() then
        for top in pairs(closed) do
            if Utils.Call(top.IsShown, top) == true then
                pcall(top.Hide, top)
            end
        end
    end
    closed = {}
end

-- What this search asks: your surname, in one band of levels if it's come to that.
local function Search(surname)
    local search = 'n-" ' .. surname .. '"'
    if band then
        search = search .. " " .. BANDS[band][1] .. "-" .. BANDS[band][2]
    end
    return search
end

-- What the game listed (or a made-up family in test mode: `other`'s, or yours), and how many it says
-- there are.
local function Listed(other)
    local test = HC.TestMode
    if test and test.active then
        local rows = other and test.WhoOther(other) or test.Who()
        return rows, #rows
    end
    local friends = C_FriendList
    local count, total = Utils.Call(friends and friends.GetNumWhoResults)
    local rows = {}
    for i = 1, Utils.IsUsableNumber(count) and count or 0 do
        local info = Utils.Call(friends.GetWhoInfo, i)
        if type(info) == "table" then
            rows[#rows + 1] = info
        end
    end
    return rows, Utils.IsUsableNumber(total) and total or #rows
end

-- The answer: the ones with exactly your surname are family. /who shows your own faction only.
local function Take()
    local rows, total = Listed()
    local me, mine = Names.Me()
    local faction = Utils.Call(UnitFactionGroup, "player")
    for _, info in ipairs(rows) do
        local first, surname = Names.Split(info.fullName)
        if first and Names.Same(surname, mine) and not Names.Same(first, me) then
            Kin.Seen({
                first = first, class = info.filename, level = info.level, zone = info.area, faction = faction,
                guild = info.fullGuildName or false, quiet = true, online = true, found = true,
            })
        end
    end
    -- what's next: the bands when the list was full, the next band, or done
    if band then
        band = band < #BANDS and band + 1 or nil
    elseif #rows >= LIMIT or total > #rows then
        band = 1
    end
    if band then
        Utils.Print(L["Many names match yours and the game lists 50 at a time. Click again to look further."])
    else
        local _, _, _, online = Kin.Counts()
        Utils.Print(online > 0 and string.format(L["Family online now: %d"], online)
            or L["Nobody else with your surname is online right now."])
    end
end

-- Whether a search can start now: your surname is known and no search is waiting.
function Find.Ready()
    local _, surname = Names.Me()
    return not waiting and Utils.IsUsableString(surname)
end

function Find.Waiting()
    return waiting ~= nil
end

-- The button's words: Find my family, Looking..., or how far through the bands.
function Find.Label()
    if waiting then
        return L["Looking..."]
    elseif band then
        return string.format(L["Keep looking (%d/%d)"], band, #BANDS)
    end
    return L["Find my family"]
end

-- One question to the game; `take` reads its answer. Call it from a click: the game takes these only
-- from one.
local function Ask(search, take)
    local test = HC.TestMode
    local run = { answered = false, take = take }
    waiting = run
    if not (test and test.active) then
        local friends = C_FriendList
        Mute()
        Utils.Call(friends and friends.SetWhoToUi, true)
        Utils.Call(friends and friends.SendWho, search)
    end
    Changed()
    Utils.After(test and test.active and TEST_WAIT or WAIT, "find my family", function()
        if test and test.active then
            run.answered = true
            take()
        elseif not run.answered then
            Unmute()
            Utils.Print(L["The game didn't answer. Try again in a moment."])
        end
        waiting = nil
        Changed()
    end)
end

-- One search for your family.
function Find.Start()
    if Find.Ready() then
        local _, surname = Names.Me()
        Ask(Search(surname), Take)
    end
end

-- Who has this surname among the players the game shows you now: your group, your target, the
-- nameplates around you, and your guild's online members. /who lists your own realm only, so a
-- player from another realm in your dungeon group is found only here. As /who's rows.
local function Around(surname)
    local rows, units = {}, { "target", "focus", "mouseover" }
    local raid = Utils.Call(IsInRaid) == true
    local count = (raid and Utils.Call(GetNumGroupMembers) or Utils.Call(GetNumSubgroupMembers)) or 0
    for i = 1, count do
        units[#units + 1] = (raid and "raid" or "party") .. i
    end
    for i = 1, NAMEPLATES do
        units[#units + 1] = "nameplate" .. i
    end
    for _, unit in ipairs(units) do
        if Utils.Call(UnitIsPlayer, unit) == true and Utils.Call(UnitIsUnit, unit, "player") ~= true then
            local first, last = Names.Unit(unit)
            if first and Names.Same(last, surname) then
                local _, class = Utils.Call(UnitClass, unit)
                rows[#rows + 1] = {
                    fullName = Names.Full(first, last), filename = class, level = Utils.Call(UnitLevel, unit),
                    area = Utils.Call(UnitIsVisible, unit) == true and Utils.Zone() or nil,
                    fullGuildName = Utils.Call(GetGuildInfo, unit),
                }
            end
        end
    end
    local me = Names.Me()
    for i = 1, Utils.Call(GetNumGuildMembers) or 0 do
        local full, _, _, level, _, zone, _, _, online, _, class = Utils.Call(GetGuildRosterInfo, i)
        local first, last = Names.Split(full)
        if online == true and Names.Same(last, surname) and not Names.Same(first, me) then
            rows[#rows + 1] = { fullName = full, filename = class, level = level, area = zone,
                fullGuildName = Utils.Call(GetGuildInfo, "player") }
        end
    end
    return rows
end

-- One search for any surname: done(rows, more) gets those with exactly it, as they are, the highest
-- level first, and whether the game's list was full. /who's answer, and who the game shows you now
-- (Around). Nobody joins your family by it.
function Find.Lookup(surname, done)
    if waiting then
        return
    end
    Ask('n-" ' .. surname .. '"', function()
        local rows, total = Listed(surname)
        local more = #rows >= LIMIT or total > #rows
        for _, row in ipairs(Around(surname)) do
            rows[#rows + 1] = row
        end
        local kept, taken = {}, {}
        for _, info in ipairs(rows) do
            local first, last = Names.Split(info.fullName)
            if first and Names.Same(last, surname) and not taken[first:lower()] then
                taken[first:lower()] = true
                kept[#kept + 1] = { first = first, full = info.fullName, class = info.filename, level = info.level,
                    zone = info.area, guild = info.fullGuildName }
            end
        end
        table.sort(kept, function(a, b)
            if (a.level or 0) ~= (b.level or 0) then
                return (a.level or 0) > (b.level or 0)
            end
            return a.first < b.first
        end)
        done(kept, more)
    end)
end

frame:SetScript("OnEvent", Utils.Protect("find my family", function()
    -- the game's own /who window answers here too: only a search of ours is read
    if waiting and not waiting.answered then
        waiting.answered = true
        -- back on even if reading it goes wrong
        local ok, problem = pcall(waiting.take)
        Unmute()
        if not ok then
            Utils.NoteError("find my family", problem)
        end
        Changed()
    end
end))
frame:RegisterEvent("WHO_LIST_UPDATE")
