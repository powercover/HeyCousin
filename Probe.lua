local _, HC = ...

-- The launch-day name test (/cousin probe): how WoW Forever hands names to addons, written into
-- the saved file (HeyCousinDB.probe) for step 3 to plug in. A checklist walks you through a few
-- small things; each ticks when the game has shown it. You stand in for the other player: it
-- targets you by your whole name, you whisper yourself, and its addon messages go to you. It
-- records only while it runs, a few samples of each kind, and stops by itself after half an hour.
HC.Probe = {}

local Probe = HC.Probe
local Utils = HC.Utils
local Theme = HC.Theme
local Names = HC.Names
local L = HC.L
local C = Theme.C

local SAMPLES = 6
local RUN_FOR = 30 * 60
local PREFIX = "HeyCousin"
local CHATS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
}
local STEPS = {
    { key = "name", text = L["Your name, as the game gives it"] },
    { key = "say", text = L["Say hello in /say"] },
    { key = "target", text = L["Target another player"] },
    { key = "mouseover", text = L["Point at another player with the mouse"] },
    { key = "guild", text = L["Open your guild window (skip it without a guild)"] },
    { key = "npc", text = L["Point at any NPC"] },
    { key = "targetSelf", text = L["Click below: target yourself by your whole name"] },
    { key = "whisper", text = L["Click below: whisper yourself, then press Enter"] },
    { key = "addon", text = L["Addon messages to yourself (by themselves)"] },
}

local frame = CreateFrame("Frame")
local running, stopAt
local seen = {}
local window
-- built in a look that's gone (the look changed during a fight): built again before it shows
local stale = false

local function Data()
    return HeyCousinDB.probe
end

-- A value from the game, as the saved file can keep it: a secret never turned into text.
local function Value(value)
    if Utils.IsSecret(value) then
        return "(secret)"
    end
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then
        return value
    end
    if value == nil then
        return "nil"
    end
    return "(" .. kind .. ")"
end

-- Every value a call answers (or its error), as a list; a nil among them is kept as "nil".
local function Pack(...)
    return { n = select("#", ...), ... }
end

