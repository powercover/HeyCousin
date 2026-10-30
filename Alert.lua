local _, HC = ...

HC.Alert = {}

local Alert = HC.Alert
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

local WIDTH, HEIGHT = 380, 92
local SHOW_FOR = 8      -- seconds on screen; pointing at it holds it
local QUEUE_MAX = 5
local STALE = 90        -- a waiting pop-up older than this is dropped
local SOUND_GAP = 3
Alert.SOUNDS = {
    boop = Theme.MEDIA .. "Sounds\\Boop.ogg",
    chime = Theme.MEDIA .. "Sounds\\Chime.ogg",
    bell = Theme.MEDIA .. "Sounds\\Bell.ogg",
}
local FACTIONS = { Horde = "FACTION_HORDE", Alliance = "FACTION_ALLIANCE" }

local toast, stale
local queue = {}
local lastSound = 0

local function Settings()
    return type(HeyCousinDB) == "table" and HeyCousinDB or {}
end

-- The pop-up's sound: the one chosen, or the theme's own ("auto").
function Alert.SoundKey()
    local key = Settings().sound
    if key == nil or key == "auto" then
        key = Theme.Skin().sound
    end
    return key
end

function Alert.PlaySound(key)
    local file = Alert.SOUNDS[key or Alert.SoundKey()]
    if file and type(PlaySoundFile) == "function" then
        pcall(PlaySoundFile, file, "Master")
    end
end

-- --- the pop-up frame --------------------------------------------------------------------------

local function SavePlace()
    local x, y = toast:GetCenter()
    local scale = toast:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if x and y then
        HeyCousinDB.alertPlace = { x = x * scale, y = y * scale }
    end
end

local function Place(offset)
    local place = Settings().alertPlace
    toast:ClearAllPoints()
    if type(place) == "table" and type(place.x) == "number" and type(place.y) == "number" then
        toast:SetPoint("CENTER", UIParent, "BOTTOMLEFT", place.x, place.y + offset)
    else
        toast:SetPoint("TOP", UIParent, "TOP", 0, -150 + offset)
    end
end

-- Slides in from a little above and fades in; out the same way, then hides.
local function Motion(value)
    toast:SetAlpha(value)
    Place((1 - value) * 14)
    if value <= 0 and toast.leaving then
        toast.leaving = false
        toast:Hide()
        Alert.Next()
    end
end

