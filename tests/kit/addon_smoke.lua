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
-- a frame with no place never shows in the game
check(next(setup.anchors) ~= nil, "the setup has a place on screen")
NoErrors(HC, "boot")

-- the setup's frame: a step bar, the look on top, back (or skip), reset and next
check(ButtonWith(setup, "Crest") and ButtonWith(setup, "Alerts") and ButtonWith(setup, "Crest").node.kind == "primary",
    "a step bar, on the first step")
check(ButtonWith(setup, "Skip for now") ~= nil and ButtonWith(setup, "Back") == nil, "the first time: skip, no back")
check(setup.look and setup.look.forward:IsVisible() and setup.look.name.text == "Pixel", "the look on top of the step")
check(not ButtonWith(setup, "Reset"):IsEnabled(), "nothing to reset yet")

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
check(ButtonWith(setup, "Reset"):IsEnabled(), "a changed step can be reset")
check(type(HeyCousinDB.testCrest) == "table" and HeyCousinDB.testCrest.shape == big.crest.shape,
    "the crest is saved as you make it")
-- a new look on this step: the setup turns, and keeps what you made
local made = HC.Crest.Normalize(big.crest)
setup.look.forward:Click()
NoErrors(HC, "look arrow")
check(HC.Theme.Skin().key == "smooth" and HeyCousinDB.skin == "smooth", "the look arrow switches the look")
setup = _G.HeyCousinSetup
big = Crest(setup, 160)
motto = All(setup, function(f) return f.kind == "EditBox" and f:IsVisible() end)[1]
check(setup:IsShown() and big.crest.shape == made.shape and big.crest.field == made.field
    and big.crest.symbol == made.symbol and big.crest.charge == made.charge, "the new look keeps the crest you made")
check(motto:GetText() == "Family first!" and ButtonWith(setup, "Crest").node.kind == "primary",
    "and your motto, on the same step")
-- reset: the step as it was when the setup opened
ButtonWith(setup, "Reset"):Click()
check(big.crest.shape == "Heater" and big.crest.symbol == "initial" and motto:GetText() == "Family first.",
    "reset puts the crest step back: " .. big.crest.shape .. ", " .. motto:GetText())
check(not ButtonWith(setup, "Reset"):IsEnabled(), "then there's nothing to reset")
All(setup, function(f) return f.direction == "RIGHT" and f:IsVisible() end)[1]:Click()
motto:SetText("Family first!")
ButtonWith(setup, "Next"):Click()
check(type(HeyCousinDB.testCrest) == "table" and HeyCousinDB.testCrest.shape == "Round"
    and HeyCousinDB.testMotto == "Family first!", "the crest and motto made in test mode are kept for Forever")
check(ButtonWith(setup, "Alerts").node.kind == "primary" and ButtonWith(setup, "Crest").check:IsShown(),
    "next: on the alerts, and the crest step has its check")
check(ButtonWith(setup, "Back") ~= nil and ButtonWith(setup, "Skip for now") == nil, "back now, no skip")
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
rows[2]:Click()
check(HeyCousinDB.enemyAlerts == false and ButtonWith(setup, "Reset"):IsEnabled(), "changed alerts can be reset")
ButtonWith(setup, "Reset"):Click()
check(HeyCousinDB.enemyAlerts == true and HeyCousinDB.sound == "auto" and not ButtonWith(setup, "Reset"):IsEnabled(),
    "reset puts the alerts back")
-- the step bar goes to any step
ButtonWith(setup, "Crest"):Click()
check(Crest(setup, 160):IsVisible() and ButtonWith(setup, "Next") ~= nil, "a click on a step goes to it")
ButtonWith(setup, "Alerts"):Click()
-- the look, twice round, from the last step
setup.look.forward:Click()
setup = _G.HeyCousinSetup
setup.look.forward:Click()
NoErrors(HC, "look arrows")
setup = _G.HeyCousinSetup
check(HC.Theme.Skin().key == "smooth" and setup:IsShown() and ButtonWith(setup, "Done") ~= nil,
    "the setup comes back in each look, on the same step")
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
check(window and window:IsShown() and next(window.anchors) ~= nil, "/cousin opens the family")
Settle()
local function Rows()
    return All(window, function(f) return f.item ~= nil and f.item.relative ~= nil and f:IsVisible() end)