local function Answers(fn, ...)
    if type(fn) ~= "function" then
        return { "(no such function)" }
    end
    local results = Pack(pcall(fn, ...))
    if not results[1] then
        return { "(error) " .. tostring(Value(results[2])) }
    end
    local out = {}
    for i = 2, results.n do
        out[#out + 1] = Value(results[i])
    end
    if #out == 0 then
        out[1] = "nil"
    end
    return out
end

-- Keeps `sample` under `kind`, once per `key`, a few of each kind.
local function Keep(kind, key, sample)
    local data = Data()
    seen[kind] = seen[kind] or {}
    local list = data[kind]
    if type(list) ~= "table" then
        list = {}
        data[kind] = list
    end
    if seen[kind][key] or #list >= SAMPLES then
        return false
    end
    seen[kind][key] = true
    sample.at = time()
    list[#list + 1] = sample
    return true
end

local function Mark(step)
    local data = Data()
    data.done = type(data.done) == "table" and data.done or {}
    if not data.done[step] then
        data.done[step] = true
        if window and window:IsShown() then
            Probe.Paint()
        end
    end
end

-- --- what it reads -----------------------------------------------------------------------------

-- Your name as the game gives it (not test mode's made-up family: the test is about the game).
local function Me()
    local ok, first, surname = pcall(UnitNameUnmodified or UnitName, "player")
    if not ok or not Utils.IsUsableString(first) then
        return "", nil
    end
    return first, Utils.IsUsableString(surname) and surname or nil
end

local function ReadClient()
    local data = Data()
    local full = Names.Full(Me())
    local separators = Constants and Constants.CharacterNameSeparatorConsts
    data.client = {
        build = Answers(GetBuildInfo),
        project = { Value(WOW_PROJECT_ID), Value(WOW_PROJECT_CAMELOT), Value(WOW_PROJECT_MAINLINE) },
        regionalNames = Answers(RegionalUniqueNamesEnabled),
        ruleset = Answers(GetRegionalRulesetName),
        showSurname = Answers(C_PlayerInfo and C_PlayerInfo.ShouldDisplaySurname),
        separator = Value(separators and separators.CHARACTERNAME_SURNAME_SEPARATOR),
        unitName = Answers(UnitName, "player"),
        unitNameUnmodified = Answers(UnitNameUnmodified, "player"),
        getUnitName = Answers(GetUnitName, "player", true),
        unitFullName = Answers(UnitFullName, "player"),
        realm = Answers(GetRealmName),
        normalizedRealm = Answers(GetNormalizedRealmName),
        guid = Value(Utils.Call(UnitGUID, "player")),
        byGuid = Answers(GetPlayerInfoByGUID, Utils.Call(UnitGUID, "player")),
        ambiguate = {
            none = Answers(Ambiguate, full, "none"), short = Answers(Ambiguate, full, "short"),
            all = Answers(Ambiguate, full, "all"), guild = Answers(Ambiguate, full, "guild"),
        },
        guildInfo = Answers(GetGuildInfo, "player"),
        channels = Answers(GetChannelList),
    }
    Mark("name")
end

local function ReadUnit(unit, source)
    if Utils.Call(UnitExists, unit) ~= true then
        return
    end
    local guid = Utils.Call(UnitGUID, unit)
    if Utils.Call(UnitIsPlayer, unit) ~= true then
        -- an NPC: its GUID carries the layer
        if Keep("npc", tostring(guid), { guid = Value(guid), layer = Value(HC.Layer.FromGUID(guid)), source = source }) then
            Mark("npc")
        end
        return
    end
    if Utils.Call(UnitIsUnit, unit, "player") == true then
        return
    end
    local kept = Keep("units", tostring(guid), {
        source = source,
        unitName = Answers(UnitName, unit),
        unitNameUnmodified = Answers(UnitNameUnmodified, unit),
        getUnitName = Answers(GetUnitName, unit, true),
        unitFullName = Answers(UnitFullName, unit),
        guid = Value(guid),
        byGuid = Answers(GetPlayerInfoByGUID, guid),
        sameServer = Answers(UnitIsSameServer, unit),
        relationship = Answers(UnitRealmRelationship, unit),
        faction = Answers(UnitFactionGroup, unit),
        guild = Answers(GetGuildInfo, unit),
        hidden = Value(Utils.UnitHidden(unit)),
    })
    if kept and (source == "target" or source == "mouseover") then
        Mark(source)
    end
end

local function ReadGroup()
    local raid = Utils.Call(IsInRaid) == true
    local count = (raid and Utils.Call(GetNumGroupMembers) or Utils.Call(GetNumSubgroupMembers)) or 0
    for i = 1, math.min(count, SAMPLES) do
        ReadUnit((raid and "raid" or "party") .. i, "group")
    end
end

local function ReadGuild()
    local count = Utils.Call(GetNumGuildMembers) or 0
    local data = Data()
    for i = 1, math.min(count, SAMPLES) do
        local entry = Answers(GetGuildRosterInfo, i)
        Keep("guild", tostring(entry[1]) .. i, {
            name = entry[1], online = entry[9], class = entry[11], guid = entry[17],
            byGuid = Answers(GetPlayerInfoByGUID, entry[17]),
        })
    end
    if count > 0 then
        data.guildCount = count
        Mark("guild")
    end
end

local function ReadChat(event, text, author, ...)
    local name2, guid = select(3, ...), select(10, ...)
    local channel, channelIndex, channelBase = select(2, ...), select(6, ...), select(7, ...)
    local sample = {
        author = Value(author), name2 = Value(name2), guid = Value(guid), text = Value(text),
        byGuid = Answers(GetPlayerInfoByGUID, guid),
        channel = event == "CHAT_MSG_CHANNEL" and { Value(channel), Value(channelIndex), Value(channelBase) } or nil,
    }
    if Keep("chat_" .. event, tostring(author), sample) then
        if event == "CHAT_MSG_SAY" then
            Mark("say")
        elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
            Mark("whisper")
        end
    end
end

local function ReadTooltip(tooltip, data)
    if not running or tooltip ~= GameTooltip then
        return
    end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or not Utils.IsUsableString(unit) or Utils.Call(UnitIsPlayer, unit) ~= true then
        return
    end
    local line = type(data) == "table" and type(data.lines) == "table" and data.lines[1]
    local first = type(line) == "table" and line.leftText
    if first == nil and GameTooltipTextLeft1 then
        first = Utils.Call(GameTooltipTextLeft1.GetText, GameTooltipTextLeft1)
    end
    Keep("tooltip", tostring(Utils.Call(UnitGUID, unit)), { first = Value(first), unitName = Answers(UnitName, unit) })
end

-- --- the tests with you as the other player ---------------------------------------------------

-- Addon whispers to yourself, by three ways of writing your name: which ones arrive tells how an
-- addon whisper must name a player. The game says "no player named" for a wrong one.
local function SendToSelf()
    local first, surname = Me()
    local forms = {
        full = Names.Full(first, surname),
        dash = surname and (first .. "-" .. surname) or first,
        first = first,
        unit = Utils.Call(GetUnitName, "player", true),
    }
    local data = Data()
    data.addon = { sent = {}, got = {}, system = {} }
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    for kind, target in pairs(forms) do
        if Utils.IsUsableString(target) then
            data.addon.sent[kind] = { target = target, result = Answers(C_ChatInfo and C_ChatInfo.SendAddonMessage, PREFIX,
                "probe:" .. kind, "WHISPER", target) }
        end
    end
end

-- Targets you by `name` (a secure button: only out of combat), then looks at what got targeted.
local function TargetResult(kind)
    local data = Data()
    data.targeting = type(data.targeting) == "table" and data.targeting or {}
    data.targeting[kind] = {
        name = Value(window and window[kind] and window[kind]:GetAttribute("macrotext1")),
        targetedYou = Value(Utils.Call(UnitIsUnit, "target", "player")),
        target = Answers(UnitName, "target"),
    }
    if kind == "targetSelf" then
        Mark("targetSelf")
    end
    Probe.Paint()
end

local function WhisperSelf()
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if type(open) == "function" then
        open("/w " .. Names.Full(Me()) .. " " .. L["Hello from the Hey Cousin! probe"], DEFAULT_CHAT_FRAME)
    end
end

-- --- events ------------------------------------------------------------------------------------

frame:SetScript("OnEvent", Utils.Protect("probe", function(_, event, ...)
    if not running then
        return
    end
    if GetTime() > stopAt then
        Probe.Stop()
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        ReadUnit("target", "target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        ReadUnit("mouseover", "mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        ReadUnit((...), "nameplate")
    elseif event == "GROUP_ROSTER_UPDATE" then
        ReadGroup()
    elseif event == "GUILD_ROSTER_UPDATE" then
        ReadGuild()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == PREFIX and Utils.IsUsableString(text) and text:find("^probe:") then
            local data = Data()
            data.addon.got[text:sub(7)] = { sender = Value(sender), channel = Value(channel) }
            Mark("addon")
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        local data = Data()
        if data.addon and #data.addon.system < SAMPLES then
            data.addon.system[#data.addon.system + 1] = Value((...))
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- the window holds secure buttons: it goes before the fight's lockdown
        if window and window:IsShown() then
            window:Hide()
        end
    else
        ReadChat(event, ...)
    end
end))

-- --- the window --------------------------------------------------------------------------------

local function SecureButton(parent, kind, label)
    local button = CreateFrame("Button", "HeyCousinProbe" .. kind, parent, "SecureActionButtonTemplate")
    button:SetSize(176, 30)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type1", "macro")
    local face = Theme.Button(button, label, "primary", 176, 30)
    face:SetAllPoints()
    face:EnableMouse(false)
    -- as wide as its label: the pixel font is wide
    button:SetWidth(math.max(176, math.ceil(face.label:GetStringWidth()) + 32))
    button:SetScript("PostClick", Utils.Protect("probe target", function(_, _, down)
        if not down then
            Utils.After(0.3, "probe target", function()
                TargetResult(kind)
            end)
        end
    end))
    return button
end

local function Build()
    window = Theme.Window("HeyCousinProbe", 460, 556)
    stale = false
    local title = Theme.Text(window, "Title")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText(L["Name test"])
    local metal = Theme.Metal()
    title:SetTextColor(metal[1], metal[2], metal[3])
    local note = Theme.Text(window, "Small", C.text2)
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    note:SetPoint("RIGHT", window, "RIGHT", -20, 0)
    note:SetWordWrap(true)
    note:SetText(L["How WoW Forever gives names to addons. Do these few things; each ticks by itself."])
    window.rows = {}
    for index, step in ipairs(STEPS) do
        local row = CreateFrame("Frame", nil, window)
        row:SetSize(420, 28)
        row:SetPoint("TOPLEFT", 20, -88 - (index - 1) * 30)
        row.check = Theme.Texture(row, Theme.Icon("Check"), "ARTWORK", 0, C.near)
        row.check:SetSize(16, 16)
        row.check:SetPoint("LEFT", 0, 0)
        row.dot = Theme.Texture(row, "Interface\\Buttons\\WHITE8X8", "ARTWORK", 0, C.text3)
        row.dot:SetSize(6, 6)
        row.dot:SetPoint("CENTER", row.check, "CENTER")
        row.text = Theme.Text(row, "Body")
        row.text:SetPoint("LEFT", 26, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.text:SetText(step.text)
        row.key = step.key
        window.rows[index] = row
    end
    local first, surname = Me()
    window.targetSelf = SecureButton(window, "targetSelf", L["Target me (whole name)"])
    -- a row each: their labels are long
    window.targetSelf:SetPoint("BOTTOMLEFT", 20, 102)
    window.targetSelf:SetAttribute("macrotext1", "/cleartarget\n/targetexact " .. Names.Full(first, surname))
    window.targetFirst = SecureButton(window, "targetFirst", L["Target me (first name)"])
    window.targetFirst:SetPoint("BOTTOMLEFT", 20, 64)
    window.targetFirst:SetAttribute("macrotext1", "/cleartarget\n/targetexact " .. first)
    local whisper = Theme.Button(window, L["Whisper myself"], "secondary", 176, 30)
    whisper:SetPoint("BOTTOMLEFT", 20, 26)
    Theme.ButtonIcon(whisper, "Whisper")
    Theme.Fit(whisper, 16, 176)
    Theme.OnClick(whisper, "probe whisper", WhisperSelf)
    local stop = Theme.Button(window, L["Stop"], "secondary", 100, 30)
    stop:SetPoint("BOTTOMRIGHT", -20, 26)
    Theme.OnClick(stop, "probe stop", function()
        Probe.Stop()
    end)
    window.footer = Theme.Text(window, "Small", C.text3)
    window.footer:SetPoint("BOTTOMLEFT", 20, 142)
    window.footer:SetPoint("RIGHT", window, "RIGHT", -20, 0)
    window.footer:SetWordWrap(true)
end

function Probe.Paint()
    if not window then
        return
    end
    local done = type(Data().done) == "table" and Data().done or {}
    local count = 0
    for _, row in ipairs(window.rows) do
        local ok = done[row.key] == true
        count = count + (ok and 1 or 0)
        row.check:SetShown(ok)
        row.dot:SetShown(not ok)
        local color = ok and C.text2 or C.text
        row.text:SetTextColor(color[1], color[2], color[3])
    end
    window.footer:SetText(string.format(L["%d of %d done. When you're done, log out or type /reload: the game writes it all down."],
        count, #STEPS))
end

-- --- starting and stopping ---------------------------------------------------------------------

function Probe.Start()
    if InCombatLockdown() then
        Utils.Print(L["Not during a fight."])
        return
    end
    HeyCousinDB.probe = { started = time(), version = HC.VERSION, done = {} }
    seen = {}
    running, stopAt = true, GetTime() + RUN_FOR
    for _, event in ipairs(CHATS) do
        frame:RegisterEvent(event)
    end
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
        "GROUP_ROSTER_UPDATE", "GUILD_ROSTER_UPDATE", "CHAT_MSG_ADDON", "CHAT_MSG_SYSTEM", "PLAYER_REGEN_DISABLED" }) do
        frame:RegisterEvent(event)
    end
    if not Probe.hooked and TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
        and Enum and Enum.TooltipDataType then
        Probe.hooked = true
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Utils.Protect("probe tooltip", ReadTooltip))
    end
    ReadClient()
    ReadGroup()
    if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
        pcall(C_GuildInfo.GuildRoster)
    end
    SendToSelf()
    if not window then
        Build()
    end
    Probe.Paint()
    window:Show()
    Utils.Print(L["Name test on. It stops by itself in half an hour."])
end

function Probe.Stop()
    if not running then
        return
    end
    running = false
    frame:UnregisterAllEvents()
    Data().stopped = time()
    if window and window:IsShown() and not InCombatLockdown() then
        window:Hide()
    end
    Utils.Print(L["Name test off. Log out or type /reload so the game writes it down."])
end

-- On, off, or the checklist again while it runs (built anew after a new look).
function Probe.Toggle()
    if not running then
        Probe.Start()
    elseif window and window:IsShown() then
        Probe.Stop()
    elseif InCombatLockdown() then
        Utils.Print(L["Not during a fight."])
    else
        if not window or stale then
            if window then
                window:Hide()
            end
            Build()
        end
        Probe.Paint()
        window:Show()
    end
end

function Probe.Running()
    return running == true
end

-- A new theme: the window is built again in it (now if it's open; after a fight, the next time).
Theme.OnSkin(function()
    if not window then
        return
    end
    if InCombatLockdown() then
        stale = true
        return
    end
    local shown = window:IsShown()
    window:Hide()
    window = nil
    if shown then
        Build()
        Probe.Paint()
        window:Show()
    end
end)
