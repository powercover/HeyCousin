local _, HC = ...

HC.Radar = {}

local Radar = HC.Radar
local Utils = HC.Utils
local Names = HC.Names
local Kin = HC.Kin

-- A player is looked at once a minute at most (a new target always is).
local LOOK_AGAIN = 60
local LOOKED_MAX = 3000

local frame = CreateFrame("Frame")
local looked, lookedCount = {}, 0
local fighting = false

-- The chats that teach the addon who's family (settings), by event.
local CHATS = {
    CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "say", CHAT_MSG_EMOTE = "say",
    CHAT_MSG_CHANNEL = "channel",
    CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "guild",
    CHAT_MSG_PARTY = "group", CHAT_MSG_PARTY_LEADER = "group", CHAT_MSG_RAID = "group",
    CHAT_MSG_RAID_LEADER = "group", CHAT_MSG_INSTANCE_CHAT = "group", CHAT_MSG_INSTANCE_CHAT_LEADER = "group",
    CHAT_MSG_WHISPER = "whisper",
}
Radar.CHATS = CHATS

function Radar.Watches(kind)
    local chats = type(HeyCousinDB) == "table" and HeyCousinDB.chats
    return type(chats) ~= "table" or chats[kind] ~= false
end

-- --- units -------------------------------------------------------------------------------------

-- How the game showed a unit: for a meeting's page.
local function How(unit)
    if unit == "target" or unit == "mouseover" then
        return unit
    elseif unit:find("^nameplate") then
        return "nameplate"
    elseif unit:find("^party") or unit:find("^raid") then
        return "group"
    end
end

-- One unit: a player with your surname becomes (or stays) a relative. `near`: seen around you,
-- so a pop-up may show.
function Radar.Look(unit, near)
    if fighting or not Radar.running then
        return
    end
    if Utils.Call(UnitIsPlayer, unit) ~= true or Utils.Call(UnitIsUnit, unit, "player") == true then
        return
    end
    local guid = Utils.Call(UnitGUID, unit)
    if not Utils.IsUsableString(guid) then
        return
    end
    local now = GetTime()
    local last = looked[guid]
    if last and now - last < LOOK_AGAIN and unit ~= "target" then
        return
    end
    if not last then
        lookedCount = lookedCount + 1
        if lookedCount > LOOKED_MAX then
            looked, lookedCount = {}, 1
        end
    end
    looked[guid] = now
    local first, surname = Names.Unit(unit)
    if not first then
        return
    end
    Kin.SawPlayer(first, surname)
    local _, mine = Names.Me()
    if not Names.Same(surname, mine) then
        return
    end
    local _, class = Utils.Call(UnitClass, unit)
    local _, race = Utils.Call(UnitRace, unit)
    local relative, new, meeting = Kin.Seen({
        first = first, class = class, race = race, level = Utils.Call(UnitLevel, unit),
        sex = Utils.Call(UnitSex, unit), faction = Utils.Call(UnitFactionGroup, unit),
        guild = Utils.Call(GetGuildInfo, unit) or false, zone = near and Utils.Zone() or nil, guid = guid,
        near = near, how = How(unit),
        group = Utils.Call(UnitInParty, unit) == true or Utils.IsUsableNumber((Utils.Call(UnitInRaid, unit))),
    })
    if relative and near and (new or meeting) then
        HC.Alert.Cousin(first, relative, new, unit)
    end
    -- their gear, once a meeting, while they're this close
    if relative and near and Kin.WantsGear(first) then
        HC.Gear.Look(unit, first)
    end
end

local function LookAtGroup()
    local raid = Utils.Call(IsInRaid) == true
    local count = (raid and Utils.Call(GetNumGroupMembers) or Utils.Call(GetNumSubgroupMembers)) or 0
    for i = 1, count do
        local unit = (raid and "raid" or "party") .. i
        Radar.Look(unit, Utils.Call(UnitIsVisible, unit) == true)
    end
end

local lookAtGroupSoon = Utils.Debounce(1.5, "group", LookAtGroup)

