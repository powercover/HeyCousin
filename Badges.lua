local _, HC = ...

-- Family achievements: small things your family does, kept with your house. Never in your way: no
-- pop-up and no sound, one quiet line in chat when you earn one (one line for several, and a setting
-- turns it off), and what you'd already done when they came counts without a word. The Stats tab's
-- star opens the list.
HC.Badges = {}

local Badges = HC.Badges
local Utils = HC.Utils
local Theme = HC.Theme
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local WIDTH = 420
local ROW = 40
local TOP = 92
local SAY_AFTER = 2  -- several at once are one line

-- Each one: its key, icon, name and how to earn it (functions: in the language chosen when shown).
-- `check(house, counts)` says whether you have it from what the family knows; the others are earned
-- when they happen (Badges.Earn).
local function Eldest(house)
    local eldest = Kin.Eldest()
    if not eldest then
        return false
    end
    local relative = house.relatives[eldest]
    return eldest == (HC.Names.Me()) or (relative ~= nil and (relative.met or 0) >= 1)
end

local function OldFriends(house)
    for _, relative in pairs(house.relatives) do
        if (relative.met or 0) >= 10 then
            return true
        end
    end
    return false
end

local LIST = {
    { key = "first", icon = "Star",
        name = function() return L["First cousin"] end,
        how = function() return L["Meet or find a cousin."] end,
        check = function(_, counts) return counts.total >= 1 end },
    { key = "ten", icon = "Star",
        name = function() return L["A real family"] end,
        how = function() return L["Know 10 cousins."] end,
        check = function(_, counts) return counts.total >= 10 end },
    { key = "fifty", icon = "Crown",
        name = function() return L["A great house"] end,
        how = function() return L["Know 50 cousins."] end,
        check = function(_, counts) return counts.total >= 50 end },
    { key = "sheep", icon = "Sheep",
        name = function() return L["The black sheep"] end,
        how = function() return L["Find a cousin on the other side."] end,
        check = function(_, counts) return counts.sheep >= 1 end },
    { key = "eldest", icon = "Crown",
        name = function() return L["Respect your elders"] end,
        how = function() return L["Meet the cousin who looks like the eldest, or be them."] end,
        check = Eldest },
    { key = "friends", icon = "Check",
        name = function() return L["Old friends"] end,
        how = function() return L["Meet one cousin 10 times."] end,
        check = OldFriends },
    { key = "hey", icon = "Sound",
        name = function() return L["Hey cousin!"] end,
        how = function() return L["Wave at a cousin."] end },
    { key = "fam", icon = "Whisper",
        name = function() return L["Family talk"] end,
        how = function() return L["Talk in family chat (/fam)."] end },
    { key = "reunion", icon = "Invite",
        name = function() return L["Family reunion!"] end,
        how = function() return L["Be in a group with a cousin."] end },
    { key = "raid", icon = "Portal",
        name = function() return L["A family raid!"] end,
        how = function() return L["Be in a group with four cousins."] end },
    { key = "apart", icon = "Search",
        name = function() return L["Long time no see!"] end,
        how = function() return L["Meet a cousin again after two weeks apart."] end },
}
Badges.LIST = LIST

local window, rows, count
local fresh = {}  -- earned a moment ago: the next line in chat names them

-- Your house's achievements, { [key] = time() earned }. The first time, what you've already done
-- counts, without a word.
local function Earned()
    local house = Kin.House()
    if not house then
        return nil
    end
    if type(house.badges) ~= "table" then
        house.badges = {}
        Badges.Check(true)
    end
    return house.badges
end

local function Counts()
    local total, _, sheep = Kin.Counts()
    return { total = total, sheep = sheep }
end

