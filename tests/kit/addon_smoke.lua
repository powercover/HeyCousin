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
check(HC.Theme.Skin().key == "pixel" and HC.Theme.ORDER[2] == "forever" and HC.Theme.ORDER[3] == "smooth",
    "Pixel is the look in use, then Forever, then Smooth")
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
check(HC.Theme.Skin().key == "forever" and HeyCousinDB.skin == "forever", "the look arrow switches the look")
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
check(#rows == 6, "six alert settings: " .. #rows)
rows[1]:Click()
check(HeyCousinDB.popup == false, "the pop-up setting turns off")
rows[1]:Click()
check(HeyCousinDB.popup == true, "and on")
check(HeyCousinDB.popupEvery == false, "a pop-up only the first time you meet, unless you want more")
rows[2]:Click()
check(HeyCousinDB.popupEvery == true, "every time you meet turns on")
rows[2]:Click()
rows[6]:Click()
check(HeyCousinDB.showMinimap == false and not minimap:IsShown(), "the minimap crest hides at once")
rows[6]:Click()
check(minimap:IsShown(), "and comes back")
local bell = ButtonWith(setup, "Bell")
bell:Click()
check(HeyCousinDB.sound == "bell" and #Mock.sounds > 0, "a sound chip picks and plays it")
rows[3]:Click()
check(HeyCousinDB.enemyAlerts == false and ButtonWith(setup, "Reset"):IsEnabled(), "changed alerts can be reset")
ButtonWith(setup, "Reset"):Click()
check(HeyCousinDB.enemyAlerts == true and HeyCousinDB.sound == "auto" and not ButtonWith(setup, "Reset"):IsEnabled(),
    "reset puts the alerts back")
-- the step bar goes to any step
ButtonWith(setup, "Crest"):Click()
check(Crest(setup, 160):IsVisible() and ButtonWith(setup, "Next") ~= nil, "a click on a step goes to it")
NoErrors(HC, "alerts")

-- the map's step: your family on your map, and sharing where you are (off until you say)
ButtonWith(setup, "Map"):Click()
local mapRows = All(setup, function(f) return f.toggle ~= nil and f:IsVisible() end)
check(#mapRows == 2 and HeyCousinDB.mapShow == true and HeyCousinDB.mapShare == false and Crest(setup, 28) ~= nil,
    "the map's step: two settings, sharing off, and how the crests look")
mapRows[2]:Click()
check(HeyCousinDB.mapShare == true and ButtonWith(setup, "Reset"):IsEnabled(), "sharing turns on")
ButtonWith(setup, "Reset"):Click()
check(HeyCousinDB.mapShare == false and not ButtonWith(setup, "Reset"):IsEnabled(), "reset: off again")
NoErrors(HC, "map step")

-- the guild's step: you lead the made-up guild, so it's yours to make a family
ButtonWith(setup, "Guild"):Click()
check(ButtonWith(setup, "Guild").node.kind == "primary" and ButtonWith(setup, "Done") ~= nil, "the guild's step, the last")
local function Boxes(root)
    return All(root, function(f) return f.kind == "EditBox" and f:IsVisible() end)
end
local fields = Boxes(setup)
check(#fields == 6 and fields[1]:GetText() == "Ashbrook" and fields[3]:GetText() == "Elder"
    and fields[6]:GetText() == "Little cousin", "a family name, a welcome line, and a word for each of the 4 ranks")
check(not ButtonWith(setup, "Reset"):IsEnabled(), "nothing changed on it yet")
fields[5]:SetText("Kin")
fields[5]:ClearFocus()
check(HC.Guild.Family().words[3] == "Kin" and ButtonWith(setup, "Reset"):IsEnabled(), "a new word, saved when you're done typing")
local stamp = HC.Guild.Family().stamp
fields[5]:ClearFocus()
fields[1]:ClearFocus()
check(HC.Guild.Family().stamp == stamp, "done typing with no change: nothing saved again")
local guildRow = All(setup, function(f) return f.toggle ~= nil and f:IsVisible() end)[1]
guildRow:Click()
check(not HC.Guild.Family().given and #Boxes(setup) == 0, "turned off: no family, no fields")
guildRow:Click()
check(HC.Guild.Family().given and #Boxes(setup) == 6, "and on again")
ButtonWith(setup, "Reset"):Click()
check(HC.Guild.Family().words[3] == "Cousin" and Boxes(setup)[5]:GetText() == "Cousin", "reset: the words as they were")
NoErrors(HC, "guild step")
-- the look, twice round, from the last step
setup.look.forward:Click()
setup = _G.HeyCousinSetup
setup.look.forward:Click()
NoErrors(HC, "look arrows")
setup = _G.HeyCousinSetup
check(HC.Theme.Skin().key == "pixel" and setup:IsShown() and ButtonWith(setup, "Done") ~= nil,
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

-- the Tree tab: the made-up guild by generation, you on top
ButtonWith(window, "Tree"):Click()
Settle()
local function Tree()
    return All(window, function(f) return f.member ~= nil and f.SetChosen ~= nil and f:IsVisible() end)
end
local boxes = Tree()
check(#boxes == 14 and not search:IsVisible() and not Rows()[1], "the tree has the whole guild, and nothing else: " .. #boxes)
-- (a box's level shows when it fits: the mock's text is wider than the game's, so only the word is
-- checked here; screens.py measures the real fonts)
check(boxes[1].member.me and boxes[1].line.text:find("Elder", 1, true) == 1, "you on top, its Elder: " .. boxes[1].line.text)
check(boxes[2].name.text == "Lia" and boxes[2].line.text:find("Parent", 1, true) == 1, "then the Parents: " .. boxes[2].line.text)
check(boxes[5].name.text == "Elowen" and boxes[5].dot:IsShown(), "the Cousins, the ones online first")
local function Box(name)
    for _, box in ipairs(Tree()) do
        if box.name.text == name then return box end
    end
end
check(Box("Pip") and Box("Pip").line.text:find("Little cousin", 1, true) == 1, "the guild master's own word for a rank")
local treeTab = boxes[1]:GetParent():GetParent():GetParent()
check(treeTab.title.text == "Ashbrook Kin" and treeTab.count.text:find("14 in the family", 1, true)
    and treeTab.welcome.text:find("Welcome home", 1, true), "the guild's name, its count and its welcome line")
-- a click shows their card
local cardOf = All(window, function(f) return f.member ~= nil and f.page ~= nil end)[1]
check(cardOf.member.me and not cardOf.whisper:IsShown(), "your own card first, nothing to send yourself")
Box("Mira"):Click()
check(cardOf.member.first == "Mira" and Box("Mira").chosen and cardOf.line.text:find("Cousin  ·  Member", 1, true)
    and cardOf.line.text:find("Elwynn Forest, now", 1, true), "a click shows their card: " .. cardOf.line.text)
check(cardOf.whisper:IsEnabled() and cardOf.page:IsShown(), "online: whisper; a relative: their page")
Box("Pip"):Click()
check(not cardOf.whisper:IsEnabled() and not cardOf.page:IsShown() and cardOf.line.text:find("Last online 2 days ago", 1, true),
    "offline and only known from the guild: " .. cardOf.line.text)
Box("Corin"):Click()
check(cardOf.name.text == "Corin Fairwind" and cardOf.line.text:find("In-law", 1, true), "an in-law: their whole name on their card")
Box("Juniper"):Click()
local lines = #Mock.chat
cardOf.whisper:Click()
check(#Mock.chat == lines + 1 and Mock.chat[#Mock.chat]:find("Test mode", 1, true), "test mode: made-up cousins can't be whispered")
Box("Mira"):Click()
cardOf.page:Click()
Settle()
check(page:IsShown() and page.first == "Mira" and ButtonWith(window, "Family").kind == "primary", "their page, on the family tab")
ButtonWith(window, "Tree"):Click()
Settle()
check(Box("Mira").chosen and not page:IsShown(), "back on the tree, Mira still chosen")
ButtonWith(window, "Family words"):Click()
check(_G.HeyCousinSetup:IsShown() and ButtonWith(_G.HeyCousinSetup, "Done") ~= nil, "the guild master's words: the setup's guild step")
_G.HeyCousinSetup:Hide()
NoErrors(HC, "tree")

-- the family map in test mode: the made-up cousins online stand around you
local function Pins()
    return All(WorldMapFrame, function(f) return f.spot ~= nil and f:IsShown() end)
end
Mock.ShowMap(1429)
local pins = Pins()
check(#pins == 4, "the cousins online, as crests on the map: " .. #pins)
Mock.Run(pins[1], "OnEnter")
check(GameTooltip.lines[2] and GameTooltip.lines[2]:find("Level", 1, true), "a crest's tooltip: who, their word, level and class")
Mock.Zoom(2)
check(pins[1].scale == 0.5 and pins[1].anchors.CENTER.x == pins[1].x * 702 * 2, "the crests keep their size as the map zooms")
Mock.ShowMap(1415)
check(#Pins() == 4, "on the continent's map too")
Mock.ShowMap(1453)
check(#Pins() == 0, "not on a map they aren't on")
HeyCousinDB.mapShow = false
Mock.ShowMap(1429)
check(#Pins() == 0, "your family on the map, turned off: no crests")
HeyCousinDB.mapShow = true
WorldMapFrame:Hide()
NoErrors(HC, "the map in test mode")

-- the next look, with the window open: it's built again in it
SlashCmdList.HEYCOUSIN("theme")
check(HC.Theme.Skin().key == "forever", "/cousin theme goes to the next look")
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
HC.Setup.Show(4)
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
-- your own realm's players come with an empty realm, the others' with a code
Mock.players["Player-1-LIA"] = { name = "Lia", surname = "Ashbrook", class = "PRIEST", race = "Human", sex = 3, realm = "" }
Mock.Fire("CHAT_MSG_SAY", "hi all", "Lia Ashbrook", "", "", "", "", 0, 0, "", 0, 4, "Player-1-LIA")
check(house.relatives.Lia and house.relatives.Lia.class == "PRIEST", "a relative heard saying something is family too")
Mock.players["Player-1-KIT"] = { name = "Kit", surname = "Ashbrook", class = "MAGE", race = "Human", sex = 3 }
Mock.Fire("CHAT_MSG_SAY", "hello", "Kit Ashbrook", "", "", "", "", 0, 0, "", 0, 5, "Player-1-KIT")
check(house.relatives.Kit and house.relatives["Kit Ashbrook"] == nil, "and one from another realm, by their first name")
check(HeyCousinDB.surnames.CAMWOWEU4Realm4PvP == nil, "a realm code is never counted as a surname")
local splitFirst, splitSurname = HC.Names.Split("Mira Ashbrook-CAMWOWEU4Realm4PvP")
check(splitFirst == "Mira" and splitSurname == "Ashbrook", "a realm after a whole name is dropped")
splitFirst, splitSurname = HC.Names.Split("Mira-Ashbrook")
check(splitFirst == "Mira" and splitSurname == "Ashbrook", "a name with a dash, as the game takes it for whispers")
HeyCousinDB.surnames.CAMWOWEU5Realm2PvP = 10
local countBefore = HeyCousinDB.surnameCount or 0
HeyCousinDB.surnameCount = countBefore + 1
HC.Kin.ForgetRealms()
check(HeyCousinDB.surnames.CAMWOWEU5Realm2PvP == nil and HeyCousinDB.surnameCount == countBefore,
    "realm codes saved by the first builds are forgotten")
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
-- a crowd of nameplates, and pointing at the player first, must not use up the target's tick
for i = 1, 8 do
    Mock.units.nameplate9 = { name = "Passer" .. i, surname = "Bystander", guid = "Player-1-PASS" .. i, class = "MAGE", faction = "Alliance" }
    Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
end
Mock.units.nameplate9 = nil
Mock.units.mouseover = Mock.units.target
Mock.Fire("UPDATE_MOUSEOVER_UNIT")
Mock.units.mouseover = nil
check(probe.done.mouseover and not probe.done.target, "pointing at a player ticks only that")
Mock.Fire("PLAYER_TARGET_CHANGED")
check(probe.units_target and probe.units_target[1].unitName[2] == "Ashbrook" and probe.done.target, "a target's name parts")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
check(probe.npc and probe.npc[1].layer == 5151 and probe.done.npc, "an NPC and its layer")
Mock.Fire("GUILD_ROSTER_UPDATE")
check(probe.guild and probe.guild[1].name == "Odo Ashbrook" and probe.done.guild, "guild names as the roster has them")
local targetSelf = _G.HeyCousinProbetargetSelf
check(targetSelf:GetAttribute("macrotext1") == "/cleartarget\n/targetexact Rowan Ashbrook", "the test targets you by your whole name")
targetSelf:Click()
Mock.Advance(1)
check(probe.targeting and probe.targeting.targetSelf and probe.done.targetSelf, "and writes down what got targeted")
_G.HeyCousinProbetargetFirst:Click()
Mock.Advance(1)
check(probe.targeting.targetFirst and probe.done.targetFirst, "your first name alone ticks too, whatever it finds")
-- /who: four searches, one a click, and it waits for the game between them
Mock.who = { { fullName = "Gus Washbrook", level = 8, area = "Agamand Mills" }, { fullName = "Odo Ashbrook", level = 9, fullGuildName = "Kin" },
    { fullName = "Nell Washbrook", level = 8 }, { fullName = "Tobin Ashbrooke", level = 7 } }
local whoButton = _G.HeyCousinProbe.who
whoButton:Click()
check(Mock.whoSent[1] == "Ashbrook" and not whoButton:IsEnabled(), "/who searches your surname, and waits")
whoButton:Click()
check(#Mock.whoSent == 1, "a click while it waits does nothing")
Mock.Fire("WHO_LIST_UPDATE")
Mock.Fire("CHAT_MSG_SYSTEM", "4 players total")
Mock.Advance(7)
local whoRun = probe.who.runs[1]
check(whoRun.event and whoRun.count[1] == 4 and whoRun.system[1] == "4 players total", "what the game answered is noted")
check(whoRun.names[4] == "Tobin Ashbrooke" and whoRun.rows[1].area == "Agamand Mills" and whoRun.rows[4] == nil,
    "every name, and every field of the first few")
for _ = 2, 4 do
    check(not probe.done.who, "not done until the last search")
    whoButton:Click()
    Mock.Advance(7)
end
check(Mock.whoSent[2] == 'n-"Ashbrook"' and Mock.whoSent[3] == 'n-"Rowan Ashbrook"' and Mock.whoSent[4]:find('^n%-"Ashbrook" %d+%-%d+$'),
    "the other ways: by name, by whole name, by your level")
check(probe.done.who and not whoButton:IsEnabled(), "four searches tick it")
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

-- your guild as a family: most of it shares your surname, so it's one by itself
local RANKS = { "Guild Master", "Officer", "Member", "Initiate" }
Mock.guild = { name = "Ashbrook Kin", rank = 2, ranks = RANKS }
Mock.roster = {
    { full = "Ogre Ashbrook", rank = 0, level = 14, class = "WARRIOR", zone = "Elwynn Forest", online = true, guid = "Player-1-OGRE" },
    { full = "Lia Ashbrook", rank = 1, level = 60, class = "PRIEST", online = false, days = 3, guid = "Player-1-LIA" },
    { full = "Rowan Ashbrook", rank = 2, level = 20, class = "WARRIOR", zone = "Elwynn Forest", online = true, guid = "Player-1-ME" },
    { full = "Mira Ashbrook", rank = 2, level = 23, class = "MAGE", zone = "Elwynn Forest", online = true, guid = "Player-1-MIRA" },
    { full = "Ann Other", rank = 3, level = 10, class = "ROGUE", online = false, guid = "Player-1-ANN" },
}
local sentBefore = #Mock.addonSent
Mock.Fire("PLAYER_GUILD_UPDATE")
Mock.Fire("GUILD_ROSTER_UPDATE")
Settle()
local hello = Mock.addonSent[sentBefore + 1]
check(hello and hello.channel == "GUILD" and hello.text == "2:H:0" and #Mock.addonSent == sentBefore + 1,
    "once a session, your addon says hello to your guild's")
local generations, family = HC.Guild.Tree()
check(family.surname == "Ashbrook" and not family.given and #generations == 3 and #generations[3].members == 3
    and generations[3].members[1].first == "Mira" and generations[3].members[2].me,
    "a family by itself: Elder, Parent, and every Cousin (an in-law too), the ones online first")
HC.Window.Show("tree")
Settle()
local treeBoxes = All(_G.HeyCousinWindow, function(f) return f.member ~= nil and f.SetChosen ~= nil and f:IsVisible() end)
check(#treeBoxes == 5 and treeBoxes[1].line.text:find("Elder", 1, true) == 1, "the Tree tab shows them all")
-- the family map: you share where you are with your guild, as you move
local function MapPins()
    return All(WorldMapFrame, function(f) return f.spot ~= nil and f:IsShown() end)
end
-- (no room for the family channel at first: your guild still hears you)
Mock.channels, Mock.channelsFull = {}, true
HeyCousinDB.mapShare = true
local mapSent = #Mock.addonSent
HC.Map.Apply()
local where = Mock.addonSent[#Mock.addonSent]
check(#Mock.addonSent == mapSent + 1 and where.channel == "GUILD" and where.text == "3:P:1429:4210:6530:WARRIOR:20",
    "sharing: where you are goes to your guild's addons: " .. tostring(where.text))
Mock.Advance(20)
check(#Mock.addonSent == mapSent + 1, "standing still: nothing more for a while")
Mock.Advance(30)
check(#Mock.addonSent == mapSent + 2, "then a word now and then, so you stay on their maps")
Mock.x = 0.45
Mock.Advance(5)
check(Mock.addonSent[#Mock.addonSent].text == "3:P:1429:4500:6530:WARRIOR:20", "a move goes in a moment")
mapSent = #Mock.addonSent
Mock.combat, Mock.x = true, 0.5
Mock.Advance(10)
check(#Mock.addonSent == mapSent, "never in a fight")
Mock.combat, Mock.instance = false, "party"
Mock.Advance(10)
check(#Mock.addonSent == mapSent + 1 and Mock.addonSent[#Mock.addonSent].text == "3:D", "in a dungeon: no place, said once")
Mock.instance, Mock.x = nil, 0.421
HeyCousinDB.mapShare = false
HC.Map.Apply()
check(Mock.addonSent[#Mock.addonSent].text == "3:X", "sharing off: your crest leaves their maps at once")
mapSent = #Mock.addonSent
Mock.Advance(60)
check(#Mock.addonSent == mapSent, "and nothing more goes")
-- their crests on your map: only your guild's family, not you, not one in a dungeon
for _, line in ipairs({ { "3:P:1429:5000:2500", "Mira Ashbrook" }, { "3:P:1429:9000:9000", "Bob Stone" },
    { "3:P:1429:9000:9000", "Rowan Ashbrook" }, { "3:P:1429:99999:1", "Lia Ashbrook" }, { "3:P:x", "Lia Ashbrook" },
    { "3:P:1429:7000:7000", "Ogre Ashbrook" }, { "3:D", "Ogre Ashbrook" } }) do
    Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", line[1], "GUILD", line[2])
end
Mock.ShowMap(1429)
local mapPins = MapPins()
check(#mapPins == 1 and mapPins[1].spot.member.first == "Mira" and mapPins[1].x == 0.5 and mapPins[1].y == 0.25
    and mapPins[1].name.text == "Mira", "a crest for each cousin who shares: " .. #mapPins)
Mock.ShowMap(1415)
mapPins = MapPins()
check(#mapPins == 1 and math.abs(mapPins[1].x - 0.5) < 0.001, "on the continent's map too")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:X", "GUILD", "Mira Ashbrook")
Mock.ShowMap(1429)
check(#MapPins() == 0, "they stopped sharing: gone at once")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:P:1429:5000:2500", "GUILD", "Mira Ashbrook")
Mock.Advance(121)
Mock.ShowMap(1429)
check(#MapPins() == 0, "a cousin whose addon went quiet leaves the map")
-- OpenMap's stitched map: a cousin in another zone shows past the edges of the map underneath, above its art
local openMapStitched = true
local openMapCalls = {}
_G.OpenMapAPI = {
    IsStitched = function() return openMapStitched end,
    ArtTopLevel = function() return 5000 end,
    WorldFromMap = function(map, x, y) openMapCalls[#openMapCalls + 1] = map; return 0.2 + x / 10, 0.4 + y / 10 end,
    MapFromWorld = function(_, u, v) return (u - 0.2) * 10 + 1, (v - 0.4) * 10 end,
}
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:P:1429:9000:2500", "GUILD", "Mira Ashbrook")
Mock.ShowMap(1453)
mapPins = MapPins()
check(#mapPins == 1 and math.abs(mapPins[1].x - 1.9) < 0.001 and math.abs(mapPins[1].y - 0.25) < 0.001,
    "on a stitched map, a cousin past the edges of the map underneath: " .. #mapPins .. " at " .. tostring(mapPins[1] and mapPins[1].x))
check(openMapCalls[1] == 1429 and mapPins[1]:GetFrameLevel() == 5001, "from their own zone, above the stitched art")
Mock.ShowMap(1429)
mapPins = MapPins()
check(#mapPins == 1 and mapPins[1].x == 0.9, "on their own zone's map as ever")
openMapStitched = false
Mock.ShowMap(1453)
mapPins = MapPins()
check(#mapPins == 0, "OpenMap's map turned off: the game's map rules again: " .. #mapPins .. " at " .. tostring(mapPins[1] and mapPins[1].x))
_G.OpenMapAPI = { IsStitched = function() error("broken") end }
Mock.ShowMap(1429)
check(#MapPins() == 1, "a broken OpenMap doesn't take the crests away")
_G.OpenMapAPI = nil
-- a crest's click opens that cousin's page, above the map
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:P:1429:5000:2500", "GUILD", "Mira Ashbrook")
house.relatives.Mira = house.relatives.Mira or { class = "MAGE", met = 1, lastSeen = 0 }
Mock.ShowMap(1429)
mapPins = MapPins()
_G.HeyCousinWindow:Hide()
Mock.Run(mapPins[1], "OnMouseUp", "RightButton")
check(not _G.HeyCousinWindow:IsShown(), "a right-click isn't for the crest")
Mock.Run(mapPins[1], "OnMouseUp", "LeftButton")
Settle()
check(_G.HeyCousinWindow:IsShown() and _G.HeyCousinWindow.strata == "FULLSCREEN_DIALOG", "a click opens the window over the map")
check(All(_G.HeyCousinWindow, function(f) return f.name and f.name.text == "Mira Ashbrook" and f.whisper and f:IsVisible() end)[1],
    "on that cousin's page, with its buttons")
_G.HeyCousinWindow:Hide()
check(_G.HeyCousinWindow.strata == "HIGH", "closed: back where it belongs")
-- the family channel: 15 seconds after you log in, so the game's own channels come first
Mock.channelsFull = false
HC.Map.Apply()
check(Mock.channels.HCashbrookA == 7, "in your family's channel, for your surname and faction")
HeyCousinDB.mapShare = true
HC.Map.Apply()
local onChannel
for _, sentLine in ipairs(Mock.addonSent) do
    if sentLine.channel == "CHANNEL" then onChannel = sentLine end
end
check(onChannel and onChannel.target == 7 and onChannel.text:find("^3:P:1429:%d+:%d+:%u+:%d+$"),
    "sharing tells your family's channel, with your class and level: " .. tostring(onChannel and onChannel.text))
HeyCousinDB.mapShare = false
HC.Map.Apply()
check(Mock.addonSent[#Mock.addonSent].channel == "CHANNEL" and Mock.addonSent[#Mock.addonSent].text == "3:X", "a stop reaches the channel too")
-- a cousin outside your guild, who shares
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:P:1429:3000:3000:ROGUE:17", "CHANNEL", "Faraway Ashbrook", "", 0, 7, "HCashbrookA")
check(house.relatives.Faraway and house.relatives.Faraway.class == "ROGUE" and house.relatives.Faraway.level == 17
    and house.relatives.Faraway.met == 0 and house.relatives.Faraway.shared, "a cousin who shares joins your family, not met")
check(HC.Kin.IsOnline("Faraway"), "and is online")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:P:1429:3000:3000:MAGE:9", "CHANNEL", "Sneaky Stranger", "", 0, 7, "HCashbrookA")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:P:1429:3000:3000:MAGE:9", "CHANNEL", "Other Ashbrook", "", 0, 3, "SomeOtherChannel")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:P:1429:3000:3000:MAGE:9", "CHANNEL", "Rowan Ashbrook", "", 0, 7, "HCashbrookA")
check(house.relatives.Sneaky == nil and house.relatives.Other == nil and house.relatives.Rowan == nil,
    "another surname, another channel and your own lines are left out")
Mock.ShowMap(1429)
mapPins = MapPins()
local farawayPin
for _, pin in ipairs(mapPins) do
    if pin.spot.member.first == "Faraway" then farawayPin = pin end
end
check(farawayPin and farawayPin.spot.word == "Cousin" and #mapPins == 2, "their crest is on your map: " .. #mapPins)
Mock.Run(farawayPin, "OnMouseUp", "LeftButton")
Settle()
check(All(_G.HeyCousinWindow, function(f) return f.name and f.name.text == "Faraway Ashbrook" and f.met
    and f.met.text:find("share their place", 1, true) and f:IsVisible() end)[1], "and a click opens their page")
_G.HeyCousinWindow:Hide()
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:X", "CHANNEL", "Faraway Ashbrook", "", 0, 7, "HCashbrookA")
Mock.ShowMap(1429)
check(#MapPins() == 1, "they stopped sharing: gone at once")
-- showing nobody and sharing nothing: out of the channel
HeyCousinDB.mapShow = false
HC.Map.Apply()
check(Mock.channels.HCashbrookA == nil, "the family map off: out of the channel")
HeyCousinDB.mapShow = true
HC.Map.Apply()
check(Mock.channels.HCashbrookA == 7, "back on: in it again")
local hideNotice = Mock.filters.CHAT_MSG_CHANNEL_NOTICE and Mock.filters.CHAT_MSG_CHANNEL_NOTICE[1]
check(hideNotice and hideNotice(nil, "CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "", "", "7. HCashbrookA", "", "", 0, 7, "HCashbrookA") == true,
    "the channel's notices stay out of your chat")
check(hideNotice(nil, "CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "", "", "1. General", "", "", 0, 1, "General") == false, "the others' don't")
-- /cousin test map: made-up cousins to see, where nobody shares yet
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:X", "GUILD", "Mira Ashbrook")
SlashCmdList.HEYCOUSIN("test map")
Mock.ShowMap(1429)
mapPins = MapPins()
-- (cousins you know around you, and the capital that's on this mock map; the other capital isn't)
check(#mapPins >= 2 and mapPins[1].spot.word == "Cousin", "/cousin test map shows cousins around you: " .. #mapPins)
local previewReal, previewMade
for _, pin in ipairs(mapPins) do
    if pin.spot.madeUp then previewMade = pin else previewReal = pin end
end
check(previewReal and house.relatives[previewReal.spot.member.first], "a cousin you know, whose page a click opens")
check(previewMade and previewMade.spot.member.first == "Lia" or previewMade == nil, "and a made-up one in the capital")
local chatBefore = #Mock.chat
if previewMade then
    Mock.Run(previewMade, "OnMouseUp", "LeftButton")
    check(#Mock.chat == chatBefore + 1 and not _G.HeyCousinWindow:IsShown(), "a made-up cousin has no page: it says so")
end
Mock.Advance(121)
Mock.ShowMap(1429)
check(#MapPins() == 0, "and they leave after two minutes")
WorldMapFrame:Hide()
-- (the tests below go on from the Tree tab)
HC.Window.Show("tree")
HC.Window.Open(nil)
NoErrors(HC, "the family map")
-- the guild master's words, from their addon (in two parts); a member's are not theirs to give
local payload = "1~Ashbrook~Round.Fess.azure.argent.or.charge.Heart~^^Kid^Little cousin^^^^^^~Welcome home, cousin!~"
local function Given(sender, stamp, parts)
    for index, part in ipairs(parts) do
        Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", string.format("2:F:%d:%d:%d:%s", stamp, index, #parts, part), "GUILD", sender)
    end
end
Given("Mira Ashbrook", 5000, { payload })
Given("Ogre", 5000, { payload })
check(not HC.Guild.Family().given, "only the guild master's addon gives the family its words, by their whole name")
local saidBefore = #Mock.chat
Given("Ogre Ashbrook", 5000, { payload:sub(1, 30), payload:sub(31) })
family = HC.Guild.Family()
check(family.given and family.words[1] == "Elder" and family.words[3] == "Kid" and family.words[4] == "Little cousin"
    and family.crest.shape == "Round" and family.crest.charge == "Heart" and family.welcome == "Welcome home, cousin!",
    "the guild master's words, crest and welcome line")
check(#Mock.chat == saidBefore + 2 and Mock.chat[saidBefore + 1]:find("Welcome to the Ashbrook family!", 1, true),
    "the family greets you")
Given("Ogre Ashbrook", 4000, { (payload:gsub("Kid", "Baby")) })
check(HC.Guild.Family().words[3] == "Kid", "older words don't come back")
generations = HC.Guild.Tree()
check(#generations == 4 and generations[3].word == "Kid" and generations[4].word == "Little cousin"
    and generations[4].members[1].first == "Ann", "a generation for each word")
Given("Ogre Ashbrook", 6000, { "1~Ash|cffff0000%0Abrook~~~" })
check(HC.Guild.Family().surname == "Ashcffff0000brook" and HC.Guild.Family().words[3] == "Cousin",
    "no codes or line breaks in the guild master's words: " .. HC.Guild.Family().surname)
check(#Mock.chat == saidBefore + 2, "the greeting comes once")
Settle()
NoErrors(HC, "the guild master's words")
-- you lead the guild: your words go to every member's addon, a moment after your last change
Mock.guild.rank, Mock.roster[1].rank, Mock.roster[3].rank = 0, 2, 0
Mock.Fire("GUILD_ROSTER_UPDATE")
local sentNow = #Mock.addonSent
HC.Guild.SetFamily({ on = true, surname = "Ashbrook", words = { "", "", "Kid" }, welcome = "Hi" })
HC.Guild.SetFamily({ on = true, surname = "Ashbrook", words = { "", "", "Kin" }, welcome = "Hi!" })
Mock.Advance(6)
local shared = Mock.addonSent[#Mock.addonSent]
check(#Mock.addonSent == sentNow + 1 and shared.channel == "GUILD" and shared.text:find("^2:F:%d+:1:1:1~Ashbrook~")
    and shared.text:find("~^^Kin^", 1, true) and shared.text:find("~Hi!~$"), "your words go to the guild once: " .. shared.text)
-- a burst of hellos gets one answer, and no more for a minute, whoever asks
sentNow = #Mock.addonSent
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "2:H:0", "GUILD", "Mira Ashbrook")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "2:H:0", "GUILD", "Lia Ashbrook")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "2:H:0", "GUILD", "Bob Stone")
Mock.Advance(6)
check(#Mock.addonSent == sentNow + 1, "three hellos, one answer: " .. (#Mock.addonSent - sentNow))
for _ = 1, 10 do
    Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "2:H:0", "GUILD", "Mira Ashbrook")
    Mock.Advance(5)
end
check(#Mock.addonSent == sentNow + 1, "hello after hello: no more answers for a minute: " .. (#Mock.addonSent - sentNow))
-- you make it no family: a guild that shares a surname isn't one by itself then
HC.Guild.SetFamily({ on = false, surname = "Ashbrook", words = {}, welcome = "" })
check(HC.Guild.Family().surname == nil and not HC.Guild.Draft().on and #HC.Guild.Tree()[3].members == 2,
    "no family: only you and your relatives (no in-laws)")
-- a long family in Russian goes in parts, each in the game's limit (one held back by the game goes
-- again), and comes back whole
local long = { on = true, surname = "Ашбрук", words = { "Старейшина", "Родитель", "Двоюродные", "Малыши" },
    welcome = "Добро пожаловать домой, кузен! Спроси родителя, если нужна помощь, и заходи к нам." }
Mock.Advance(6)
sentNow = #Mock.addonSent
Mock.throttle = 1
HC.Guild.SetFamily(long)
Mock.Advance(6)
check(#Mock.addonSent == sentNow and Mock.throttle == 0, "the game held the first part back")
Mock.Advance(3)
local parts = {}
for i = sentNow + 1, #Mock.addonSent do parts[#parts + 1] = Mock.addonSent[i].text end
check(#parts == 2 and parts[1]:find("^2:F:%d+:1:2:") and parts[2]:find("^2:F:%d+:2:2:"), "then both parts went: " .. #parts)
Mock.guild = { name = "Other Kin", rank = 2, ranks = RANKS }
Mock.roster[1].rank, Mock.roster[3].rank = 0, 2
Mock.Fire("GUILD_ROSTER_UPDATE")
saidBefore = #Mock.chat
Given("Ogre Ashbrook", 1000, { "1~Ashbrook~~~~o" })
check(#Mock.chat == saidBefore and not HC.Guild.Family().given, "no family from the guild master: no greeting")
for _, text in ipairs(parts) do
    Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", text, "GUILD", "Ogre Ashbrook")
end
family = HC.Guild.Family()
check(family.surname == "Ашбрук" and family.words[1] == "Старейшина" and family.words[4] == "Малыши"
    and family.welcome == long.welcome and #Mock.chat == saidBefore + 2, "it comes back whole in another guild, with a greeting: "
    .. tostring(family.surname) .. ", " .. (#Mock.chat - saidBefore) .. " lines: " .. tostring(Mock.chat[#Mock.chat]))
-- back in your own guild, as its master: your addon tells the members online by itself
Mock.guild = { name = "Ashbrook Kin", rank = 0, ranks = RANKS }
Mock.roster[1].rank, Mock.roster[3].rank = 2, 0
sentNow = #Mock.addonSent
Mock.Fire("GUILD_ROSTER_UPDATE")
Mock.Advance(6)
check(#Mock.addonSent == sentNow + 2 and Mock.addonSent[sentNow + 1].text:find("^2:F:%d+:1:2:"),
    "the guild master's addon tells the members online, by itself: " .. (#Mock.addonSent - sentNow))
-- out of a guild: the tree waits
Mock.guild, Mock.roster = nil, {}
Mock.Fire("PLAYER_GUILD_UPDATE")
Settle()
local treeTab = treeBoxes[1]:GetParent():GetParent():GetParent()
check(treeTab.title.text == "" and All(treeTab, function(f) return f.title and f.title.text == "No guild yet" and f:IsVisible() end)[1],
    "no guild: the tree says how it grows")
_G.HeyCousinWindow:Hide()
NoErrors(HC, "guild")

-- === Quieter pop-ups ==========================================================================

HC = Mock.Boot("forever", { setupDone = true })
local realShow, popped = HC.Alert.Show, 0
HC.Alert.Show = function() popped = popped + 1 end
HC.Alert.Cousin("Zed", { met = 1 }, true, nil)
check(popped == 1, "the first time you meet: a pop-up")
HC.Alert.Cousin("Zed", { met = 2 }, false, nil)
check(popped == 1, "the next times: none")
HeyCousinDB.popupEvery = true
HC.Alert.Cousin("Zed", { met = 2 }, false, nil)
check(popped == 2, "unless you want one every time")
HC.Alert.Show = realShow
NoErrors(HC, "quieter pop-ups")

-- === Find my family ===========================================================================

HC = Mock.Boot("forever", { setupDone = true })
house = HC.Kin.House()
-- the game's own window, which opens when it hears a /who answer
local gameWhoWindow = CreateFrame("Frame", "GameWhoWindow", UIParent)
gameWhoWindow:Hide()
local gameWhoHeard = 0
gameWhoWindow:SetScript("OnEvent", function(self)
    gameWhoHeard = gameWhoHeard + 1
    self:Show()
end)
gameWhoWindow:RegisterEvent("WHO_LIST_UPDATE")
Mock.whoSent, Mock.who = {}, {
    { fullName = "Rowan Ashbrook", filename = "ROGUE", level = 8, area = "Goldshire", fullGuildName = "" },
    { fullName = "Perrin Ashbrook", filename = "MAGE", level = 18, area = "Lordamere Overlook", fullGuildName = "Vale Kin" },
    { fullName = "Peg ashbrook", filename = "PRIEST", level = 7, area = "Mulgore", fullGuildName = "" },
    { fullName = "Bram Bashbrook", filename = "PALADIN", level = 23, area = "Blackthorn Ridge", fullGuildName = "Ashbrook" },
    { fullName = "Tobin Ashbrookel", filename = "PRIEST", level = 21, area = "Mulgore", fullGuildName = "" },
    { fullName = Mock.SECRET, filename = "MAGE", level = 1 },
}
HC.Window.Show("stats")
local findButton = _G.HeyCousinWindow.find
check(findButton:GetText() == "Find my family" and findButton:IsEnabled(), "the Find my family button waits on every tab")
findButton:Click()
check(Mock.whoSent[1] == 'n-" Ashbrook"', "it asks /who for surnames only: " .. tostring(Mock.whoSent[1]))
Settle()
check(findButton:GetText() == "Looking..." and not findButton:IsEnabled(), "and shows it's looking")
findButton:Click()
check(#Mock.whoSent == 1, "a click while it looks asks nothing more")
check(Mock.events.WHO_LIST_UPDATE[gameWhoWindow] == nil, "while it waits the game's window doesn't listen")
Mock.Fire("WHO_LIST_UPDATE")
check(gameWhoHeard == 0 and not gameWhoWindow:IsShown(), "so the answer doesn't open it")
check(Mock.events.WHO_LIST_UPDATE[gameWhoWindow] == true, "and afterwards it listens again")
check(house.relatives.Perrin and house.relatives.Perrin.level == 18 and house.relatives.Perrin.zone == "Lordamere Overlook",
    "a cousin it found, with their level and zone")
check(house.relatives.Perrin.guild == "Vale Kin" and house.relatives.Perrin.met == 0 and house.relatives.Perrin.found,
    "and their guild: found, not met")
check(house.relatives.Peg and house.relatives.Peg.class == "PRIEST" and house.relatives.Peg.guild == nil, "big or small letters are one family")
check(house.relatives.Rowan == nil, "you aren't your own cousin")
check(house.relatives.Bram == nil and house.relatives.Tobin == nil, "a surname with yours only inside isn't family")
check(HC.Kin.IsOnline("Perrin") and not HC.Kin.IsNear("Perrin"), "online, not near")
Settle()
check(select(4, HC.Kin.Counts()) == 2, "two of the family online")
Mock.Advance(7)
check(findButton:IsEnabled() and findButton:GetText() == "Find my family", "then it can search again")
Mock.Fire("WHO_LIST_UPDATE")
check(house.relatives.Bram == nil and #Mock.whoSent == 1, "the game's own /who window isn't read")
check(gameWhoHeard == 1 and gameWhoWindow:IsShown(), "and your own /who opens the game's window as usual")
-- a window you opened keeps hearing the answers, and stays open
gameWhoHeard = 0
findButton:Click()
check(Mock.events.WHO_LIST_UPDATE[gameWhoWindow] == true, "a window you opened keeps listening")
Mock.Fire("WHO_LIST_UPDATE")
check(gameWhoHeard == 1 and gameWhoWindow:IsShown(), "and stays open")
Mock.Advance(7)
-- a window the game opens anyway closes again with the answer; a part of it may be what listens
gameWhoWindow:Hide()
local gameWhoPart = CreateFrame("Frame", nil, gameWhoWindow)
gameWhoWindow:UnregisterEvent("WHO_LIST_UPDATE")
gameWhoPart:RegisterEvent("WHO_LIST_UPDATE")
Mock.whoOpens = gameWhoWindow
findButton:Click()
check(gameWhoWindow:IsShown(), "the game opens its window by itself")
Mock.Fire("WHO_LIST_UPDATE")
check(not gameWhoWindow:IsShown(), "the answer closes it")
Mock.whoOpens = nil
Mock.Advance(7)
-- that window open on another of its pages stays open
gameWhoWindow:Show()
gameWhoPart:Hide()
findButton:Click()
Mock.Fire("WHO_LIST_UPDATE")
check(gameWhoWindow:IsShown(), "a window you had open on another page stays open")
gameWhoWindow:Hide()
gameWhoPart:UnregisterEvent("WHO_LIST_UPDATE")
Mock.Advance(7)
Mock.Advance(5 * 60)
check(not HC.Kin.IsOnline("Perrin"), "after a while it doesn't claim they're still online")
-- a full list: each next click looks at one band of levels
Mock.who = {}
for i = 1, 50 do
    Mock.who[i] = { fullName = "Other" .. i .. " Bashbrook", filename = "MAGE", level = 10, fullGuildName = "" }
end
findButton:Click()
Mock.Fire("WHO_LIST_UPDATE")
Mock.Advance(7)
check(findButton:GetText() == "Keep looking (1/7)", "a full list: it offers to look further: " .. tostring(findButton:GetText()))
Mock.who = { { fullName = "Hidden Ashbrook", filename = "DRUID", level = 5, area = "Durotar", fullGuildName = "" } }
findButton:Click()
check(Mock.whoSent[#Mock.whoSent] == 'n-" Ashbrook" 1-9', "the first band: " .. tostring(Mock.whoSent[#Mock.whoSent]))
Mock.Fire("WHO_LIST_UPDATE")
check(house.relatives.Hidden ~= nil, "and finds a cousin the full list hid")
Mock.Advance(7)
for _ = 2, 7 do
    findButton:Click()
    Mock.Fire("WHO_LIST_UPDATE")
    Mock.Advance(7)
end
check(Mock.whoSent[#Mock.whoSent] == 'n-" Ashbrook" 60-99' and findButton:GetText() == "Find my family", "after the last band it's done")
-- no answer: it says so, and you can try again
local sentBefore = #Mock.whoSent
findButton:Click()
Mock.Advance(7)
check(#Mock.whoSent == sentBefore + 1 and findButton:IsEnabled(), "no answer from the game: you can try again")
-- their page says how you know them
HC.Window.Open("Perrin")
Settle()
check(All(_G.HeyCousinWindow, function(f) return f.met and f.met.text and f.met.text:find("found by searching", 1, true) and f:IsVisible() end)[1],
    "their page says a search found them")
HC.Window.Open(nil)
_G.HeyCousinWindow:Hide()
NoErrors(HC, "find my family")

-- test mode: the made-up family, and no search goes to the game
HC = Mock.Boot("retail", { setupDone = true })
Mock.whoSent = {}
HC.Window.Show("family")
_G.HeyCousinWindow.find:Click()
Mock.Advance(2)
local testHouse = HC.Kin.House()
check(#Mock.whoSent == 0 and testHouse.relatives.Perrin and testHouse.relatives.Perrin.met == 0, "test mode finds a made-up cousin")
check(testHouse.relatives.Nell == nil and testHouse.relatives.Gus == nil and HC.Kin.IsOnline("Mira"), "and leaves the near-names out")
_G.HeyCousinWindow:Hide()
NoErrors(HC, "find in test mode")

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
