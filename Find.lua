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

local frame = CreateFrame("Frame")
-- the search waiting for its answer, and the next band of levels when one list wasn't enough
local waiting, band

local function Changed()
    HC.Window.Refresh(true)
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
    local names = {}
    for _, listener in ipairs({ Utils.Call(GetFramesRegisteredForEvent, "WHO_LIST_UPDATE") }) do
        if listener ~= frame and Utils.Call(listener.IsVisible, listener) ~= true then
            -- which frames these are: to read in the saved file if a window ever opens anyway
            names[#names + 1] = tostring(Utils.Call(listener.GetName, listener))
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
    HeyCousinDB.whoFrames = names
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

-- What the game listed (or the made-up family in test mode), and how many it says there are.
local function Listed()
    local test = HC.TestMode
    if test and test.active then
        local rows = test.Who()
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

-- One search. Call it from a click: the game takes these only from one.
function Find.Start()
    if not Find.Ready() then
        return
    end
    local _, surname = Names.Me()
    local test = HC.TestMode
    local run = { answered = false }
    waiting = run
    if not (test and test.active) then
        local friends = C_FriendList
        Mute()
        Utils.Call(friends and friends.SetWhoToUi, true)
        Utils.Call(friends and friends.SendWho, Search(surname))
    end
    Changed()
    Utils.After(test and test.active and TEST_WAIT or WAIT, "find my family", function()
        if test and test.active then
            run.answered = true
            Take()
        elseif not run.answered then
            Unmute()
            Utils.Print(L["The game didn't answer. Try again in a moment."])
        end
        waiting = nil
        Changed()
    end)
end

frame:SetScript("OnEvent", Utils.Protect("find my family", function()
    -- the game's own /who window answers here too: only a search of ours is read
    if waiting and not waiting.answered then
        waiting.answered = true
        -- back on even if reading it goes wrong
        local ok, problem = pcall(Take)
        Unmute()
        if not ok then
            Utils.NoteError("find my family", problem)
        end
        Changed()
    end
end))
frame:RegisterEvent("WHO_LIST_UPDATE")
