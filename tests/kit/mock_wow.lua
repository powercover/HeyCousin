-- A small World of Warcraft for the smoke tests: frames, textures, fonts, animations, timers,
-- events, units and the game functions the addon calls, in plain Lua. Only methods listed here
-- exist: calling another fails, as a mistyped one would in the game. Mock.Boot loads the addon
-- as the game does (the TOC's files in order, then its loading events). Frames keep their
-- anchors, layers, colors and texts, for screens.py, which draws them.
if not unpack then unpack = table.unpack end

Mock = {}

local function Class(parent)
    local class = {}
    class.__index = class
    if parent then
        setmetatable(class, { __index = parent })
    end
    return class
end

local Region = Class()
local Frame = Class(Region)
local Button = Class(Frame)
local EditBox = Class(Frame)
local Model = Class(Frame)
local Texture = Class(Region)
local FontString = Class(Region)
local Mask = Class(Region)
local Group = Class()
local Animation = Class()
local Font = Class()

-- --- regions -----------------------------------------------------------------------------------

local serial = 0
local function New(class, parent)
    serial = serial + 1
    local object = setmetatable({ parent = parent, shown = true, alpha = 1, points = 0, anchors = {}, serial = serial,
        scripts = {}, hooks = {} }, class)
    return object
end

-- A frame's textures and font strings, in the order they were made.
local function Add(frame, region)
    frame.regions = frame.regions or {}
    table.insert(frame.regions, region)
    return region
end

function Region:SetSize(w, h) self.w, self.h = w, h end
function Region:SetWidth(w) self.w = w end
function Region:SetHeight(h) self.h = h end
function Region:GetWidth() return self.w or (self.points >= 2 and 300) or 0 end
function Region:GetHeight() return self.h or (self.points >= 2 and 300) or 0 end
-- (point [, relativeTo [, relativePoint]] [, x, y]), as the game takes them; a point set again
-- replaces the old one.
function Region:SetPoint(point, ...)
    assert(type(point) == "string", "SetPoint needs a point")
    self.points = self.points + 1
    local to, at, x, y = ...
    if type(to) == "number" then
        to, at, x, y = nil, nil, to, at
    elseif type(at) == "number" then
        at, x, y = nil, at, x
    end
    self.anchors[point:upper()] = { to = to, at = (at or point):upper(), x = x or 0, y = y or 0 }
end
function Region:ClearAllPoints() self.points = 0; self.anchors = {} end
function Region:SetAllPoints(to)
    self.points = 2
    self.anchors = { TOPLEFT = { to = to, at = "TOPLEFT", x = 0, y = 0 },
        BOTTOMRIGHT = { to = to, at = "BOTTOMRIGHT", x = 0, y = 0 } }
end
function Region:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Region:IsShown() return self.shown end
function Region:IsVisible()
    local region = self
    while region do
        if not region.shown then return false end
        region = region.parent
    end
    return true
end
function Region:SetAlpha(a) assert(type(a) == "number", "SetAlpha needs a number"); self.alpha = a end
function Region:GetAlpha() return self.alpha end
function Region:GetParent() return self.parent end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:GetCenter() return 400, 300 end
function Region:GetEffectiveScale() return 1 end
function Region:SetScale(s) self.scale = s end
function Region:CreateAnimationGroup() return New(Group, self) end
function Region:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end

-- scripts and hooks
function Mock.Run(object, name, ...)
    local script = object.scripts[name]
    if script then script(object, ...) end
    for _, hook in ipairs(object.hooks[name] or {}) do hook(object, ...) end
end

function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:HookScript(name, fn)
    self.hooks[name] = self.hooks[name] or {}
    table.insert(self.hooks[name], fn)
end
function Frame:Show()
    local was = self.shown
    self.shown = true
    if not was then Mock.Run(self, "OnShow") end
end
function Frame:Hide()
    local was = self.shown
    self.shown = false
    if was then Mock.Run(self, "OnHide") end
end
function Frame:RegisterEvent(event)
    Mock.events[event] = Mock.events[event] or {}
    Mock.events[event][self] = true
end
function Frame:UnregisterEvent(event) if Mock.events[event] then Mock.events[event][self] = nil end end
function Frame:RegisterAllEvents() Mock.all[self] = true end
function Frame:UnregisterAllEvents()
    Mock.all[self] = nil
    for _, frames in pairs(Mock.events) do frames[self] = nil end
end
function Frame:CreateTexture(_, layer, _, sublevel)
    local t = Add(self, New(Texture, self))
    t.layer, t.sublevel = layer, sublevel
    return t
end
function Frame:CreateFontString(_, layer) local t = Add(self, New(FontString, self)); t.layer = layer; t.text = ""; return t end
function Frame:CreateMaskTexture() return New(Mask, self) end
function Frame:SetFrameStrata(strata) self.strata = strata end
-- (the mock's own fields have names the addon's frames don't use: a row's .level is its text)
function Frame:SetFrameLevel(level) self.frameLevel = level end
-- one above its parent, as the game makes them, unless it was set
function Frame:GetFrameLevel() return self.frameLevel or (self.parent and self.parent:GetFrameLevel() + 1) or 0 end
function Frame:SetToplevel() end
function Frame:SetClampedToScreen() end
function Frame:EnableMouse(on) self.mouse = on end
function Frame:EnableMouseWheel(on) self.wheel = on end
function Frame:SetMovable() end
function Frame:RegisterForDrag() end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:SetClipsChildren(on) self.clips = on end
function Frame:IsForbidden() return false end
function Frame:GetName() return self.frameName end
function Frame:SetAttribute(key, value)
    assert(not Mock.combat or not self.secure, "ADDON_ACTION_BLOCKED: SetAttribute on a secure frame in combat")
    self.attributes = self.attributes or {}
    self.attributes[key] = value
end
function Frame:GetAttribute(key) return self.attributes and self.attributes[key] end
function Frame:SetParent(parent) self.parent = parent end

-- a protected frame (or one holding a secure button) can't be shown or hidden in combat
local function Guard(frame, what)
    if not Mock.combat then return end
    local function Secure(f)
        if f.secure then return true end
        for _, child in ipairs(f.children or {}) do
            if Secure(child) then return true end
        end
        return false
    end
    assert(not Secure(frame), "ADDON_ACTION_BLOCKED: " .. what .. " on a frame with a secure button, in combat")
end
-- The mouse, as the game moves it: a click points at its button first (OnLeave on the frame it
-- left, OnEnter on this one), and a frame hidden under the mouse, or with a parent, gets OnLeave.
function Mock.Point(frame)
    if Mock.focus == frame then return end
    local left = Mock.focus
    Mock.focus = frame
    if left then Mock.Run(left, "OnLeave") end
    if frame then Mock.Run(frame, "OnEnter") end
end

local FrameShow, FrameHide = Frame.Show, Frame.Hide
function Frame:Show() Guard(self, "Show"); FrameShow(self) end
function Frame:Hide()
    Guard(self, "Hide")
    FrameHide(self)
    local under = Mock.focus
    while under do
        if under == self then Mock.Point(nil); break end
        under = under.parent
    end
end

function Button:RegisterForClicks() end
function Button:IsEnabled() return self.enabled ~= false end
function Button:SetEnabled(on)
    local was = self:IsEnabled()
    self.enabled = on and true or false
    if was ~= self.enabled then Mock.Run(self, on and "OnEnable" or "OnDisable") end
end
function Button:Enable() self:SetEnabled(true) end
function Button:Disable() self:SetEnabled(false) end
function Button:Click(which)
    if not self:IsEnabled() then return end
    Mock.Point(self)
    Mock.Run(self, "OnClick", which or "LeftButton", false)
    Mock.Run(self, "PostClick", which or "LeftButton", false)
end

function EditBox:SetFontObject(font) self.font = font end
function EditBox:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function EditBox:SetAutoFocus() end
function EditBox:SetMaxLetters(n) self.max = n end
function EditBox:SetText(text) self.text = text; Mock.Run(self, "OnTextChanged", false) end
function EditBox:GetText() return self.text or "" end
function EditBox:HasFocus() return self.focus == true end
function EditBox:SetFocus() self.focus = true; Mock.Run(self, "OnEditFocusGained") end
function EditBox:ClearFocus() self.focus = false; Mock.Run(self, "OnEditFocusLost") end

function Model:SetUnit(unit) assert(type(unit) == "string"); self.unit = unit; Mock.Run(self, "OnModelLoaded") end
function Model:ClearModel() self.unit = nil end
function Model:SetPortraitZoom(zoom) assert(type(zoom) == "number"); self.zoom = zoom end

function Texture:SetTexture(file, wrapH, wrapV, filter)
    assert(file == nil or type(file) == "string" or type(file) == "number", "SetTexture needs a file")
    assert(filter == nil or filter == "LINEAR" or filter == "NEAREST" or filter == "TRILINEAR", "bad filter " .. tostring(filter))
    self.file, self.filter = file, filter
    if type(file) == "string" then Mock.textures[file] = true end
    return true
end
function Texture:SetTexCoord(...) self.coords = { ... } end
function Texture:SetVertexColor(r, g, b, a)
    assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetVertexColor needs numbers")
    self.color = { r, g, b, a }
end
function Texture:SetAtlas(atlas) self.atlas = atlas end
function Texture:SetBlendMode(mode) self.blend = mode end
function Texture:AddMaskTexture(mask) self.mask = mask end
function Mask:SetTexture(file) self.file = file end

function FontString:SetFontObject(font) assert(font ~= nil, "SetFontObject(nil)"); self.font = font end
function FontString:GetFontObject() return self.font end
function FontString:SetText(text)
    assert(text == nil or type(text) == "string" or type(text) == "number", "SetText needs text, got " .. type(text))
    self.text = text and tostring(text) or ""
end
function FontString:GetText() return self.text end
function FontString:SetTextColor(r, g, b, a)
    assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetTextColor needs numbers")
    self.textColor = { r, g, b, a }
end
function FontString:SetJustifyH(justify) self.justifyH = justify end
function FontString:SetJustifyV(justify) self.justifyV = justify end
function FontString:SetWordWrap(wrap) self.wrap = wrap end
function FontString:SetSpacing(spacing) self.spacing = spacing end
function FontString:SetShadowColor(r, g, b, a) self.shadowColor = { r, g, b, a } end
function FontString:SetShadowOffset(x, y) self.shadowOffset = { x, y } end
function FontString:GetStringWidth()
    local plain = (self.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "XX")
    return #plain * 6
end

function Group:CreateAnimation() return setmetatable({}, Animation) end
function Group:SetLooping() end
function Group:Play() self.playing = true end
function Group:Stop() self.playing = false end
function Group:IsPlaying() return self.playing == true end
for _, name in ipairs({ "SetFromAlpha", "SetToAlpha", "SetDuration", "SetSmoothing", "SetStartDelay", "SetScaleFrom",
    "SetScaleTo", "SetOffset" }) do
    Animation[name] = function() end
end

function Font:SetFont(file, height, flags)
    assert(type(file) == "string" and type(height) == "number", "SetFont needs a file and a height")
    self.file, self.height, self.flags = file, height, flags
    return true
end
function Font:GetFont() return self.file, self.height, self.flags end
function Font:CopyFontObject(other) self.file, self.height, self.flags = other.file, other.height, other.flags end
function Font:SetShadowColor(r, g, b, a) self.shadowColor = { r, g, b, a } end
function Font:SetShadowOffset(x, y) self.shadowOffset = { x, y } end
function Font:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function Font:GetFontObjectForAlphabet(alphabet) return self.members and self.members[alphabet] end

local function FontObject(file, height)
    return setmetatable({ file = file, height = height, flags = "" }, Font)
end

-- the classes, for screens.py: it measures and lays out the frames as the game would
Mock.classes = { Region = Region, Frame = Frame, Button = Button, EditBox = EditBox, Model = Model, Texture = Texture,
    FontString = FontString, Mask = Mask }

-- --- the world ---------------------------------------------------------------------------------

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
Mock.SECRET = setmetatable({}, { __tostring = function() return "a secret" end })

local function Globals()
    Mock.frames, Mock.events, Mock.timers, Mock.textures = {}, {}, {}, {}
    Mock.clock, Mock.now, Mock.combat = 1000, 1700000000, false
    Mock.chat, Mock.addonSent, Mock.sounds, Mock.invites, Mock.opened, Mock.tells = {}, {}, {}, {}, {}, {}
    Mock.filters, Mock.postCalls, Mock.accepted = {}, {}, 0
    Mock.inGroup, Mock.zone, Mock.map = false, "Elwynn Forest", 1429
    Mock.focus, Mock.all = nil, {}
    Mock.units, Mock.players, Mock.roster, Mock.guild, Mock.throttle, Mock.instance = {}, {}, {}, nil, 0, nil

    function CreateFrame(kind, name, parent, template)
        local class = kind == "Button" and Button or kind == "EditBox" and EditBox or kind == "PlayerModel" and Model or Frame
        local frame = New(class, parent)
        frame.frameName, frame.kind = name, kind
        frame.secure = template ~= nil and template:find("Secure") ~= nil
        if parent then
            parent.children = parent.children or {}
            table.insert(parent.children, frame)
        end
        if name then _G[name] = frame end
        table.insert(Mock.frames, frame)
        return frame
    end
    UIParent = CreateFrame("Frame", "UIParent")
    Minimap = CreateFrame("Frame", "Minimap")
    Minimap:SetSize(198, 198)
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) table.insert(Mock.chat, text) end }
    SlashCmdList, UISpecialFrames = {}, {}
    GameFontHighlight = FontObject("Fonts\\FRIZQT__.TTF", 12)
    GameFontHighlight.members = {}
    for _, alphabet in ipairs({ "roman", "russian", "korean", "simplifiedchinese", "traditionalchinese" }) do
        GameFontHighlight.members[alphabet] = FontObject("Fonts\\" .. alphabet .. ".TTF", 12)
    end
    function CreateFont(name) local f = FontObject("Fonts\\FRIZQT__.TTF", 12); _G[name] = f; return f end
    function CreateFontFamily(name, members)
        local family = FontObject(members[1].file, members[1].height)
        family.members = {}
        for _, m in ipairs(members) do family.members[m.alphabet] = FontObject(m.file, m.height) end
        _G[name] = family
        return family
    end

    GameTooltip = CreateFrame("Frame", "GameTooltip")
    GameTooltip.lines, GameTooltip.colors = {}, {}
    function GameTooltip:SetOwner() self.lines, self.colors = {}, {} end
    function GameTooltip:SetText(text, r, g, b) self.lines, self.colors = { text }, { { r, g, b } } end
    function GameTooltip:AddLine(text, r, g, b)
        table.insert(self.lines, text)
        table.insert(self.colors, { r, g, b })
    end
    function GameTooltip:AddDoubleLine(a, b, r, g, bl)
        table.insert(self.lines, a .. " | " .. b)
        table.insert(self.colors, { r, g, bl })
    end
    function GameTooltip:GetUnit() return self.unitName, self.unit end
    function GameTooltip:NumLines() return #self.lines end
    function GameTooltip:SetItemByID(id) self.lines, self.colors = { "item " .. id }, { {} } end

    TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) Mock.postCalls[kind] = fn end }
    Enum = { TooltipDataType = { Unit = 2 },
        SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8 } }
    ChatFrameUtil = {
        AddMessageEventFilter = function(event, fn)
            Mock.filters[event] = Mock.filters[event] or {}
            table.insert(Mock.filters[event], fn)
        end,
        SendTell = function(name) table.insert(Mock.tells, name) end,
        OpenChat = function(text) table.insert(Mock.opened, text) end,
    }
    C_ChatInfo = {
        RegisterAddonMessagePrefix = function(prefix) Mock.prefix = prefix end,
        -- (Mock.throttle: how many messages the game holds back, as when a prefix sends too many)
        SendAddonMessage = function(prefix, text, channel, target)
            assert(type(text) == "string" and #text <= 255, "an addon message is 255 bytes at most")
            assert(channel == "GUILD" or (type(target) == "string" and channel == "WHISPER"))
            if Mock.throttle > 0 then
                Mock.throttle = Mock.throttle - 1
                return Enum.SendAddonMessageResult.AddonMessageThrottle
            end
            table.insert(Mock.addonSent, { prefix = prefix, text = text, channel = channel, target = target })
            return Enum.SendAddonMessageResult.Success
        end,
    }
    C_PartyInfo = { InviteUnit = function(name) table.insert(Mock.invites, name) end }
    function AcceptGroup() Mock.accepted = Mock.accepted + 1 end
    function StaticPopup_Hide(name) Mock.popupHidden = name end
    function PlaySoundFile(file) table.insert(Mock.sounds, file) end
    function securecall(fn, ...) return fn(...) end
    function issecretvalue(value) return value == Mock.SECRET end
    C_Secrets = nil
    C_Timer = {
        After = function(delay, fn) table.insert(Mock.timers, { at = Mock.clock + delay, fn = fn }) end,
        NewTicker = function(interval, fn)
            local ticker = { at = Mock.clock + interval, fn = fn, interval = interval }
            function ticker:Cancel() self.cancelled = true end
            table.insert(Mock.timers, ticker)
            return ticker
        end,
    }
    function GetTime() return Mock.clock end
    function time() return Mock.now end
    function GetLocale() return "enUS" end
    function InCombatLockdown() return Mock.combat end
    -- (Mock.instance: the kind of instance you're in, "party" or "raid"; nil out in the world)
    function IsInInstance() return Mock.instance ~= nil, Mock.instance or "none" end
    function IsInGroup() return Mock.inGroup end
    function IsInRaid() return false end
    function GetNumSubgroupMembers() local n = 0; for i = 1, 4 do if Mock.units["party" .. i] then n = i end end; return n end
    function GetNumGroupMembers() return GetNumSubgroupMembers() + 1 end
    function GetRealZoneText() return Mock.zone end
    function GetZoneText() return Mock.zone end
    -- maps on one made-up continent (0), each { left, top, width, height } in yards: Elwynn Forest,
    -- Stormwind City in it, and the Eastern Kingdoms around them
    Mock.maps = { [1429] = { 0, 0, 1000, 667 }, [1453] = { 300, 100, 200, 133 }, [1415] = { -4000, -5000, 9000, 6000 } }
    function CreateVector2D(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
    C_Map = {
        GetBestMapForUnit = function() return Mock.map end,
        GetPlayerMapPosition = function(map, unit)
            assert(type(map) == "number" and unit == "player")
            return { GetXY = function() return Mock.x, Mock.y end }
        end,
        GetWorldPosFromMapPos = function(map, at)
            local m = Mock.maps[map]
            if m then return 0, CreateVector2D(m[1] + at.x * m[3], m[2] + at.y * m[4]) end
        end,
        GetMapPosFromWorldPos = function(continent, world, map)
            local m = Mock.maps[map]
            if m and continent == 0 then return map, CreateVector2D((world.x - m[1]) / m[3], (world.y - m[2]) / m[4]) end
        end,
    }
    -- the world map: its canvas (the addon's crests go on it) and its data providers
    MapCanvasDataProviderMixin = {}
    function MapCanvasDataProviderMixin:OnAdded(map) self.owningMap = map end
    function MapCanvasDataProviderMixin:GetMap() return self.owningMap end
    function MapCanvasDataProviderMixin:RefreshAllData() end
    function MapCanvasDataProviderMixin:RemoveAllData() end
    function MapCanvasDataProviderMixin:OnCanvasScaleChanged() end
    function CreateFromMixins(...)
        local object = {}
        for _, mixin in ipairs({ ... }) do for key, value in pairs(mixin) do object[key] = value end end
        return object
    end
    WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
    WorldMapFrame:SetSize(702, 468)
    WorldMapFrame:Hide()
    WorldMapFrame.ScrollContainer = CreateFrame("Frame", nil, WorldMapFrame)
    WorldMapFrame.ScrollContainer:SetAllPoints()
    WorldMapFrame.ScrollContainer.Child = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
    WorldMapFrame.ScrollContainer.Child:SetSize(702, 468)
    WorldMapFrame.ScrollContainer.Child:SetPoint("TOPLEFT")
    WorldMapFrame.dataProviders, WorldMapFrame.mapID, WorldMapFrame.zoom = {}, 1429, 1
    function WorldMapFrame:AddDataProvider(provider)
        table.insert(self.dataProviders, provider)
        provider:OnAdded(self)
    end
    function WorldMapFrame:GetMapID() return self.mapID end
    function WorldMapFrame:GetCanvas() return self.ScrollContainer.Child end
    function WorldMapFrame:GetCanvasScale() return self.zoom end
    Mock.subzone, Mock.x, Mock.y, Mock.resting, Mock.hour = "Goldshire", 0.421, 0.653, false, 14
    function GetSubZoneText() return Mock.subzone end
    function IsResting() return Mock.resting end
    function GetGameTime() return Mock.hour, 30 end
    date = os.date
    function IsShiftKeyDown() return false end
    function GetCursorPosition() return 0, 0 end
    function GetMinimapShape() return "ROUND" end
    RAID_CLASS_COLORS, LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE, CLASS_ICON_TCOORDS = {}, {}, {}, {}
    for i, class in ipairs(CLASSES) do
        RAID_CLASS_COLORS[class] = { r = i / 10, g = 0.5, b = 0.5 }
        LOCALIZED_CLASS_NAMES_MALE[class] = class:sub(1, 1) .. class:sub(2):lower()
        LOCALIZED_CLASS_NAMES_FEMALE[class] = LOCALIZED_CLASS_NAMES_MALE[class]
        CLASS_ICON_TCOORDS[class] = { 0, 0.25, 0, 0.25 }
    end
    C_ClassColor = nil
    C_Texture = { GetAtlasInfo = function() return nil end }
    FACTION_HORDE, FACTION_ALLIANCE = "Horde", "Alliance"
    ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
    C_GuildInfo = { GuildRoster = function() end }

    -- units: Mock.units[token] = { name, surname, guid, class, race, level, sex, faction, guild, npc }
    local function U(unit) return Mock.units[unit] end
    function UnitName(unit) local u = U(unit); if u then return u.name, u.surname end end
    UnitNameUnmodified = UnitName
    function UnitGUID(unit) local u = U(unit); return u and u.guid end
    function UnitIsPlayer(unit) local u = U(unit); if u then return not u.npc end end
    function UnitIsUnit(a, b) local x, y = U(a), U(b); return x ~= nil and y ~= nil and x.guid == y.guid end
    function UnitClass(unit) local u = U(unit); if u and u.class then return LOCALIZED_CLASS_NAMES_MALE[u.class], u.class end end
    function UnitRace(unit) local u = U(unit); if u then return u.race, u.race end end
    function UnitLevel(unit) local u = U(unit); return u and u.level or 0 end
    function UnitSex(unit) local u = U(unit); return u and u.sex or 2 end
    function UnitFactionGroup(unit) local u = U(unit); return u and u.faction end
    function UnitExists(unit) return U(unit) ~= nil end
    function UnitInParty(unit) local u = U(unit); return u ~= nil and u.party == true end
    function UnitInRaid() return nil end
    -- inspect: a look at a unit's gear (Mock.units[unit].gear = { [slot] = item id }, .ilvl)
    Mock.inspects = {}
    function CanInspect(unit) local u = U(unit); return u ~= nil and not u.npc end
    function CheckInteractDistance(unit) return U(unit) ~= nil end
    function NotifyInspect(unit) table.insert(Mock.inspects, unit) end
    function ClearInspectPlayer() Mock.cleared = (Mock.cleared or 0) + 1 end
    function GetInventoryItemID(unit, slot) local u = U(unit); return u and u.gear and u.gear[slot] end
    C_PaperDollInfo = { GetInspectItemLevel = function(unit) local u = U(unit); return u and u.ilvl end }
    C_Item = { GetItemIconByID = function(id) return 130000 + id end }
    function UnitIsVisible(unit) local u = U(unit); return u ~= nil and u.visible ~= false end
    function UnitTokenFromGUID(guid)
        for token, u in pairs(Mock.units) do if u.guid == guid and token ~= "player" then return token end end
    end
    function GetPlayerInfoByGUID(guid)
        local p = Mock.players[guid]
        if not p then
            for _, u in pairs(Mock.units) do if u.guid == guid then p = u end end
        end
        -- as Forever answers (the launch-day test): the whole name, then a realm code, empty for your own
        if p then
            local whole = p.surname and (p.name .. " " .. p.surname) or p.name
            return p.class, p.class, p.race, p.race, p.sex or 2, whole, p.realm or "CAMWOWEU4Realm4PvP", p.level or 8
        end
    end
    -- your guild: Mock.guild = { name =, rank = (yours, 0: you lead it), ranks = { its rank names } };
    -- its members, Mock.roster[i] = { full, rank, level, class, zone, online, guid, days (since online) }
    function IsInGuild() return Mock.guild ~= nil end
    function IsGuildLeader() return Mock.guild ~= nil and Mock.guild.rank == 0 end
    function GetGuildInfo(unit)
        if unit == "player" then
            local g = Mock.guild
            if g then return g.name, g.ranks[g.rank + 1], g.rank end
            return nil
        end
        local u = U(unit); return u and u.guild
    end
    function GuildControlGetNumRanks() return Mock.guild and #Mock.guild.ranks or 0 end
    function GuildControlGetRankName(index) return Mock.guild and Mock.guild.ranks[index] end
    function GetUnitName(unit) local u = U(unit); if u then return u.surname and (u.name .. " " .. u.surname) or u.name end end
    function UnitFullName(unit) local u = U(unit); if u then return u.name, u.surname end end
    function GetRealmName() return "Forever" end
    function GetNormalizedRealmName() return "Forever" end
    function Ambiguate(name) return name end
    function GetChannelList() return 1, "General", false, 2, "Trade", false end
    function GetNumGuildMembers() return #Mock.roster end
    function GetGuildRosterInfo(i)
        local m = Mock.roster[i]
        local rank = m.rank or 2
        local rankName = Mock.guild and Mock.guild.ranks[rank + 1] or "Member"
        return m.full, rankName, rank, m.level, m.class, m.zone, "", "", m.online, 0, m.class, 0, 0, false, false, 0, m.guid
    end
    function GetGuildRosterLastOnline(i) local m = Mock.roster[i]; return 0, 0, m and m.days or 2, 0 end
end

-- --- running -----------------------------------------------------------------------------------

function Mock.Fire(event, ...)
    local list = {}
    for frame in pairs(Mock.events[event] or {}) do list[#list + 1] = frame end
    for frame in pairs(Mock.all) do
        if not (Mock.events[event] or {})[frame] then list[#list + 1] = frame end
    end
    for _, frame in ipairs(list) do
        local script = frame.scripts.OnEvent
        if script then script(frame, event, ...) end
    end
end

-- The world map opens on `map` (zoomed `zoom` times), and asks its data providers for their pins,
-- as the game does when it shows or changes maps.
function Mock.ShowMap(map, zoom)
    WorldMapFrame.mapID, WorldMapFrame.zoom = map or WorldMapFrame.mapID, zoom or 1
    WorldMapFrame:Show()
    for _, provider in ipairs(WorldMapFrame.dataProviders) do provider:RefreshAllData(true) end
end

-- The open map zooms (its providers keep their pins' size).
function Mock.Zoom(zoom)
    WorldMapFrame.zoom = zoom
    for _, provider in ipairs(WorldMapFrame.dataProviders) do provider:OnCanvasScaleChanged() end
end

-- Runs every visible frame's OnUpdate for `frames` frames of `elapsed` seconds each.
function Mock.Tick(frames, elapsed)
    for _ = 1, frames or 1 do
        for _, frame in ipairs(Mock.frames) do
            local script = frame.scripts.OnUpdate
            if script and frame:IsVisible() then script(frame, elapsed or 0.016) end
        end
    end
end

-- Moves the clocks on, running the timers that come due.
function Mock.Advance(seconds)
    local target = Mock.clock + seconds
    while true do
        local soonest, index
        for i, timer in ipairs(Mock.timers) do
            if not timer.cancelled and timer.at <= target and (not soonest or timer.at < soonest.at) then
                soonest, index = timer, i
            end
        end
        if not soonest then break end
        Mock.now = Mock.now + (soonest.at - Mock.clock)
        Mock.clock = soonest.at
        if soonest.interval then
            soonest.at = soonest.at + soonest.interval
        else
            table.remove(Mock.timers, index)
        end
        soonest.fn()
    end
    Mock.now = Mock.now + (target - Mock.clock)
    Mock.clock = target
end

local function TocFiles()
    local files = {}
    for raw in io.lines("HeyCousin.toc") do
        local line = raw:gsub("\r$", "")
        if line ~= "" and not line:find("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

-- A client: "retail" (test mode) or "forever" (surnames). Loads the addon with `saved` as its saved
-- variables and fires the loading events. Returns the addon's table.
function Mock.Boot(client, saved, player)
    Globals()
    local forever = client == "forever"
    WOW_PROJECT_MAINLINE, WOW_PROJECT_CAMELOT = 1, 18
    WOW_PROJECT_ID = forever and 18 or 1
    function GetBuildInfo()
        if forever then return "1.60.1", "70634", "Oct 30 2026", 16001 end
        return "12.1.5", "70575", "Oct 30 2026", 120105
    end
    RegionalUniqueNamesEnabled = forever and function() return true end or nil
    GetRegionalRulesetName = forever and function() return "PvE" end or nil
    C_PlayerInfo = forever and { ShouldDisplaySurname = function() return true end } or {}
    Constants = forever and { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } } or {}
    Mock.units.player = player or { name = "Rowan", surname = forever and "Ashbrook" or nil, guid = "Player-1-ME",
        class = "WARRIOR", race = "Human", level = 20, sex = 2, faction = "Alliance" }
    HeyCousinDB = saved
    local HC = {}
    for _, path in ipairs(TocFiles()) do assert(loadfile(path))("HeyCousin", HC) end
    Mock.Fire("ADDON_LOADED", "HeyCousin")
    Mock.Fire("PLAYER_LOGIN")
    Mock.Fire("PLAYER_ENTERING_WORLD", true, false)
    return HC
end

function Mock.Said(text)
    for _, line in ipairs(Mock.chat) do
        if line:find(text, 1, true) then return true end
    end
    return false
end
