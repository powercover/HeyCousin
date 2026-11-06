local _, HC = ...

-- The family map: the cousins who share where they are show as crests on the game's own world
-- map, beside its quest marks. Sharing is yours to turn on (the settings, or the setup's Family step): your addon tells
-- your guild's addons and the cousins in your family's channel (Family.lua) where you are every few
-- seconds while you move, never in a fight or a dungeon. The family channel is a hidden chat channel
-- for one surname and one faction, so the other side's addon never joins it. The crests change only while the map is open,
-- and nothing runs every frame.
HC.Map = {}

local Map = HC.Map
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local PREFIX = "HeyCousin"
-- how often your addon looks where you are while you share, and an update while you stand still
local LOOK_GAP, STILL_GAP = 5, 45
-- a cousin's crest leaves the map when their addon has been quiet this long
local FORGET = 120
-- a move worth telling: this share of the map
local MOVED = 0.002
-- a cousin who shares is noted in your family this often, not on every move
local LEARN_GAP = 60
-- a crest's size on the map, whatever the zoom
local PIN = 24
local WHITE = "Interface\\Buttons\\WHITE8X8"

local frame = CreateFrame("Frame")
local spots = {}  -- [full name] = { map, x, y, at } (or { away, at }: in a dungeon), as their addons tell
local sent = {}   -- what your addon told last: map, x, y, at (or away, at)
local ticker
local provider    -- the addon's crests on the game's world map
local pins = {}
local madeUp      -- test mode: the made-up cousins online stand around you
local learned = {} -- [full name] = GetTime() of the last time a cousin who shares was noted

-- --- sharing where you are ---------------------------------------------------------------------

-- Whether your addon shares where you are: you turned it on, on Forever.
local function Sharing()
    return HeyCousinDB.mapShare == true and Names.HaveSurnames()
end

-- Tells your guild and your family, the next few in turn; with `all`, every cousin (a change that
-- mustn't be missed). Whether any of it went.
local function Tell(text, all)
    local told = false
    if HC.Guild.Mine() ~= nil then
        told = HC.Guild.Send(text)
    end
    local family
    if all then
        family = HC.Family.Send(text)
    else
        family = HC.Family.Spread(text)
    end
    return family or told
end

-- Your map and your place on it (0 to 1 across and down); `away` in a dungeon, where the game
-- gives no place.
local function Where()
    local inside = Utils.Call(IsInInstance)
    if inside == true then
        return nil, true
    end
    local map = C_Map and Utils.Call(C_Map.GetBestMapForUnit, "player")
    if not Utils.IsUsableNumber(map) then
        return nil
    end
    local x, y = Utils.Call(function()
        return C_Map.GetPlayerMapPosition(map, "player"):GetXY()
    end)
    if not Utils.IsUsableNumber(x) or not Utils.IsUsableNumber(y) or (x <= 0 and y <= 0) then
        return nil
    end
    return map, false, x, y
end

-- Tells your cousins where you are, when you moved (or, standing still, now and then), with your
-- class and level: a cousin outside your guild may know nothing else about you.
local function Look()
    if not Sharing() or Utils.Call(InCombatLockdown) == true then
        return
    end
    local map, away, x, y = Where()
    local now = GetTime()
    if away then
        if not sent.away and Tell("3:D", true) then
            sent = { away = true, at = now }
        end
        return
    end
    if not map then
        return
    end
    local moved = map ~= sent.map or math.abs(x - sent.x) >= MOVED or math.abs(y - sent.y) >= MOVED
    if moved or now - sent.at >= STILL_GAP then
        local _, class = Utils.Call(UnitClass, "player")
        local text = string.format("3:P:%d:%d:%d:%s:%d", map, math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5),
            Utils.IsUsableString(class) and class or "", Utils.Call(UnitLevel, "player") or 0)
        if Tell(text) then
            sent = { map = map, x = x, y = y, at = now }
        end
    end
end

-- Starts or stops sharing as the setting is: a stop takes your crest off their maps at once.
function Map.Apply()
    local on = Sharing()
    if on and not ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
        ticker = C_Timer.NewTicker(LOOK_GAP, Utils.Protect("map share", Look))
        Look()
    elseif not on and ticker then
        ticker:Cancel()
        ticker = nil
        if sent.at then
            Tell("3:X", true)
        end
        sent = {}
    end
    if Names.HaveSurnames() then
        HC.Family.Keep()
    end
    Map.Refresh()
end

-- --- where your cousins are ---------------------------------------------------------------------

local refreshSoon = Utils.Debounce(0.5, "map crests", function()
    Map.Refresh()
end)

-- A cousin who shares joins your family, learned, not met.
local function Learn(member, map)
    local now = GetTime()
    if learned[member.full] and now - learned[member.full] < LEARN_GAP then
        return
    end
    learned[member.full] = now
    local info = C_Map and Utils.Call(C_Map.GetMapInfo, map)
    Kin.Seen({
        first = member.first, class = member.class, level = member.level, zone = type(info) == "table" and info.name or nil,
        faction = Utils.Call(UnitFactionGroup, "player"), quiet = true, online = true, shared = true, usesAddon = true,
    })
end

local function Heard(text, sender, onChannel)
    if not Utils.IsUsableString(text) then
        return
    end
    local kind, rest = text:match("^3:(%a)(.*)$")
    -- only your guild's members or your family (and not your own, coming back)
    local member = kind and (onChannel and HC.Family.Cousin(sender) or not onChannel and HC.Guild.Sender(sender))
    if not member or member.me then
        return
    end
    if kind == "P" then
        local map, x, y, class, level = rest:match("^:(%d+):(%d+):(%d+):?(%u*):?(%d*)$")
        map, x, y = tonumber(map), tonumber(x), tonumber(y)
        if not map or x > 10000 or y > 10000 then
            return
        end
        local spot = { map = map, x = x / 10000, y = y / 10000, at = GetTime() }
        if onChannel then
            member.class, member.level = class ~= "" and class or nil, tonumber(level)
            spot.cousin = member
            Learn(member, map)
        end
        spots[member.full] = spot
    elseif kind == "D" then
        spots[member.full] = { away = true, at = GetTime() }
    elseif kind == "X" then
        spots[member.full] = nil
    else
        return
    end
    refreshSoon()
end

-- Test mode: the made-up cousins online stand around you, from the first time the map shows.
local AROUND = { { 0.07, -0.06 }, { -0.085, 0.02 }, { 0.025, 0.085 }, { -0.04, -0.1 }, { 0.1, 0.05 } }

local function MakeUp()
    local map = C_Map and Utils.Call(C_Map.GetBestMapForUnit, "player")
    if madeUp or not Utils.IsUsableNumber(map) then
        return
    end
    madeUp = true
    local x, y = Utils.Call(function()
        return C_Map.GetPlayerMapPosition(map, "player"):GetXY()
    end)
    x, y = Utils.IsUsableNumber(x) and x or 0.5, Utils.IsUsableNumber(y) and y or 0.5
    local index = 0
    for _, member in ipairs(HC.TestMode.Guild()) do
        if member.online and not member.me then
            index = index + 1
            local around = AROUND[(index - 1) % #AROUND + 1]
            spots[member.full] = { map = map, x = math.min(0.98, math.max(0.02, x + around[1])),
                y = math.min(0.98, math.max(0.02, y + around[2])), at = math.huge }
        end
    end
end

-- /cousin test map: cousins on your real map for a while, to see the crests where nobody is
-- sharing yet: around you (cousins you know, so a click opens a real page; made up without any), and
-- in the two capitals (other zones, for the continent map and OpenMap's stitched map).
local PREVIEW = {
    { "Mira", "MAGE", 0.07, -0.06 }, { "Elowen", "PALADIN", -0.085, 0.02 },
    { "Thane", "WARRIOR", 0.5, 0.5, 1454 }, { "Lia", "PRIEST", 0.5, 0.5, 1453 },
}

function Map.Preview()
    local map = C_Map and Utils.Call(C_Map.GetBestMapForUnit, "player")
    local x, y
    if Utils.IsUsableNumber(map) then
        x, y = Utils.Call(function()
            return C_Map.GetPlayerMapPosition(map, "player"):GetXY()
        end)
    end
    local surname = select(2, Names.Me())
    local known = Kin.List()
    for index, row in ipairs(PREVIEW) do
        local first, class, a, b, capital = unpack(row)
        local real = not capital and known[index]
        if real then
            first, class = real.first, real.relative.class
        end
        local spot = capital and { map = capital, x = a, y = b }
            or Utils.IsUsableNumber(map) and { map = map, x = math.min(0.98, math.max(0.02, (x or 0.5) + a)),
                y = math.min(0.98, math.max(0.02, (y or 0.5) + b)) }
        if spot then
            local full = Names.Full(first, surname)
            spot.at = GetTime()
            spot.kin = { member = { first = first, full = full, class = class, level = real and real.relative.level or 20 },
                word = L["Cousin"], madeUp = not real }
            spots[full] = spot
        end
    end
    Utils.Print(L["Made-up cousins are on your map for two minutes. Open it to see them."])
    Map.Refresh()
end

-- OpenMap (an addon) shows one stitched world over the game's map, past the edges of the map
-- underneath. Its API says where things fall on it, and how high its art reaches.
local function OpenMap()
    local api = _G.OpenMapAPI
    if type(api) == "table" and type(api.IsStitched) == "function" and Utils.Call(api.IsStitched) == true then
        return api
    end
end

-- Where a spot falls on map `shown` (0 to 1 across and down, or past that on a stitched map):
-- through the world's coordinates when it's another map (a zone on its continent's map); nothing
-- when it isn't on it.
local function Place(spot, shown)
    if spot.map == shown then
        return spot.x, spot.y
    end
    local stitched = OpenMap()
    if stitched then
        local u, v = Utils.Call(stitched.WorldFromMap, spot.map, spot.x, spot.y)
        if Utils.IsUsableNumber(u) and Utils.IsUsableNumber(v) then
            local x, y = Utils.Call(stitched.MapFromWorld, shown, u, v)
            if Utils.IsUsableNumber(x) and Utils.IsUsableNumber(y) then
                return x, y
            end
        end
    end
    if not (C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos) or type(CreateVector2D) ~= "function" then
        return nil
    end
    local continent, world = Utils.Call(C_Map.GetWorldPosFromMapPos, spot.map, CreateVector2D(spot.x, spot.y))
    if not Utils.IsUsableNumber(continent) or type(world) ~= "table" then
        return nil
    end
    local _, at = Utils.Call(C_Map.GetMapPosFromWorldPos, continent, world, shown)
    if type(at) ~= "table" then
        return nil
    end
    local x, y = at:GetXY()
    if Utils.IsUsableNumber(x) and Utils.IsUsableNumber(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        return x, y
    end
    return nil
end

-- The family in your guild, as the Tree tab has it: [full name] = { member, word }.
local function Family()
    local family = {}
    for _, generation in ipairs((HC.Guild.Tree())) do
        for _, member in ipairs(generation.members) do
            family[member.full] = { member = member, word = generation.word }
        end
    end
    return family
end

-- --- the crests on the map ---------------------------------------------------------------------

local function Tip(pin)
    local spot = pin.spot
    if not spot then
        return
    end
    local member = spot.member
    local color = Utils.ClassColor(member.class, true)
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(member.full, color[1], color[2], color[3])
    local parts = { spot.word }
    local className = Utils.ClassName(member.class)
    if member.level and className then
        parts[#parts + 1] = string.format(L["Level %d %s"], member.level, className)
    end
    GameTooltip:AddLine(table.concat(parts, "  ·  "), C.tip2[1], C.tip2[2], C.tip2[3])
    if not spot.madeUp then
        GameTooltip:AddLine(L["Click to open their page"], C.tip3[1], C.tip3[2], C.tip3[3])
    end
    GameTooltip:Show()
end

-- A click on a crest: that cousin's page; someone only in your guild (another surname, or not known
-- yet): the Tree tab, where they are.
local function OpenPage(pin, button)
    local spot = pin.spot
    if not spot or button ~= "LeftButton" then
        return
    end
    if spot.madeUp then
        Utils.Print(L["Test mode: made-up cousins can't hear you."])
        return
    end
    local member = spot.member
    local house, surname = Kin.House()
    GameTooltip:Hide()
    if house and house.relatives[member.first] and (member.surname == nil or Names.Same(member.surname, surname)) then
        HC.Window.ShowRelative(member.first)
    else
        HC.Window.Show("tree")
    end
    HC.Window.Raise()
end

local function NewPin(canvas)
    local pin = CreateFrame("Frame", nil, canvas)
    pin:SetSize(PIN, PIN)
    pin:EnableMouse(true)
    pin.crest = Crest.Create(pin, PIN)
    pin.crest:SetPoint("CENTER")
    -- their class, in a bar under the crest, and their name under it
    pin.bar = Theme.Texture(pin, WHITE, "OVERLAY", 0)
    pin.bar:SetSize(PIN - 8, 3)
    pin.bar:SetPoint("TOP", pin, "BOTTOM", 0, 1)
    pin.name = Theme.Text(pin, "Tiny")
    pin.name:SetPoint("TOP", pin, "BOTTOM", 0, -4)
    pin.name:SetShadowOffset(1, -1)
    pin.name:SetShadowColor(0, 0, 0, 1)
    pin:SetScript("OnEnter", Tip)
    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    pin:SetScript("OnMouseUp", Utils.Protect("map crest", OpenPage))
    return pin
end

-- The crests keep their size as the map zooms, at their places on it.
local function Scale()
    local map = provider and provider:GetMap()
    if not map then
        return
    end
    local canvas = map:GetCanvas()
    local scale = 1 / (map:GetCanvasScale() or 1)
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    for _, pin in ipairs(pins) do
        if pin:IsShown() then
            pin:SetScale(scale)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", pin.x * width / scale, -pin.y * height / scale)
        end
    end
end

-- Puts a crest on the open map for each cousin whose addon told where they are.
function Map.Refresh()
    local map = provider and provider:GetMap()
    if not map or not map:IsShown() then
        return
    end
    local shown = map:GetMapID()
    local count = 0
    if HeyCousinDB.mapShow ~= false and Utils.IsUsableNumber(shown) then
        if HC.TestMode.active then
            MakeUp()
        end
        local family, now = Family(), GetTime()
        local guildFamily = HC.Guild.Family()
        local crest = guildFamily and guildFamily.crest or Kin.Crest()
        local surname = guildFamily and guildFamily.surname or select(2, Names.Me())
        local canvas = map:GetCanvas()
        local level = canvas:GetFrameLevel() + 100
        -- above a stitched map's art
        local stitched = OpenMap()
        local artTop = stitched and Utils.Call(stitched.ArtTopLevel)
        if Utils.IsUsableNumber(artTop) then
            level = math.max(level, artTop + 1)
        end
        for full, spot in pairs(spots) do
            local kin = spot.kin or family[full] or (spot.cousin and { member = spot.cousin, word = L["Cousin"] })
            if now - spot.at > FORGET then
                spots[full] = nil
            elseif kin and not spot.away then
                local x, y = Place(spot, shown)
                if x then
                    count = count + 1
                    local pin = pins[count] or NewPin(canvas)
                    pins[count] = pin
                    pin.spot, pin.x, pin.y = { member = kin.member, word = kin.word, madeUp = kin.madeUp }, x, y
                    pin:SetFrameLevel(level)
                    -- the guild's crest for its family; your house's for the cousins beyond it
                    if family[full] then
                        pin.crest:SetCrest(crest, surname)
                    else
                        pin.crest:SetCrest(Kin.CrestOf(kin.member.first), select(2, Names.Me()))
                    end
                    local color = Utils.ClassColor(kin.member.class, true)
                    pin.bar:SetVertexColor(color[1], color[2], color[3])
                    pin.name:SetText(kin.member.first or full)
                    pin.name:SetTextColor(color[1], color[2], color[3])
                    pin:Show()
                end
            end
        end
    end
    for index = count + 1, #pins do
        pins[index]:Hide()
    end
    Scale()
end

-- The addon's crests join the game's world map, as one of its data providers.
local function Hook()
    if provider or type(WorldMapFrame) ~= "table" or type(WorldMapFrame.AddDataProvider) ~= "function"
        or type(MapCanvasDataProviderMixin) ~= "table" or type(CreateFromMixins) ~= "function" then
        return
    end
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
    -- (a mistake in the addon's crests must never break the game's map)
    provider.RefreshAllData = Utils.Protect("map crests", function()
        Map.Refresh()
    end)
    provider.RemoveAllData = Utils.Protect("map crests", function()
        for _, pin in ipairs(pins) do
            pin:Hide()
        end
    end)
    provider.OnCanvasScaleChanged = Utils.Protect("map zoom", Scale)
    WorldMapFrame:AddDataProvider(provider)
    -- OpenMap's map on or off: the places change
    local api = _G.OpenMapAPI
    if type(api) == "table" and type(api.RegisterCallback) == "function" then
        pcall(api.RegisterCallback, "HeyCousin", "OpenMap_StitchedChanged", refreshSoon)
    end
end

-- --- events ------------------------------------------------------------------------------------

frame:SetScript("OnEvent", Utils.Protect("map", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender, _, _, localID, channelName = ...
        if prefix == PREFIX and channel == "GUILD" then
            Heard(text, sender, false)
        elseif prefix == PREFIX and channel == "WHISPER" then
            Heard(text, sender, true)
        elseif prefix == PREFIX and channel == "CHANNEL" then
            -- only your family's channel
            local id, name = HC.Family.Channel()
            if name and ((id and localID == id) or channelName == name) then
                Heard(text, sender, true)
            end
        end
    elseif event == "ADDON_LOADED" then
        if (...) == "Blizzard_WorldMap" then
            Hook()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- after a loading screen, where you are is told again
        sent = {}
    else
        Map.Apply()
    end
end))

-- The crests go on the map in test mode too (made-up cousins); sharing is Forever's.
function Map.Start()
    Hook()
    frame:RegisterEvent("ADDON_LOADED")
    if Names.HaveSurnames() then
        for _, event in ipairs({ "CHAT_MSG_ADDON", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
            frame:RegisterEvent(event)
        end
        Map.Apply()
    end
end

Kin.OnChange(function()
    Map.Refresh()
end)

-- A new theme: the crests are made again in it.
Theme.OnSkin(function()
    for _, pin in ipairs(pins) do
        pin:Hide()
    end
    pins = {}
    Map.Refresh()
end)
