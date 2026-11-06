local _, HC = ...

-- The family portrait: your house on one card, made to be a good picture: crest, name, motto, the
-- family in numbers, and the cousins you've met most.
HC.Portrait = {}

local Portrait = HC.Portrait
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local WIDTH, HEIGHT = 440, 610
local COUSINS = 12
local PER_ROW = 4

local window, crest, ribbon, motto, counts, eldest, faces, none

local function Build()
    window = Theme.Window("HeyCousinPortrait", WIDTH, HEIGHT)
    window:SetFrameStrata("DIALOG")
    crest = Crest.Create(window, 180)
    crest:SetPoint("TOP", 0, -24)
    ribbon = Theme.Ribbon(window, 320, 36)
    ribbon:SetPoint("TOP", 0, -212)
    motto = Theme.Text(window, "Body", C.text2)
    motto:SetPoint("TOP", 0, -256)
    motto:SetWidth(WIDTH - 40)
    motto:SetJustifyH("CENTER")
    counts = Theme.Text(window, "Small", C.text2)
    counts:SetPoint("TOP", 0, -282)
    counts:SetWidth(WIDTH - 40)
    counts:SetJustifyH("CENTER")
    eldest = Theme.Text(window, "Small", C.gold)
    eldest:SetPoint("TOP", 0, -302)
    eldest:SetWidth(WIDTH - 40)
    eldest:SetJustifyH("CENTER")
    -- the cousins met most, each with their class and name
    faces = {}
    local cellW, cellH = (WIDTH - 40) / PER_ROW, 76
    for index = 1, COUSINS do
        local face = CreateFrame("Frame", nil, window)
        face:SetSize(cellW, cellH)
        local column, row = (index - 1) % PER_ROW, math.floor((index - 1) / PER_ROW)
        face:SetPoint("TOPLEFT", 20 + column * cellW, -330 - row * cellH)
        face.avatar = Theme.Skin().Avatar(face, 38)
        face.avatar:SetPoint("TOP", 0, -4)
        face.name = Theme.Text(face, "Small")
        face.name:SetPoint("TOP", 0, -48)
        face.name:SetWidth(cellW - 4)
        face.name:SetJustifyH("CENTER")
        faces[index] = face
    end
    none = Theme.Text(window, "Body", C.text3)
    none:SetPoint("TOP", 0, -380)
    none:SetWidth(WIDTH - 60)
    none:SetWordWrap(true)
    none:SetJustifyH("CENTER")
    none:SetText(L["No cousins yet. Click Find my family, and they'll be here."])
    -- a word for whoever sees the picture
    local made = Theme.Text(window, "Tiny", C.text3)
    made:SetPoint("BOTTOM", 0, 26)
    made:SetText(L["Made with Hey Cousin!"])
end

local function Paint()
    local house, surname = Kin.House()
    crest:SetCrest(Kin.Crest(), surname)
    ribbon.text:SetText(surname and string.format(L["House %s"], surname) or L["Your house"])
    local words = house and house.motto or ""
    motto:SetText(words ~= "" and ("\226\128\156" .. words .. "\226\128\157") or "")
    local total, _, sheep = Kin.Counts()
    local parts = { total == 1 and L["1 relative"] or string.format(L["%d relatives"], total) }
    if sheep > 0 then
        parts[#parts + 1] = sheep == 1 and L["1 black sheep"] or string.format(L["%d black sheep"], sheep)
    end
    counts:SetText(table.concat(parts, "  ·  "))
    local oldest = Kin.Eldest()
    eldest:SetText(oldest and string.format(L["Eldest we know: %s"], oldest) or "")
    local list = Kin.Stats(COUSINS).mostMet
    for index, face in ipairs(faces) do
        local entry = list[index]
        face:SetShown(entry ~= nil)
        if entry then
            local color = Utils.ClassColor(entry.relative.class)
            face.avatar.icon:SetShown(Utils.SetClassIcon(face.avatar.icon, entry.relative.class))
            face.avatar.ring:SetVertexColor(color[1], color[2], color[3], 0.9)
            face.name:SetText(entry.first)
            face.name:SetTextColor(color[1], color[2], color[3])
        end
    end
    none:SetShown(#list == 0)
end

-- Opens the card, and says how to keep it.
function Portrait.Show()
    if not window then
        Build()
    end
    Paint()
    window:Show()
    Utils.Print(L["Your family portrait. Press Print Screen to take a picture."])
end

function Portrait.Toggle()
    if window and window:IsShown() then
        window:Hide()
    else
        Portrait.Show()
    end
end

-- A new look: the card is built again in it.
Theme.OnSkin(function()
    if not window then
        return
    end
    local shown = window:IsShown()
    window:Hide()
    window = nil
    if shown then
        Build()
        Paint()
        window:Show()
    end
end)
