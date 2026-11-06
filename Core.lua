local addonName, HC = ...

HC.VERSION = "0.1.0"
HC.AUTHOR = "powercover"

local Utils = HC.Utils
local L = HC.L
local frame = CreateFrame("Frame")

-- WoW Forever, or Retail in test mode: Retail has no surnames, so the addon shows a made-up family
-- there.
HC.IsForever = Utils.IsForever()

local DEFAULTS = {
    debug = false,
    language = "auto",
    skin = "forever",
    setupDone = false,
    popup = true,
    enemyAlerts = true,
    sound = "auto",
    cooldown = 30,
    chatCrest = true,
    tooltipLine = true,
    showMinimap = true,
    minimapAngle = 200,
    lockMinimap = false,
    chats = { say = true, channel = true, guild = true, group = true, whisper = true },
    -- the family map: your cousins' crests on yours; where you are, shared only when you say
    mapShow = true,
    mapShare = false,
}

local function SavedDefaults()
    HeyCousinDB = Utils.CopyDefaults(HeyCousinDB, DEFAULTS)
end

-- What the game tells the addon about the client and this character: the first thing to check
-- on a new build of the game.
function HC.PrintStatus()
    local version, build, _, interface = Utils.Call(GetBuildInfo)
    Utils.Print(string.format(L["Version %s by %s"], HC.VERSION, HC.AUTHOR))
    Utils.Print(string.format(L["Game: %s, build %s, interface %s"], Utils.Shown(version), Utils.Shown(build),
        Utils.Shown(interface)))
    Utils.Print(HC.IsForever and L["This is WoW Forever."] or L["This is not WoW Forever: test mode."])
    -- Forever's name rules; Retail has none of these
    local playerInfo = C_PlayerInfo
    local separators = Constants and Constants.CharacterNameSeparatorConsts
    Utils.Print(string.format(L["Names unique in the region: %s"], Utils.Shown((Utils.Call(RegionalUniqueNamesEnabled)))))
    Utils.Print(string.format(L["Ruleset: %s"], Utils.Shown((Utils.Call(GetRegionalRulesetName)))))
    Utils.Print(string.format(L["Your surname shown: %s"],
        Utils.Shown(playerInfo and (Utils.Call(playerInfo.ShouldDisplaySurname)))))
    Utils.Print(string.format(L["Between name and surname: %s"],
        Utils.Shown(separators and separators.CHARACTERNAME_SURNAME_SEPARATOR)))
    -- Forever's UnitName gives the first name, then the surname; Retail's, the name and no realm
    local ok, name, second = pcall(UnitName, "player")
    if ok then
        Utils.Print(string.format(L["Your name: %s, then %s"], Utils.Shown(name), Utils.Shown(second)))
    end
    Utils.Print(string.format(L["Your layer: %s"], Utils.Shown(HC.Layer.Current())))
end

-- The errors the addon caught (Utils.Protect), the newest last.
local function PrintErrors()
    if #HC.errors == 0 then
        Utils.Print(L["No errors caught."])
        return
    end
    for _, known in ipairs(HC.errors) do
        Utils.Print(string.format("%s: %s (x%d)", known.label, known.message, known.count))
    end
end

local function PrintHelp()
    Utils.Print(string.format(L["Version %s by %s"], HC.VERSION, HC.AUTHOR))
    Utils.Print("/cousin - " .. L["your family"])
    Utils.Print("/cousin tree - " .. L["your guild as a family tree"])
    Utils.Print("/cousin setup - " .. L["your crest, alerts and look"])
    Utils.Print("/cousin test - " .. L["a pop-up to try"])
    Utils.Print("/cousin test map - " .. L["made-up cousins on your map, to try"])
    Utils.Print("/cousin theme - " .. L["the next look"])
    Utils.Print("/cousin status - " .. L["what the game tells the addon about you"])
    Utils.Print("/cousin probe - " .. L["the launch-day name test (on or off)"])
    Utils.Print("/cousin debug - " .. L["the errors the addon caught, in chat (on or off)"])
end

local function HandleSlash(message)
    local command = Utils.Trim(message):lower()
    if command == "" then
        HC.Window.Toggle()
    elseif command == "tree" then
        HC.Window.Show("tree")
    elseif command == "setup" then
        HC.Setup.Show()
    elseif command == "test" then
        if HC.TestMode.active then
            HC.TestMode.Pop()
        else
            HC.Alert.Preview()
        end
    elseif command == "test map" then
        HC.Map.Preview()
    elseif command == "theme" or command == "look" then
        HC.Theme.SetSkin(HC.Theme.Next(HC.Theme.Skin().key))
        Utils.Print(string.format(L["Look: %s"], HC.Theme.Skin().name))
    elseif command == "status" then
        HC.PrintStatus()
    elseif command == "probe" then
        HC.Probe.Toggle()
    elseif command == "probe stop" then
        HC.Probe.Stop()
    elseif command == "debug" then
        SavedDefaults()
        HeyCousinDB.debug = not HeyCousinDB.debug
        Utils.Print(HeyCousinDB.debug and L["Debug on: errors the addon catches show in chat."] or L["Debug off."])
        if HeyCousinDB.debug then
            PrintErrors()
        end
    elseif command == "help" then
        PrintHelp()
    else
        Utils.Print(L["Unknown command."])
        PrintHelp()
    end
end

local welcomed = false

-- Every game event the addon reacts to; an error in one is noted (Utils.Protect), never shown.
frame:SetScript("OnEvent", Utils.Protect("event", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then
            return
        end
        SavedDefaults()
        HC.Kin.ForgetRealms()
        -- The chosen language and look first: everything built from here on has them.
        HC.Locale.Apply()
        HC.Theme.Use(HeyCousinDB.skin)
        if not HC.IsForever then
            HC.TestMode.Start()
        end
        HC.Kin.ApplyAccent()
    elseif event == "PLAYER_LOGIN" then
        HC.Minimap.Apply()
        HC.Tooltip.Start()
        HC.Chat.Start()
        HC.Radar.Start()
        HC.Layer.Start()
        HC.Guild.Start()
        HC.Map.Start()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- the first time: the setup, a moment after the world shows
        if not welcomed and not HeyCousinDB.setupDone then
            welcomed = true
            Utils.After(4, "welcome", function()
                if not InCombatLockdown() and not HeyCousinDB.setupDone then
                    HC.Setup.Show()
                end
            end)
        end
    end
end))

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

SLASH_HEYCOUSIN1 = "/heycousin"
SLASH_HEYCOUSIN2 = "/cousin"
SlashCmdList.HEYCOUSIN = Utils.Protect("chat command", HandleSlash)
