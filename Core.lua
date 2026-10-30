local addonName, HC = ...

HC.VERSION = "0.1.0"
HC.AUTHOR = "powercover"

local Utils = HC.Utils
local L = HC.L
local frame = CreateFrame("Frame")

-- WoW Forever, or Retail in test mode: Retail has no surnames, so the addon shows made-up cousins
-- there.
HC.IsForever = Utils.IsForever()

local function SavedDefaults()
    HeyCousinDB = Utils.CopyDefaults(HeyCousinDB, {
        debug = false,
        language = "auto",
    })
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
    Utils.Print(L["Commands: /heycousin or /cousin, then:"])
    Utils.Print("  status - " .. L["what the game tells the addon about you"])
    Utils.Print("  debug - " .. L["the errors the addon caught, in chat (on or off)"])
end

local function HandleSlash(message)
    local command = Utils.Trim(message):lower()
    if command == "" or command == "help" then
        PrintHelp()
    elseif command == "status" then
        HC.PrintStatus()
    elseif command == "debug" then
        SavedDefaults()
        HeyCousinDB.debug = not HeyCousinDB.debug
        Utils.Print(HeyCousinDB.debug and L["Debug on: errors the addon catches show in chat."] or L["Debug off."])
        if HeyCousinDB.debug then
            PrintErrors()
        end
    else
        Utils.Print(L["Unknown command."])
        PrintHelp()
    end
end

-- Every game event the addon reacts to; an error in one is noted (Utils.Protect), never shown.
frame:SetScript("OnEvent", Utils.Protect("event", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        SavedDefaults()
        -- The chosen language first: everything built from here on speaks it.
        HC.Locale.Apply()
    end
end))

frame:RegisterEvent("ADDON_LOADED")

SLASH_HEYCOUSIN1 = "/heycousin"
SLASH_HEYCOUSIN2 = "/cousin"
SlashCmdList.HEYCOUSIN = Utils.Protect("chat command", HandleSlash)
