local _, HC = ...

-- Who in my family has it? You name one item; every cousin online whose addon answers says how many
-- they have, bags and bank (the game keeps the count from their last bank visit). Nothing is ever
-- looked through in the background: an answer is one count from the game, for the item asked about,
-- and only that number goes back. One cousin can't wear anyone out: each addon answers a cousin once
-- in ASKER_GAP seconds and ANSWERS_MAX times a minute at most, the rest go unanswered. A setting stops
-- the answers altogether.
HC.Stock = {}

local Stock = HC.Stock
local Utils = HC.Utils

local WAIT = 4          -- the answers come within this long
local REST = 5          -- between your searches
local ASKER_GAP = 10    -- one answer to the same cousin this often
local ANSWERS_MAX = 6   -- answers a minute, to everyone together

local asking            -- the last search: { id, item, name, at, done, answers = { [first] = count } }
local lastAsk = -REST
local answeredAt = {}   -- [first name] = GetTime() of the last answer to them
local minuteFrom, minuteCount = 0, 0

function Stock.On()
    return type(HeyCousinDB) ~= "table" or HeyCousinDB.answerItems ~= false
end

local function Changed()
    HC.Window.Refresh(true)
end

-- An item from what you typed: its number, from a link, a number, or a name the game knows.
function Stock.Resolve(text)
    if not Utils.IsUsableString(text) then
        return nil
    end
    local id = tonumber(text:match("item:(%d+)")) or tonumber(Utils.Trim(text))
    if not id then
        local find = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        id = Utils.Call(find, Utils.Trim(text))
    end
    if not Utils.IsUsableNumber(id) or id <= 0 then
        return nil
    end
    local name = Utils.Call(C_Item and C_Item.GetItemNameByID, id)
    return id, Utils.IsUsableString(name) and name or Utils.Trim(text)
end

-- How many of an item you have, bags and bank.
local function Count(id)
    local count = Utils.Call((C_Item and C_Item.GetItemCount) or GetItemCount, id, true)
    return Utils.IsUsableNumber(count) and count or 0
end

-- Asks the family. False and why when it can't now: "wait" (a search a moment ago), "unknown" (no
-- such item the game knows), "off" (family messages are off), "channel" (not ready yet).
function Stock.Ask(text)
    local now = GetTime()
    if now - lastAsk < REST then
        return false, "wait"
    end
    local id, name = Stock.Resolve(text)
    if not id then
        return false, "unknown"
    end
    if not HC.Family.Messages() then
        return false, "off"
    end
    local query = math.random(1, 9999)
    if HC.TestMode.active then
        asking = { id = query, item = id, name = name, at = now, answers = {} }
        -- (made-up cousins answer in test mode)
        local made = 0
        for first in pairs(HC.TestMode.House().relatives) do
            made = made + 1
            if made <= 2 then
                asking.answers[first] = made * 7
            end
        end
    elseif HC.Family.Send("6:Q:" .. query .. ":" .. id) then
        asking = { id = query, item = id, name = name, at = now, answers = {} }
    else
        return false, "channel"
    end
    lastAsk = now
    local run = asking
    Utils.After(WAIT, "who has it", function()
        run.done = true
        Changed()
    end)
    Changed()
    return true
end

-- The last search, while it's fresh enough to show.
function Stock.Current()
    return asking
end

-- Its answers: { first, count } each, the most first.
function Stock.Answers()
    local rows = {}
    for first, count in pairs(asking and asking.answers or {}) do
        rows[#rows + 1] = { first = first, count = count }
    end
    table.sort(rows, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.first < b.first
    end)
    return rows
end

-- A question (Q) or an answer (R) from a cousin (Share.Heard has checked who it's from).
function Stock.Heard(kind, rest, member)
    if kind == "Q" then
        local query, id = rest:match("^(%d+):(%d+)$")
        if not query or not Stock.On() or HC.TestMode.active then
            return
        end
        local now = GetTime()
        if answeredAt[member.first] and now - answeredAt[member.first] < ASKER_GAP then
            return
        end
        if now - minuteFrom >= 60 then
            minuteFrom, minuteCount = now, 0
        end
        if minuteCount >= ANSWERS_MAX then
            return
        end
        answeredAt[member.first] = now
        minuteCount = minuteCount + 1
        local count = Count(tonumber(id))
        if count > 0 then
            HC.Family.Whisper("6:R:" .. query .. ":" .. id .. ":" .. count, member.full)
        end
    elseif kind == "R" then
        local query, id, count = rest:match("^(%d+):(%d+):(%d+)$")
        if asking and query and tonumber(query) == asking.id and tonumber(id) == asking.item then
            asking.answers[member.first] = math.min(tonumber(count), 99999)
            Changed()
        end
    end
end