-- --- the guild roster --------------------------------------------------------------------------

-- Guild members with your surname are family too: learned quietly (no pop-up, no meeting), with
-- when they were last online.
local function ReadRoster()
    if fighting or not Radar.running or type(GetGuildRosterInfo) ~= "function" then
        return
    end
    local _, mine = Names.Me()
    local guild = Utils.Call(GetGuildInfo, "player")
    local count = Utils.Call(GetNumGuildMembers) or 0
    local now = time()
    for i = 1, count do
        local full, _, _, level, _, zone, _, _, online, _, class, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        local first, surname = Names.Split(full)
        if first and Names.Same(surname, mine) and not Utils.IsSecret(full) then
            local seen
            if online then
                seen = now
            elseif type(GetGuildRosterLastOnline) == "function" then
                local years, months, days, hours = GetGuildRosterLastOnline(i)
                if years then
                    seen = now - ((((years * 12 + months) * 30 + days) * 24 + hours) * 3600)
                end
            end
            Kin.Seen({
                first = first, class = class, level = level, guild = guild, guid = guid,
                zone = online and zone or nil, quiet = true, seenAt = seen,
            })
        end
    end
end

local readRosterSoon = Utils.Debounce(8, "guild roster", ReadRoster)

-- --- chat --------------------------------------------------------------------------------------

-- A chat line from a relative teaches the addon too: say and yell mean they're around you.
local function Heard(event, text, author, ...)
    local kind = CHATS[event]
    if not kind or not Radar.Watches(kind) or Utils.IsSecret(text) or Utils.IsSecret(author) then
        return
    end
    local guid = select(10, ...)
    local first, surname, class, race, sex = Names.FromGUID(guid)
    if not first then
        return
    end
    Kin.SawPlayer(first, surname)
    local _, mine = Names.Me()
    if not Names.Same(surname, mine) or Names.Same(first, (Names.Me())) then
        return
    end
    local near = kind == "say"
    local relative, new, meeting = Kin.Seen({
        first = first, class = class, race = race, sex = sex, guid = guid, near = near,
        zone = near and Utils.Zone() or nil, quiet = not near and kind ~= "whisper",
        how = (near or kind == "whisper") and (near and "say" or "whisper") or nil,
        -- what they said around you (a whisper is yours, not kept)
        said = near and text or nil,
    })
    if relative and near and (new or meeting) then
        HC.Alert.Cousin(first, relative, new, nil)
    end
end

-- --- events ------------------------------------------------------------------------------------

frame:SetScript("OnEvent", Utils.Protect("radar", function(_, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        -- before the lockdown starts: the pop-up's secure button must go now
        fighting = true
        HC.Alert.HideForCombat()
    elseif event == "PLAYER_REGEN_ENABLED" then
        fighting = false
        HC.Alert.Next()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        Radar.Look((...), true)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Radar.Look("mouseover", true)
    elseif event == "PLAYER_TARGET_CHANGED" then
        Radar.Look("target", true)
    elseif event == "GROUP_ROSTER_UPDATE" then
        lookAtGroupSoon()
    elseif event == "GUILD_ROSTER_UPDATE" then
        readRosterSoon()
    elseif CHATS[event] then
        if not fighting and Radar.running then
            Heard(event, ...)
        end
    end
end))

-- The fight events always: the pop-up (test mode's too) hides when a fight starts.
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Starts looking for relatives: only where names have surnames (WoW Forever).
function Radar.Start()
    if Radar.running or not Names.HaveSurnames() then
        return
    end
    Radar.running = true
    fighting = Utils.Call(InCombatLockdown) == true
    for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED",
        "GROUP_ROSTER_UPDATE", "GUILD_ROSTER_UPDATE" }) do
        frame:RegisterEvent(event)
    end
    for event in pairs(CHATS) do
        frame:RegisterEvent(event)
    end
    LookAtGroup()
    if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
        pcall(C_GuildInfo.GuildRoster)
    elseif type(GuildRoster) == "function" then
        pcall(GuildRoster)
    end
end
