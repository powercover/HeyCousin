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
check(HeyCousinDB.setupDone == true, "and counts as seen at once: it won't open by itself again")
-- a frame with no place never shows in the game
check(next(setup.anchors) ~= nil, "the setup has a place on screen")
NoErrors(HC, "boot")

-- the setup's frame: a step bar, the look on top, back (or skip), reset and next
check(ButtonWith(setup, "Crest") and ButtonWith(setup, "Family") and ButtonWith(setup, "Crest").node.kind == "primary",
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
check(ButtonWith(setup, "Family").node.kind == "primary" and ButtonWith(setup, "Crest").check:IsShown(),
    "next: on your family, and the crest step has its check")
check(ButtonWith(setup, "Back") ~= nil and ButtonWith(setup, "Skip for now") == nil, "back now, no skip")
NoErrors(HC, "crest page")

-- the family's step: only what matters on day one
local rows = All(setup, function(f) return f.toggle ~= nil and f:IsVisible() end)
check(#rows == 4 and Crest(setup, 28) ~= nil, "four settings, and how the crests look: " .. #rows)
check(HeyCousinDB.mapShare == false, "sharing where you are stays off until you say")
rows[1]:Click()
check(HeyCousinDB.popup == false, "the pop-up setting turns off")
rows[1]:Click()
check(HeyCousinDB.popup == true, "and on")
check(HeyCousinDB.popupEvery == false, "a pop-up only the first time you meet, unless you want more")
rows[4]:Click()
check(HeyCousinDB.mapShare == true and ButtonWith(setup, "Reset"):IsEnabled(), "sharing turns on")
ButtonWith(setup, "Reset"):Click()
check(HeyCousinDB.mapShare == false and not ButtonWith(setup, "Reset"):IsEnabled(), "reset: off again")
-- the step bar goes to any step
ButtonWith(setup, "Crest"):Click()
check(Crest(setup, 160):IsVisible() and ButtonWith(setup, "Next") ~= nil, "a click on a step goes to it")
ButtonWith(setup, "Next"):Click()
check(ButtonWith(setup, "Done") ~= nil and ButtonWith(setup, "Guild") == nil, "two steps, and no guild's step")
NoErrors(HC, "the family's step")
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
NoErrors(HC, "the end of the setup")

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
check(list[2].item.alt == true and list[2].item.first == "Wynn", "your other character under you")
local first = list[3].item.first
list[3]:Click()
Settle()
local page = All(window, function(f) return f.whisper ~= nil end)[1]
check(page and page:IsShown() and not list[3]:IsVisible(), "a click on a relative opens their page")
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
check(_G.HeyCousinOptions:IsShown() and ButtonWith(_G.HeyCousinOptions, "Reset") ~= nil and ButtonWith(_G.HeyCousinOptions, "Back") ~= nil,
    "the guild master's words: their page in the settings")
_G.HeyCousinOptions:Hide()
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
-- another house's player: how many of it you've met, from two on
local function HouseTip()
    GameTooltip.unit = "mouseover"
    Mock.Run(GameTooltip, "OnTooltipCleared")
    GameTooltip.lines = {}
    Mock.postCalls[2](GameTooltip, {})
    return table.concat(GameTooltip.lines, " ")
end
check(not HouseTip():find("House Stone", 1, true), "only one Stone met: no line")
HeyCousinDB.surnames.Stone = 3
check(HouseTip():find("House Stone: met 3", 1, true), "another house: how many of it you've met")
HeyCousinDB.houseLine = false
check(not HouseTip():find("House Stone", 1, true), "switched off: no line")
HeyCousinDB.houseLine = nil
HeyCousinDB.surnames.Stone = 1
GameTooltip.unit = "target"
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
check(Mock.Said("Your character ID: \"Player-1-ME\""), "and your character ID")
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
    if sentLine.channel == "WHISPER" then onChannel = sentLine end
end
check(onChannel and onChannel.target == "Anyone Ashbrook" and onChannel.text:find("^3:P:1429:%d+:%d+:%u+:%d+$"),
    "sharing tells the cousins in your family's channel, with your class and level: " .. tostring(onChannel and onChannel.text))
HeyCousinDB.mapShare = false
HC.Map.Apply()
check(Mock.addonSent[#Mock.addonSent].channel == "WHISPER" and Mock.addonSent[#Mock.addonSent].text == "3:X", "a stop reaches the family too")
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
-- wanting nothing of it: out of the channel
HeyCousinDB.mapShow, HeyCousinDB.presence, HeyCousinDB.familyNews, HeyCousinDB.familyChat = false, false, false, false
HeyCousinDB.familyGroups = false
HC.Map.Apply()
check(Mock.channels.HCashbrookA == nil, "the family map, hello, news and chat all off: out of the channel")
HeyCousinDB.mapShow, HeyCousinDB.presence = true, true
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

-- === The eldest cousin ========================================================================

HC = Mock.Boot("forever", { setupDone = true })
house = HC.Kin.House()
check(HC.Kin.Eldest() == nil, "no cousins with an ID: no eldest")
house.relatives.Alba = { guid = "Player-1-00E3D28D", class = "MAGE", met = 1, lastSeen = 1 }
check(HC.Kin.Eldest() == nil, "one to look at isn't enough to compare")
house.relatives.Bryn = { guid = "Player-2-00090F33", class = "MAGE", met = 1, lastSeen = 1 }
house.relatives.Cato = { class = "MAGE", met = 0, lastSeen = 1 }
check(HC.Kin.Eldest() == "Bryn", "the lowest character number is the eldest; no ID, no place: " .. tostring(HC.Kin.Eldest()))
Mock.units.player.guid = "Player-1-00000F33"
check(HC.Kin.Eldest() == "Rowan", "it may be you")
Mock.units.player.guid = "Player-1-ME"
HC.Window.Show("family")
Settle()
local function EldestOn(root)
    return All(root, function(f) return f.crown ~= nil and f.crown:IsShown() and f.item and f:IsVisible() end)
end
local crowned = EldestOn(_G.HeyCousinWindow)
check(#crowned == 1 and crowned[1].item.first == "Bryn", "a crown on the eldest's row, and only theirs: " .. #crowned)
check(_G.HeyCousinWindow.footer.text:find("Eldest we know: Bryn", 1, true), "the window's last line names them")
check(_G.HeyCousinWindow.footer:GetStringWidth() <= 500 - 36, "and the line stays inside the window")
HC.Window.Open("Bryn")
Settle()
check(All(_G.HeyCousinWindow, function(f) return f.line and f.whisper and f.line.text:find("Eldest cousin", 1, true) and f:IsVisible() end)[1],
    "their page says so")
HC.Window.Open("Alba")
Settle()
check(All(_G.HeyCousinWindow, function(f) return f.line and f.whisper and f.line.text:find("Cousin", 1, true) == 1 and f:IsVisible() end)[1],
    "another's page doesn't")
_G.HeyCousinWindow:Hide()
NoErrors(HC, "the eldest")

-- === The family's hello =======================================================================

HC = Mock.Boot("forever", { setupDone = true })
house = HC.Kin.House()
local function ChannelSent(pattern)
    local found
    for _, line in ipairs(Mock.addonSent) do
        if line.channel == "WHISPER" and line.target == "Anyone Ashbrook" and line.text:find(pattern) then found = line end
    end
    return found
end
Mock.Fire("PLAYER_ENTERING_WORLD")
check(not next(Mock.channels), "not in the channel yet, so the game's own come first")
Mock.Advance(16)
check(Mock.channels.HCashbrookA == 7, "then in it")
Mock.Advance(6)
local hello = ChannelSent("^4:H:")
check(hello and hello.text:find("^4:H:WARRIOR:20:Heater%.") and #hello.text < 200, "the hello says your class, level and crest: " .. tostring(hello and hello.text))
-- the answers right after your hello are one line
local chatBefore = #Mock.chat
local line = "4:A:MAGE:18:Round.Plain.azure.or.or.charge.Star"
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", line, "WHISPER", "Rena Ashbrook")
check(house.relatives.Rena and house.relatives.Rena.usesAddon and house.relatives.Rena.class == "MAGE" and house.relatives.Rena.level == 18,
    "an answer: a cousin who uses the addon")
check(HC.Kin.IsOnline("Rena") and house.relatives.Rena.met == 0, "online, not met")
check(HC.Kin.CrestOf("Rena").shape == "Round" and HC.Kin.CrestOf("Rena").charge == "Star", "with their own crest")
check(#Mock.chat == chatBefore, "no line of its own in the first moments")
Mock.Advance(31)
check(Mock.Said("Family online now: 1"), "one line for them all")
-- someone coming later: a line of their own, and an answer from you
chatBefore = #Mock.chat
local sentBefore = #Mock.addonSent
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:H:ROGUE:30:Kite.Plain.gules.or.or.initial.", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore + 1 and Mock.chat[#Mock.chat]:find("Kit Ashbrook", 1, true) and Mock.chat[#Mock.chat]:find("is online.", 1, true), "a cousin coming online: a line in chat")
Mock.Advance(7)
local answer
for i = sentBefore + 1, #Mock.addonSent do
    if Mock.addonSent[i].channel == "WHISPER" then answer = Mock.addonSent[i] end
end
check(answer and answer.target == "Kit Ashbrook" and answer.text:find("^4:A:"), "and your addon answers them, by itself")
-- not again while they're online, and not for a word from them
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:S:ROGUE:31:", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore and house.relatives.Kit.level == 31, "a word from them: no line, their new level")
-- who it isn't from
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:H:MAGE:1:", "CHANNEL", "Sly Stranger", "", 0, 7, "HCashbrookA")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:H:MAGE:1:", "CHANNEL", "Rowan Ashbrook", "", 0, 7, "HCashbrookA")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:H:MAGE:1:", "CHANNEL", "Oren Ashbrook", "", 0, 3, "SomeOtherChannel")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:Q:|cffff0000bad", "CHANNEL", "Pip Ashbrook", "", 0, 7, "HCashbrookA")
check(house.relatives.Sly == nil and house.relatives.Rowan == nil and house.relatives.Oren == nil and house.relatives.Pip == nil,
    "another surname, you, another channel and a broken line are left out")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:H:MAGE:9:Nope.Nope.Nope.Nope.Nope.charge.Nope", "CHANNEL", "Sol Ashbrook", "", 0, 7, "HCashbrookA")
check(house.relatives.Sol and HC.Kin.CrestOf("Sol").shape ~= "Nope", "a crest that doesn't exist is made safe")
-- a word now and then, your own new level soon after a level up
Mock.Advance(4 * 60 + 6)
check(ChannelSent("^4:S:"), "a word now and then while you play")
-- the row says so
HC.Window.Show("family")
Settle()
local usesRows = All(_G.HeyCousinWindow, function(f) return f.item and f.item.first == "Kit" and f.tag and f:IsVisible() end)
check(usesRows[1] and usesRows[1].tag.text == "(uses addon)", "the list marks who uses the addon")
_G.HeyCousinWindow:Hide()
-- off: no word goes, no line comes, but who uses it is still learned
HeyCousinDB.presence = false
sentBefore = #Mock.addonSent
chatBefore = #Mock.chat
Mock.Advance(5 * 60)
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:H:PRIEST:5:", "CHANNEL", "Una Ashbrook", "", 0, 7, "HCashbrookA")
Mock.Advance(10)
local anyFamily = false
for i = sentBefore + 1, #Mock.addonSent do
    if Mock.addonSent[i].text:find("^4:") then anyFamily = true end
end
check(not anyFamily and #Mock.chat == chatBefore and house.relatives.Una.usesAddon, "turned off: nothing goes out and no line, their mark stays")
NoErrors(HC, "the family's hello")

-- === Family news and chat =====================================================================

HC = Mock.Boot("forever", { setupDone = true })
house = HC.Kin.House()
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Advance(22)
-- your own level goes out with the next tick; the hello came first
Mock.units.player.level = 21
Mock.Fire("PLAYER_LEVEL_UP", 21)
Mock.Advance(6)
local levelLine = ChannelSent("^4:L:")
check(levelLine and levelLine.text:find("^4:L:WARRIOR:21:"), "your new level goes to the family")
Mock.Advance(31)
-- a cousin's: news on a round one, and their level is kept on any
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:L:MAGE:29:", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore and house.relatives.Kit.level == 29, "level 29: no line, the level kept")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:L:MAGE:30:", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(Mock.chat[#Mock.chat]:find("Kit Ashbrook", 1, true) and Mock.chat[#Mock.chat]:find("reached level 30!", 1, true), "level 30: news")
HeyCousinDB.familyNews = false
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:L:MAGE:35:", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore and house.relatives.Kit.level == 35, "news off: no line")
HeyCousinDB.familyNews = true
-- family chat: yours goes out and shows, no codes in it
SlashCmdList.HEYCOUSINFAM("Who's up for |cffff0000Deadmines?")
local said = ChannelSent("^5:C:")
check(said and said.text == "5:C:Who's up for cffff0000Deadmines?", "/fam goes to the family, with no codes: " .. tostring(said and said.text))
check(Mock.chat[#Mock.chat]:find("[Family]", 1, true) and Mock.chat[#Mock.chat]:find("Rowan", 1, true), "and shows in your chat")
chatBefore = #Mock.chat
SlashCmdList.HEYCOUSINFAM("   ")
check(#Mock.chat == chatBefore + 1 and Mock.chat[#Mock.chat]:find("/fam", 1, true), "/fam alone says how")
SlashCmdList.HEYCOUSINFAM(string.rep("long ", 100))
said = ChannelSent("^5:C:long")
check(said and #said.text <= 255, "a long line still fits a message")
-- a cousin's: their first name in your chat, no codes, no flood
Mock.Advance(2)
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:C:Hi |TInterface\\Icons\\Big:900|t all", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
local heardLine = Mock.chat[#Mock.chat]
check(heardLine:find("Kit", 1, true) and heardLine:find("Hi TInterface", 1, true) and not heardLine:find("|T", 1, true), "a cousin's words, without their codes: " .. heardLine)
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:C:again", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore, "not many lines at once")
Mock.Advance(2)
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:C:hello", "CHANNEL", "Sly Stranger", "", 0, 7, "HCashbrookA")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:C:hello", "CHANNEL", "Oren Ashbrook", "", 0, 3, "SomeOtherChannel")
check(#Mock.chat == chatBefore, "another surname and another channel are left out")
Mock.ignored = { ["Kit Ashbrook"] = true }
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:C:hello", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore, "nor anyone on your ignore list")
Mock.ignored = nil
-- turned off: nothing shows, and /fam says why
HeyCousinDB.familyChat = false
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:C:hello", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore, "chat off: their words don't show")
SlashCmdList.HEYCOUSINFAM("hello?")
check(Mock.Said("Family chat is off"), "and /fam says why")
HeyCousinDB.familyChat = true
NoErrors(HC, "family news and chat")

do
-- "Hey cousin!": only from a click, and it says their name
HC = Mock.Boot("forever", { setupDone = true })
house = HC.Kin.House()
Mock.units.nameplate8 = { name = "Fern", surname = "Ashbrook", guid = "Player-1-FERN", class = "DRUID", race = "NightElf",
    level = 22, sex = 3, faction = "Alliance" }
Mock.said, Mock.emotes = {}, {}
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate8")
Settle()
check(#Mock.said == 0 and #Mock.emotes == 0, "nothing is said by itself")
local heyAlert = _G.HeyCousinAlert
check(heyAlert:IsShown() and heyAlert.hey:IsVisible(), "the pop-up has the button")
heyAlert.hey:Click()
check(Mock.said[1] and Mock.said[1].text == "Hey cousin Fern!" and Mock.said[1].kind == "SAY", "a click says it out loud: " .. tostring(Mock.said[1] and Mock.said[1].text))
check(Mock.emotes[1] and Mock.emotes[1].token == "WAVE" and Mock.emotes[1].unit == "nameplate8", "and waves at them")
heyAlert.hey:Click()
check(#Mock.said == 1, "a double click isn't two")
-- their page has it while they're near, and not once they've gone
HC.Window.ShowRelative("Fern")
Settle()
local heyPage = All(_G.HeyCousinWindow, function(f) return f.heyUnit ~= nil or f.hey ~= nil end)[1]
check(heyPage and heyPage.hey:IsVisible(), "their page has it while they're near")
Mock.Advance(11)
heyPage.hey:Click()
check(#Mock.said == 2 and Mock.emotes[2].unit == "nameplate8", "from the page, it waves at them too")
Mock.Advance(11)
Mock.units.nameplate8 = nil
HC.Window.Refresh(true)
heyPage.hey:Click()
check(#Mock.said == 3 and Mock.emotes[3].unit == "none", "and at nobody once the game can't see them")
Mock.Advance(200)
HC.Window.Refresh(true)
check(not heyPage.hey:IsVisible(), "gone from near you: no button")
_G.HeyCousinWindow:Hide()
HC.Alert.Dismiss()
Settle()
-- your own preview has no button
HC.Alert.Preview()
Settle()
check(not heyAlert.hey:IsVisible(), "not on a preview of yourself")
HC.Alert.Dismiss()
Settle()
NoErrors(HC, "hey cousin")
end

-- the family race: you and those with the addon, by level
HC = Mock.Boot("forever", { setupDone = true, houses = { Ashbrook = { relatives = {
    Kit = { class = "MAGE", level = 30, usesAddon = true, faction = "Alliance", met = 0 },
    Lia = { class = "PRIEST", level = 12, usesAddon = true, faction = "Alliance", met = 0 },
    Bram = { class = "WARRIOR", level = 50, faction = "Alliance", met = 1 },
    Sly = { class = "ROGUE", level = 55, usesAddon = true, faction = "Horde", met = 1 },
} } } })
house = HC.Kin.House()
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Advance(60)
local racers = HC.Race.List()
check(#racers == 3 and racers[1].first == "Kit" and racers[2].first == "Rowan" and racers[2].me and racers[3].first == "Lia",
    "the addon's cousins and you, by level; no others, no black sheep")
SlashCmdList.HEYCOUSIN("race")
Settle()
local raceRows = All(_G.HeyCousinWindow, function(f) return f.rank ~= nil and f.item and f:IsVisible() end)
check(#raceRows == 3, "a row each")
local stayed = ButtonWith(_G.HeyCousinWindow, "See the race")
check(stayed == nil, "the race is over the stats")
HC.Window.Race(false)
check(ButtonWith(_G.HeyCousinWindow, "See the race") ~= nil, "back on the stats, with the way to it")
ButtonWith(_G.HeyCousinWindow, "See the race"):Click()
check(ButtonWith(_G.HeyCousinWindow, "See the race") == nil, "the button opens it")
ButtonWith(_G.HeyCousinWindow, "Family"):Click()
ButtonWith(_G.HeyCousinWindow, "Stats"):Click()
check(ButtonWith(_G.HeyCousinWindow, "See the race") ~= nil, "another tab leaves it")
_G.HeyCousinWindow:Hide()
-- being passed is news
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:L:PRIEST:21:", "CHANNEL", "Lia Ashbrook", "", 0, 7, "HCashbrookA")
check(Mock.chat[#Mock.chat]:find("Lia Ashbrook", 1, true) and Mock.chat[#Mock.chat]:find("just passed you", 1, true), "a cousin passes you: news")
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:L:MAGE:31:", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore, "one already ahead: no line")
NoErrors(HC, "the family race")

-- the family portrait: your house on a card
HC = Mock.Boot("retail", { setupDone = true })
HC.Window.Show("stats")
ButtonWith(_G.HeyCousinWindow, "Family portrait"):Click()
local card = _G.HeyCousinPortrait
check(card and card:IsShown() and next(card.anchors) ~= nil and Crest(card, 180) ~= nil, "the Stats tab opens the card")
check(Mock.Said("Print Screen"), "and it says how to keep it")
local cardFaces = All(card, function(f) return f.avatar ~= nil and f:IsVisible() end)
check(#cardFaces > 0 and #cardFaces <= 12 and cardFaces[1].name.text ~= "", "the cousins met most: " .. #cardFaces)
check((function()
    for _, region in ipairs(card.regions or {}) do
        if type(region.text) == "string" and region.text:find("^Highest level: ") then return true end
    end
end)(), "the highest level of the family")
local shootButton = ButtonWith(card, "Take a picture")
shootButton:Click()
check(Mock.screenshots == 1 and not shootButton:IsShown() and not card.close:IsShown(), "a picture, without its buttons")
Mock.Advance(1)
check(shootButton:IsShown() and card.close:IsShown(), "and they come back")
SlashCmdList.HEYCOUSIN("theme")
Settle()
check(_G.HeyCousinPortrait:IsShown(), "a new look builds it again")
SlashCmdList.HEYCOUSIN("theme")
SlashCmdList.HEYCOUSIN("theme")
SlashCmdList.HEYCOUSIN("portrait")
check(not _G.HeyCousinPortrait:IsShown(), "/cousin portrait closes it")
_G.HeyCousinWindow:Hide()
NoErrors(HC, "the family portrait")
HC = Mock.Boot("forever", { setupDone = true })
HC.Portrait.Show()
check(_G.HeyCousinPortrait:IsShown(), "with nobody yet, it still opens")
_G.HeyCousinPortrait:Hide()
NoErrors(HC, "an empty family portrait")

-- cousins on the minimap: where they stand, by the same word the world map hears
do
HC = Mock.Boot("forever", { setupDone = true })
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Advance(25)
local function MiniCrests()
    return All(Minimap, function(f) return f.size == 20 and f.SetCrest ~= nil and f:IsShown() end)
end
check(#MiniCrests() == 0, "nobody shares: nothing on the minimap")
-- right where you are (the mock's player stands at a known place on map 1429)
local px, py = C_Map.GetPlayerMapPosition(1429, "player"):GetXY()
local function Say(name, x, y)
    Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", string.format("3:P:1429:%d:%d:MAGE:30", math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5)), "WHISPER", name .. " Ashbrook")
end
-- a little to the north-east
local world, a = C_Map.GetWorldPosFromMapPos(1429, CreateVector2D(0, 0))
local _, b = C_Map.GetWorldPosFromMapPos(1429, CreateVector2D(1, 1))
local widthYards, heightYards = math.abs(b.x - a.x), math.abs(b.y - a.y)
Say("Kit", px + 100 / widthYards, py - 50 / heightYards)
Mock.Advance(0.5)
local crests = MiniCrests()
check(#crests == 1 and crests[1].member and crests[1].member.first == "Kit", "a cousin who shares: a crest on the minimap")
check(crests[1].symbol:IsShown() or crests[1].letter:IsShown(), "with its symbol, as on the world map")
local spot = crests[1].anchors.CENTER
check(spot.to == Minimap and spot.x > 0 and spot.y > 0, "to the north-east: right and up, got " .. spot.x .. ", " .. spot.y)
-- the zoom: at the widest, 466.67 yards across on a minimap 198 wide
local perYard = 99 / (466.67 / 2)
check(math.abs(spot.x - 100 * perYard) < 1 and math.abs(spot.y - 50 * perYard) < 1, "at the right distance for the zoom: " .. spot.x)
check(crests[1].alpha == nil or crests[1].alpha == 1, "in range: not faded")
Mock.minimapZoom = 5
Mock.Advance(0.5)
local zoomed = MiniCrests()[1].anchors.CENTER
check(math.sqrt(zoomed.x ^ 2 + zoomed.y ^ 2) > 0 and zoomed.x > spot.x, "zoomed in: further from the center")
Mock.minimapZoom = nil
-- a client that tells its radius
C_Minimap = { GetViewRadius = function() return 100 end }
Mock.Advance(0.5)
local told = MiniCrests()[1].anchors.CENTER
check(math.abs(told.x - 99) < 3 or told.x > 80, "the game's own radius counts: " .. told.x)
C_Minimap = nil
-- a turning minimap: facing east, what's to the east is up
Mock.cvars, Mock.facing = { rotateMinimap = "1" }, -math.pi / 2
Mock.Advance(0.5)
local turned = MiniCrests()[1].anchors.CENTER
check(turned.y > math.abs(turned.x), "a turning minimap: facing them, they're up: " .. turned.x .. ", " .. turned.y)
Mock.cvars, Mock.facing = nil, nil
-- far away: at the edge, faded, in their direction
Say("Kit", math.min(0.99, px + 2000 / widthYards), py)
Mock.Advance(0.5)
local far = MiniCrests()[1]
check(math.abs(math.sqrt(far.anchors.CENTER.x ^ 2 + far.anchors.CENTER.y ^ 2) - 97) < 1 and far.alpha == 0.6, "far away: at the edge, faded")
-- a square minimap
GetMinimapShape = function() return "SQUARE" end
Mock.Advance(0.5)
check(math.abs(MiniCrests()[1].anchors.CENTER.x - 97) < 1, "a square minimap's edge is its own")
GetMinimapShape = function() return "ROUND" end
-- its tooltip and click
far:GetScript("OnEnter")(far)
check(GameTooltip.lines[1] == "Kit Ashbrook", "pointing at it says who")
far:GetScript("OnLeave")(far)
far:GetScript("OnMouseUp")(far, "LeftButton")
check(_G.HeyCousinWindow and _G.HeyCousinWindow:IsShown(), "a click opens their page")
_G.HeyCousinWindow:Hide()
-- in a dungeon: none
Mock.instance = "party"
Mock.Advance(0.5)
check(#MiniCrests() == 0, "in a dungeon: none")
Mock.instance = nil
Mock.Advance(0.5)
check(#MiniCrests() == 1, "back out: back")
-- the setting
HC.Options.Show("map")
local miniRow = ButtonWith(_G.HeyCousinOptions, "Your family on the minimap")
miniRow:Click()
check(HeyCousinDB.minimapCousins == false and #MiniCrests() == 0, "turned off: gone")
Say("Kit", px, py)
Mock.Advance(0.5)
check(#MiniCrests() == 0, "and stays gone as they move")
miniRow:Click()
Mock.Advance(0.5)
check(#MiniCrests() == 1, "on again: back")
_G.HeyCousinOptions:Hide()
-- they stop sharing, or go quiet: gone, and nothing runs for nobody
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:X", "WHISPER", "Kit Ashbrook")
Mock.Advance(0.5)
check(#MiniCrests() == 0, "they stop sharing: gone")
Say("Kit", px, py)
Mock.Advance(0.5)
Mock.Advance(121)
check(#MiniCrests() == 0, "quiet for two minutes: gone")
-- a new look with one showing
Say("Kit", px, py)
Mock.Advance(0.5)
SlashCmdList.HEYCOUSIN("theme")
Mock.Advance(0.5)
check(#All(Minimap, function(f) return f.size == 20 and f.SetCrest ~= nil and f.member ~= nil and f:IsShown() end) >= 1, "a new look: still there")
SlashCmdList.HEYCOUSIN("theme")
SlashCmdList.HEYCOUSIN("theme")
NoErrors(HC, "cousins on the minimap")
-- test mode: the made-up family
HC = Mock.Boot("retail", { setupDone = true })
Mock.Advance(1)
check(#All(Minimap, function(f) return f.size == 20 and f.member ~= nil and f:IsShown() end) > 0, "test mode: made-up cousins on the minimap")
NoErrors(HC, "the minimap in test mode")
end

do
-- the channel finds cousins; whispers reach them (Forever takes channel messages but doesn't deliver them)
HC = Mock.Boot("forever", { setupDone = true })
Mock.channelMembers = { "*Rowan Ashbrook", "Kit Ashbrook", "@Lia Ashbrook", "Sly Stranger" }
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Advance(25)
local function SentTo(target, pattern)
    for _, line in ipairs(Mock.addonSent) do
        if line.channel == "WHISPER" and line.target == target and line.text:find(pattern) then return line end
    end
end
for _, line in ipairs(Mock.addonSent) do
    check(line.channel ~= "CHANNEL", "nothing goes on the channel itself: " .. line.text)
end
check(SentTo("Kit Ashbrook", "^4:H:") and SentTo("Lia Ashbrook", "^4:H:"), "the hello goes to each cousin on the list")
check(not SentTo("Sly Stranger", "") and not SentTo("Rowan Ashbrook", ""), "not to you, nor a stranger who joined")
-- the game's answer stays out of your chat, unless you asked
local rosterFilter = Mock.filters.CHAT_MSG_CHANNEL_LIST[1]
HC.Family.AskRoster()
check(rosterFilter(nil, "CHAT_MSG_CHANNEL_LIST", "*Rowan Ashbrook", "", "", "7. HCashbrookA", "", "", 0, 7, "HCashbrookA") == true, "the list stays out of your chat")
check(not rosterFilter(nil, "CHAT_MSG_CHANNEL_LIST", "Bo Other", "", "", "8. SomeChannel", "", "", 0, 8, "SomeChannel"), "another channel's stays")
Mock.Advance(3)
check(not rosterFilter(nil, "CHAT_MSG_CHANNEL_LIST", "*Rowan Ashbrook", "", "", "7. HCashbrookA", "", "", 0, 7, "HCashbrookA"), "and your own /chatlist shows")
-- in combat, a boss fight or a key the game blocks asking who's there: it waits, then asks
for _, lock in ipairs({ "combat", "encounter", "chatLockdown" }) do
    Mock[lock] = true
    Mock.listed = nil
    HC.Family.AskRoster()
    Mock.Advance(70)
    check(Mock.listed == nil, "no channel list asked during " .. lock)
    Mock[lock] = false
    Mock.Advance(6)
    check(Mock.listed ~= nil, "asked once " .. lock .. " is over")
    Mock.Advance(3)
end
-- /fam, a post and the map all reach them, and they're heard by whisper
SlashCmdList.HEYCOUSINFAM("hello")
check(SentTo("Kit Ashbrook", "^5:C:hello") and SentTo("Lia Ashbrook", "^5:C:hello"), "/fam goes to each")
check(not SentTo("Sly Stranger", "^5:C:"), "and not to a stranger in the channel")
-- your motto goes to them when it changes, and theirs comes to you
HC.Kin.SetCrest(HC.Kin.Crest(), "Family first")
check(SentTo("Kit Ashbrook", "^4:M:Family first$") and SentTo("Lia Ashbrook", "^4:M:Family first$"), "a new motto goes to each")
local mottoSent = #Mock.addonSent
HC.Kin.SetCrest(HC.Kin.Crest(), "Family first")
check(#Mock.addonSent == mottoSent, "the same motto again: nothing goes")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:M:Never skip |cffleg day", "WHISPER", "Kit Ashbrook")
Settle()
check(HC.Kin.House().relatives.Kit.motto == "Never skip cffleg day", "their motto is kept, without codes: "
    .. tostring(HC.Kin.House().relatives.Kit.motto))
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:M:Sly words", "WHISPER", "Sly Stranger")
check(HC.Kin.House().relatives.Sly == nil, "a stranger's motto: nothing")
HC.Window.ShowRelative("Kit")
Settle()
local mottoShown = false
Walk(_G.HeyCousinWindow, function(f)
    for _, region in ipairs(f.regions or {}) do
        if type(region.text) == "string" and region.text:find("Never skip cffleg day", 1, true) and region:IsVisible() then
            mottoShown = true
        end
    end
end)
check(mottoShown, "their page shows it")
_G.HeyCousinWindow:Hide()
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:M:", "WHISPER", "Kit Ashbrook")
check(HC.Kin.House().relatives.Kit.motto == nil, "an empty one clears it")
for _, line in ipairs(Mock.addonSent) do
    check(not line.text:find("^5:C:") or line.channel == "WHISPER", "/fam goes to no guild or group: only whispers to cousins")
end
HC.Groups.Post("Deadmines")
check(SentTo("Kit Ashbrook", "^5:G:Deadmines") ~= nil, "a post too")
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:C:hi there", "WHISPER", "Kit Ashbrook")
check(Mock.chat[#Mock.chat]:find("hi there", 1, true) and #Mock.chat == chatBefore + 1, "their words come by whisper")
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:C:buy my gold", "WHISPER", "Sly Stranger")
check(#Mock.chat == chatBefore, "a stranger's words don't show, even if their addon whispers you")
HeyCousinDB.mapShare = true
HC.Map.Apply()
Mock.Advance(6)
check(SentTo("Kit Ashbrook", "^3:P:") ~= nil, "where you are goes to them")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:P:1429:5000:2500:MAGE:30", "WHISPER", "Kit Ashbrook")
Mock.ShowMap(1429)
local whisperedPins = All(WorldMapFrame, function(f) return f.spot ~= nil and f:IsShown() end)
check(#whisperedPins == 1 and whisperedPins[1].spot.member.first == "Kit", "and theirs shows on your map")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:P:1429:7000:2500:MAGE:30", "WHISPER", "Sly Stranger")
Mock.ShowMap(1429)
check(#All(WorldMapFrame, function(f) return f.spot ~= nil and f:IsShown() end) == 1, "a stranger's whisper doesn't")
-- many cousins: where you are goes to a few at a time, in turn; a message for all waits its turn
Mock.channelMembers = {}
for i = 1, 20 do Mock.channelMembers[i] = "Many" .. i .. " Ashbrook" end
HC.Family.AskRoster()
Mock.Advance(3)
local sentBeforeMany = #Mock.addonSent
HC.Family.Spread("3:P:1:1:1::0")
check(#Mock.addonSent == sentBeforeMany + 4, "a position goes to four at a time")
HC.Family.Spread("3:P:1:1:1::0")
check(Mock.addonSent[#Mock.addonSent].target ~= Mock.addonSent[sentBeforeMany + 4].target, "the next four next")
sentBeforeMany = #Mock.addonSent
SlashCmdList.HEYCOUSINFAM("all of you")
check(#Mock.addonSent == sentBeforeMany + 3, "a message for all: a few now")
Mock.Advance(10)
local reached = 0
for i = sentBeforeMany + 1, #Mock.addonSent do
    if Mock.addonSent[i].text == "5:C:all of you" then reached = reached + 1 end
end
check(reached == 20, "and the rest in turn: " .. reached)
-- the game holds one back: it goes again
Mock.throttle = 1
sentBeforeMany = #Mock.addonSent
SlashCmdList.HEYCOUSINFAM("held back")
Mock.Advance(40)
reached = 0
for _, line in ipairs(Mock.addonSent) do
    if line.text == "5:C:held back" then reached = reached + 1 end
end
Mock.throttle = 0
check(reached >= 20, "held back by the game, every one still goes: " .. reached)
-- no answer to who's there: nothing breaks, and someone heard from still counts
HC = Mock.Boot("forever", { setupDone = true })
Mock.rosterSilent = true
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Advance(25)
SlashCmdList.HEYCOUSINFAM("anyone?")
check(Mock.Said("isn't ready yet"), "no list yet: it says so")
Mock.rosterSilent = nil
NoErrors(HC, "whispers between cousins")
end

-- /cousin check: what goes out and comes in, to find why two cousins don't see each other
HC = Mock.Boot("forever", { setupDone = true })
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Advance(40)
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:P:1429:5000:2500:MAGE:30", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "3:P:1429:5000:2500:MAGE:30", "CHANNEL", "Sly Stranger", "", 0, 7, "HCashbrookA")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:S:WARRIOR:20:", "CHANNEL", "Rowan Ashbrook", "", 0, 7, "HCashbrookA")
chatBefore = #Mock.chat
SlashCmdList.HEYCOUSIN("check")
local checkText = table.concat(Mock.chat, "\n", chatBefore + 1)
check(checkText:find("family channel HCashbrookA: in it, number 7", 1, true), "it says the channel")
check(checkText:find("cousins it sends to: 1", 1, true) and checkText:find("Anyone Ashbrook", 1, true), "and who it sends to")
check(checkText:find("heard 2 from others", 1, true) and checkText:find("[Kit Ashbrook]", 1, true) and checkText:find("cousin: yes", 1, true)
    and checkText:find("cousin: no", 1, true), "what it heard, as the game gave it, and whether that's a cousin")
check(checkText:find("a word sent just now: true", 1, true) and Mock.listed == "HCashbrookA", "it sends a word and asks who's in the channel")
-- a refusal from the game is not "sent"
Mock.throttle = 0
local realSend = C_ChatInfo.SendAddonMessage
C_ChatInfo.SendAddonMessage = function() return Enum.SendAddonMessageResult.GeneralError or 9 end
Enum.SendAddonMessageResult.Success, Enum.SendAddonMessageResult.GeneralError = 0, 9
check(HC.Guild.Send("4:S:::", "WHISPER", "Anyone Ashbrook") == false, "the game refuses a message: it didn't go")
C_ChatInfo.SendAddonMessage = function() error("nope") end
check(HC.Guild.Send("4:S:::", "WHISPER", "Anyone Ashbrook") == false, "the call fails: it didn't go")
SlashCmdList.HEYCOUSINFAM("refused every time")
Mock.Advance(15)
C_ChatInfo.SendAddonMessage = realSend
check(HC.Guild.Send("4:S:::", "WHISPER", "Anyone Ashbrook") == true, "and goes again when the game takes it")
SlashCmdList.HEYCOUSINFAM("next one")
check(Mock.addonSent[#Mock.addonSent].text == "5:C:next one", "one refused every time doesn't hold up the rest")
NoErrors(HC, "/cousin check")

do
-- crests on nameplates: on the game's own plate frame, so any nameplate addon keeps them
HC = Mock.Boot("forever", { setupDone = true })
house = HC.Kin.House()
local function PlateUnit(token, name, surname, faction, guid)
    Mock.units[token] = { name = name, surname = surname, guid = guid, class = "DRUID", race = "NightElf", level = 22, sex = 3,
        faction = faction, isPlayer = true }
end
PlateUnit("nameplate1", "Fern", "Ashbrook", "Alliance", "Player-1-FERN")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
local fernCrest = HC.Plates.CrestOn("nameplate1")
local fernPlate = C_NamePlate.GetNamePlateForUnit("nameplate1")
check(fernCrest and fernCrest:IsShown() and fernCrest.parent == fernPlate, "a cousin's plate: a crest, on the game's own plate frame")
check(fernCrest.anchors.CENTER.to == fernPlate and fernCrest.anchors.CENTER.x == 0 and fernCrest.anchors.CENTER.y == 34, "in its place")
check(not fernCrest.mouse, "it takes no clicks")
check(fernCrest:GetFrameLevel() > fernPlate:GetFrameLevel() + 10, "above what an addon draws")
check(not (fernCrest.crown and fernCrest.crown:IsShown()), "no crown while nobody can be compared")
house.relatives.Fern.guid = "Player-1-00000A"
house.relatives.Later = { guid = "Player-1-00000F", class = "MAGE", met = 1, lastSeen = 1 }
HC.Kin.Changed()
Settle()
check(fernCrest.crown and fernCrest.crown:IsShown(), "the eldest cousin's plate: a crown over the crest")
house.relatives.Later.guid = "Player-1-000001"
HC.Kin.Changed()
Settle()
check(not fernCrest.crown:IsShown(), "someone older comes: the crown goes")
house.relatives.Later, house.relatives.Fern.guid = nil, nil
HC.Kin.Changed()
Settle()
-- not on anyone else
PlateUnit("nameplate2", "Sly", "Stranger", "Alliance", "Player-1-SLY")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
check(HC.Plates.CrestOn("nameplate2") == nil, "a stranger: no crest")
Mock.units.nameplate3 = { name = "Hogger", guid = "Creature-1-HOG", npc = true }
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
check(HC.Plates.CrestOn("nameplate3") == nil, "a creature: no crest")
Mock.units.nameplate4 = Mock.units.player
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
check(HC.Plates.CrestOn("nameplate4") == nil, "you: no crest")
-- the plate goes, the crest waits for the next
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
check(HC.Plates.CrestOn("nameplate1") == nil and not fernCrest:IsShown(), "the plate goes, the crest goes")
PlateUnit("nameplate5", "Kit", "Ashbrook", "Alliance", "Player-1-KIT")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
check(HC.Plates.CrestOn("nameplate5") == fernCrest and fernCrest.parent == C_NamePlate.GetNamePlateForUnit("nameplate5"), "and comes back on the next")
-- a plate the game keeps to itself
PlateUnit("nameplate6", "Wren", "Ashbrook", "Alliance", "Player-1-WREN")
Mock.noPlate = true
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate6")
Mock.noPlate = nil
check(HC.Plates.CrestOn("nameplate6") == nil, "no plate frame: no crest, no error")
local forbidden = C_NamePlate.GetNamePlateForUnit("nameplate6")
function forbidden:IsForbidden() return true end
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate6")
check(HC.Plates.CrestOn("nameplate6") == nil, "a forbidden plate: left alone")
-- a cousin on the other side: the same crest, the black sheep's red
PlateUnit("nameplate7", "Grom", "Ashbrook", "Horde", "Player-2-GROM")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate7")
local sheepCrest = HC.Plates.CrestOn("nameplate7")
check(sheepCrest and sheepCrest:IsShown() and sheepCrest.parent == C_NamePlate.GetNamePlateForUnit("nameplate7"), "an enemy plate of a black sheep: a crest too")
check(sheepCrest.fill.color[1] == HC.Theme.C.enemy[1] and sheepCrest.fill.color[2] == HC.Theme.C.enemy[2], "in the black sheep's red")
check(sheepCrest.anchors.CENTER.y == 34, "in the same place")
PlateUnit("nameplate2", "Sly", "Stranger", "Horde", "Player-2-SLY")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
check(HC.Plates.CrestOn("nameplate2") == nil, "an enemy who isn't family: no crest")
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate7")
Mock.units.nameplate7 = nil
-- the settings' page: a sample, a drag, the wheel, buttons, real plates following
HC.Options.Show("plates")
local platesPage = _G.HeyCousinOptions
check(ButtonWith(platesPage, "Nameplates").kind == "primary" and Crest(platesPage, 33):IsVisible(), "a page, with a sample and a crest on it")
local sample = Crest(platesPage, 33)
local plateSamples = All(platesPage, function(f) return f.size == 33 and f:IsVisible() end)
check(#plateSamples == 2, "two samples: your side and a black sheep's: " .. #plateSamples)
check(plateSamples[1].fill.color[1] ~= HC.Theme.C.enemy[1] and plateSamples[2].fill.color[1] == HC.Theme.C.enemy[1], "the second in the black sheep's red")
check(sample.mouseEnabled ~= false and not ButtonWith(platesPage, "Reset"):IsEnabled(), "at its starting place: nothing to reset")
local cursorX, cursorY = 100, 100
local realCursor = GetCursorPosition
function GetCursorPosition() return cursorX, cursorY end
sample:GetScript("OnMouseDown")(sample)
cursorX, cursorY = 130, 85
sample:GetScript("OnUpdate")(sample, 0.01)
sample:GetScript("OnMouseUp")(sample)
check(HeyCousinDB.plateX == 20 and HeyCousinDB.plateY == 24, "a drag moves it, at the sample's size: " .. HeyCousinDB.plateX .. ", " .. HeyCousinDB.plateY)
check(plateSamples[2].anchors.CENTER.x == 30 and plateSamples[2].anchors.CENTER.y == 36, "both samples show it")
check(fernCrest.anchors.CENTER.x == 20 and fernCrest.anchors.CENTER.y == 24, "and real plates follow at once")
check(sample:GetScript("OnUpdate") == nil, "the drag ends with the mouse")
cursorX, cursorY = 100, 100
plateSamples[2]:GetScript("OnMouseDown")(plateSamples[2])
cursorX = 115
plateSamples[2]:GetScript("OnUpdate")(plateSamples[2], 0.01)
plateSamples[2]:GetScript("OnMouseUp")(plateSamples[2])
check(HeyCousinDB.plateX == 30 and sample.anchors.CENTER.x == 45 and fernCrest.anchors.CENTER.x == 30, "the black sheep's crest drags the same one")
cursorX, cursorY = 900, -900
sample:GetScript("OnMouseDown")(sample)
cursorX, cursorY = 9000, 9000
sample:GetScript("OnUpdate")(sample, 0.01)
sample:GetScript("OnMouseUp")(sample)
check(HeyCousinDB.plateX == 100 and HeyCousinDB.plateY == 50, "it stays near the plate")
GetCursorPosition = realCursor
local plateStage = sample.parent
plateStage:GetScript("OnMouseWheel")(plateStage, 1)
check(HeyCousinDB.plateScale == 1.1 and fernCrest.scale == 1.1, "the wheel resizes it, real plates too")
check(fernCrest.anchors.CENTER.x == 100 / 1.1, "and the same place at any size")
ButtonWith(platesPage, "+"):Click()
check(HeyCousinDB.plateScale == 1.2, "so does a button")
ButtonWith(platesPage, "-"):Click()
for _ = 1, 40 do ButtonWith(platesPage, "-"):Click() end
check(HeyCousinDB.plateScale == 0.5, "not too small")
for _ = 1, 40 do ButtonWith(platesPage, "+"):Click() end
check(HeyCousinDB.plateScale == 3, "not too big")
ButtonWith(platesPage, "Reset"):Click()
check(HeyCousinDB.plateX == 0 and HeyCousinDB.plateY == 34 and HeyCousinDB.plateScale == 1 and not ButtonWith(platesPage, "Reset"):IsEnabled(), "reset: back to where it starts")
-- off: gone from every plate, on: back
All(platesPage, function(f) return f.toggle ~= nil and f:IsVisible() end)[1]:Click()
check(HeyCousinDB.plateCrest == false and HC.Plates.CrestOn("nameplate5") == nil, "off: gone")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
check(HC.Plates.CrestOn("nameplate5") == nil, "and none on new plates")
All(platesPage, function(f) return f.toggle ~= nil and f:IsVisible() end)[1]:Click()
check(HC.Plates.CrestOn("nameplate5") ~= nil, "on: back on the plates there are")
-- a new look: new crests
SlashCmdList.HEYCOUSIN("theme")
check(HC.Plates.CrestOn("nameplate5") ~= nil and HC.Plates.CrestOn("nameplate5") ~= fernCrest, "a new look: new crests")
SlashCmdList.HEYCOUSIN("theme")
SlashCmdList.HEYCOUSIN("theme")
_G.HeyCousinOptions:Hide()
-- broken saved numbers
HeyCousinDB.plateX, HeyCousinDB.plateY, HeyCousinDB.plateScale = "x", 9999, 0
local badX, badY, badScale = HC.Plates.Position()
check(badX == 0 and badY == 50 and badScale == 0.5, "broken saved numbers are made safe")
NoErrors(HC, "crests on nameplates")
-- test mode: no surnames on Retail, the page still works
HC = Mock.Boot("retail", { setupDone = true })
HC.Options.Show("plates")
check(Crest(_G.HeyCousinOptions, 33):IsVisible(), "test mode: the page and its sample")
ButtonWith(_G.HeyCousinOptions, "+"):Click()
check(HeyCousinDB.plateScale == 1.1, "and its buttons")
_G.HeyCousinOptions:Hide()
NoErrors(HC, "the nameplate page in test mode")
end

do
-- the settings' samples follow the game's own settings for friendly players
HC = Mock.Boot("forever", { setupDone = true })
HC.Options.Show("plates")
local page = _G.HeyCousinOptions
local function TextOn(root, words)
    for _, region in ipairs(root.regions or {}) do
        if region.text == words and region:IsVisible() then return region end
    end
    for _, child in ipairs(root.children or {}) do
        local found = TextOn(child, words)
        if found then return found end
    end
end
local plainName = TextOn(page, "Rowan Ashbrook")
check(plainName and plainName.anchors.BOTTOM ~= nil, "a friendly player's sample: your name over a bar, by default")
page:Hide()
Mock.cvars = Mock.cvars or {}
Mock.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = "1"
_G.SystemFont_NamePlate = CreateFont("SystemFont_NamePlate")
HC.Options.Show("plates")
plainName = TextOn(page, "Rowan Ashbrook")
check(plainName and plainName.anchors.CENTER ~= nil and plainName.font == _G.SystemFont_NamePlate, "your game shows friendly players as names: so does the sample, in the game's font")
check(TextOn(page, "Grom Ashbrook").anchors.BOTTOM ~= nil, "an enemy's keeps its bar")
Mock.cvars.nameplateUseClassColorForFriendlyPlayerUnitNames = "0"
page:Hide()
HC.Options.Show("plates")
check(TextOn(page, "Rowan Ashbrook").textColor[1] == 1 and TextOn(page, "Rowan Ashbrook").textColor[2] == 1, "white if the game doesn't class-color names")
Mock.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = nil
Mock.cvars.nameplateUseClassColorForFriendlyPlayerUnitNames = nil
_G.SystemFont_NamePlate = nil
page:Hide()
NoErrors(HC, "the samples follow the game's settings")
check((Mock.fontAfterText or 0) == 0, "the sample's font goes on before the words")
end

do
-- while the page is open, the real plates around you show the crest: the game won't let us measure them
HC = Mock.Boot("forever", { setupDone = true })
Mock.units.player.faction = "Alliance"
Mock.units.nameplate1 = { name = "Sly", surname = "Stranger", guid = "Player-1-SLY", class = "MAGE", faction = "Alliance" }
Mock.units.nameplate2 = { name = "Hogger", guid = "Creature-1-HOG", npc = true }
Mock.units.nameplate3 = { name = "Fern", surname = "Ashbrook", guid = "Player-1-FERN", class = "DRUID", faction = "Alliance" }
Mock.units.nameplate4 = Mock.units.player
for index = 1, 4 do
    Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. index)
end
check(HC.Plates.CrestOn("nameplate1") == nil and HC.Plates.CrestOn("nameplate2") == nil and HC.Plates.CrestOn("nameplate3") ~= nil, "page closed: only cousins")
HC.Options.Show("family")
check(HC.Plates.CrestOn("nameplate1") == nil, "another page: only cousins")
HC.Options.Show("plates")
local onStranger, onCreature = HC.Plates.CrestOn("nameplate1"), HC.Plates.CrestOn("nameplate2")
check(onStranger and onStranger:IsShown() and onStranger.parent == C_NamePlate.GetNamePlateForUnit("nameplate1"), "the page open: every plate shows it")
check(onStranger.anchors.CENTER.y == 34 and onCreature and onCreature.anchors.CENTER.y == 34, "where it'll be")
check(onCreature.fill.color[1] == HC.Theme.C.enemy[1] and onStranger.fill.color[1] ~= HC.Theme.C.enemy[1], "red on an enemy's, as a black sheep's")
check(HC.Plates.CrestOn("nameplate4") == nil, "not on your own")
HC.Plates.Move(10, 20)
check(onStranger.anchors.CENTER.x == 10 and onStranger.anchors.CENTER.y == 20, "they follow as you drag")
Mock.units.nameplate5 = { name = "Passer", surname = "Bystander", guid = "Player-1-PASS", class = "MAGE", faction = "Alliance" }
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
check(HC.Plates.CrestOn("nameplate5") ~= nil, "a plate that comes while it's open shows it too")
local samplePage = Crest(_G.HeyCousinOptions, 33).parent.parent
samplePage:GetScript("OnHide")(samplePage)
check(HC.Plates.CrestOn("nameplate1") == nil and HC.Plates.CrestOn("nameplate2") == nil and HC.Plates.CrestOn("nameplate3") ~= nil, "closed: only cousins again")
samplePage:GetScript("OnShow")(samplePage)
check(HC.Plates.CrestOn("nameplate1") ~= nil, "open again: all of them")
HeyCousinDB.plateCrest = false
HC.Plates.Apply()
check(HC.Plates.CrestOn("nameplate1") == nil, "crests off: none, page open or not")
HeyCousinDB.plateCrest = true
samplePage:GetScript("OnHide")(samplePage)
_G.HeyCousinOptions:Hide()
NoErrors(HC, "crests on real plates while the page is open")
end

-- one switch for all the family's messages, both ways
HC = Mock.Boot("forever", { setupDone = true })
house = HC.Kin.House()
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Advance(60)
HC.Options.Show("family")
local familyPage = _G.HeyCousinOptions
check(HeyCousinDB.familyMessages == true, "on by default")
local allRow = ButtonWith(familyPage, "Family messages")
local chatRow = ButtonWith(familyPage, "Family chat")
check(allRow and chatRow, "one switch above the others")
HC.Window.Show("groups")
HC.Groups.Post("Deadmines tonight")
check(HC.Groups.Mine() ~= nil, "(a post of yours is up)")
sentBefore = #Mock.addonSent
allRow:Click()
check(HeyCousinDB.familyMessages == false and not chatRow:IsVisible() and ButtonWith(familyPage, "Family news") == nil, "off: the others wait, out of sight")
check(HeyCousinDB.familyChat == true and HeyCousinDB.presence == true, "as they were")
check(HC.Groups.Mine() == nil and Mock.addonSent[sentBefore + 1] and Mock.addonSent[sentBefore + 1].text == "5:X", "your post comes down, and cousins hear it")
-- nothing shows
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:C:hello", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:L:MAGE:30:", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:H:MAGE:30:", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:G:Stockades", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:J", "WHISPER", "Kit Ashbrook")
check(#Mock.chat == chatBefore and #HC.Groups.List() == 0, "off: no chat, news, online line or group from cousins")
-- nothing goes
sentBefore = #Mock.addonSent
Mock.Advance(5 * 60)
local wentOut = false
for i = sentBefore + 1, #Mock.addonSent do
    wentOut = wentOut or Mock.addonSent[i].text:find("^[45]:") ~= nil
end
check(not wentOut, "off: no answer and no word goes to cousins")
SlashCmdList.HEYCOUSINFAM("hello?")
check(Mock.Said("Family chat is off"), "/fam says it's off")
HC.Groups.Post("Stockades?")
check(HC.Groups.Mine() == nil and Mock.Said("Family messages are off"), "and a post says why it can't go")
-- the map isn't a message: the channel stays for it, and goes when that's off too
check(Mock.channels.HCashbrookA ~= nil, "the map still has the channel")
HeyCousinDB.mapShow = false
HC.Map.Apply()
check(Mock.channels.HCashbrookA == nil, "with the map off too: out of the channel")
HeyCousinDB.mapShow = true
-- back on: it all comes back as it was
allRow:Click()
check(HeyCousinDB.familyMessages == true and chatRow:IsVisible() and Mock.channels.HCashbrookA ~= nil, "on again: the others show, back in the channel")
chatBefore = #Mock.chat
Mock.Advance(1)
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:C:hello again", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore + 1, "and their words show")
_G.HeyCousinOptions:Hide()
_G.HeyCousinWindow:Hide()
NoErrors(HC, "the one switch")

-- a big family doesn't fill your chat: a few lines a minute about cousins; chat itself is what people say
HC = Mock.Boot("forever", { setupDone = true })
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Advance(60)
chatBefore = #Mock.chat
for i = 1, 20 do
    Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:H:MAGE:10:", "CHANNEL", "Busy" .. i .. " Ashbrook", "", 0, 7, "HCashbrookA")
end
check(#Mock.chat == chatBefore + 3, "twenty cousins coming online at once: three lines, got " .. (#Mock.chat - chatBefore))
check(HC.Kin.House().relatives.Busy20 and HC.Kin.IsOnline("Busy20"), "and all of them are still known to be online")
Mock.Advance(61)
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:H:MAGE:10:", "CHANNEL", "Late Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore + 1, "a minute later, a line again")
NoErrors(HC, "lines about cousins")

-- === Family groups ============================================================================

HC = Mock.Boot("forever", { setupDone = true })
house = HC.Kin.House()
Mock.Fire("PLAYER_ENTERING_WORLD")
Mock.Advance(40)
HC.Window.Show("groups")
local groupsWindow = _G.HeyCousinWindow
check(ButtonWith(groupsWindow, "Groups").kind == "primary" and ButtonWith(groupsWindow, "Post") ~= nil, "the Groups tab, with its box")
check(not ButtonWith(groupsWindow, "Post"):IsEnabled(), "nothing to post yet")
local groupBox = All(groupsWindow, function(f) return f.kind == "EditBox" and f:IsVisible() end)[1]
-- your post goes to the family
groupBox:SetText("Deadmines, |cffff0000need a healer")
ButtonWith(groupsWindow, "Post"):Click()
check(ChannelSent("^5:G:") and ChannelSent("^5:G:").text == "5:G:Deadmines, cffff0000need a healer", "your post goes out, with no codes")
check(ButtonWith(groupsWindow, "Take it down") ~= nil, "then it can come down")
-- a cousin logging in gets it too
sentBefore = #Mock.addonSent
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "4:H:ROGUE:30:", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
Mock.Advance(7)
local toKit
for i = sentBefore + 1, #Mock.addonSent do
    if Mock.addonSent[i].text:find("^5:G:") and Mock.addonSent[i].target == "Kit Ashbrook" then toKit = true end
end
check(toKit, "a cousin who logs in gets your post")
-- someone asks to join: one button, the invite is your click
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:J", "WHISPER", "Kit Ashbrook")
local askWindow = _G.HeyCousinAsk
check(askWindow and askWindow:IsShown() and askWindow.text.text:find("join your group", 1, true), "their Join: an ask, about your group")
check(#Mock.invites == 0 or Mock.invites[#Mock.invites] ~= "Kit Ashbrook", "no invite by itself")
ButtonWith(askWindow, "Invite"):Click()
check(Mock.invites[#Mock.invites] == "Kit Ashbrook", "one click invites them")
-- down again: no more asks
ButtonWith(groupsWindow, "Take it down"):Click()
check(ChannelSent("^5:X") ~= nil and HC.Groups.Mine() == nil and groupBox:GetText() == "", "your post comes down")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:J", "WHISPER", "Kit Ashbrook")
check(not askWindow:IsShown(), "no post, no ask")
-- a cousin's post: a line in chat, and a row with Join
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:G:Stockades |TInterface:900|t tonight", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore + 1 and Mock.chat[#Mock.chat]:find("looks for a group: Stockades", 1, true) and not Mock.chat[#Mock.chat]:find("|T", 1, true),
    "a cousin's post: a line in chat, with no codes")
Settle()
local groupRows = All(groupsWindow, function(f) return f.item and f.item.words and f.join and f:IsVisible() end)
check(#groupRows == 1 and groupRows[1].item.first == "Kit" and groupRows[1].words.text:find("Stockades", 1, true), "and a row")
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:G:Stockades TInterface:900t tonight", "CHANNEL", "Kit Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore + 1, "the same post again: no new line")
sentBefore = #Mock.addonSent
groupRows[1].join:Click()
check(Mock.addonSent[#Mock.addonSent].text == "5:J" and Mock.addonSent[#Mock.addonSent].target == "Kit Ashbrook", "Join asks them")
check(not groupRows[1].join:IsEnabled() and groupRows[1].join.label.text == "Asked", "once")
-- who it isn't from
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:G:spam", "CHANNEL", "Sly Stranger", "", 0, 7, "HCashbrookA")
Mock.ignored = { ["Oren Ashbrook"] = true }
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:G:spam", "CHANNEL", "Oren Ashbrook", "", 0, 7, "HCashbrookA")
Mock.ignored = nil
check(#HC.Groups.List() == 1, "another surname and your ignore list are left out")
-- the line can be turned off; the post still shows
HeyCousinDB.familyGroups = false
chatBefore = #Mock.chat
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:G:Scarlet Monastery", "CHANNEL", "Lia Ashbrook", "", 0, 7, "HCashbrookA")
check(#Mock.chat == chatBefore and #HC.Groups.List() == 2, "no line, the post still shows")
HeyCousinDB.familyGroups = true
-- they take it down, or half an hour goes by
Mock.Fire("CHAT_MSG_ADDON", "HeyCousin", "5:X", "CHANNEL", "Lia Ashbrook", "", 0, 7, "HCashbrookA")
check(#HC.Groups.List() == 1, "they take it down")
Mock.Advance(31 * 60)
check(#HC.Groups.List() == 0, "it's gone after half an hour")
Settle()
_G.HeyCousinWindow:Hide()
NoErrors(HC, "family groups")

-- test mode: made-up posts, and nothing goes out
HC = Mock.Boot("retail", { setupDone = true })
sentBefore = #Mock.addonSent
SlashCmdList.HEYCOUSIN("groups")
Settle()
check(_G.HeyCousinWindow:IsShown() and #HC.Groups.List() == 2, "test mode: made-up posts")
HC.Groups.Post("Test")
check(HC.Groups.Mine().words == "Test" and #Mock.addonSent == sentBefore, "and your post goes nowhere")
HC.Groups.Join(HC.Groups.List()[1])
check(Mock.Said("made-up cousins can't hear you"), "and neither does a Join")
-- a new look with the tab open
HC.Theme.SetSkin("smooth")
Settle()
check(ButtonWith(_G.HeyCousinWindow, "Groups") ~= nil, "a new look builds the tab again")
HC.Theme.SetSkin("pixel")
_G.HeyCousinWindow:Hide()
NoErrors(HC, "family groups in test mode")

-- === Look up a family =========================================================================

HC = Mock.Boot("forever", { setupDone = true })
house = HC.Kin.House()
Mock.whoSent, Mock.who = {}, {
    { fullName = "Bram Stormvale", filename = "PALADIN", level = 38, area = "Duskwood", fullGuildName = "Vale Keepers" },
    { fullName = "Odalys Stormvale", filename = "HUNTER", level = 52, area = "Winterspring", fullGuildName = "" },
    { fullName = "Nell Stormvales", filename = "PRIEST", level = 22, area = "Duskwood", fullGuildName = "" },
}
HC.Window.Show("family")
_G.HeyCousinWindow.lookup:Click()
local lookupWindow = _G.HeyCousinLookup
check(lookupWindow and lookupWindow:IsShown(), "the window's button opens it")
check(not ButtonWith(lookupWindow, "Search"):IsEnabled(), "nothing to search for yet")
local lookupBox = All(lookupWindow, function(f) return f.kind == "EditBox" and f:IsVisible() end)[1]
lookupBox:SetText('Storm"vale ')
ButtonWith(lookupWindow, "Search"):Click()
check(Mock.whoSent[1] == 'n-" Stormvale"', "it asks the game, by surname: " .. tostring(Mock.whoSent[1]))
check(not ButtonWith(lookupWindow, "Search"):IsEnabled(), "one search at a time")
Mock.Fire("WHO_LIST_UPDATE")
Settle()
local lookupRows = All(lookupWindow, function(f) return f.where and f.item and f:IsVisible() end)
table.sort(lookupRows, function(a, b) return a.item.level > b.item.level end)
check(#lookupRows == 2 and lookupRows[1].item.first == "Odalys" and lookupRows[2].where.text:find("Vale Keepers", 1, true),
    "exactly that surname, the highest first, with zone and guild")
check(house.relatives.Bram == nil and house.relatives.Odalys == nil, "nobody joins your family by it")
Mock.Advance(7)
check(ButtonWith(lookupWindow, "Search"):IsEnabled(), "the next search can go")
-- from a command, and nobody there
Mock.who = {}
SlashCmdList.HEYCOUSIN("find Nobodyhere")
check(Mock.whoSent[2] == 'n-" Nobodyhere"', "/cousin find Surname searches")
Mock.Fire("WHO_LIST_UPDATE")
local function LookupSays(words)
    for _, region in ipairs(lookupWindow.regions or {}) do
        if region.text and region.text:find(words, 1, true) then return true end
    end
    return false
end
check(LookupSays("Nobody with the surname Nobodyhere"), "nobody there: it says so")
Mock.Advance(7)
-- /who lists your own realm only: someone in your group from another realm is found there
Mock.units.party1 = { name = "Fen", surname = "Thornwick", guid = "Player-9-FEN", class = "DRUID", level = 44,
    faction = "Alliance", visible = false }
Mock.roster[#Mock.roster + 1] = { full = "Ivo Thornwick", level = 30, class = "MAGE", zone = "Duskwood", online = true }
Mock.roster[#Mock.roster + 1] = { full = "Ada Thornwick", level = 31, class = "MAGE", zone = "Duskwood", online = false }
Mock.who = { { fullName = "Ivo Thornwick", filename = "MAGE", level = 30, area = "Duskwood", fullGuildName = "" } }
SlashCmdList.HEYCOUSIN("find Thornwick")
Mock.Fire("WHO_LIST_UPDATE")
lookupRows = All(lookupWindow, function(f) return f.where and f.item and f:IsVisible() end)
local foundNames = {}
for _, row in ipairs(lookupRows) do foundNames[#foundNames + 1] = row.item.first end
table.sort(foundNames)
check(table.concat(foundNames, ",") == "Fen,Ivo", "your group's player and /who's, once each, and your guild's online only: "
    .. table.concat(foundNames, ","))
Mock.units.party1 = nil
table.remove(Mock.roster)
table.remove(Mock.roster)
Mock.who = {}
Mock.Advance(7)
-- no answer: it says so
SlashCmdList.HEYCOUSIN("find Quiet")
check(LookupSays("Looking..."), "while it waits, it says so")
Mock.Advance(7)
check(LookupSays("The game didn't answer"), "no answer: it says so")
-- your own family's search still works beside it
HC.Window.Show("family")
_G.HeyCousinWindow.find:Click()
check(Mock.whoSent[#Mock.whoSent] == 'n-" Ashbrook"', "Find my family asks as before")
Mock.Fire("WHO_LIST_UPDATE")
Mock.Advance(7)
-- a new look keeps what it found
HC.Theme.SetSkin("smooth")
check(_G.HeyCousinLookup:IsShown(), "a new look builds it again")
HC.Theme.SetSkin("pixel")
_G.HeyCousinLookup:Hide()
_G.HeyCousinWindow:Hide()
NoErrors(HC, "look up a family")

HC = Mock.Boot("retail", { setupDone = true })
HC.Lookup.Show("Stormvale")
Mock.Advance(2)
lookupRows = All(_G.HeyCousinLookup, function(f) return f.where and f.item and f:IsVisible() end)
check(#lookupRows == 3, "test mode: a made-up house, the near-name left out")
_G.HeyCousinLookup:Hide()
NoErrors(HC, "look up a family in test mode")

-- === Recruit ==================================================================================

HC = Mock.Boot("forever", { setupDone = true })
house = HC.Kin.House()
Mock.whoSent, Mock.who = {}, {
    { fullName = "Perrin Ashbrook", filename = "ROGUE", level = 16, area = "Westfall", fullGuildName = "" },
    { fullName = "Kit Ashbrook", filename = "MAGE", level = 30, area = "Duskwood", fullGuildName = "" },
    { fullName = "Bram Ashbrook", filename = "WARRIOR", level = 40, area = "Wetlands", fullGuildName = "Vale Kin" },
}
house.relatives.Cato = { class = "PRIEST", level = 50, met = 0, lastSeen = 1 } -- never learned: unknown, not listed
house.relatives.Bru = { class = "DRUID", level = 20, met = 1, lastSeen = 1, noGuild = true, faction = "Horde" } -- the other side
HC.Window.Show("family")
_G.HeyCousinWindow.find:Click()
Mock.Fire("WHO_LIST_UPDATE")
Mock.Advance(7)
check(house.relatives.Perrin.noGuild and not house.relatives.Bram.noGuild, "a search learns who has no guild")
HC.Kin.Seen({ first = "Bram", guild = false })
check(house.relatives.Bram.noGuild, "leaving a guild is noted")
HC.Kin.Seen({ first = "Bram", guild = "Vale Kin" })
check(not house.relatives.Bram.noGuild and house.relatives.Bram.guild == "Vale Kin", "and so is joining one")
local recruits = HC.Recruit.List()
check(#recruits == 2 and recruits[1].first == "Kit" and recruits[2].first == "Perrin",
    "the cousins known to have no guild, on your side, the highest first: " .. #recruits)
local function RecruitRows()
    return All(_G.HeyCousinWindow, function(f) return f.invite ~= nil and f.item ~= nil and f:IsVisible() end)
end
local recruitButton = _G.HeyCousinWindow.recruit
Settle()
check(recruitButton:IsShown() and recruitButton:GetText() == "Recruit (2)", "the button says how many: " .. tostring(recruitButton:GetText()))
check(_G.HeyCousinWindow.footer:GetStringWidth() + recruitButton:GetWidth() <= 500 - 36, "the last line leaves it room")
recruitButton:Click()
Settle()
check(#RecruitRows() == 2 and not recruitButton:IsShown(), "it opens the Recruit page: " .. #RecruitRows())
-- no guild: you can still whisper, and it says so
local recruitRow = RecruitRows()[1]
check(recruitRow.item.first == "Kit" and not recruitRow.invite:IsEnabled() and recruitRow.invite.barred == "You have no guild.", "no guild: no invite, and why")
Mock.opened = {}
recruitRow.whisper:Click()
check(Mock.opened[1] == "/w Kit Ashbrook Hey cousin! We share a surname. Want to join the family?", "the whisper opens with the welcome: " .. tostring(Mock.opened[1]))
-- a guild, and a rank that can't invite
Mock.guild = { name = "Ashbrook Kin", rank = 3, ranks = { "Master", "Officer", "Member", "Initiate" } }
Mock.mayInvite = false
HC.Window.Refresh()
check(not RecruitRows()[1].invite:IsEnabled() and RecruitRows()[1].invite.barred == "Your rank can't invite.", "a rank that can't invite: no invite, and why")
-- a rank that can
Mock.mayInvite = true
HC.Window.Refresh()
recruitRow = RecruitRows()[1]
check(recruitRow.invite:IsEnabled() and recruitRow.invite.barred == nil, "a rank that can invite")
Mock.opened = {}
recruitRow.invite:Click()
local copyBox = All(_G.HeyCousinWindow, function(f) return f.edit ~= nil and f.edit:GetText() == "/ginvite Kit Ashbrook" and f:IsVisible() end)[1]
check(copyBox and copyBox.edit:HasFocus() and copyBox.edit.highlighted, "one click: /ginvite by their whole name, chosen, ready to copy")
check(#Mock.opened == 0 and not Mock.guildInviteBlocked, "the addon touches neither the invite nor the chat box: the game blocks those")
copyBox.edit:SetText("oops")
check(copyBox.edit:GetText() == "/ginvite Kit Ashbrook", "the line can't be changed by a slip")
Mock.controlDown = true
Mock.Run(copyBox.edit, "OnKeyDown", "C")
Mock.controlDown = false
Mock.Run(copyBox.edit, "OnKeyUp", "CTRL")
check(not copyBox.edit:HasFocus(), "Ctrl+C: the box lets go, so Enter opens your own chat box")
recruitRow.invite:Click()
check(recruitRow.invite:IsEnabled() and copyBox.edit:HasFocus(), "the button stays: you may have closed the box")
copyBox.edit:SetText("")
check(not copyBox:IsVisible(), "the box's X closes it")
recruitRow.invite:Click()
_G.HeyCousinWindow:Hide()
_G.HeyCousinWindow:Show()
Settle()
-- your own welcome is kept
local welcomeBox = All(_G.HeyCousinWindow, function(f) return f.edit ~= nil and f.onChange ~= nil and f:IsVisible() end)[1]
welcomeBox.edit:SetFocus()
welcomeBox.edit:SetText("  Come home, cousin!  ", true)
Mock.Run(welcomeBox.edit, "OnTextChanged", true)
check(house.welcome == "Come home, cousin!", "your own welcome is kept: " .. tostring(house.welcome))
welcomeBox.edit:ClearFocus()
HC.Window.Refresh()
Mock.opened = {}
RecruitRows()[2].whisper:Click()
check(Mock.opened[1] == "/w Perrin Ashbrook Come home, cousin!", "and goes out: " .. tostring(Mock.opened[1]))
Mock.guild, Mock.mayInvite = nil, nil
-- offline: invite rests
Mock.Advance(5 * 60)
HC.Window.Refresh()
check(RecruitRows()[1].invite.barred ~= nil, "not seen online lately: invite rests")
-- a row's click opens the page, and back to the family
RecruitRows()[1]:Click()
Settle()
check(All(_G.HeyCousinWindow, function(f) return f.whisper ~= nil and f.met ~= nil and f:IsVisible() end)[1], "a row opens their page")
HC.Window.Open(nil)
Settle()
check(recruitButton:IsShown() and #RecruitRows() == 0, "and back to the family")
SlashCmdList.HEYCOUSIN("recruit")
Settle()
check(#RecruitRows() >= 1, "/cousin recruit opens it")
_G.HeyCousinWindow:Hide()
NoErrors(HC, "recruit")

-- === Your other characters ====================================================================

-- the saved file another character of yours left: its row, and a line it once saw you on
HC = Mock.Boot("forever", { setupDone = true, houses = { Ashbrook = {
    relatives = { Rowan = { class = "ROGUE", met = 1, lastSeen = 5 } },
    mine = { Slate = { class = "ROGUE", level = 18, zone = "Orgrimmar", faction = "Alliance", lastSeen = 1700000000 - 3600, guid = "Player-1-00090F33" },
        Broken = "oops" },
} } })
house = HC.Kin.House()
check(house.mine.Broken == nil, "a broken saved character is dropped")
Mock.Fire("PLAYER_ENTERING_WORLD")
check(house.mine.Rowan and house.mine.Rowan.guid == "Player-1-ME" and house.mine.Rowan.zone == "Elwynn Forest", "logging in notes this character")
check(house.relatives.Rowan == nil, "and you stop being your own cousin")
local alts = HC.Kin.Alts()
check(#alts == 1 and alts[1].first == "Slate", "your other character, without this one")
check(select(1, HC.Kin.Counts()) == 0, "they don't count as relatives")
HC.Window.Show("family")
Settle()
local altRows = All(_G.HeyCousinWindow, function(f) return f.item and f.item.alt and f:IsVisible() end)
check(#altRows == 1 and altRows[1].item.first == "Slate" and altRows[1].tag.text == "(your character)" and altRows[1].level.text == "18",
    "it shows under you, marked as yours: " .. #altRows)
check(not altRows[1].sheep:IsShown(), "even on the other side, it isn't a black sheep")
altRows[1]:Click()
Settle()
check(altRows[1]:IsVisible(), "it has no cousin's page to open")
_G.HeyCousinWindow:Hide()
local slateBefore = HC.Kin.Seen({ first = "Slate", class = "ROGUE", near = true })
check(slateBefore == nil and house.relatives.Slate == nil, "seen around, it doesn't turn into a cousin")
house.relatives.Alba = { guid = "Player-1-00E3D28D", class = "MAGE", met = 1, lastSeen = 1 }
check(HC.Kin.Eldest() == "Slate", "your oldest character can be the eldest")
house.relatives.Alba = nil
SlashCmdList.HEYCOUSIN("forget Nobody")
check(Mock.Said("Nobody isn't one of your other characters."), "forgetting a name that isn't yours says so")
SlashCmdList.HEYCOUSIN("forget Rowan")
check(house.mine.Rowan ~= nil, "the character you're on can't be forgotten")
SlashCmdList.HEYCOUSIN("forget SLATE")
check(house.mine.Slate == nil and #HC.Kin.Alts() == 0 and Mock.Said("Slate forgotten."), "/cousin forget takes a deleted one off the list")
SlashCmdList.HEYCOUSIN("delete Nobody")
check(Mock.Said("Nobody isn't in your family."), "deleting a name that isn't family says so")
SlashCmdList.HEYCOUSIN("delete Rowan")
check(house.mine.Rowan ~= nil and Mock.Said("Rowan isn't in your family."), "you aren't your own cousin to delete")
Mock.units.nameplate7 = { name = "Dell", surname = "Ashbrook", guid = "Player-1-DELL", class = "MAGE", race = "Human",
    level = 30, sex = 3, faction = "Alliance" }
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate7")
check(house.relatives.Dell and house.relatives.Dell.met == 1 and HC.Kin.IsNear("Dell"), "a cousin met")
house.relatives.Dell.met = 5
SlashCmdList.HEYCOUSIN("delete dell ashbrook")
check(house.relatives.Dell == nil and not HC.Kin.IsNear("Dell") and Mock.Said("Dell forgotten."),
    "/cousin delete takes them off, by their whole name in any letters")
Settle()
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate7")
check(house.relatives.Dell and house.relatives.Dell.met == 1 and house.relatives.Dell.alerted ~= nil,
    "still standing there, they're a new cousin at once, with the first pop-up")
house.relatives.Dell, Mock.units.nameplate7 = nil, nil
HC.Alert.Dismiss()
Settle()
Mock.Fire("PLAYER_LOGOUT")
check(house.mine.Rowan.lastSeen ~= nil, "logging out notes it again, where you were")
NoErrors(HC, "your other characters")

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

-- === The settings ===============================================================================

HC = Mock.Boot("forever", { setupDone = true })
HC.Window.Show("family")
-- the gear opens them, and the minimap's right-click, and /cousin settings
local gearButton = All(_G.HeyCousinWindow, function(f) return f.icon and f.icon.file and f.icon.file:find("Gear") end)[1]
gearButton:Click()
local options = _G.HeyCousinOptions
check(options and options:IsShown() and ButtonWith(options, "Alerts").kind == "primary", "the gear opens the settings, on Alerts")
check(next(options.anchors) ~= nil, "the settings have a place on screen")
options:Hide()
SlashCmdList.HEYCOUSIN("settings")
check(options:IsShown(), "/cousin settings")
options:Hide()
_G.HeyCousinMinimapButton:GetScript("OnClick")(_G.HeyCousinMinimapButton, "RightButton")
check(options:IsShown(), "the minimap's right-click")
-- a page for each thing, and each row sets what it says
local function Rows(root) return All(root, function(f) return f.toggle ~= nil and f:IsVisible() end) end
local function Row(root, text)
    for _, row in ipairs(Rows(root)) do
        if row.label.text == text then return row end
    end
end
check(#Rows(options) == 4, "Alerts: four rows")
Row(options, "Every time you meet"):Click()
check(HeyCousinDB.popupEvery == true, "a row sets its setting")
Row(options, "Every time you meet"):Click()
ButtonWith(options, "Bell"):Click()
check(HeyCousinDB.sound == "bell" and ButtonWith(options, "Bell").kind == "primary" and #Mock.sounds > 0, "a sound chip picks and plays it")
ButtonWith(options, "Family"):Click()
check(ButtonWith(options, "Family").kind == "primary" and ButtonWith(options, "Alerts").kind == "secondary", "the chosen page is lit")
check(Crest(options, 64):IsVisible() and Row(options, "Cousins coming online") and not Row(options, "Every time you meet"),
    "Family: your crest, and only its own rows")
check(ButtonWith(options, "Your guild") == nil, "no guild to lead, no guild button")
-- your crest: a page of its own in this window, not the setup
ButtonWith(options, "Change your crest"):Click()
check(options:IsShown() and not (_G.HeyCousinSetup and _G.HeyCousinSetup:IsShown()), "the crest stays in the settings, no setup")
check(ButtonWith(options, "Family") == nil and Crest(options, 160):IsVisible() and ButtonWith(options, "Back") ~= nil,
    "a page of its own, with a way back")
check(not ButtonWith(options, "Reset"):IsEnabled(), "nothing to reset yet")
local optionsRights = All(options, function(f) return f.direction == "RIGHT" and f:IsVisible() end)
optionsRights[1]:Click()
check(HC.Kin.House().crest.shape == "Round" and ButtonWith(options, "Reset"):IsEnabled(), "saved as you make it")
ButtonWith(options, "Reset"):Click()
check(HC.Kin.House().crest.shape == "Heater" and not ButtonWith(options, "Reset"):IsEnabled(), "reset: as it was")
optionsRights[1]:Click()
ButtonWith(options, "Back"):Click()
check(ButtonWith(options, "Family").kind == "primary" and Crest(options, 64).crest.shape == "Round", "back: on Family, with the new crest")
-- opened again, the window is back on its pages
ButtonWith(options, "Change your crest"):Click()
options:Hide()
SlashCmdList.HEYCOUSIN("settings")
check(ButtonWith(options, "Family") ~= nil, "closed on the crest, it opens on its pages again")
SlashCmdList.HEYCOUSIN("theme")
options = _G.HeyCousinOptions
HC.Options.Show("crest")
SlashCmdList.HEYCOUSIN("theme")
options = _G.HeyCousinOptions
check(options:IsShown() and Crest(options, 160):IsVisible(), "a new look on the crest's page stays there")
SlashCmdList.HEYCOUSIN("theme")
options = _G.HeyCousinOptions
ButtonWith(options, "Back"):Click()
Row(options, "Cousins coming online"):Click()
check(HeyCousinDB.presence == false, "the hello can be turned off here")
Row(options, "Cousins coming online"):Click()
Row(options, "Family news"):Click()
Row(options, "Family chat"):Click()
Row(options, "Family groups"):Click()
check(HeyCousinDB.familyNews == false and HeyCousinDB.familyChat == false and HeyCousinDB.familyGroups == false,
    "news, chat and groups can be turned off here")
Row(options, "Family groups"):Click()
Row(options, "Family news"):Click()
Row(options, "Family chat"):Click()
ButtonWith(options, "Map"):Click()
Row(options, "Share it with your family"):Click()
check(HeyCousinDB.mapShare == true, "sharing where you are")
Row(options, "Share it with your family"):Click()
Mock.printed = nil
ButtonWith(options, "Try it on your map"):Click()
ButtonWith(options, "In the game"):Click()
Row(options, "Lock the button"):Click()
check(HeyCousinDB.lockMinimap == true, "the minimap's lock")
Row(options, "Lock the button"):Click()
Row(options, "The minimap crest"):Click()
check(not _G.HeyCousinMinimapButton:IsShown(), "the minimap button goes as you turn it off")
Row(options, "The minimap crest"):Click()
check(_G.HeyCousinMinimapButton:IsShown(), "and comes back")
ButtonWith(options, "Guild"):Click()
check(HeyCousinDB.chats.guild == false, "a chat chip")
ButtonWith(options, "Guild"):Click()
-- the language waits for a reload, with a button for it
ButtonWith(options, "Look & language"):Click()
check(ButtonWith(options, "Reload to show it") == nil, "nothing to reload yet")
ButtonWith(options, "Deutsch"):Click()
check(HeyCousinDB.language == "deDE" and ButtonWith(options, "Deutsch").kind == "primary", "a language")
ButtonWith(options, "Reload to show it"):Click()
check(Mock.reloads == 1, "reload to show it")
ButtonWith(options, "The game's"):Click()
check(HeyCousinDB.language == "auto" and ButtonWith(options, "Reload to show it") == nil, "the game's language again: no reload")
-- a new look builds them again, on the same page
ButtonWith(options, "Smooth"):Click()
check(HeyCousinDB.skin == "smooth" and _G.HeyCousinOptions:IsShown() and ButtonWith(_G.HeyCousinOptions, "Look & language").kind == "primary",
    "a new look, on the same page")
options = _G.HeyCousinOptions
ButtonWith(options, "Pixel"):Click()
options = _G.HeyCousinOptions
-- About: the version shows what's new, and the setup runs from here
ButtonWith(options, "About"):Click()
local versions = All(options, function(f) return f.text and f.text.text == "Version " .. HC.VERSION and f:IsVisible() end)
check(#versions == 2, "the version, on every page and in About")
versions[1]:Click()
check(GameTooltip.lines[1] == "What's new in " .. HC.VERSION and #GameTooltip.lines > 2, "a click on the version: what's new")
versions[1]:GetScript("OnLeave")(versions[1])
ButtonWith(options, "Open the setup"):Click()
check(_G.HeyCousinSetup:IsShown() and not options:IsShown(), "the setup runs from the settings, which close")
SlashCmdList.HEYCOUSIN("settings")
check(options:IsShown() and not _G.HeyCousinSetup:IsShown(), "and the settings close the setup: one at a time")
options:Hide()
-- the game's own Options > AddOns
local gamePage = Mock.optionsPage
check(gamePage and gamePage.name == "Hey Cousin!", "a page in the game's Options")
SettingsPanel:Show()
gamePage.panel:Show()
gamePage.panel:SetPoint("CENTER")
ButtonWith(gamePage.panel, "Open the settings"):Click()
check(options:IsShown() and not SettingsPanel:IsShown(), "its button opens the settings and closes the game's panel")
options:Hide()
NoErrors(HC, "the settings")

-- every page in a guild master's test mode, and the look's own window
HC = Mock.Boot("retail", { setupDone = true })
HC.Options.Show("family")
check(ButtonWith(_G.HeyCousinOptions, "Your guild") ~= nil, "a guild master has the guild's button")
ButtonWith(_G.HeyCousinOptions, "Your guild"):Click()
local guildPage = _G.HeyCousinOptions
check(guildPage:IsShown() and not (_G.HeyCousinSetup and _G.HeyCousinSetup:IsShown()) and ButtonWith(guildPage, "Family") == nil,
    "the guild's family: a page of its own in the settings")
local function Boxes(root)
    return All(root, function(f) return f.kind == "EditBox" and f:IsVisible() end)
end
local fields = Boxes(guildPage)
check(#fields == 6 and fields[1]:GetText() == "Ashbrook" and fields[3]:GetText() == "Elder"
    and fields[6]:GetText() == "Little cousin", "a family name, a welcome line, and a word for each of the 4 ranks")
check(not ButtonWith(guildPage, "Reset"):IsEnabled(), "nothing changed on it yet")
fields[5]:SetText("Kin")
fields[5]:ClearFocus()
check(HC.Guild.Family().words[3] == "Kin" and ButtonWith(guildPage, "Reset"):IsEnabled(), "a new word, saved when you're done typing")
local stamp = HC.Guild.Family().stamp
fields[5]:ClearFocus()
fields[1]:ClearFocus()
check(HC.Guild.Family().stamp == stamp, "done typing with no change: nothing saved again")
local guildRow = All(guildPage, function(f) return f.toggle ~= nil and f:IsVisible() end)[1]
guildRow:Click()
check(not HC.Guild.Family().given and #Boxes(guildPage) == 0, "turned off: no family, no fields")
guildRow:Click()
check(HC.Guild.Family().given and #Boxes(guildPage) == 6, "and on again")
ButtonWith(guildPage, "Reset"):Click()
check(HC.Guild.Family().words[3] == "Cousin" and Boxes(guildPage)[5]:GetText() == "Cousin", "reset: the words as they were")
ButtonWith(guildPage, "Back"):Click()
check(ButtonWith(guildPage, "Family").kind == "primary", "back on Family")
guildPage:Hide()
NoErrors(HC, "the settings in test mode")

-- === The setup opens by itself once, however it's closed ======================================

local firstSaved = {}
HC = Mock.Boot("forever", firstSaved)
Mock.Advance(5)
check(_G.HeyCousinSetup:IsShown() and ButtonWith(_G.HeyCousinSetup, "Skip for now") ~= nil, "a first install: the setup, with Skip")
-- closed with the X (Escape hides the window the same way)
_G.HeyCousinSetup.close:Click()
check(not _G.HeyCousinSetup:IsShown(), "the X closes it")
HC = Mock.Boot("forever", HeyCousinDB, { name = "Hollis", surname = "Ashbrook", class = "MAGE", race = "Human", level = 5, sex = 2,
    faction = "Alliance", guid = "Player-1-HOLLIS" })
Mock.Advance(5)
check(not (_G.HeyCousinSetup and _G.HeyCousinSetup:IsShown()), "after the X: not at the next login, not on another character")
-- never closed at all: logged out with it open
HC = Mock.Boot("forever", {})
Mock.Advance(5)
check(_G.HeyCousinSetup:IsShown(), "another first install")
-- (logging out takes the old window with it, and nothing closes it first)
_G.HeyCousinSetup = nil
HC = Mock.Boot("forever", HeyCousinDB)
Mock.Advance(5)
check(not (_G.HeyCousinSetup and _G.HeyCousinSetup:IsShown()), "left open and logged out: not again")
-- asked for, it still opens, with no Skip
SlashCmdList.HEYCOUSIN("setup")
check(_G.HeyCousinSetup:IsShown() and ButtonWith(_G.HeyCousinSetup, "Skip for now") == nil, "/cousin setup opens it any time, with no Skip")
_G.HeyCousinSetup:Hide()
NoErrors(HC, "the setup, once")

-- === A new player closes the setup at once: the defaults work, everything opens =================

HC = Mock.Boot("forever", {})
Mock.Advance(5)
_G.HeyCousinSetup.close:Click()
local defaults = { popup = true, popupEvery = false, enemyAlerts = true, sound = "auto", chatCrest = true, tooltipLine = true,
    showMinimap = true, lockMinimap = false, mapShow = true, mapShare = false, presence = true, familyNews = true,
    familyChat = true, familyGroups = true, familyMessages = true, skin = "pixel", language = "auto", setupDone = true }
for key, value in pairs(defaults) do
    check(HeyCousinDB[key] == value, "closed at once, the default stays: " .. key .. " = " .. tostring(HeyCousinDB[key]))
end
check(HC.Kin.House().crest.shape == "Heater" and HC.Kin.House().crest.symbol == "initial", "the default crest")
local anySent = false
for _, sent in ipairs(Mock.addonSent) do
    anySent = anySent or sent.text:find("^3:P") ~= nil
end
check(not anySent, "where you are isn't shared")
-- every window, every tab, every page, every command
HC.Window.Show("family")
Settle()
for _, tab in ipairs({ "tree", "groups", "stats", "family" }) do
    HC.Window.Show(tab)
    Settle()
end
HC.Window.Recruit(true)
Settle()
HC.Window.Recruit(false)
for _, page in ipairs({ "alerts", "family", "map", "plates", "game", "look", "about", "crest" }) do
    HC.Options.Show(page)
    Settle()
end
_G.HeyCousinOptions:Hide()
for _, command in ipairs({ "tree", "recruit", "groups", "find", "find Stormvale", "settings", "setup", "test", "test map", "theme",
    "theme", "theme", "status", "help", "debug", "debug", "forget Nobody", "delete Nobody", "nonsense" }) do
    SlashCmdList.HEYCOUSIN(command)
    Settle()
end
SlashCmdList.HEYCOUSINFAM("hello")
Mock.Advance(40)
-- and it finds a cousin as it should
Mock.units.nameplate7 = { name = "Fern", surname = "Ashbrook", guid = "Player-1-FERN", class = "DRUID", race = "NightElf",
    level = 22, sex = 3, faction = "Alliance" }
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate7")
Settle()
check(HC.Kin.House().relatives.Fern ~= nil and _G.HeyCousinAlert and _G.HeyCousinAlert:IsShown(), "a cousin near you: known, with a pop-up")
NoErrors(HC, "a new player who closed the setup")

-- === The surnames you meet ====================================================================

-- each player counts once: not again after a reload
local bob = { name = "Bob", surname = "Stone", guid = "Player-1-BOB", class = "ROGUE", faction = "Alliance" }
HC = Mock.Boot("forever", { setupDone = true })
Mock.units.mouseover = bob
Mock.Fire("UPDATE_MOUSEOVER_UNIT")
local saved = HeyCousinDB
HC = Mock.Boot("forever", saved)
Mock.units.mouseover = bob
Mock.Fire("UPDATE_MOUSEOVER_UNIT")
check(HeyCousinDB.surnames.Stone == 1, "the same stranger after a reload: still one Stone")
Mock.units.mouseover = { name = "Bea", surname = "Stone", guid = "Player-1-BEA", class = "MAGE", faction = "Alliance" }
Mock.Fire("UPDATE_MOUSEOVER_UNIT")
check(HeyCousinDB.surnames.Stone == 2, "another Stone: two")
-- counts from before 1.1.2 (each session again) start over
HC = Mock.Boot("forever", { setupDone = true, surnames = { Stone = 38 }, surnameCount = 1 })
check(next(HeyCousinDB.surnames) == nil and HeyCousinDB.surnameCount == 0, "old counts start over")
Mock.units.mouseover = bob
Mock.Fire("UPDATE_MOUSEOVER_UNIT")
check(HeyCousinDB.surnames.Stone == 1, "and count again, one a player")
NoErrors(HC, "the surnames you meet")

-- === Family reunion ===========================================================================

local function Says(root, words)
    for _, region in ipairs(root.regions or {}) do
        if type(region.text) == "string" and region.text:find(words, 1, true) and region:IsVisible() then return region end
    end
    for _, child in ipairs(root.children or {}) do
        local found = Says(child, words)
        if found then return found end
    end
end
HC = Mock.Boot("forever", { setupDone = true })
Mock.Fire("PLAYER_ENTERING_WORLD")
-- already in a group with a cousin when you log in: no banner for it
Mock.inGroup = true
Mock.units.party1 = { name = "Kit", surname = "Ashbrook", guid = "Player-1-KIT", class = "MAGE", level = 20, faction = "Alliance" }
Mock.Fire("GROUP_ROSTER_UPDATE")
Mock.Advance(12)
local reunion = _G.HeyCousinReunion
check(not (reunion and reunion:IsShown()), "the group you log in with: no banner")
-- a second cousin joins: a reunion of three
Mock.units.party2 = { name = "Lia", surname = "Ashbrook", guid = "Player-1-LIA", class = "PRIEST", level = 22, faction = "Alliance" }
Mock.units.party3 = { name = "Sly", surname = "Stranger", guid = "Player-1-SLY", class = "ROGUE", level = 22, faction = "Alliance" }
Mock.Fire("GROUP_ROSTER_UPDATE")
Mock.Advance(3)
reunion = _G.HeyCousinReunion
check(reunion and reunion:IsShown(), "a cousin joins: the banner shows")
check(Says(reunion, "Family reunion!") and Says(reunion, "3 of House Ashbrook in one group"), "three of the house, the stranger not counted")
local reunionCrests = All(reunion, function(f) return f.SetCrest ~= nil and f:IsVisible() end)
check(#reunionCrests == 3, "a crest each: " .. #reunionCrests)
Mock.Tick(60, 0.25)
check(not reunion:IsShown(), "it goes by itself")
-- the same group again: nothing new
Mock.Fire("GROUP_ROSTER_UPDATE")
Mock.Advance(3)
check(not reunion:IsShown(), "the same cousins: no second banner")
-- one joins in a fight: it waits for the fight to end
Mock.units.party4 = { name = "Ned", surname = "Ashbrook", guid = "Player-1-NED", class = "WARRIOR", level = 25, faction = "Alliance" }
Mock.combat = true
Mock.Fire("GROUP_ROSTER_UPDATE")
Mock.Advance(3)
check(not reunion:IsShown(), "not in a fight")
Mock.combat = false
Mock.Fire("PLAYER_REGEN_ENABLED")
check(reunion:IsShown() and Says(reunion, "4 of House Ashbrook"), "after the fight: four of the house")
Mock.Tick(60, 0.25)
-- off in the settings: none
HeyCousinDB.reunion = false
Mock.units.party3 = { name = "Ola", surname = "Ashbrook", guid = "Player-1-OLA", class = "HUNTER", level = 25, faction = "Alliance" }
Mock.Fire("GROUP_ROSTER_UPDATE")
Mock.Advance(3)
check(not reunion:IsShown(), "switched off: no banner")
HeyCousinDB.reunion = true
-- the group ends: the next one is news again
for i = 1, 4 do Mock.units["party" .. i] = nil end
Mock.inGroup = false
Mock.Fire("GROUP_ROSTER_UPDATE")
Mock.Advance(3)
-- the preview
SlashCmdList.HEYCOUSIN("test reunion")
check(reunion:IsShown() and Says(reunion, "Preview: a reunion shows like this"), "/cousin test reunion shows one")
HC.Theme.SetSkin("smooth")
check(not reunion:IsShown(), "a new look: the next one is built in it")
SlashCmdList.HEYCOUSIN("test reunion")
check(_G.HeyCousinReunion:IsShown(), "and shows in it")
HC.Theme.SetSkin("pixel")
NoErrors(HC, "family reunion")

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

check(not Mock.fontAfterText, "no words change their font after they're set: Cyrillic shows as boxes in the game")

print(fails == 0 and ("addon checks passed (" .. checks .. " checks)") or (fails .. " addon checks failed"))
