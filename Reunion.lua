local _, HC = ...

-- A family reunion: two or more of your family in one group (you among them) get a banner with
-- their crests side by side, five or more a family raid. Once a group: again only when another
-- cousin joins it. Never in a fight: it waits for the fight to end.
HC.Reunion = {}

local Reunion = HC.Reunion
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local WIDTH, HEIGHT = 460, 186
local SHOW_FOR = 9      -- seconds on screen; pointing at it holds it
local FACES = 5         -- crests shown; the rest are a number
local RAID = 5          -- this many of you: a family raid
local SETTLE = 2        -- the group's changes come in bursts
local WAKE = 10         -- after you log in, the group you're in is the one you were in: no banner
local CREST = 52
local PREVIEW = { { "Mira", "MAGE", 23 }, { "Thane", "WARRIOR", 31 }, { "Bram", "PALADIN", 38 } }

local banner, stale
local cheered = {}      -- [first name] = true: in the banner of this group already
local awake = false
local later = false     -- a reunion came in a fight: it shows when the fight ends

local function Settings()
    return type(HeyCousinDB) == "table" and HeyCousinDB or {}
end

function Reunion.On()
    return Settings().reunion ~= false
end

-- Who in your group shares your surname, you first: { first, class, level, crest, me } each.
function Reunion.Gathered()
    local me, mine = Names.Me()
    if not Utils.IsUsableString(mine) then
        return {}
    end
    local _, myClass = Utils.Call(UnitClass, "player")
    local list = { { first = me, class = myClass, level = Utils.Call(UnitLevel, "player"), crest = Kin.Crest(), me = true } }
    local raid = Utils.Call(IsInRaid) == true
    local count = (raid and Utils.Call(GetNumGroupMembers) or Utils.Call(GetNumSubgroupMembers)) or 0
    for i = 1, count do
        local unit = (raid and "raid" or "party") .. i
        if Utils.Call(UnitIsPlayer, unit) == true and Utils.Call(UnitIsUnit, unit, "player") ~= true then
            local first, surname = Names.Unit(unit)
            if first and Names.Same(surname, mine) then
                local _, class = Utils.Call(UnitClass, unit)
                list[#list + 1] = { first = first, class = class, level = Utils.Call(UnitLevel, unit),
                    crest = Kin.CrestOf(first) }
            end
        end
    end
    return list
end

-- --- the banner --------------------------------------------------------------------------------

local function Motion(value)
    banner:SetAlpha(value)
    banner:ClearAllPoints()
    banner:SetPoint("TOP", UIParent, "TOP", 0, -260 + (1 - value) * 16)
    if value <= 0 and banner.leaving then
        banner.leaving = false
        banner:Hide()
    end
end

local function Build()
    banner = CreateFrame("Frame", "HeyCousinReunion", UIParent)
    banner:SetSize(WIDTH, HEIGHT)
    banner:SetFrameStrata("DIALOG")
    banner:SetClampedToScreen(true)
    banner:EnableMouse(true)
    banner:Hide()
    Theme.Panel(banner, "toast")
    banner.glow = Theme.Texture(banner, Theme.Shared("Glow"), "BACKGROUND", 2)
    banner.glow:SetSize(WIDTH, 220)
    banner.glow:SetPoint("CENTER", 0, -6)
    banner.glow:SetBlendMode("ADD")
    banner.ribbon = Theme.Ribbon(banner, 300, 36)
    banner.ribbon:SetPoint("TOP", 0, -14)
    banner.ribbon.text:SetFontObject(Theme.Font("Headline"))
    banner.line = Theme.Text(banner, "Small", C.text2)
    banner.line:SetPoint("TOP", banner.ribbon, "BOTTOM", 0, -6)
    banner.line:SetWidth(WIDTH - 60)
    banner.line:SetJustifyH("CENTER")
    banner.faces = {}
    for index = 1, FACES do
        local face = CreateFrame("Frame", nil, banner)
        face:SetSize(80, 80)
        face.crest = Crest.Create(face, CREST)
        face.crest:SetPoint("TOP", 0, 0)
        -- the one who looks like the eldest wears the crown
        face.crown = Theme.Texture(face, Theme.Icon("Crown"), "OVERLAY", 2, C.gold)
        face.crown:SetSize(18, 18)
        face.crown:SetPoint("BOTTOM", face.crest, "TOP", 0, -4)
        face.name = Theme.Text(face, "Small")
        face.name:SetPoint("TOP", face.crest, "BOTTOM", 0, -4)
        face.name:SetWidth(80)
        face.name:SetJustifyH("CENTER")
        banner.faces[index] = face
    end
    banner.more = Theme.Text(banner, "Body", C.text2)
    banner.close = Theme.IconButton(banner, "Close", 22)
    banner.close:SetPoint("TOPRIGHT", -10, -10)
    Theme.OnClick(banner.close, "reunion close", function()
        Reunion.Dismiss()
    end)
    banner.timer = Theme.Texture(banner, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 3)
    banner.timer:SetHeight(2)
    banner.timer:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 12, 7)
    banner:SetScript("OnEnter", function(self)
        self.hovered = true
    end)
    banner:SetScript("OnLeave", function(self)
        self.hovered = false
    end)
    banner:SetScript("OnUpdate", Utils.Protect("reunion timer", function(self, elapsed)
        if not self.hovered and not self.leaving then
            self.left = self.left - elapsed
        end
        self.timer:SetWidth(math.max(0.01, (WIDTH - 24) * math.max(0, self.left / SHOW_FOR)))
        if self.left <= 0 and not self.leaving then
            Reunion.Dismiss()
        end
    end))
