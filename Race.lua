local _, HC = ...

-- The family race: you and the cousins who have the addon, by level. Only they count: their addons
-- tell their levels as they play, where anyone else's would be as old as the last time you saw them.
HC.Race = {}

local Race = HC.Race
local Utils = HC.Utils
local Theme = HC.Theme
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local ROW = 34
local MOST_LEVEL = 60
local BAR_W = 200
local WHITE = "Interface\\Buttons\\WHITE8X8"

local panel, list, empty

-- Everyone in the race, the highest level first: { first, class, level, me }.
function Race.List()
    local items = {}
    local _, class = Utils.Call(UnitClass, "player")
    local first = Names.Me()
    if first then
        items[1] = { first = first, class = class, level = Utils.Call(UnitLevel, "player") or 0, me = true }
    end
    local house = Kin.House()
    for name, relative in pairs(house and house.relatives or {}) do
        if relative.usesAddon and relative.level and not Kin.IsBlackSheep(relative) then
            items[#items + 1] = { first = name, class = relative.class, level = relative.level }
        end
    end
    table.sort(items, function(a, b)
        if a.level ~= b.level then
            return a.level > b.level
        end
        return a.first < b.first
    end)
    return items
end

local function NewRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.line = Theme.Texture(row, WHITE, "BACKGROUND", 1, C.line)
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT", 8, 0)
    row.line:SetPoint("BOTTOMRIGHT", -8, 0)
    row.mine = Theme.Texture(row, WHITE, "BACKGROUND", 0, C.selected)
    row.mine:SetAllPoints()
    row.rank = Theme.Text(row, "Body", C.text3)
    row.rank:SetPoint("LEFT", 8, 0)
    row.rank:SetWidth(26)
    row.rank:SetJustifyH("RIGHT")
    row.avatar = Theme.Skin().Avatar(row, 22)
    row.avatar:SetPoint("LEFT", 40, 0)
    row.name = Theme.Text(row, "Body")
    row.name:SetPoint("LEFT", 70, 0)
    row.name:SetWidth(130)
    row.back = Theme.Texture(row, WHITE, "ARTWORK", 0, C.ink)
    row.back:SetPoint("LEFT", 206, 0)
    row.back:SetSize(BAR_W, 10)
    row.bar = Theme.Texture(row, WHITE, "ARTWORK", 1)
    row.bar:SetPoint("LEFT", row.back, "LEFT", 0, 0)
    row.bar:SetHeight(10)
    row.level = Theme.Text(row, "Body", C.text2)
    row.level:SetPoint("RIGHT", -8, 0)
    row.level:SetWidth(32)
    row.level:SetJustifyH("RIGHT")
    return row
end

local function PaintRow(row, item, index)
    local color = Utils.ClassColor(item.class)
    row.mine:SetShown(item.me == true)
    row.rank:SetText(index .. ".")
    local top = index <= 3 and Theme.Title() or C.text3
    row.rank:SetTextColor(top[1], top[2], top[3])
    row.avatar.icon:SetShown(Utils.SetClassIcon(row.avatar.icon, item.class))
    row.avatar.ring:SetVertexColor(color[1], color[2], color[3], 0.9)
    row.name:SetText(item.me and (item.first .. " " .. L["(you)"]) or item.first)
    row.name:SetTextColor(color[1], color[2], color[3])
    row.level:SetText(item.level)
    row.bar:SetVertexColor(color[1], color[2], color[3])
    row.bar:SetWidth(math.max(1, BAR_W * math.min(1, item.level / MOST_LEVEL)))
end

-- The page, under the window's tabs: `x` and `top` from the window's corner, `bottom` from its foot.
function Race.Build(window, x, top, bottom)
    panel = CreateFrame("Frame", nil, window)
    panel:SetPoint("TOPLEFT", window, "TOPLEFT", x, -top)
    panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -x, bottom)
    panel:Hide()
    local back = Theme.IconButton(panel, "ChevronLeft", 26, L["Stats"])
    back:SetPoint("TOPLEFT", 0, -2)
    Theme.OnClick(back, "back to the stats", function()
        HC.Window.Race(false)
    end)
    local title = Theme.Text(panel, "Headline")
    title:SetPoint("LEFT", back, "RIGHT", 10, 0)
    title:SetText(L["Family race"])
    local note = Theme.Text(panel, "Small", C.text2)
    note:SetPoint("TOPLEFT", 0, -36)
    note:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    note:SetText(L["You and the cousins who have the addon: their levels come as they play."])
    list = Theme.List(panel, ROW, NewRow, PaintRow)
    list:SetPoint("TOPLEFT", 0, -60)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    empty = Theme.Text(panel, "Body", C.text2)
    empty:SetPoint("TOP", list, "TOP", 0, -60)
    empty:SetWidth(340)
    empty:SetWordWrap(true)
    empty:SetJustifyH("CENTER")
    empty:SetText(L["No other cousin with the addon yet. Tell your family about it!"])
    return panel
end

function Race.Paint(keep)
    local items = Race.List()
    list:SetItems(items, keep)
    empty:SetShown(#items <= 1)
end

-- The first few, in a line.
function Race.Line()
    local parts = {}
    for index, item in ipairs(Race.List()) do
        if index > 3 then
            break
        end
        parts[#parts + 1] = Theme.Paint(index .. ". ", C.text3) .. Theme.Paint(item.first, Utils.ClassColor(item.class))
            .. Theme.Paint(" " .. item.level, C.text2)
    end
    return table.concat(parts, "   ")
end
