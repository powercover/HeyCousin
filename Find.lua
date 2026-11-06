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
        Utils.Call(friends and friends.SetWhoToUi, true)
        Utils.Call(friends and friends.SendWho, Search(surname))
    end
    Changed()
    Utils.After(test and test.active and TEST_WAIT or WAIT, "find my family", function()
        if test and test.active then
            run.answered = true
            Take()
        elseif not run.answered then
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
        Take()
        Changed()
    end
end))
frame:RegisterEvent("WHO_LIST_UPDATE")