local Say = Utils.Debounce(SAY_AFTER, "achievements", function()
    local names = fresh
    fresh = {}
    if #names == 0 or (type(HeyCousinDB) == "table" and HeyCousinDB.badgeLines == false) then
        return
    end
    if #names == 1 then
        Utils.Print(string.format(L["Family achievement: %s"], names[1]))
    else
        Utils.Print(string.format(L["%d new family achievements. They're on the Stats tab."], #names))
    end
end)

local function Give(entry, quiet)
    local earned = Kin.House().badges
    if earned[entry.key] then
        return
    end
    earned[entry.key] = time()
    if not quiet then
        fresh[#fresh + 1] = entry.name()
        Say()
    end
    if window and window:IsShown() then
        Badges.Paint()
    end
end

-- Looks at what the family knows for the ones it can tell; `quiet`: no line for them.
function Badges.Check(quiet)
    local house = Kin.House()
    if not house or type(house.badges) ~= "table" then
        if house then
            Earned()
        end
        return
    end
    local counts = Counts()
    for _, entry in ipairs(LIST) do
        if entry.check and not house.badges[entry.key] then
            local ok, has = pcall(entry.check, house, counts)
            if ok and has then
                Give(entry, quiet)
            end
        end
    end
end

-- At login: what you'd already done before achievements came counts now, without a word, so the
-- next new thing is the first line.
function Badges.Start()
    Earned()
end

-- One that's earned when it happens: "hey", "fam", "reunion", "raid", "apart".
function Badges.Earn(key)
    if HC.TestMode.active or not Earned() then
        return
    end
    for _, entry in ipairs(LIST) do
        if entry.key == key then
            Give(entry)
        end
    end
end

-- How many you have, and how many there are.
function Badges.Count()
    local earned = Earned() or {}
    local have = 0
    for _, entry in ipairs(LIST) do
        if earned[entry.key] then
            have = have + 1
        end
    end
    return have, #LIST
end

-- --- the list ---------------------------------------------------------------------------------

local function Build()
    window = Theme.Window("HeyCousinBadges", WIDTH, TOP + #LIST * ROW + 24)
    window:SetFrameStrata("DIALOG")
    local heading = Theme.Text(window, "Title")
    heading:SetPoint("TOPLEFT", 20, -20)
    heading:SetPoint("RIGHT", window.close, "LEFT", -8, 0)
    heading:SetText(L["Family achievements"])
    local title = Theme.Title()
    heading:SetTextColor(title[1], title[2], title[3])
    count = Theme.Text(window, "Small", C.text2)
    count:SetPoint("TOPLEFT", 20, -56)
    rows = {}
    for index, entry in ipairs(LIST) do
        local row = CreateFrame("Frame", nil, window)
        row:SetSize(WIDTH - 40, ROW)
        row:SetPoint("TOPLEFT", 20, -TOP - (index - 1) * ROW)
        row.icon = Theme.Texture(row, Theme.Icon(entry.icon), "ARTWORK", 0)
        row.icon:SetSize(22, 22)
        row.icon:SetPoint("LEFT", 4, 0)
        row.name = Theme.Text(row, "Body")
        row.name:SetPoint("TOPLEFT", 38, -3)
        row.name:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.line = Theme.Text(row, "Small", C.text3)
        row.line:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
        row.line:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.entry = entry
        rows[index] = row
    end
end

function Badges.Paint()
    if not window then
        return
    end
    local earned = Earned() or {}
    local have, all = Badges.Count()
    count:SetText(string.format(L["%d of %d"], have, all))
    for _, row in ipairs(rows) do
        local at = earned[row.entry.key]
        row.name:SetText(row.entry.name())
        local color = at and C.gold or C.text3
        row.icon:SetVertexColor(color[1], color[2], color[3], at and 1 or 0.5)
        row.name:SetTextColor(at and C.text[1] or C.text3[1], at and C.text[2] or C.text3[2], at and C.text[3] or C.text3[3])
        row.line:SetText(at and string.format(L["Earned %s"], Utils.When(at)) or row.entry.how())
    end
end

function Badges.Show()
    if not window then
        Build()
    end
    Badges.Paint()
    window:Show()
end

function Badges.Toggle()
    if window and window:IsShown() then
        window:Hide()
    else
        Badges.Show()
    end
end

Kin.OnChange(function()
    Badges.Check()
end)

-- A new look: the list is built again in it.
Theme.OnSkin(function()
    if not window then
        return
    end
    local shown = window:IsShown()
    window:Hide()
    window = nil
    if shown then
        Badges.Show()
    end
end)
