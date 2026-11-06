local _, HC = ...

-- The crest maker: shape and pattern arrows, colors, a symbol, the dice and your motto. The setup's
-- first step and the settings' crest page each hold one. What you make is saved as you make it, so
-- every crest on screen follows (and your guild's, when you lead it as a family).
HC.CrestEditor = {}

local CrestEditor = HC.CrestEditor
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local WIDTH, HEIGHT = 620, 480
local PAD = 22

-- Plain names for the shapes and patterns: heraldry's own words are hard.
local SHAPE_NAMES = { Heater = "Shield", Round = "Round", Kite = "Kite", Banner = "Banner" }
local PATTERN_NAMES = { Plain = "Plain", Pale = "Split", Fess = "Halves", Bend = "Diagonal", Quarterly = "Quarters",
    Chevron = "Chevron", Cross = "Cross" }
-- the symbols' names where a word means something else too (the Tree tab)
local CHARGE_NAMES = { Tree = "A tree" }

-- The next or previous of `list` after `value`.
local function Step(list, value, delta)
    local index = 1
    for i, item in ipairs(list) do
        if item == value then
            index = i
        end
    end
    return list[(index - 1 + delta) % #list + 1]
end

-- A new maker on `parent` (place it with SetPoint; its text starts 54 down). `onEdit()` runs after
-- every change, for a Reset button. Fill it with :Load before showing it.
function CrestEditor.New(parent, onEdit)
    local ed = CreateFrame("Frame", nil, parent)
    ed:SetSize(WIDTH, HEIGHT)
    local crestBig, ribbon, shapeText, patternText, mottoBox
    local pickers = {}

    local function Told()
        if onEdit then
            onEdit()
        end
    end

    function ed:Save()
        Kin.SetCrest(self.draft, Utils.Trim(self.motto or ""))
        HC.Guild.CrestChanged()
    end

    function ed:Paint()
        local _, surname = Kin.House()
        crestBig:SetCrest(self.draft, surname)
        ribbon.text:SetText(surname and string.format(L["House %s"], surname) or L["Your house"])
        shapeText:SetText(L[SHAPE_NAMES[self.draft.shape]])
        patternText:SetText(L[PATTERN_NAMES[self.draft.division]])
        for _, picker in ipairs(pickers) do
            picker:Paint()
        end
    end

    local function Edited()
        ed:Save()
        ed:Paint()
        Told()
    end

    local function Arrow(direction, x, y, onClick)
        local arrow = Theme.Arrow(ed, direction, 44)
        arrow:SetPoint("CENTER", ed, "TOP", x, y)
        Theme.OnClick(arrow, "crest arrow", function()
            onClick(direction == "RIGHT" and 1 or -1)
            Edited()
        end)
        return arrow
    end

    -- A strip of choices that opens under its button: the colors, or the symbols.
    local function Strip(rows)
        local strip = CreateFrame("Frame", nil, ed)
        strip:SetSize(WIDTH - PAD * 2, rows * 36 + 14)
        strip:SetPoint("TOP", ed, "TOP", 0, -338)
        Theme.Panel(strip, "well")
        strip:Hide()
        return strip
    end

    local function ColorPicker(label, field, x)
        local button = Theme.Button(ed, label, "secondary", 116, 30)
        button:SetPoint("TOPLEFT", ed, "TOPLEFT", x, -294)
        -- the color in a dark rim, so it shows on a button of its own color
        button.rim = Theme.Texture(button, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 0, C.ink)
        button.rim:SetSize(16, 16)
        button.rim:SetPoint("LEFT", 8, 0)
        button.chip = Theme.Texture(button, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 1)
        button.chip:SetSize(12, 12)
        button.chip:SetPoint("CENTER", button.rim, "CENTER")
        button.labelX = 8
        local strip = Strip(1)
        strip.swatches = {}
        local count = #Crest.TINCTURES
        local cell = math.floor((strip:GetWidth() - 16) / count)
        for index, tincture in ipairs(Crest.TINCTURES) do
            local swatch = Theme.Swatch(strip, tincture.color, 20)
            swatch:SetPoint("LEFT", strip, "LEFT", 8 + (index - 1) * cell + (cell - swatch:GetWidth()) / 2, 0)
            swatch.key = tincture.key
            Theme.Tip(swatch, L[tincture.name] or tincture.name)
            Theme.OnClick(swatch, "color", function(self)
                ed.draft[field] = self.key
                Edited()
            end)
            strip.swatches[index] = swatch
        end
        function button:Paint()
            local color = Crest.Color(ed.draft[field])
            self.chip:SetVertexColor(color[1], color[2], color[3])
            for _, swatch in ipairs(strip.swatches) do
                swatch:SetChosen(swatch.key == ed.draft[field])
            end
            -- the second color only shows on a divided shield
            self:SetEnabled(field ~= "second" or ed.draft.division ~= "Plain")
            if field == "second" and ed.draft.division == "Plain" and ed.open == self then
                strip:Hide()
                ed.open = nil
            end
        end
        button.strip = strip
        Theme.PaintButton(button)
        return button
    end

    local function SymbolPicker(x)
        local button = Theme.Button(ed, L["Symbol"], "secondary", 116, 30)
        button:SetPoint("TOPLEFT", ed, "TOPLEFT", x, -294)
        local strip = Strip(2)
        strip.cells = {}
        local choices = { { symbol = "initial" } }
        for _, key in ipairs(Crest.CHARGES) do
            choices[#choices + 1] = { symbol = "charge", charge = key }
        end
        choices[#choices + 1] = { symbol = "none" }
        local perRow = 10
        local cell = math.floor((strip:GetWidth() - 16) / perRow)
        for index, choice in ipairs(choices) do
            local b = Theme.Button(strip, "", "secondary", cell - 6, 30)
            local column, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
            b:SetPoint("TOPLEFT", strip, "TOPLEFT", 8 + column * cell + 3, -7 - row * 36)
            if choice.symbol == "charge" then
                b.icon = Theme.Texture(b, Theme.Folder() .. "Charge\\" .. choice.charge, "ARTWORK", 1, C.text)
                b.icon:SetSize(22, 22)
                Theme.Tip(b, L[CHARGE_NAMES[choice.charge] or choice.charge])
            elseif choice.symbol == "initial" then
                local _, surname = Kin.House()
                b:SetText(Crest.Initial(surname) ~= "" and Crest.Initial(surname) or "A")
                Theme.Tip(b, L["Your initial"])
            else
                b:SetText("-")
                Theme.Tip(b, L["No symbol"])
            end
            Theme.PaintButton(b)
            b.choice = choice
            Theme.OnClick(b, "symbol", function(self)
                ed.draft.symbol, ed.draft.charge = self.choice.symbol, self.choice.charge
                Edited()
            end)
            strip.cells[index] = b
        end
        function button:Paint()
            for _, b in ipairs(strip.cells) do
                local chosen = b.choice.symbol == ed.draft.symbol
                    and (b.choice.symbol ~= "charge" or b.choice.charge == ed.draft.charge)
                Theme.SetKind(b, chosen and "primary" or "secondary")
            end
        end
        button.strip = strip
        return button
    end

    -- Opens a picker's strip (or closes it); one is open at a time.
    local function Toggle(picker)
        for _, other in ipairs(pickers) do
            if other ~= picker then
                other.strip:Hide()
                Theme.SetKind(other, "secondary")
            end
        end
        local open = not picker.strip:IsShown()
        picker.strip:SetShown(open)
        Theme.SetKind(picker, open and "primary" or "secondary")
        ed.open = open and picker or nil
    end

    local subtitle = Theme.Text(ed, "Body", C.text2)
    subtitle:SetPoint("TOPLEFT", PAD, -54)
    subtitle:SetText(L["The crest your family wears. Flip through with the arrows."])
    crestBig = Crest.Create(ed, 160)
    crestBig:SetPoint("TOP", ed, "TOP", 0, -78)
    local function Shape(delta)
        ed.draft.shape = Step(Crest.SHAPES, ed.draft.shape, delta)
    end
    local function Pattern(delta)
        ed.draft.division = Step(Crest.DIVISIONS, ed.draft.division, delta)
    end
    Arrow("LEFT", -140, -112, Shape)
    Arrow("RIGHT", 140, -112, Shape)
    Arrow("LEFT", -140, -188, Pattern)
    Arrow("RIGHT", 140, -188, Pattern)
    local function Caption(text, y)
        local caption = Theme.Text(ed, "Tiny", C.text3)
        caption:SetPoint("RIGHT", ed, "TOP", -172, y + 8)
        caption:SetJustifyH("RIGHT")
        caption:SetText(text)
        local value = Theme.Text(ed, "Small", C.text2)
        value:SetPoint("RIGHT", ed, "TOP", -172, y - 8)
        value:SetJustifyH("RIGHT")
        return value
    end
    shapeText = Caption(L["SHAPE"], -112)
    patternText = Caption(L["PATTERN"], -188)
    ribbon = Theme.Ribbon(ed, 280, 32)
    ribbon:SetPoint("TOP", ed, "TOP", 0, -244)
    pickers = {
        ColorPicker(L["Main"], "field", 52),
        ColorPicker(L["Second"], "second", 176),
        ColorPicker(L["Rim"], "metal", 300),
        SymbolPicker(424),
    }
    for _, picker in ipairs(pickers) do
        Theme.OnClick(picker, "picker", function(self)
            Toggle(self)
        end)
    end
    local dice = Theme.IconButton(ed, "Dice", 30, L["Surprise me"], L["A random crest. Click again for another."])
    dice:SetPoint("LEFT", pickers[4], "RIGHT", 10, 0)
    Theme.OnClick(dice, "dice", function()
        ed.draft = Crest.Random()
        Edited()
    end)
    local mottoLabel = Theme.Text(ed, "Small", C.text2)
    mottoLabel:SetPoint("TOPLEFT", PAD + 30, -446)
    mottoLabel:SetText(L["Motto"])
    mottoBox = Theme.EditBox(ed, 360, L["A few words for your family"], nil, 40)
    mottoBox:SetPoint("LEFT", mottoLabel, "RIGHT", 12, 0)
    mottoBox.onChange = function(text)
        ed.motto = text
        Told()
    end
    -- the motto is saved when you're done typing it
    mottoBox.edit:HookScript("OnEditFocusLost", function()
        ed:Save()
    end)

    -- Shows this crest and motto (and with `openPicker`, the number of the picker to open).
    function ed:Load(crest, motto, openPicker)
        self.draft = Utils.Copy(crest)
        self.motto = motto or ""
        mottoBox.edit:SetText(self.motto)
        self.open = nil
        for index, picker in ipairs(pickers) do
            local open = openPicker == index
            picker.strip:SetShown(open)
            Theme.SetKind(picker, open and "primary" or "secondary")
            self.open = open and picker or self.open
        end
        self:Paint()
    end

    -- The number of the open picker, to open it again in a new look.
    function ed:OpenPicker()
        for index, picker in ipairs(pickers) do
            if picker == self.open then
                return index
            end
        end
    end

    -- Whether it's changed from this crest and motto.
    function ed:Changed(crest, motto)
        return not Utils.Same(self.draft, crest) or Utils.Trim(self.motto or "") ~= Utils.Trim(motto or "")
    end

    -- Done typing: what's in the motto box is saved.
    function ed:Blur()
        mottoBox.edit:ClearFocus()
    end

    return ed
end
