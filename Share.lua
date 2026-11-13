local _, HC = ...

-- What cousins' addons tell each other to play together: your professions and their skill (the
-- Crafters page), and the numbers of the quests you're on (same quests, quest buddies). Each is a
-- setting, on unless you say. Only cousins on your family list get it: after your hello, and when it
-- changes, a while later. The other "6:" lines go on to Stock.lua (who has it) and Help.lua.
HC.Share = {}

local Share = HC.Share
local Utils = HC.Utils
local Kin = HC.Kin

local CRAFTS_MAX = 6
local QUESTS_MAX = 35
local QUESTS_FRESH = 3 * 86400  -- a cousin's quests older than this are left out
local BUDDY_LEVELS = 3

local function Settings()
    return type(HeyCousinDB) == "table" and HeyCousinDB or {}
end

function Share.CraftsOn()
    return Settings().shareCrafts ~= false
end

function Share.QuestsOn()
    return Settings().shareQuests ~= false
end

-- --- yours -------------------------------------------------------------------------------------

-- Your professions: { line = the game's skill line, rank, name } each.
function Share.MyCrafts()
    local list = {}
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return list
    end
    local found = { Utils.Call(GetProfessions) }
    for index = 1, 5 do
        local slot = found[index]
        if Utils.IsUsableNumber(slot) then
            local name, _, rank, _, _, _, line = Utils.Call(GetProfessionInfo, slot)
            if Utils.IsUsableString(name) and Utils.IsUsableNumber(rank) and Utils.IsUsableNumber(line) then
                list[#list + 1] = { line = line, rank = rank, name = name }
            end
        end
    end
    return list
end

-- The numbers of the quests in your log, and their titles.
function Share.MyQuests()
    local ids, titles = {}, {}
    local log = C_QuestLog
    local count = log and Utils.Call(log.GetNumQuestLogEntries) or 0
    for index = 1, Utils.IsUsableNumber(count) and count or 0 do
        local info = Utils.Call(log.GetInfo, index)
        if type(info) == "table" and not info.isHeader and Utils.IsUsableNumber(info.questID) and info.questID > 0 then
            ids[#ids + 1] = info.questID
            titles[info.questID] = Utils.IsUsableString(info.title) and info.title or nil
            if #ids >= QUESTS_MAX then
                break
            end
        end
    end
    return ids, titles
end

local function CraftsLine()
    local parts = {}
    if Share.CraftsOn() then
        for _, craft in ipairs(Share.MyCrafts()) do
            local name = HC.Guild.Plain(craft.name, 24):gsub("[;,:]", "")
            parts[#parts + 1] = craft.line .. "," .. craft.rank .. "," .. name
        end
    end
    return "6:P:" .. table.concat(parts, ";")
end

local function QuestsLine()
    return "6:U:" .. (Share.QuestsOn() and table.concat((Share.MyQuests()), ",") or "")
end

-- Sends what changed since the last time, to every cousin: what's off goes as nothing, so it leaves
-- their lists.
local sent = {}
local function SendChanged()
    if HC.TestMode.active or not HC.Family.Messages() then
        return
    end
    for _, line in ipairs({ CraftsLine(), QuestsLine() }) do
        local kind = line:sub(3, 3)
        if sent[kind] ~= line and HC.Family.Send(line) then
            sent[kind] = line
        end
    end
end

local sendSoon = Utils.Debounce(30, "share", SendChanged)

-- A switch changed: what it shares goes, or leaves, now.
function Share.Changed()
    SendChanged()
end

-- After your hello (to everyone) or your answer to a cousin's (`target`).
HC.Family.OnHello(function(target)
    if HC.TestMode.active then
        return
    end
    for _, line in ipairs({ CraftsLine(), QuestsLine() }) do
        if target then
            HC.Family.Whisper(line, target)
        elseif HC.Family.Send(line) then
            sent[line:sub(3, 3)] = line
        end
    end
end)

-- --- theirs ------------------------------------------------------------------------------------

local function Learn(member)
    return Kin.Seen({ first = member.first, faction = Utils.Call(UnitFactionGroup, "player"), quiet = true,
        online = true, usesAddon = true })
end

-- A "6:" line from a cousin.
function Share.Heard(text, sender)
    local member = HC.Family.Cousin(sender)
    local kind, rest = text:match("^6:(%u):?(.*)$")
    if not member or not kind then
        return
    end
    if kind == "P" then
        local relative = Learn(member)
        if relative then
            local crafts = {}
            for entry in rest:gmatch("[^;]+") do
                local line, rank, name = entry:match("^(%d+),(%d+),(.*)$")
                name = name and HC.Guild.Plain(name, 24)
                if line and name and name ~= "" and #crafts < CRAFTS_MAX then
                    crafts[#crafts + 1] = { line = tonumber(line), rank = tonumber(rank), name = name }
                end
            end
            relative.crafts = #crafts > 0 and crafts or nil
            Kin.Changed()
        end
    elseif kind == "U" then
        local relative = Learn(member)
        if relative then
            local ids = {}
            for id in rest:gmatch("%d+") do
                if #ids < QUESTS_MAX then
                    ids[#ids + 1] = tonumber(id)
                end
            end
            relative.quests, relative.questsAt = #ids > 0 and ids or nil, time()
            Kin.Changed()
        end
    elseif kind == "Q" or kind == "R" then
        HC.Stock.Heard(kind, rest, member)
    elseif kind == "H" or kind == "Y" then
        HC.Help.Heard(kind, rest, member)
    end
end

-- The quests a relative is on that you're on too: { id, title } each, by your log's order.
function Share.SameQuests(relative)
    local same = {}
    if type(relative) ~= "table" or type(relative.quests) ~= "table"
        or time() - (relative.questsAt or 0) > QUESTS_FRESH then
        return same
    end
    local theirs = {}
    for _, id in ipairs(relative.quests) do
        theirs[id] = true
    end
    local mine, titles = Share.MyQuests()
    for _, id in ipairs(mine) do
        if theirs[id] then
            same[#same + 1] = { id = id, title = titles[id] or tostring(id) }
        end
    end
    return same
end

-- Who crafts what: { first, relative, craft } each, by profession, the most skilled first.
function Share.Crafters()
    local rows = {}
    for _, entry in ipairs(Kin.List()) do
        for _, craft in ipairs(type(entry.relative.crafts) == "table" and entry.relative.crafts or {}) do
            rows[#rows + 1] = { first = entry.first, relative = entry.relative, craft = craft }
        end
    end
    table.sort(rows, function(a, b)
        if a.craft.name ~= b.craft.name then
            return a.craft.name < b.craft.name
        end
        return (a.craft.rank or 0) > (b.craft.rank or 0)
    end)
    return rows
end

-- Cousins online within a few levels of you, to play with: the ones in your zone first, then the ones
-- on most of your quests. { first, relative, same, here } each.
function Share.Buddies()
    local mine = Utils.Call(UnitLevel, "player") or 0
    local zone = Utils.Zone()
    local rows = {}
    for _, entry in ipairs(Kin.List()) do
        local relative = entry.relative
        local level = relative.level
        if (Kin.IsOnline(entry.first) or Kin.IsNear(entry.first)) and not Kin.IsBlackSheep(relative)
            and Utils.IsUsableNumber(level) and math.abs(level - mine) <= BUDDY_LEVELS then
            rows[#rows + 1] = { first = entry.first, relative = relative, same = #Share.SameQuests(relative),
                here = zone ~= nil and relative.zone == zone }
        end
    end
    table.sort(rows, function(a, b)
        if a.here ~= b.here then
            return a.here
        end
        if a.same ~= b.same then
            return a.same > b.same
        end
        return a.first < b.first
    end)
    return rows
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", Utils.Protect("share", function()
    sendSoon()
end))
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_REMOVED")
frame:RegisterEvent("SKILL_LINES_CHANGED")

-- (for the tests: the lines it would send)
Share.CraftsLine, Share.QuestsLine = CraftsLine, QuestsLine
