-- The addon as the game loads it (the TOC's files, in its order) on mocked game functions: the
-- saved settings get their defaults, the chat commands answer, WoW Forever is told apart from
-- Retail's test mode, a secret name is never turned into text, and an error is caught and noted.
if not unpack then unpack = table.unpack end
local fails = 0
local function check(ok, message) if not ok then fails = fails + 1; print("CORE FAIL: " .. message) end end

local files = {}
for raw in io.lines("HeyCousin.toc") do
  local line = raw:gsub("\r$", "")
  if line ~= "" and not line:find("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
end
check(files[1] == "Locales/Locales.lua" and files[#files] == "Core.lua", "the TOC loads the Locales first and Core.lua last")

-- the game, mocked
local printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) printed[#printed + 1] = text end }
local frame
function CreateFrame()
  frame = { events = {} }
  function frame:SetScript(name, fn) self[name] = fn end
  function frame:RegisterEvent(event) self.events[event] = true end
  return frame
end
function GetLocale() return "enUS" end
local SECRET = setmetatable({}, { __tostring = function() return "a secret" end })
function issecretvalue(value) return value == SECRET end

local FOREVER = { project = 18, interface = 16001, version = "1.60.1", build = "70634", name = "Mira",
  second = "Ashbrook", regional = true, ruleset = "PvE" }
-- some Forever builds report WOW_PROJECT_MAINLINE, like Retail
local FOREVER_AS_MAINLINE = { project = 1, interface = 16001, version = "1.60.1", build = "70634", name = "Mira",
  second = "Ashbrook", regional = true, ruleset = "PvE" }
local RETAIL = { project = 1, interface = 120105, version = "12.1.5", build = "70575", name = "Mira" }

-- Loads the addon on one client with its saved settings as the game hands them over, and fires
-- its ADDON_LOADED.
local function Load(client, saved)
  WOW_PROJECT_MAINLINE, WOW_PROJECT_CAMELOT, WOW_PROJECT_ID = 1, 18, client.project
  function GetBuildInfo() return client.version, client.build, "Oct 30 2026", client.interface end
  function UnitName() return client.name, client.second end
  RegionalUniqueNamesEnabled = client.regional and function() return true end or nil
  GetRegionalRulesetName = client.ruleset and function() return client.ruleset end or nil
  C_PlayerInfo = client.regional and { ShouldDisplaySurname = function() return true end } or {}
  Constants = client.regional and { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } } or {}
  SlashCmdList, HeyCousinDB, printed = {}, saved, {}
  local HC = {}
  for _, path in ipairs(files) do assert(loadfile(path))("HeyCousin", HC) end
  frame.OnEvent(frame, "ADDON_LOADED", "HeyCousin")
  return HC
end

local function Printed(text)
  for _, line in ipairs(printed) do
    if line:find(text, 1, true) then return true end
  end
  return false
end

local function Run(command)
  printed = {}
  SlashCmdList.HEYCOUSIN(command)
end

-- WoW Forever: the defaults, the commands, the status
local HC = Load(FOREVER, nil)
check(HC.IsForever == true, "WOW_PROJECT_CAMELOT is WoW Forever")
check(HeyCousinDB.debug == false and HeyCousinDB.language == "auto", "the saved settings get their defaults")
check(frame.events.ADDON_LOADED, "the addon waits for its saved settings")
check(SLASH_HEYCOUSIN1 == "/heycousin" and SLASH_HEYCOUSIN2 == "/cousin", "the chat commands: /heycousin and /cousin")
Run("")
check(Printed(HC.VERSION) and Printed("powercover") and Printed("status"), "/heycousin alone shows the version and the commands")
Run("  STATUS ")
check(Printed('"Mira", then "Ashbrook"'), "status shows the name and the surname as UnitName gives them")
check(Printed("This is WoW Forever.") and Printed('Ruleset: "PvE"') and Printed("Names unique in the region: true"),
  "status shows Forever's name rules")
check(Printed('Between name and surname: " "'), "and the separator, in quotes so a space shows")
Run("dance")
check(Printed("Unknown command.") and Printed("status"), "an unknown command shows the commands")
Run("debug")
check(HeyCousinDB.debug == true and Printed("No errors caught."), "debug turns on and lists the caught errors")
Run("debug")
check(HeyCousinDB.debug == false and Printed("Debug off."), "and off again")
check(#HC.errors == 0, "no error caught on the way: " .. tostring(HC.errors[1] and HC.errors[1].message))

-- the saved settings are kept as they are
Load(FOREVER, { debug = true, language = "deDE", later = 1 })
check(HeyCousinDB.debug == true and HeyCousinDB.language == "deDE" and HeyCousinDB.later == 1, "saved settings are kept")

-- a Forever build that reports WOW_PROJECT_MAINLINE: its interface version tells
HC = Load(FOREVER_AS_MAINLINE, nil)
check(HC.IsForever == true, "a Forever build reporting WOW_PROJECT_MAINLINE is still Forever")

-- Retail: test mode, and none of Forever's name functions
HC = Load(RETAIL, nil)
check(HC.IsForever == false, "Retail is not Forever")
Run("status")
check(Printed("test mode") and Printed('"Mira", then -') and Printed("Names unique in the region: -"),
  "status on Retail: test mode, no surname, no name rules")
check(#HC.errors == 0, "Retail: no error caught: " .. tostring(HC.errors[1] and HC.errors[1].message))

-- a secret name (protected content) is never turned into text
FOREVER.name = SECRET
HC = Load(FOREVER, nil)
Run("status")
check(Printed("(secret), then") and not Printed("a secret"), "a secret name shows as (secret)")
FOREVER.name = "Mira"

-- an error in the addon is caught and noted, never thrown at the game
HC = Load(FOREVER, nil)
local boom = HC.Utils.Protect("test", function() error("boom") end)
local ok = pcall(boom)
check(ok and #HC.errors == 1 and HC.errors[1].label == "test" and HC.errors[1].count == 1, "Protect catches and notes an error")
boom()
check(#HC.errors == 1 and HC.errors[1].count == 2, "the same error again is counted, not listed twice")
Run("debug")
check(Printed("test:") and Printed("(x2)"), "debug lists it with its count")

print(fails == 0 and "core checks passed" or (fails .. " core checks failed"))