local function Build()
    toast = CreateFrame("Frame", "HeyCousinAlert", UIParent)
    toast:SetSize(WIDTH, HEIGHT)
    toast:SetFrameStrata("DIALOG")
    toast:SetClampedToScreen(true)
    toast:SetMovable(true)
    toast:Hide()
    Theme.Panel(toast, "toast")

    -- the house's color glowing behind the portrait
    toast.glow = Theme.Texture(toast, Theme.Shared("Glow"), "BACKGROUND", 2)
    toast.glow:SetSize(150, 150)
    toast.glow:SetPoint("CENTER", toast, "LEFT", 48, 0)
    toast.glow:SetBlendMode("ADD")

    -- their face when they're near (the game shows a model only for a unit it can see), else
    -- the crest
    local portrait = CreateFrame("Frame", nil, toast)
    portrait:SetSize(64, 64)
    portrait:SetPoint("LEFT", 14, 0)
    Theme.Panel(portrait, "frame")
    toast.portrait = portrait
    local model = CreateFrame("PlayerModel", nil, portrait)
    model:SetPoint("TOPLEFT", 4, -4)
    model:SetPoint("BOTTOMRIGHT", -4, 4)
    model:SetScript("OnModelLoaded", function(self)
        self:SetPortraitZoom(1)
    end)
    toast.model = model
    toast.crest = Crest.Create(toast, 64)
    toast.crest:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    -- the crest pops in with a little bounce
    local bounce = toast.crest:CreateAnimationGroup()
    local grow = bounce:CreateAnimation("Scale")
    grow:SetScaleFrom(0.6, 0.6)
    grow:SetScaleTo(1.12, 1.12)
    grow:SetDuration(0.18)
    grow:SetSmoothing("OUT")
    local settle = bounce:CreateAnimation("Scale")
    settle:SetScaleFrom(1, 1)
    settle:SetScaleTo(0.893, 0.893)
    settle:SetDuration(0.12)
    settle:SetStartDelay(0.18)
    settle:SetSmoothing("IN_OUT")
    toast.bounce = bounce
    toast.badge = Crest.Create(toast, 28)
    toast.badge:SetPoint("CENTER", portrait, "BOTTOMRIGHT", -2, 4)
    toast.badge:SetFrameLevel(portrait:GetFrameLevel() + 6)

    toast.title = Theme.Text(toast, "Headline")
    toast.title:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 14, -3)
    toast.title:SetPoint("RIGHT", toast, "RIGHT", -60, 0)
    toast.mark = Theme.Texture(toast, Theme.Icon("Star"), "OVERLAY", 0)
    toast.mark:SetSize(16, 16)
    toast.name = Theme.Text(toast, "Body")
    toast.name:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -8)
    toast.name:SetPoint("RIGHT", toast, "RIGHT", -16, 0)
    toast.note = Theme.Text(toast, "Small", C.text3)
    toast.note:SetPoint("TOPLEFT", toast.name, "BOTTOMLEFT", 0, -6)
    toast.note:SetPoint("RIGHT", toast, "RIGHT", -16, 0)
    toast.more = Theme.Text(toast, "Small", C.text2)
    toast.more:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -40, -14)

    -- how long it stays: a thin line along the bottom that empties
    toast.timer = Theme.Texture(toast, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 3)
    toast.timer:SetHeight(2)
    toast.timer:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 12, 7)

    -- a band of light sweeps over it once as it comes in
    local clip = CreateFrame("Frame", nil, toast)
    clip:SetPoint("TOPLEFT", 4, -4)
    clip:SetPoint("BOTTOMRIGHT", -4, 4)
    clip:SetClipsChildren(true)
    local sheen = Theme.Texture(clip, Theme.Shared("Sheen"), "OVERLAY", 0, { 1, 1, 1 }, 0.12)
    sheen:SetSize(150, HEIGHT)
    sheen:SetPoint("LEFT", clip, "LEFT", -150, 0)
    sheen:SetBlendMode("ADD")
    local sweep = sheen:CreateAnimationGroup()
    local move = sweep:CreateAnimation("Translation")
    move:SetOffset(WIDTH + 150, 0)
    move:SetDuration(1.1)
    move:SetSmoothing("IN_OUT")
    move:SetStartDelay(0.15)
    toast.sweep = sweep

    -- Left-click targets them: only a secure button may, and only out of combat, which is the
    -- only time the pop-up shows. Right-click opens the family; Shift-drag moves the pop-up.
    local click = CreateFrame("Button", "HeyCousinAlertClick", toast, "SecureActionButtonTemplate")
    click:SetAllPoints()
    click:SetFrameLevel(toast:GetFrameLevel() + 8)
    click:RegisterForClicks("AnyUp", "AnyDown")
    click:SetAttribute("useOnKeyDown", false)
    click:SetAttribute("type1", "macro")
    click:RegisterForDrag("LeftButton")
    click:SetScript("PostClick", Utils.Protect("pop-up click", function(_, button, down)
        if down or not toast.item then
            return
        end
        if button == "RightButton" and HC.Window then
            HC.Window.ShowRelative(toast.item.first)
            Alert.Dismiss()
        end
    end))
    click:SetScript("OnEnter", function()
        toast.hovered = true
    end)
    click:SetScript("OnLeave", function()
        toast.hovered = false
    end)
    click:SetScript("OnDragStart", function()
        if IsShiftKeyDown() then
            toast:StartMoving()
        end
    end)
    click:SetScript("OnDragStop", function()
        toast:StopMovingOrSizing()
        SavePlace()
    end)
    toast.click = click

    toast.close = Theme.IconButton(toast, "Close", 22)
    toast.close:SetPoint("TOPRIGHT", -10, -10)
    toast.close:SetFrameLevel(click:GetFrameLevel() + 2)
    Theme.OnClick(toast.close, "pop-up close", function()
        Alert.Dismiss()
    end)

    toast:SetScript("OnUpdate", Utils.Protect("pop-up timer", function(self, elapsed)
        if not self.hovered and not self.leaving then
            self.left = self.left - elapsed
        end
        self.timer:SetWidth(math.max(0.01, (WIDTH - 24) * math.max(0, self.left / SHOW_FOR)))
        if self.left <= 0 and not self.leaving then
            Alert.Dismiss()
        end
    end))
