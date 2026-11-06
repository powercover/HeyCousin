local _, HC = ...

-- Your family's crests on nameplates, so you spot a cousin in a crowd. A crest hangs on the game's own
-- nameplate frame, the one C_NamePlate gives, and not on what's drawn in it: a nameplate addon (Plater,
-- ElvUI, Kui...) replaces the bar inside, while this frame stays, so the crest follows the plate
-- under any of them. Its place and size are yours (the settings), kept relative to that frame's
-- center. It takes no clicks, so the plate under it still does. While the settings' page is open, every
-- plate around you shows it, cousin or not: the game won't let an addon measure a plate, so this is the one
-- way to see the crest exactly where it'll be, on your own plates.
HC.Plates = {}

local Plates = HC.Plates
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin

Plates.DEFAULT = { x = 0, y = 34, scale = 1 }
Plates.SIZE = 22
-- how far it can go from the plate's center, and how big it can get
Plates.MOST_X, Plates.MOST_Y = 100, 50
Plates.LEAST_SCALE, Plates.MOST_SCALE, Plates.SCALE_STEP = 0.5, 3, 0.1
-- above what an addon draws on the plate
local LEVEL_UP = 50
local MOST_PLATES = 40

local frame = CreateFrame("Frame")
local active = {}  -- [unit] = its crest
local pool = {}
local running = false
local previewing = false

local function Clamp(value, least, most)
    return math.max(least, math.min(most, value))
end

-- Where the crest goes and how big, as saved: x and y from the plate's center, and its scale.
function Plates.Position()
    local saved, default = HeyCousinDB, Plates.DEFAULT
    local x = Utils.IsUsableNumber(saved.plateX) and saved.plateX or default.x
    local y = Utils.IsUsableNumber(saved.plateY) and saved.plateY or default.y
    local scale = Utils.IsUsableNumber(saved.plateScale) and saved.plateScale or default.scale
    return Clamp(x, -Plates.MOST_X, Plates.MOST_X), Clamp(y, -Plates.MOST_Y, Plates.MOST_Y),
        Clamp(scale, Plates.LEAST_SCALE, Plates.MOST_SCALE)
end

local function Hang(crest, plate)
    local x, y, scale = Plates.Position()
    crest:SetParent(plate)
    crest:SetFrameLevel(plate:GetFrameLevel() + LEVEL_UP)
    crest:SetScale(scale)
    crest:ClearAllPoints()
    -- (a point's offset is in the frame's own scale: what's saved isn't)
    crest:SetPoint("CENTER", plate, "CENTER", x / scale, y / scale)
    crest:Show()
end

-- A new place or size, on every plate at once: you see it as you drag.
function Plates.Move(x, y, scale)
    local old = { Plates.Position() }
    HeyCousinDB.plateX = Clamp(math.floor((x or old[1]) + 0.5), -Plates.MOST_X, Plates.MOST_X)
    HeyCousinDB.plateY = Clamp(math.floor((y or old[2]) + 0.5), -Plates.MOST_Y, Plates.MOST_Y)
    HeyCousinDB.plateScale = Clamp(math.floor((scale or old[3]) * 10 + 0.5) / 10, Plates.LEAST_SCALE, Plates.MOST_SCALE)
    for unit, crest in pairs(active) do
        local plate = Utils.Call(C_NamePlate.GetNamePlateForUnit, unit)
        if plate then
            Hang(crest, plate)
        end
    end
end

local function Release(unit)
    local crest = active[unit]
    if crest then
        active[unit] = nil
        crest:Hide()
        crest:SetParent(UIParent)
        pool[#pool + 1] = crest
    end
end

-- A cousin's first name and surname on this unit, or nothing (not you, not a stranger).
local function Cousin(unit)
    if Utils.Call(UnitIsPlayer, unit) ~= true or Utils.Call(UnitIsUnit, unit, "player") == true then
        return
    end
    local first, surname = Names.Unit(unit)
    local me, mine = Names.Me()
    if first and Names.Same(surname, mine) and not Names.Same(first, me) then
        return first, surname
    end
end

local function Paint(crest, unit, first, surname)
    local sheep = Kin.IsBlackSheep({ faction = Utils.Call(UnitFactionGroup, unit) })
    crest:SetCrest(Kin.CrestOf(first), surname, sheep)
end

-- A plate that isn't a cousin's, while the page is open: your crest, red on an enemy's as a black sheep's.
local function PaintPreview(crest, unit)
    local _, mine = Names.Me()
    crest:SetCrest(Kin.Crest(), mine, Utils.Call(UnitIsFriend, "player", unit) ~= true)
end

local function Added(unit)
    Release(unit)
    if HeyCousinDB.plateCrest == false then
        return
    end
    local first, surname = Cousin(unit)
    if not first and (not previewing or Utils.Call(UnitIsUnit, unit, "player") == true) then
        return
    end
    -- (in a dungeon the game keeps friendly plates to itself: no frame, or one nobody may touch)
    local plate = C_NamePlate and Utils.Call(C_NamePlate.GetNamePlateForUnit, unit)
    if not plate or Utils.Call(plate.IsForbidden, plate) == true then
        return
    end
    local crest = table.remove(pool) or Crest.Create(UIParent, Plates.SIZE)
    active[unit] = crest
    if first then
        Paint(crest, unit, first, surname)
    else
        PaintPreview(crest, unit)
    end
    Hang(crest, plate)
end

-- Every plate on screen, as the settings say now.
function Plates.Apply()
    if not running then
        return
    end
    for unit in pairs(active) do
        Release(unit)
    end
    for index = 1, MOST_PLATES do
        local unit = "nameplate" .. index
        if Utils.Call(UnitExists, unit) == true then
            Added(unit)
        end
    end
end

-- The settings' page opens or closes: every plate around you shows the crest, or only cousins' again.
function Plates.Preview(on)
    if previewing ~= (on == true) then
        previewing = on == true
        Plates.Apply()
    end
end

-- The crest on this unit's plate, if there is one.
function Plates.CrestOn(unit)
    return active[unit]
end

frame:SetScript("OnEvent", Utils.Protect("nameplate crests", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Added(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Release(unit)
    end
end))

-- On Forever only: surnames are what it's for.
function Plates.Start()
    if running or not Names.HaveSurnames() then
        return
    end
    running = true
    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    Plates.Apply()
end

-- A new crest, or a cousin's own crest come: every plate shows it.
Kin.OnChange(function()
    for unit, crest in pairs(active) do
        local first, surname = Cousin(unit)
        if first then
            Paint(crest, unit, first, surname)
        elseif previewing then
            PaintPreview(crest, unit)
        end
    end
end)

-- A new look: new crests in it.
Theme.OnSkin(function()
    for unit in pairs(active) do
        Release(unit)
    end
    pool = {}
    Plates.Apply()
end)
