local _, HC = ...

-- Your family on the minimap: the cousins who share where they are (Map.lua), as small crests where
-- they stand. One further away than the minimap shows sits at its edge, faded, in their direction. It
-- runs a few times a second, and only while there's someone to show.
HC.MiniPins = {}

local MiniPins = HC.MiniPins
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

-- (a crest under 18 has no room for its symbol)
local SIZE = 20
local LOOK_GAP = 0.2
local MOST = 20
local EDGE_ALPHA = 0.6
-- what the minimap shows across, in yards, at each zoom, for a client that doesn't tell
local ACROSS = {
    indoor = { [0] = 300, 240, 180, 120, 80, 50 },
    outdoor = { [0] = 466.67, 400, 333.33, 266.67, 200, 133.33 },
}

local pins = {}
local axes = {}  -- [map] = the world's directions on it: east and south, a yard long
local ticker

local function World(map, x, y)
    local continent, at = Utils.Call(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if not Utils.IsUsableNumber(continent) or type(at) ~= "table" then
        return nil
    end
    local wx, wy = at:GetXY()
    if Utils.IsUsableNumber(wx) and Utils.IsUsableNumber(wy) then
        return continent, wx, wy
    end
end

-- East and south on `map`, in the world's coordinates, from its corners: whichever way those run.
local function Axes(map)
    if axes[map] == nil then
        axes[map] = false
        local continent, x0, y0 = World(map, 0, 0)
        local _, x1, y1 = World(map, 1, 0)
        local _, x2, y2 = World(map, 0, 1)
        if continent and x1 and x2 then
            local width = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
            local height = math.sqrt((x2 - x0) ^ 2 + (y2 - y0) ^ 2)
            if width > 0 and height > 0 then
                axes[map] = { (x1 - x0) / width, (y1 - y0) / width, (x2 - x0) / height, (y2 - y0) / height }
            end
        end
    end
    return axes[map] or nil
end

-- How many yards the minimap shows from its center to its edge.
local function ViewRadius()
    local radius = C_Minimap and Utils.Call(C_Minimap.GetViewRadius)
    if Utils.IsUsableNumber(radius) and radius > 0 then
        return radius
    end
    local zoom = Utils.Call(Minimap.GetZoom, Minimap) or 0
    local kind = Utils.Call(IsIndoors) == true and ACROSS.indoor or ACROSS.outdoor
    return (kind[zoom] or kind[0]) / 2
end

local function NewPin()
    local pin = Crest.Create(Minimap, SIZE)
    pin:SetFrameLevel(Minimap:GetFrameLevel() + 6)
    pin:EnableMouse(true)
    pin:SetScript("OnEnter", function(self)
        local member = self.member
        if not member then
            return
        end
        local color = Utils.ClassColor(member.class, true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(member.full or member.first, color[1], color[2], color[3])
        local className = Utils.ClassName(member.class)
        if member.level and className then
            GameTooltip:AddLine(string.format(L["Level %d %s"], member.level, className), C.tip2[1], C.tip2[2], C.tip2[3])
        end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    pin:SetScript("OnMouseUp", Utils.Protect("minimap crest", function(self, button)
        if self.member and button == "LeftButton" then
            GameTooltip:Hide()
            HC.Map.OpenMember(self.member, self.madeUp)
        end
    end))
    return pin
end

-- Where you are in the world, or nothing where the game gives no place (a dungeon).
local function Me()
    if Utils.Call(IsInInstance) == true then
        return nil
    end
    local map = C_Map and Utils.Call(C_Map.GetBestMapForUnit, "player")
    if not Utils.IsUsableNumber(map) then
        return nil
    end
    local x, y = Utils.Call(function()
        return C_Map.GetPlayerMapPosition(map, "player"):GetXY()
    end)
    if not Utils.IsUsableNumber(x) or not Utils.IsUsableNumber(y) then
        return nil
    end
    local continent, wx, wy = World(map, x, y)
    if continent then
        return map, continent, wx, wy
    end
end

local function Stop()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    for _, pin in ipairs(pins) do
        pin:Hide()
        pin.member, pin.who = nil, nil
    end
end

-- Whoever shares on your continent, the nearest first.
local function Gather(map, continent, wx, wy)
    local list = {}
    local axis = Axes(map)
    if not axis then
        return list
    end
    HC.Map.Each(function(full, spot, kin)
        local where, x, y = World(spot.map, spot.x, spot.y)
        if where == continent then
            local dx, dy = x - wx, y - wy
            local east = dx * axis[1] + dy * axis[2]
            local north = -(dx * axis[3] + dy * axis[4])
            list[#list + 1] = { full = full, kin = kin, east = east, north = north,
                distance = math.sqrt(east * east + north * north) }
        end
    end)
    table.sort(list, function(a, b)
        return a.distance < b.distance
    end)
    return list
end

local function Look()
    if HeyCousinDB.minimapCousins == false or not HC.Map.AnyoneShares() then
        Stop()
        return
    end
    local map, continent, wx, wy = Me()
    local list = {}
    if map and Utils.Call(Minimap.IsVisible, Minimap) == true then
        list = Gather(map, continent, wx, wy)
    end
    local half = Minimap:GetWidth() / 2
    local scale = half / ViewRadius()
    -- a minimap that turns with you: your way is up
    local facing = Utils.Call(GetCVar, "rotateMinimap") == "1" and Utils.Call(GetPlayerFacing)
    local sine, cosine = 0, 1
    if Utils.IsUsableNumber(facing) then
        sine, cosine = math.sin(facing), math.cos(facing)
    end
    local square = Utils.Call(GetMinimapShape) == "SQUARE"
    local count = 0
    for _, item in ipairs(list) do
        if count >= MOST then
            break
        end
        count = count + 1
        local pin = pins[count]
        if not pin then
            pin = NewPin()
            pins[count] = pin
        end
        local x = (item.east * cosine + item.north * sine) * scale
        local y = (-item.east * sine + item.north * cosine) * scale
        local room = half - 2
        local far
        if square then
            far = math.abs(x) > room or math.abs(y) > room
            x, y = math.max(-room, math.min(room, x)), math.max(-room, math.min(room, y))
        else
            local out = math.sqrt(x * x + y * y)
            far = out > room
            if far then
                x, y = x * room / out, y * room / out
            end
        end
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", Minimap, "CENTER", x, y)
        pin:SetAlpha(far and EDGE_ALPHA or 1)
        -- (painted once for each cousin: this runs often)
        if pin.who ~= item.full then
            local first = item.kin.member.first
            pin.who = item.full
            pin:SetCrest(first and Kin.CrestOf(first) or Kin.Crest(), select(2, Names.Me()))
        end
        pin.member, pin.madeUp = item.kin.member, item.kin.madeUp
        pin:Show()
    end
    for index = count + 1, #pins do
        pins[index]:Hide()
        pins[index].member, pins[index].who = nil, nil
    end
end

local protectedLook = Utils.Protect("minimap crests", Look)

-- A cousin shared where they are: starts looking, if nothing is yet.
function MiniPins.Wake()
    if not ticker and HeyCousinDB.minimapCousins ~= false and C_Timer and type(C_Timer.NewTicker) == "function" then
        ticker = C_Timer.NewTicker(LOOK_GAP, protectedLook)
        protectedLook()
    end
end

-- As the setting says now.
function MiniPins.Apply()
    if HeyCousinDB.minimapCousins == false then
        Stop()
    elseif HC.Map.AnyoneShares() then
        MiniPins.Wake()
    end
end

-- A new crest, a cousin's own crest come: painted again.
Kin.OnChange(function()
    for _, pin in ipairs(pins) do
        pin.who = nil
    end
end)

-- A new look: new crests.
Theme.OnSkin(function()
    for _, pin in ipairs(pins) do
        pin:Hide()
    end
    pins = {}
    if ticker then
        protectedLook()
    end
end)