end

-- --- showing -----------------------------------------------------------------------------------

local function Paint(item)
    local relative = item.relative or {}
    local house, surname = Kin.House()
    local crest = house and house.crest or Crest.Normalize(nil)
    local sheep = Kin.IsBlackSheep(relative)
    local metal, accent = Theme.Metal(), Theme.Accent()

    if sheep then
        local faction = _G[FACTIONS[relative.faction] or ""] or relative.faction or ""
        toast.title:SetText(string.format(L["Your cousin joined the %s!"], faction))
        toast.title:SetTextColor(C.enemy[1], C.enemy[2], C.enemy[3])
        Theme.SetArt(toast.mark, Theme.Icon("Sheep"))
        toast.mark:SetVertexColor(C.text[1], C.text[2], C.text[3])
    elseif item.new then
        toast.title:SetText(L["A new cousin!"])
        toast.title:SetTextColor(metal[1], metal[2], metal[3])
        Theme.SetArt(toast.mark, Theme.Icon("Star"))
        toast.mark:SetVertexColor(metal[1], metal[2], metal[3])
    else
        toast.title:SetText(L["A cousin is near!"])
        toast.title:SetTextColor(metal[1], metal[2], metal[3])
    end
    toast.mark:SetShown(sheep or item.new == true)
    toast.mark:ClearAllPoints()
    toast.mark:SetPoint("LEFT", toast.title, "LEFT", toast.title:GetStringWidth() + 6, 0)

    local full = Names.Full(item.first, surname)
    local line = Theme.Paint(full, Utils.ClassColor(relative.class))
    local className = Utils.ClassName(relative.class, relative.sex)
    if relative.level and className then
        line = line .. Theme.Paint("  ·  " .. string.format(L["Level %d %s"], relative.level, className), C.text2)
    end
    toast.name:SetText(line)
    local note
    if item.preview then
        note = L["Preview: a cousin shows like this"]
    elseif item.test then
        note = L["Test mode: a made-up cousin"]
    elseif item.new or (relative.met or 0) <= 1 then
        note = L["The first time you meet"]
    else
        note = string.format(L["Met %d times"], relative.met)
    end
    toast.note:SetText(note .. "  ·  " .. L["Click: target · Right-click: family"])

    local glow = sheep and C.enemy or accent
    toast.glow:SetVertexColor(glow[1], glow[2], glow[3], 0.5)
    toast.timer:SetVertexColor(metal[1], metal[2], metal[3], 0.85)

    -- their face if the game can show them, else the crest
    local unit = item.unit
    local live = unit and Utils.Call(UnitExists, unit) and not Utils.UnitHidden(unit)
    toast.model:ClearModel()
    if live then
        toast.model:SetUnit(unit)
        toast.model:SetPortraitZoom(1)
        toast.model:Show()
        toast.crest:Hide()
        toast.badge:SetCrest(crest, surname, sheep)
        toast.badge:Show()
    else
        toast.model:Hide()
        toast.badge:Hide()
        toast.crest:SetCrest(crest, surname, sheep)
        toast.crest:Show()
    end

    toast.click:SetAttribute("macrotext1", "/cleartarget\n/targetexact " .. full)
    toast.more:SetText(#queue > 0 and ("+" .. #queue) or "")
end

local function Present(item)
    if not toast or stale then
        if toast then
            toast:Hide()
        end
        Build()
        stale = false
    end
    toast.item = item
    Paint(item)
    toast.left, toast.hovered, toast.leaving = SHOW_FOR, false, false
    toast:Show()
    Theme.Ease(toast, 1, Motion, 12, 0)
    toast.sweep:Stop()
    toast.sweep:Play()
    if toast.crest:IsShown() then
        toast.bounce:Stop()
        toast.bounce:Play()
    end
    if Alert.SoundKey() ~= "none" and GetTime() - lastSound > SOUND_GAP then
        lastSound = GetTime()
        Alert.PlaySound()
    end
end

-- The next waiting pop-up, if any is still fresh and the game allows it now.
function Alert.Next()
    if InCombatLockdown() or (toast and toast:IsShown()) then
        return
    end
    while #queue > 0 do
        local item = table.remove(queue, 1)
        if GetTime() - item.at < STALE then
            Present(item)
            return
        end
    end
end

-- Shows a pop-up for `item` = { first, relative, new, unit, test }, now or after the one on
-- screen. Never in combat: it waits for the fight to end.
function Alert.Show(item)
    item.at = GetTime()
    for index = #queue, 1, -1 do
        if queue[index].first == item.first then
            table.remove(queue, index)
        end
    end
    if toast and toast:IsShown() and toast.item and toast.item.first == item.first then
        return
    end
    if #queue >= QUEUE_MAX then
        table.remove(queue, 1)
    end
    queue[#queue + 1] = item
    if toast and toast:IsShown() then
        toast.more:SetText("+" .. #queue)
    end
    Alert.Next()
end

-- The rules for a relative the radar just saw: pop-ups on, not one for them lately, black sheep
-- only when wanted.
function Alert.Cousin(first, relative, new, unit)
    local settings = Settings()
    if settings.popup == false then
        return
    end
    if Kin.IsBlackSheep(relative) and settings.enemyAlerts == false then
        return
    end
    local cooldown = (tonumber(settings.cooldown) or 30) * 60
    if relative.alerted and time() - relative.alerted < cooldown then
        return
    end
    relative.alerted = time()
    Alert.Show({ first = first, relative = relative, new = new, unit = unit })
end

-- How a cousin will look, with you as the cousin (after the setup, and /cousin test on Forever).
function Alert.Preview()
    local first = Names.Me()
    local _, class = Utils.Call(UnitClass, "player")
    Alert.Show({
        first = first or L["You"], unit = "player", preview = true, new = true,
        relative = {
            class = class, level = Utils.Call(UnitLevel, "player"), sex = Utils.Call(UnitSex, "player"),
            faction = Utils.Call(UnitFactionGroup, "player"), met = 1,
        },
    })
end

function Alert.Dismiss()
    if not toast or not toast:IsShown() or toast.leaving then
        return
    end
    if InCombatLockdown() then
        return
    end
    toast.leaving = true
    Theme.Ease(toast, 0, Motion, 14)
end

-- A fight is about to start (PLAYER_REGEN_DISABLED, just before the lockdown): the pop-up goes
-- at once, as its secure button can't be hidden once the lockdown is on.
function Alert.HideForCombat()
    if toast and toast:IsShown() then
        toast.leaving = false
        Theme.Jump(toast, 0)
        toast:Hide()
        if toast.item then
            toast.item.at = GetTime()
            table.insert(queue, 1, toast.item)
        end
    end
end

-- A new theme: the next pop-up is built in it.
Theme.OnSkin(function()
    if toast then
        stale = true
        if toast:IsShown() and not InCombatLockdown() then
            toast:Hide()
        end
    end
end)
