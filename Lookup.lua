local _, HC = ...

-- Look up a family: who's online with any surname, by the same /who search as Find my family, and
-- among the players the game shows you (your group: /who lists your own realm only). It's a
-- look at another house: nobody joins your family by it. Each search needs a click of its own (or
-- Enter), and the game lists 50 people at most.
HC.Lookup = {}

local Lookup = HC.Lookup
local Utils = HC.Utils
local Theme = HC.Theme
local L = HC.L
local C = Theme.C

local WIDTH, HEIGHT = 440, 500
local PAD = 20
local ROW = 42
local NAME_MAX = 24
local WHITE = "Interface\\Buttons\\WHITE8X8"

local window, box, button, status, list
local asked       -- the surname of the last search
local results     -- what it found: nil until it answers
local full        -- the game's list was full: there may be more

local function Paint(keep)
    if not window or not window:IsShown() then
        return
    end
    local looking = HC.Find.Waiting()
    button:SetEnabled(not looking and #Utils.Trim(box.edit:GetText() or "") >= 2)
    if results then
        local count = #results
        if count == 0 then
            status:SetText(string.format(L["Nobody with the surname %s is online right now."], asked))
        else
            status:SetText(string.format(L["House %s: %d online"], asked, count)
                .. (full and ("  " .. L["The game lists 50 at a time: there may be more."]) or ""))
        end
    elseif asked and looking then
        status:SetText(L["Looking..."])
    elseif asked then
        status:SetText(L["The game didn't answer. Try again in a moment."])
    else
        status:SetText(L["Who's online with any surname? Type it, and press Enter."])
    end
    list:SetItems(results or {}, keep)
end

-- Called when a search starts or ends (Find.lua).
function Lookup.Changed()
    Paint(true)
end

-- One search. Call it from a click or Enter: the game takes these only from one.
function Lookup.Search(text)
    local surname = HC.Guild.Plain(text, NAME_MAX):gsub('["%s]', "")
    if #surname < 2 or HC.Find.Waiting() then
        return
    end
    asked, results, full = surname, nil, false
    HC.Find.Lookup(surname, function(rows, more)
        results, full = rows, more
        Paint()
    end)
    Paint()
end

local function NewRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.line = Theme.Texture(row, WHITE, "BACKGROUND", 1, C.line)
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT", 8, 0)
    row.line:SetPoint("BOTTOMRIGHT", -8, 0)
    row.avatar = Theme.Skin().Avatar(row, 26)
    row.avatar:SetPoint("LEFT", 8, 0)
    row.whisper = Theme.IconButton(row, "Whisper", 26, L["Whisper"])
    row.whisper:SetPoint("RIGHT", -4, 0)
    Theme.OnClick(row.whisper, "look up whisper", function(self)
        local item = self:GetParent().item
        if item and HC.TestMode.active then
            Utils.Print(L["Test mode: made-up cousins can't hear you."])
        elseif item then
            HC.Recruit.OpenChat("/w " .. item.full .. " ")
        end
    end)
    row.name = Theme.Text(row, "Body")
    row.name:SetPoint("TOPLEFT", 44, -5)
    row.name:SetPoint("RIGHT", row.whisper, "LEFT", -6, 0)
    row.where = Theme.Text(row, "Small", C.text2)
    row.where:SetPoint("TOPLEFT", 44, -23)
    row.where:SetPoint("RIGHT", row.whisper, "LEFT", -6, 0)
    return row
end

local function PaintRow(row, item)
    local color = Utils.ClassColor(item.class)
    row.avatar.icon:SetShown(Utils.SetClassIcon(row.avatar.icon, item.class))
    row.avatar.ring:SetVertexColor(color[1], color[2], color[3], 0.9)
    row.name:SetText(item.first .. "  " .. Theme.Paint(item.level or "", C.text3))
    row.name:SetTextColor(color[1], color[2], color[3])
    local where = item.zone or ""
    if Utils.IsUsableString(item.guild) then
        where = where ~= "" and (where .. Theme.Sep() .. item.guild) or item.guild
    end
    row.where:SetText(where)
end

local function Build()
    window = Theme.Window("HeyCousinLookup", WIDTH, HEIGHT)
    window:SetFrameStrata("DIALOG")
    local heading = Theme.Text(window, "Title")
    heading:SetPoint("TOPLEFT", PAD, -20)
    heading:SetPoint("RIGHT", window.close, "LEFT", -8, 0)
    heading:SetText(L["Look up a family"])
    local title = Theme.Title()
    heading:SetTextColor(title[1], title[2], title[3])
    button = Theme.Button(window, L["Search"], "primary", 80, 30)
    button:SetPoint("TOPRIGHT", -PAD, -56)
    Theme.Fit(button, 12, 80)
    box = Theme.EditBox(window, 200, L["A surname"], "Search", NAME_MAX)
    box:SetPoint("TOPLEFT", PAD, -56)
    box:SetPoint("RIGHT", button, "LEFT", -6, 0)
    box.onChange = function()
        Paint(true)
    end
    local function Go()
        box.edit:ClearFocus()
        Lookup.Search(box.edit:GetText())
    end
    box.edit:SetScript("OnEnterPressed", Utils.Protect("look up", Go))
    Theme.OnClick(button, "look up", Go)
    status = Theme.Text(window, "Small", C.text2)
    status:SetPoint("TOPLEFT", PAD, -94)
    status:SetPoint("RIGHT", window, "RIGHT", -PAD, 0)
    list = Theme.List(window, ROW, NewRow, PaintRow)
    list:SetPoint("TOPLEFT", PAD, -116)
    list:SetPoint("BOTTOMRIGHT", -PAD, 18)
    window:HookScript("OnShow", function()
        Paint()
    end)
    window:HookScript("OnHide", function()
        box.edit:ClearFocus()
    end)
end

-- Opens the window; with `surname`, searches for it (from a command: Enter counts as a click).
function Lookup.Show(surname)
    if not window then
        Build()
    end
    window:Show()
    if asked and not surname then
        box.edit:SetText(asked)
    end
    if surname then
        box.edit:SetText(surname)
        Lookup.Search(surname)
    end
end

-- A new look: the window is built again in it, with what it found.
Theme.OnSkin(function()
    if not window then
        return
    end
    local shown = window:IsShown()
    window:Hide()
    window = nil
    if shown then
        Lookup.Show()
    end
end)