end

local function Paint(gathered, note)
    local _, surname = Kin.House()
    local count = #gathered
    banner.ribbon.text:SetText(count >= RAID and L["A family raid!"] or L["Family reunion!"])
    local line = string.format(L["%d of House %s in one group"], count, surname or "")
    banner.line:SetText(note and (line .. "  ·  " .. note) or line)
    local shown = math.min(count, FACES)
    local eldest = Kin.Eldest()
    local gap = (WIDTH - 40) / math.max(shown, 1)
    local left = 20 + ((WIDTH - 40) - gap * shown) / 2
    for index, face in ipairs(banner.faces) do
        local who = gathered[index]
        face:SetShown(index <= shown)
        if index <= shown then
            face:ClearAllPoints()
            face:SetPoint("TOP", banner, "TOPLEFT", left + gap * (index - 0.5), -82)
            face.crest:SetCrest(who.crest or Kin.Crest(), surname)
            local color = Utils.ClassColor(who.class)
            face.name:SetText(who.me and L["You"] or who.first)
            face.name:SetTextColor(color[1], color[2], color[3])
            face.crown:SetShown(eldest ~= nil and who.first == eldest)
        end
    end
    banner.more:ClearAllPoints()
    banner.more:SetPoint("RIGHT", banner, "RIGHT", -16, -16)
    banner.more:SetText(count > FACES and ("+" .. (count - FACES)) or "")
    local metal, accent = Theme.Title(), Theme.Accent()
    banner.glow:SetVertexColor(accent[1], accent[2], accent[3], 0.35)
    banner.timer:SetVertexColor(metal[1], metal[2], metal[3], 0.85)
end

-- Shows the banner for `gathered` (Reunion.Gathered's list); `note` goes after the line.
function Reunion.Show(gathered, note)
    if not banner or stale then
        if banner then
            banner:Hide()
        end
        Build()
        stale = false
    end
    Paint(gathered, note)
    banner.left, banner.hovered, banner.leaving = SHOW_FOR, false, false
    banner:Show()
    Theme.Ease(banner, 1, Motion, 12, 0)
    for index, face in ipairs(banner.faces) do
        if face:IsShown() then
            Utils.After(0.12 * index, "reunion crest", function()
                Theme.Ease(face, 1, function(value)
                    face:SetAlpha(value)
                end, 10, 0)
            end)
        end
    end
    if HC.Alert.SoundKey() ~= "none" then
        HC.Alert.PlaySound("bell")
    end
    -- (a preview has its note: it earns nothing)
    if not note then
        HC.Badges.Earn("reunion")
        if #gathered >= RAID then
            HC.Badges.Earn("raid")
        end
    end
end

function Reunion.Dismiss()
    if not banner or not banner:IsShown() or banner.leaving then
        return
    end
    banner.leaving = true
    Theme.Ease(banner, 0, Motion, 14)
end

-- How it looks: you and made-up cousins (/cousin test reunion).
function Reunion.Preview()
    local _, mine = Names.Me()
    if not Utils.IsUsableString(mine) then
        return
    end
    local gathered = { Reunion.Gathered()[1] }
    for _, made in ipairs(PREVIEW) do
        gathered[#gathered + 1] = { first = made[1], class = made[2], level = made[3], crest = Kin.Crest() }
    end
    Reunion.Show(gathered, L["Preview: a reunion shows like this"])
end

-- --- the group ---------------------------------------------------------------------------------

-- The group changed: a banner when a cousin is in it who wasn't before.
local function Check()
    if Utils.Call(IsInGroup) ~= true then
        cheered, later = {}, false
        return
    end
    local gathered = Reunion.Gathered()
    local fresh = false
    for _, who in ipairs(gathered) do
        fresh = fresh or (not who.me and not cheered[who.first])
    end
    if not fresh then
        return
    end
    if not awake or not Reunion.On() then
        -- (counted as seen: they're no news later)
        for _, who in ipairs(gathered) do
            cheered[who.first] = true
        end
        return
    end
    if InCombatLockdown() then
        later = true
        return
    end
    for _, who in ipairs(gathered) do
        cheered[who.first] = true
    end
    Reunion.Show(gathered)
end

local checkSoon = Utils.Debounce(SETTLE, "reunion", Check)

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", Utils.Protect("reunion", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if later then
            later = false
            Check()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not awake and not frame.waking then
            frame.waking = true
            Utils.After(WAKE, "reunion wake", function()
                Check()
                awake = true
            end)
        end
    else
        checkSoon()
    end
end))
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- A new theme: the next banner is built in it.
Theme.OnSkin(function()
    if banner then
        stale = true
        banner:Hide()
    end
end)