end
local list = Rows()
check(#list >= 9, "the list shows the family: " .. #list)
check(list[1].item.me == true, "you are on top")
local first = list[2].item.first
list[2]:Click()
Settle()
local page = All(window, function(f) return f.whisper ~= nil end)[1]
check(page and page:IsShown() and not list[2]:IsVisible(), "a click on a relative opens their page")
local function Meetings()
    return All(page, function(f) return f.item ~= nil and f.item.meeting ~= nil and f:IsShown() end)
end
local made = HC.TestMode.House().relatives[first]
check(#Meetings() >= 1 and #made.meetings == made.met, "their page lists every meeting: " .. #Meetings())
check(page.detail:IsShown() and page.detail.when.text ~= "" and page.detail.place.text ~= "",
    "the newest meeting shows in full")
local older = Meetings()[2]
if older then
    older:Click()
    check(older.chosen and page.detail.when.text:find(HC.Utils.When(older.item.meeting.at), 1, true) == 1,
        "a click on a meeting shows it in full")
end
ButtonWith(window, "Whisper"):Click()
check(Mock.Said("Test mode"), "test mode: made-up cousins can't be whispered")
page.back:Click()
check(not page:IsShown() and Rows()[1] ~= nil, "the arrow goes back to the family")
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

-- Every window open with the mouse on one of its buttons, round all the looks twice: each window
-- is built again in the new look, and the game gives the old one's buttons a last OnLeave.
local function Hover(root)
    local button = root and All(root, function(f) return f.skin ~= nil and f.label ~= nil and f:IsVisible() end)[1]
    check(button ~= nil, "a theme button to point at")
    if button then Mock.Point(button) end
end
local function Round(where)
    local start = HC.Theme.Skin().key
    for _ = 1, #HC.Theme.ORDER * 2 do
        SlashCmdList.HEYCOUSIN("theme")
        Settle()
    end
    check(HC.Theme.Skin().key == start, where .. ": round the looks, back to " .. start)
    NoErrors(HC, where)
end
HC.Window.Show("family")
Hover(_G.HeyCousinWindow)
Round("looks with the family open")
check(_G.HeyCousinWindow:IsShown(), "the family stays open through the looks")
HC.Setup.Show(1)
Hover(_G.HeyCousinSetup)
Round("looks with the setup's first step")
HC.Setup.Show(2)
Hover(_G.HeyCousinSetup)
Round("looks with the setup's last step")
check(_G.HeyCousinSetup:IsShown() and ButtonWith(_G.HeyCousinSetup, "Done") ~= nil, "the setup stays on its step")
Mock.Point(ButtonWith(_G.HeyCousinSetup, "Crest"))
_G.HeyCousinSetup:Hide()
NoErrors(HC, "the setup closing with the mouse on a step")
HC.Alert.Show({ first = "Isla", relative = HC.TestMode.House().relatives.Isla, unit = "player", test = true })
Settle()
Hover(_G.HeyCousinAlert)
Round("looks with a pop-up showing")
HC.Layer.ShowAsk("Elowen Ashbrook", true)
Settle()
Hover(_G.HeyCousinAsk)
Round("looks with the layer ask showing")

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
check(probe.channels and probe.channels[2] == "General", "the channels you're in")
Mock.Fire("CHAT_MSG_CHANNEL", "lfg", "Bob Stone", "", "1. Local", "", "", 0, 1, "Local", 0, 10, "Player-1-BOB")
local localLines = probe.chat_CHAT_MSG_CHANNEL_Local
check(localLines and localLines[1].channel[3] == "Local" and localLines[1].author == "Bob Stone",
    "each channel's lines are kept apart")
Mock.Fire("CHAT_MSG_LOCAL", "hi", "Bob Stone", "", "", "", "", 0, 0, "", 0, 11, "Player-1-BOB")
check(probe.chat_CHAT_MSG_LOCAL and probe.chat_CHAT_MSG_LOCAL[1].text == "hi", "a kind of chat it doesn't know is kept too")
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
-- the checklist through the looks, and back with /cousin probe after one
SlashCmdList.HEYCOUSIN("probe")
Hover(_G.HeyCousinProbe)
Round("looks with the name test open")
check(_G.HeyCousinProbe:IsShown() and HC.Probe.Running(), "the checklist stays open through the looks")
_G.HeyCousinProbe:Hide()
SlashCmdList.HEYCOUSIN("theme")
SlashCmdList.HEYCOUSIN("probe")
check(_G.HeyCousinProbe:IsShown() and HC.Probe.Running(), "/cousin probe brings the checklist back in a new look")
SlashCmdList.HEYCOUSIN("theme")
SlashCmdList.HEYCOUSIN("probe stop")
NoErrors(HC, "name test and looks")

-- a secret name (protected content) is never used
Mock.units.target = { name = Mock.SECRET, surname = "Ashbrook", guid = "Player-9-SEC", class = "MAGE", faction = "Alliance" }
Mock.Fire("PLAYER_TARGET_CHANGED")
for first in pairs(house.relatives) do check(type(first) == "string", "relatives are named by text only") end
NoErrors(HC, "secrets")

-- meetings: where, when, how, both levels; one meeting while you keep seeing them (Wren, of her
-- own, so the tests above keep theirs). The name test's fight is over first.
Mock.Fire("PLAYER_REGEN_ENABLED")
Mock.units.nameplate3 = { name = "Wren", surname = "Ashbrook", guid = "Player-1-WREN", class = "SHAMAN", race = "Dwarf",
    level = 19, sex = 3, faction = "Alliance" }
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
local wren = house.relatives.Wren
local m1 = wren and wren.meetings and wren.meetings[1]
check(m1 and m1.zone == "Elwynn Forest" and m1.sub == "Goldshire" and m1.map == 1429 and m1.x == 42.1 and m1.y == 65.3
    and m1.how == "nameplate" and m1.level == 19 and m1.myLevel == 20 and not m1.rest and not m1.night,
    "a meeting keeps where, how and both levels")
Mock.Advance(10 * 60)
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
check(wren.met == 1 and #wren.meetings == 1 and m1.last > m1.at, "seen again 10 minutes on: the same meeting")
Mock.Advance(20 * 60)
Mock.subzone, Mock.resting, Mock.hour, Mock.units.nameplate3.level = "Lion's Pride Inn", true, 22, 20
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
local m2 = wren.meetings[2]
check(wren.met == 2 and m2 and m2.sub == "Lion's Pride Inn" and m2.rest and m2.night and m2.level == 20,
    "20 minutes away, then a new meeting: in a town, at night")
Mock.subzone, Mock.resting, Mock.hour = "Goldshire", false, 14
-- their gear: a quiet look while they're close, kept with the meeting
check(Mock.inspects[#Mock.inspects] == "nameplate3", "a quiet look at their gear, up close")
Mock.units.nameplate3.gear, Mock.units.nameplate3.ilvl = { [1] = 1001, [5] = 1005, [16] = 1016 }, 31.6
Mock.Fire("INSPECT_READY", "Player-1-WREN")
check(m2.gear and m2.gear[1] == 1001 and m2.gear[5] == 1005 and m2.gear[15] == 1016 and m2.ilvl == 32
    and (Mock.cleared or 0) > 0, "their gear and item level, with the meeting")
local looks = #Mock.inspects
Mock.Advance(61)
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
check(#Mock.inspects == looks, "one look a meeting")
-- what they said near you
Mock.Fire("CHAT_MSG_SAY", "Hey cousin, nice crest!", "Wren Ashbrook", "", "", "", "", 0, 0, "", 0, 20, "Player-1-WREN")
check(m2.said == "Hey cousin, nice crest!", "what they said near you")
-- a long adventure: the first meeting and the latest, 100 in all
for _ = 1, 105 do
    Mock.Advance(16 * 60)
    Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
end
check(#wren.meetings == 100 and wren.met == 107 and wren.meetings[1] == m1,
    "100 meetings kept, the first among them: " .. #wren.meetings .. ", met " .. wren.met)
HC.Window.ShowRelative("Wren")
Settle()
local wrenPage = All(_G.HeyCousinWindow, function(f) return f.whisper ~= nil end)[1]
check(wrenPage:IsShown() and wrenPage.heading.text == "Meetings (107)" and wrenPage.detail.place.text:find("Goldshire"),
    "her page has them all: " .. tostring(wrenPage.heading.text))
_G.HeyCousinWindow:Hide()
Mock.units.nameplate3 = nil
NoErrors(HC, "meetings")

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

HC = Mock.Boot("forever", { setupDone = true, houses = { Ashbrook = { relatives = {
    Ann = { met = 2, meetings = "junk" }, Cy = "oops",
    Bo = { met = 3, meetings = { 5, { at = "x" }, { at = 1699990000, zone = 3, x = "y", gear = "z", said = 4 } } },
} } } })
house = HC.Kin.House()
check(house.relatives.Ann.meetings == nil and #house.relatives.Bo.meetings == 1 and house.relatives.Cy == nil,
    "broken saved meetings are mended")
HC.Window.ShowRelative("Bo")
Settle()
HC.Window.ShowRelative("Ann")
Settle()
NoErrors(HC, "broken saved meetings")

print(fails == 0 and ("addon checks passed (" .. checks .. " checks)") or (fails .. " addon checks failed"))
