-- The whole addon on the mock game (mock_wow.lua): Retail's test mode and WoW Forever, both
-- themes, every window, the radar, the pop-up, chat, tooltips and layers. An error the addon
-- catches (Utils.Protect) fails the run as well.
local fails, checks = 0, 0
local function check(ok, message)
    checks = checks + 1
    if not ok then fails = fails + 1; print("ADDON FAIL: " .. message) end
end
local function NoErrors(HC, where)
    for _, e in ipairs(HC.errors) do check(false, where .. ": caught " .. e.label .. ": " .. e.message) end
    for i = #HC.errors, 1, -1 do HC.errors[i] = nil end
end
local function Walk(frame, fn)
    fn(frame)
    for _, child in ipairs(frame.children or {}) do Walk(child, fn) end
end
local function All(root, test)
    local list = {}
    Walk(root, function(f) if test(f) then list[#list + 1] = f end end)
    return list
end
local function ButtonWith(root, text)
    return All(root, function(f) return f.label and f.label.text == text and f:IsVisible() end)[1]
end
local function Crest(root, size)
    return All(root, function(f) return f.size == size and f.SetCrest ~= nil end)[1]
end
local function Settle()
    Mock.Tick(60)
    Mock.Advance(1)
end

-- === Retail: the test mode, the first setup, both themes ===================================

local HC = Mock.Boot("retail", nil)
check(HC.IsForever == false and HC.TestMode.active == true, "Retail runs the test mode")
check(HeyCousinDB.skin == "pixel" and HeyCousinDB.setupDone == false, "defaults: the Pixel look, no setup yet")
check(HC.Theme.Skin().key == "pixel", "Pixel is the look in use")
local minimap = _G.HeyCousinMinimapButton
check(minimap and minimap:IsShown(), "the minimap crest shows")
check(minimap.badge.text.text == "13", "the minimap badge counts the made-up family: " .. tostring(minimap.badge.text.text))
Mock.Advance(5)
local setup = _G.HeyCousinSetup
check(setup and setup:IsShown(), "the setup opens by itself the first time")
NoErrors(HC, "boot")

-- the crest page
local big = Crest(setup, 160)
check(big and big.crest.shape == "Heater" and big.crest.symbol == "initial", "the setup starts on the default crest")
local rights = All(setup, function(f) return f.direction == "RIGHT" and f:IsVisible() end)
check(#rights == 2, "two right arrows: shape and pattern")
rights[1]:Click()
check(big.crest.shape == "Round", "the shape arrow turns the shield: " .. big.crest.shape)
rights[2]:Click()
check(big.crest.division == "Pale", "the pattern arrow splits it: " .. big.crest.division)
local main = ButtonWith(setup, "Main")
main:Click()
check(main.strip:IsShown(), "the main color opens its colors")
local azure = All(main.strip, function(f) return f.key == "azure" end)[1]
azure:Click()
check(big.crest.field == "azure", "a color click paints the crest")
local symbol = ButtonWith(setup, "Symbol")
symbol:Click()
check(symbol.strip:IsShown() and not main.strip:IsShown(), "one picker open at a time")
local heart = All(symbol.strip, function(f) return f.choice and f.choice.charge == "Heart" end)[1]
heart:Click()
check(big.crest.symbol == "charge" and big.crest.charge == "Heart", "a symbol click puts it on")
local dice = All(setup, function(f) return f.icon and f.icon.file and f.icon.file:find("Dice") end)[1]
for _ = 1, 20 do dice:Click() end
check(HC.Crest.Normalize(big.crest).shape == big.crest.shape, "the dice makes real crests")
local motto = All(setup, function(f) return f.kind == "EditBox" and f:IsVisible() end)[1]
motto:SetText("Family first!")
ButtonWith(setup, "Next"):Click()
check(type(HeyCousinDB.testCrest) == "table" and HeyCousinDB.testMotto == "Family first!",
    "the crest and motto made in test mode are kept for Forever")
NoErrors(HC, "crest page")

-- alerts and look
local rows = All(setup, function(f) return f.toggle ~= nil and f:IsVisible() end)
check(#rows == 5, "five alert settings: " .. #rows)
rows[1]:Click()
check(HeyCousinDB.popup == false, "the pop-up setting turns off")
rows[1]:Click()
check(HeyCousinDB.popup == true, "and on")
rows[5]:Click()
check(HeyCousinDB.showMinimap == false and not minimap:IsShown(), "the minimap crest hides at once")
rows[5]:Click()
check(minimap:IsShown(), "and comes back")
local bell = ButtonWith(setup, "Bell")
bell:Click()
check(HeyCousinDB.sound == "bell" and #Mock.sounds > 0, "a sound chip picks and plays it")
local smooth = All(setup, function(f) return f.key == "smooth" and f.preview end)[1]
smooth:Click()
NoErrors(HC, "theme card")
check(HC.Theme.Skin().key == "smooth" and HeyCousinDB.skin == "smooth", "a theme card switches the look")
setup = _G.HeyCousinSetup
check(setup:IsShown() and ButtonWith(setup, "Done") ~= nil, "the setup comes back in the new look, on the same page")
Settle()
local done = ButtonWith(setup, "Done")
if done then done:Click() else setup:Hide(); HeyCousinDB.setupDone = true end
check(HeyCousinDB.setupDone == true and not setup:IsShown(), "done: the setup closes and won't open by itself again")
Settle()
check(_G.HeyCousinAlert and _G.HeyCousinAlert:IsShown(), "and a test pop-up shows how a cousin looks")
NoErrors(HC, "alerts and look")

-- the family window
SlashCmdList.HEYCOUSIN("")
local window = _G.HeyCousinWindow
check(window and window:IsShown(), "/cousin opens the family")
Settle()
local function Rows()
    return All(window, function(f) return f.item ~= nil and f:IsShown() end)
end
local list = Rows()
check(#list >= 9, "the list shows the family: " .. #list)
check(list[1].item.me == true, "you are on top")
list[2]:Click()
local card = All(window, function(f) return f.whisper ~= nil end)[1]
check(card and card:IsShown(), "a click on a relative opens their card")
ButtonWith(window, "Whisper"):Click()
check(Mock.Said("Test mode"), "test mode: made-up cousins can't be whispered")
ButtonWith(window, "Stats"):Click()
Settle()
ButtonWith(window, "Family"):Click()
local search = All(window, function(f) return f.kind == "EditBox" and f:IsVisible() end)[1]
search:SetText("mira")
Settle()
check(#Rows() == 1 and Rows()[1].item.first == "Mira", "search finds by name")
search:SetText("")
for _, key in ipairs({ "name", "level", "zone", "seen", "seen" }) do
    All(window, function(f) return f.key == key and f.arrow ~= nil end)[1]:Click()
end
Settle()
NoErrors(HC, "window")

-- the next look, with the window open: it's built again in it
SlashCmdList.HEYCOUSIN("theme")
check(HC.Theme.Skin().key == "pixel", "/cousin theme goes to the next look")
window = _G.HeyCousinWindow
check(window:IsShown(), "the open window comes back in the new look")
Settle()
NoErrors(HC, "theme switch")

-- every test pop-up, and the combat rule
for _ = 1, 4 do
    SlashCmdList.HEYCOUSIN("test")
    Settle()
    Mock.Advance(10)
    Settle()
end
check(_G.HeyCousinAsk and _G.HeyCousinAsk:IsShown(), "the fourth test is a cousin asking to join your layer")
SlashCmdList.HEYCOUSIN("test")
Settle()
local toast = _G.HeyCousinAlert
check(toast:IsShown(), "a pop-up shows")
Mock.Fire("PLAYER_REGEN_DISABLED")
check(not toast:IsShown(), "a fight starting hides the pop-up at once")
Mock.combat = true
Mock.Advance(20)
Settle()
check(not toast:IsShown(), "no pop-up during the fight")
Mock.combat = false
Mock.Fire("PLAYER_REGEN_ENABLED")
Settle()
check(toast:IsShown(), "it comes back after the fight")
NoErrors(HC, "pop-ups")

-- your own tooltip, in test mode
GameTooltip.unit = "player"
Mock.Run(GameTooltip, "OnTooltipCleared")
Mock.postCalls[2](GameTooltip, {})
local family
for _, line in ipairs(GameTooltip.lines) do family = family or (line:find("Family: Ashbrook", 1, true) and line) end
check(family ~= nil, "your tooltip has the family line")
NoErrors(HC, "tooltip")

-- === WoW Forever: the radar, chat, tooltips, layers ===========================================

HC = Mock.Boot("forever", { setupDone = true })
check(HC.IsForever == true and HC.TestMode.active == false, "Forever: no test mode")
local house = HC.Kin.House()
check(house ~= nil, "your house, by your surname")
Mock.units.target = { name = "Mira", surname = "Ashbrook", guid = "Player-1-MIRA", class = "MAGE", race = "Human",
    level = 23, sex = 3, faction = "Alliance" }
Mock.Fire("PLAYER_TARGET_CHANGED")
check(house.relatives.Mira and house.relatives.Mira.class == "MAGE" and house.relatives.Mira.met == 1,
    "a target with your surname becomes a relative")
Settle()
toast = _G.HeyCousinAlert
check(toast and toast:IsShown(), "a cousin near you: the pop-up")
check(_G.HeyCousinAlertClick:GetAttribute("macrotext1") == "/cleartarget\n/targetexact Mira Ashbrook",
    "a click targets them by their whole name")
Mock.units.mouseover = { name = "Bob", surname = "Stone", guid = "Player-1-BOB", class = "ROGUE", faction = "Alliance" }
Mock.Fire("UPDATE_MOUSEOVER_UNIT")
check(house.relatives.Bob == nil and HeyCousinDB.surnames.Stone == 1, "a stranger isn't family, but their surname counts")
Mock.units.nameplate1 = { name = "Grom", surname = "Ashbrook", guid = "Player-2-GROM", class = "HUNTER", race = "Orc",
    level = 8, faction = "Horde" }
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(house.relatives.Grom and HC.Kin.IsBlackSheep(house.relatives.Grom), "a cousin on the other side: a black sheep")
Mock.Advance(12)
Settle()
Mock.Advance(2)
Settle()
check(toast:IsShown(), "the black sheep's pop-up follows")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(house.relatives.Grom.met == 1, "seen again at once: still one meeting")
Mock.units.nameplate2 = { npc = true, guid = "Creature-0-1-1-4242-55-66" }
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
check(HC.Layer.Current() == 4242, "an NPC tells your layer: " .. tostring(HC.Layer.Current()))
NoErrors(HC, "radar")

-- chat: the crest leads a relative's lines
local filter = Mock.filters.CHAT_MSG_SAY and Mock.filters.CHAT_MSG_SAY[1]
check(filter ~= nil, "a chat filter is set")
local changed, text = filter(nil, "CHAT_MSG_SAY", "hello", "Mira Ashbrook", "", "", "", "", 0, 0, "", 0, 1, "Player-1-MIRA")
check(changed == false and text and text:find("|T", 1, true) == 1 and text:find("hello", 1, true), "the crest leads Mira's line")
changed, text = filter(nil, "CHAT_MSG_SAY", "hey", "Bob Stone", "", "", "", "", 0, 0, "", 0, 2, "Player-1-BOB")
check(changed == false and text == nil, "a stranger's line stays as it is")
changed, text = filter(nil, "CHAT_MSG_SAY", Mock.SECRET, "Mira Ashbrook", "", "", "", "", 0, 0, "", 0, 3, "Player-1-MIRA")
check(changed == false and text == nil, "a secret line passes untouched")
Mock.players["Player-1-LIA"] = { name = "Lia", surname = "Ashbrook", class = "PRIEST", race = "Human", sex = 3 }
Mock.Fire("CHAT_MSG_SAY", "hi all", "Lia Ashbrook", "", "", "", "", 0, 0, "", 0, 4, "Player-1-LIA")
check(house.relatives.Lia and house.relatives.Lia.class == "PRIEST", "a relative heard saying something is family too")
Mock.roster = { { full = "Odo Ashbrook", level = 45, class = "MAGE", zone = "Tanaris", online = true, guid = "Player-1-ODO" },
    { full = "Ann Other", level = 10, class = "ROGUE", zone = "Durotar", online = false, guid = "Player-1-ANN" } }
Mock.Fire("GUILD_ROSTER_UPDATE")
Mock.Advance(9)
check(house.relatives.Odo and house.relatives.Odo.met == 0 and house.relatives.Ann == nil,
    "guild members with your surname are learned, not met")
NoErrors(HC, "chat")

-- tooltips
GameTooltip.unit = "target"
Mock.Run(GameTooltip, "OnTooltipCleared")
Mock.postCalls[2](GameTooltip, {})
local lines = table.concat(GameTooltip.lines, "\n")
check(lines:find("Family: Ashbrook (cousin)", 1, true) and lines:find("Met once", 1, true), "a cousin's tooltip has the family lines")
local count = #GameTooltip.lines
Mock.postCalls[2](GameTooltip, {})
check(#GameTooltip.lines == count, "a tooltip refresh doesn't add the lines twice")
NoErrors(HC, "tooltips")

-- layers: asking, and being asked
HC.Layer.Ask("Mira", "Ashbrook")
local sent = Mock.addonSent[#Mock.addonSent]
check(sent and sent.text == "1:A" and sent.target == "Mira Ashbrook" and sent.prefix == "HeyCousin", "the ask goes to their addon")
Mock.Advance(4)
check(Mock.opened[1] and Mock.opened[1]:find("/w Mira Ashbrook", 1, true) == 1, "no addon answered: a whisper waits in your chat box")
Mock.Fire("PARTY_INVITE_REQUEST", "Mira Ashbrook")
check(Mock.accepted == 1 and Mock.popupHidden == "PARTY_INVITE", "the invite you asked for is accepted")
Mock.units.nameplate3 = { npc = true, guid = "Creature-0-1-1-5151-55-67" }
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
check(Mock.Said("layer now"), "a new layer: you hear you're there")
Mock.Fire("PARTY_INVITE_REQUEST", "Bob Stone")
check(Mock.accepted == 1, "an invite you didn't ask for is yours to answer")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "1:A", "WHISPER", "Lia Ashbrook")
local ask = _G.HeyCousinAsk
check(ask and ask:IsShown(), "a cousin's ask shows")
check(Mock.addonSent[#Mock.addonSent].text == "1:Y", "and their addon hears you got it")
ButtonWith(ask, "Invite"):Click()
check(Mock.invites[#Mock.invites] == "Lia Ashbrook" and not ask:IsShown(), "one click invites them")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "1:A", "WHISPER", "Bob Stone")
check(not ask:IsShown(), "a stranger can't ask")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "1:Q", "WHISPER", "Mira Ashbrook")
check(Mock.addonSent[#Mock.addonSent].text == "1:L:5151:1429", "a cousin's addon asks: yours tells your layer")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "1:L:5151:1429", "WHISPER", "Mira Ashbrook")
check(HC.Layer.Status("Mira") ~= nil and HC.Layer.Status("Mira"):find("Same layer", 1, true), "their answer: same layer")
HC.Layer.Query("Odo", "Ashbrook")
local quiet = Mock.filters.CHAT_MSG_SYSTEM and Mock.filters.CHAT_MSG_SYSTEM[1]
check(quiet and quiet(nil, "CHAT_MSG_SYSTEM", "No player named 'Odo Ashbrook' is currently playing.") == true,
    "the game's 'no player named' for an automatic question is hidden")
NoErrors(HC, "layers")

-- the window on Forever
SlashCmdList.HEYCOUSIN("")
window = _G.HeyCousinWindow
Settle()
local mira = All(window, function(f) return f.item and f.item.first == "Mira" and f:IsShown() end)[1]
check(mira ~= nil, "Mira is in the list")
mira:Click()
Settle()
ButtonWith(window, "Whisper"):Click()
check(Mock.tells[#Mock.tells] == "Mira Ashbrook", "Whisper opens a whisper to their whole name")
ButtonWith(window, "Invite"):Click()
check(Mock.invites[#Mock.invites] == "Mira Ashbrook", "Invite invites them")
SlashCmdList.HEYCOUSIN("status")
check(Mock.Said("Your layer: 5151") and Mock.Said("\"Ashbrook\""), "status shows your surname and your layer")
NoErrors(HC, "forever window")

-- the launch-day name test: a checklist, and what the game hands over written down
Mock.units.target = { name = "Mira", surname = "Ashbrook", guid = "Player-1-MIRA", class = "MAGE", race = "Human",
    level = 23, sex = 3, faction = "Alliance" }
SlashCmdList.HEYCOUSIN("probe")
local probe = HeyCousinDB.probe
check(probe and probe.client and probe.done.name, "the name test reads your name at once")
check(probe.client.unitName[1] == "Rowan" and probe.client.unitName[2] == "Ashbrook", "your name, both parts as the game gives them")
check(_G.HeyCousinProbe and _G.HeyCousinProbe:IsShown(), "its checklist shows")
local forms = 0
for kind, sent in pairs(probe.addon.sent) do
    forms = forms + 1
    check(type(sent.target) == "string", "an addon message to yourself as " .. kind)
end
check(forms >= 3, "addon messages to yourself, your name written three ways: " .. forms)
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "probe:full", "WHISPER", "Rowan Ashbrook")
check(probe.addon.got.full and probe.addon.got.full.sender == "Rowan Ashbrook" and probe.done.addon, "the one that arrives is noted")
Mock.Fire("CHAT_MSG_SAY", "hello", "Mira Ashbrook", "", "", "", "", 0, 0, "", 0, 9, "Player-1-MIRA")
check(probe.chat_CHAT_MSG_SAY and probe.chat_CHAT_MSG_SAY[1].author == "Mira Ashbrook" and probe.done.say, "a /say line, its author as it came")
Mock.Fire("PLAYER_TARGET_CHANGED")
check(probe.units and probe.units[1].unitName[2] == "Ashbrook" and probe.done.target, "a target's name parts")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
check(probe.npc and probe.npc[1].layer == 5151 and probe.done.npc, "an NPC and its layer")
Mock.Fire("GUILD_ROSTER_UPDATE")
check(probe.guild and probe.guild[1].name == "Odo Ashbrook" and probe.done.guild, "guild names as the roster has them")
local targetSelf = _G.HeyCousinProbetargetSelf
check(targetSelf:GetAttribute("macrotext1") == "/cleartarget\n/targetexact Rowan Ashbrook", "the test targets you by your whole name")
targetSelf:Click()
Mock.Advance(1)
check(probe.targeting and probe.targeting.targetSelf and probe.done.targetSelf, "and writes down what got targeted")
Mock.Fire("PLAYER_REGEN_DISABLED")
check(not _G.HeyCousinProbe:IsShown(), "a fight hides the checklist (it has secure buttons)")
SlashCmdList.HEYCOUSIN("probe")
check(_G.HeyCousinProbe:IsShown(), "/cousin probe brings it back while it runs")
for _ = 1, 10 do Mock.Fire("CHAT_MSG_SAY", "spam", "Bob Stone", "", "", "", "", 0, 0, "", 0, 9, "Player-1-BOB") end
check(#probe.chat_CHAT_MSG_SAY <= 6, "only a few samples of each kind")
SlashCmdList.HEYCOUSIN("probe stop")
check(probe.stopped and not _G.HeyCousinProbe:IsShown(), "it stops")
Mock.Fire("CHAT_MSG_SAY", "after", "Lia Ashbrook", "", "", "", "", 0, 0, "", 0, 9, "Player-1-LIA")
check(#probe.chat_CHAT_MSG_SAY == 2, "and records nothing after")
NoErrors(HC, "name test")

-- a secret name (protected content) is never used
Mock.units.target = { name = Mock.SECRET, surname = "Ashbrook", guid = "Player-9-SEC", class = "MAGE", faction = "Alliance" }
Mock.Fire("PLAYER_TARGET_CHANGED")
for first in pairs(house.relatives) do check(type(first) == "string", "relatives are named by text only") end
NoErrors(HC, "secrets")

-- === Broken saved data ========================================================================

HC = Mock.Boot("forever", { skin = "nope", chats = "x", setupDone = true, windows = 5,
    houses = { Ashbrook = { crest = { shape = "Weird", field = 5, symbol = "charge", charge = "Nope" }, relatives = "oops", motto = 7 } } })
house = HC.Kin.House()
check(house.crest.shape == "Heater" and house.crest.symbol == "initial" and type(house.relatives) == "table",
    "a broken saved house is mended")
check(HC.Theme.Skin().key == "pixel", "an unknown look falls back to Pixel")
SlashCmdList.HEYCOUSIN("")
Settle()
SlashCmdList.HEYCOUSIN("setup")
Settle()
NoErrors(HC, "broken saved data")

print(fails == 0 and ("addon checks passed (" .. checks .. " checks)") or (fails .. " addon checks failed"))
