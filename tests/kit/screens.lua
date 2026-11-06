-- The scenes screens.py draws. Each boots the addon on the mock game (mock_wow.lua) in one theme
-- and opens one screen as a player would. It returns what to draw: `frames`, the addon's frames
-- the picture is cut around (or the whole screen with `full`), and the game's own parts around
-- them, which screens.py draws as plain stand-ins: the `minimap`, `chat` lines and the `tooltip`
-- (GameTooltip's lines).
Screens = {}

-- the game's class colors; the class icon sheet is screens.py's own, a class in each quarter
Screens.CLASS_COLORS = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
    ROGUE = { 1, 0.96, 0.41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.25, 0.78, 0.92 },
    WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1, 0.49, 0.04 },
}
Screens.CLASS_CELLS = {
    WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.5, 0, 0.25 }, ROGUE = { 0.5, 0.75, 0, 0.25 },
    DRUID = { 0.75, 1, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.5, 0.25, 0.5 },
    PRIEST = { 0.5, 0.75, 0.25, 0.5 }, WARLOCK = { 0.75, 1, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 },
}

-- screens.py asks what each object is (its class in the mock)
function Screens.Kind(object)
    local meta = getmetatable(object)
    for name, class in pairs(Mock.classes) do
        if meta == class then
            return name
        end
    end
end

-- the shown button whose label reads `text` (English, or its translation: screens.py --lang),
-- under `root` (as the smoke test finds them)
local function ButtonWith(root, text)
    local translated = Screens.HC and Screens.HC.L[text] or text
    for _, child in ipairs(root.children or {}) do
        if child.label and (child.label.text == text or child.label.text == translated) and child:IsVisible() then
            return child
        end
        local found = ButtonWith(child, text)
        if found then
            return found
        end
    end
end

local function Boot(skin, client, saved, player)
    saved = saved or {}
    -- (screens.py --lang: the addon speaks that language)
    saved.skin, saved.setupDone, saved.language = skin, true, Screens.LANGUAGE
    local HC = Mock.Boot(client or "retail", saved, player)
    for class, color in pairs(Screens.CLASS_COLORS) do
        RAID_CLASS_COLORS[class] = { r = color[1], g = color[2], b = color[3] }
        CLASS_ICON_TCOORDS[class] = Screens.CLASS_CELLS[class]
    end
    Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -26, -38)
    Screens.HC = HC
    return HC
end

-- the family window
function Screens.family(skin)
    local HC = Boot(skin)
    HC.Window.Show("family")
    -- (this and the next ones are the store page's pictures: Listing/make_shots.py)
    HeyCousinWindow.badge:Hide()
    return { frames = { HeyCousinWindow } }
end

-- Find my family, clicked: the cousins online on top, one never met
function Screens.found(skin)
    local HC = Boot(skin)
    HC.Window.Show("family")
    HeyCousinWindow.find:Click()
    Mock.Advance(2)
    HeyCousinWindow.badge:Hide()
    return { frames = { HeyCousinWindow } }
end

-- the cousin it found: never met, with their guild and what you can do
function Screens.foundpage(skin)
    local HC = Boot(skin)
    HC.Window.Show("family")
    HeyCousinWindow.find:Click()
    Mock.Advance(2)
    HC.Window.Open("Perrin")
    HeyCousinWindow.badge:Hide()
    return { frames = { HeyCousinWindow } }
end

-- Recruit: the cousins Find my family found with no guild
function Screens.recruit(skin)
    local HC = Boot(skin)
    HC.Window.Show("family")
    HeyCousinWindow.find:Click()
    Mock.Advance(2)
    HC.Window.Recruit(true)
    HeyCousinWindow.badge:Hide()
    return { frames = { HeyCousinWindow } }
end

-- Groups: made-up cousins looking for a group, and your own post
function Screens.groups(skin)
    local HC = Boot(skin)
    HC.Window.Show("groups")
    HC.Groups.Post("Need one more for Wailing Caverns")
    HeyCousinWindow.badge:Hide()
    return { frames = { HeyCousinWindow } }
end

-- Look up a family: a made-up house, online now
function Screens.lookup(skin)
    local HC = Boot(skin)
    HC.Lookup.Show("Stormwind")
    Mock.Advance(2)
    return { frames = { HeyCousinLookup } }
end

-- The family race: a family that has all taken the addon
function Screens.race(skin)
    local HC = Boot(skin)
    for _, relative in pairs(HC.TestMode.House().relatives) do
        relative.usesAddon = true
    end
    HC.Window.Show("stats")
    HC.Window.Race(true)
    HeyCousinWindow.badge:Hide()
    return { frames = { HeyCousinWindow } }
end

-- The family portrait
function Screens.portrait(skin)
    local HC = Boot(skin)
    HC.Portrait.Show()
    return { frames = { HeyCousinPortrait } }
end

-- a pop-up as a player sees it, for the store page: Forever, a cousin near you
function Screens.heypop(skin)
    local HC = Boot(skin, "forever", { houses = { Ashbrook = {} } })
    local relative = { class = "MAGE", race = "Gnome", level = 23, sex = 3, faction = "Alliance", met = 1 }
    HC.Kin.House().relatives.Mira = relative
    HC.Alert.Show({ first = "Mira", relative = relative, new = false })
    return { frames = { HeyCousinAlert } }
end

-- Mira's page: every meeting, the one before the last in full
function Screens.cousin(skin)
    local HC = Boot(skin)
    HC.Window.Show("family")
    HC.Window.Open("Mira")
    local rows = {}
    local function Walk(frame)
        if frame.item and frame.item.meeting and frame:IsVisible() then
            rows[#rows + 1] = frame
        end
        for _, child in ipairs(frame.children or {}) do
            Walk(child)
        end
    end
    Walk(HeyCousinWindow)
    table.sort(rows, function(a, b) return a.item.meeting.at > b.item.meeting.at end)
    if rows[2] then
        rows[2]:Click()
    end
    HeyCousinWindow.badge:Hide()
    return { frames = { HeyCousinWindow } }
end

-- the Tree tab: the made-up guild you lead, by generation, with Mira's card
function Screens.tree(skin)
    local HC = Boot(skin)
    HC.Window.Show("tree")
    local function Walk(frame)
        if frame.member and frame.SetChosen and frame.member.first == "Mira" and frame:IsVisible() then
            return frame
        end
        for _, child in ipairs(frame.children or {}) do
            local found = Walk(child)
            if found then
                return found
            end
        end
    end
    local mira = Walk(HeyCousinWindow)
    if mira then
        mira:Click()
    end
    HeyCousinWindow.badge:Hide()
    return { frames = { HeyCousinWindow } }
end

-- WoW Forever, before you're in a guild: the tree says how it grows
function Screens.treeless(skin)
    local HC = Boot(skin, "forever")
    HC.Window.Show("tree")
    return { frames = { HeyCousinWindow } }
end

-- The family map in test mode: the made-up cousins online around you, on a bit of map that
-- stands in for the game's (fields, woods, a lake, a road, names, and you).
function Screens.map(skin)
    Boot(skin)
    local map = WorldMapFrame
    map:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    local canvas = map:GetCanvas()
    local function Patch(parent, color, x, y, w, h, sublevel)
        local patch = parent:CreateTexture(nil, "BACKGROUND", nil, sublevel or 0)
        patch:SetTexture("Interface\\Buttons\\WHITE8X8")
        patch:SetVertexColor(color[1], color[2], color[3])
        patch:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
        patch:SetSize(w, h)
    end
    Patch(map, { 0.16, 0.12, 0.09 }, -6, -6, 714, 480, -1)
    Patch(canvas, { 0.42, 0.49, 0.29 }, 0, 0, 702, 468)
    for _, wood in ipairs({ { 20, 30, 190, 120 }, { 470, 60, 200, 150 }, { 60, 330, 160, 110 }, { 520, 300, 150, 140 } }) do
        Patch(canvas, { 0.27, 0.36, 0.2 }, wood[1], wood[2], wood[3], wood[4], 1)
    end
    Patch(canvas, { 0.27, 0.43, 0.56 }, 360, 360, 120, 70, 1)
    Patch(canvas, { 0.62, 0.53, 0.36 }, 0, 300, 702, 6, 2)
    Patch(canvas, { 0.62, 0.53, 0.36 }, 292, 0, 6, 468, 2)
    local function Name(text, x, y, font)
        local label = canvas:CreateFontString(nil, "ARTWORK")
        label:SetFontObject(Screens.HC.Theme.Font(font or "Small"))
        label:SetTextColor(0.98, 0.9, 0.7)
        label:SetPoint("TOP", canvas, "TOPLEFT", x, -y)
        label:SetText(text)
    end
    Name("Elwynn Forest", 351, 14, "Headline")
    Name("Goldshire", 300, 418)
    -- you: a gold dot where you stand
    Patch(canvas, { 1, 0.82, 0.2 }, 0.421 * 702 - 4, 0.653 * 468 - 4, 8, 8, 3)
    Mock.ShowMap(1429)
    return { frames = { map } }
end

-- the settings, each page
local function SettingsPage(skin, page)
    local HC = Boot(skin)
    HC.Options.Show(page)
    return { frames = { HeyCousinOptions } }
end
for _, page in ipairs({ "alerts", "family", "map", "plates", "game", "look", "about" }) do
    Screens["settings" .. page] = function(skin)
        return SettingsPage(skin, page)
    end
end

-- the nameplate page as a player sees it once their plates are copied: a made-up addon's look
local function MadeUpLook(setup, r, g, b)
    local white = "Interface\\Buttons\\WHITE8X8"
    local coords = { 0, 0, 0, 1, 1, 0, 1, 1 }
    local font = "Fonts\\FRIZQT__.TTF"
    return { player = true, setup = setup, pieces = {
        { x = 0, y = -4, w = 134, h = 12, file = white, coords = coords, r = 0, g = 0, b = 0, a = 1, layer = "BACKGROUND", sublevel = 0, level = 1 },
        { x = 0, y = -4, w = 132, h = 10, file = white, coords = coords, r = r, g = g, b = b, a = 1, layer = "ARTWORK", sublevel = 0, level = 2, bar = true },
        { x = 0, y = 9, w = 120, h = 12, text = true, name = true, font = font, size = 11, flags = "OUTLINE", r = 1, g = 1, b = 1, a = 1, layer = "OVERLAY", level = 3, justify = "CENTER" },
        { x = -54, y = -4, w = 20, h = 10, text = true, words = "23", font = font, size = 8, flags = "OUTLINE", r = 1, g = 1, b = 1, a = 1, layer = "OVERLAY", level = 3, justify = "CENTER" },
        { x = 50, y = -4, w = 30, h = 10, text = true, words = "100%", font = font, size = 8, flags = "OUTLINE", r = 1, g = 1, b = 1, a = 1, layer = "OVERLAY", level = 3, justify = "CENTER" },
    } }
end

function Screens.settingsplates(skin)
    local HC = Boot(skin)
    local setup = HC.PlateLook.Setup()
    HeyCousinDB.plateLook = { friend = MadeUpLook(setup, 0.2, 0.55, 0.85), enemy = MadeUpLook(setup, 0.62, 0.1, 0.1) }
    HC.Options.Show("plates")
    return { frames = { HeyCousinOptions } }
end

-- the settings' own pages: your crest with a picker open, and a guild master's words
function Screens.settingscrest(skin)
    local HC = Boot(skin)
    HC.Options.Show("crest")
    ButtonWith(HeyCousinOptions, "Symbol"):Click()
    return { frames = { HeyCousinOptions } }
end

function Screens.guild(skin)
    local HC = Boot(skin)
    HC.Options.Show("guild")
    return { frames = { HeyCousinOptions } }
end

function Screens.stats(skin)
    local HC = Boot(skin)
    HC.Window.Show("stats")
    return { frames = { HeyCousinWindow } }
end

-- WoW Forever, before you met anyone
function Screens.empty(skin)
    local HC = Boot(skin, "forever")
    HC.Window.Show("family")
    return { frames = { HeyCousinWindow } }
end

-- the crest page, with the main color's swatches open
function Screens.crest(skin)
    local HC = Boot(skin)
    HC.Setup.Show(1)
    ButtonWith(HeyCousinSetup, "Main"):Click()
    return { frames = { HeyCousinSetup } }
end

-- the family step, reached with Next (the crest step has its check), with one setting changed (so
-- Reset is on)
function Screens.familystep(skin)
    local HC = Boot(skin)
    HC.Setup.Show(1)
    ButtonWith(HeyCousinSetup, "Next"):Click()
    ButtonWith(HeyCousinSetup, "Share it with your family"):Click()
    return { frames = { HeyCousinSetup } }
end

-- a pop-up for a made-up cousin, as /cousin test shows them
local function Pop(skin, first, new)
    local HC = Boot(skin)
    HC.Kin.MarkNear(first)
    HC.Alert.Show({ first = first, relative = HC.TestMode.House().relatives[first], new = new, unit = "player", test = true })
    return { frames = { HeyCousinAlert } }
end

function Screens.near(skin) return Pop(skin, "Mira", false) end
function Screens.new(skin) return Pop(skin, "Tamsin", true) end
function Screens.sheep(skin) return Pop(skin, "Bru", false) end

-- a black sheep who joined the Alliance (you're Horde): the longer faction name
function Screens.alliance(skin)
    local HC = Boot(skin, nil, nil, { name = "Rowan", class = "WARRIOR", race = "Orc", level = 20, sex = 2,
        faction = "Horde", guid = "Player-1-ME" })
    HC.Kin.MarkNear("Bru")
    HC.Alert.Show({ first = "Bru", relative = HC.TestMode.House().relatives.Bru, new = false, unit = "player", test = true })
    return { frames = { HeyCousinAlert } }
end

function Screens.ask(skin)
    local HC = Boot(skin)
    HC.Layer.ShowAsk("Elowen Ashbrook", true)
    return { frames = { HeyCousinAsk } }
end

function Screens.probe(skin)
    local HC = Boot(skin, "forever")
    HC.Probe.Start()
    return { frames = { HeyCousinProbe } }
end

-- every shape with every pattern, the 18 symbols, and the black sheep's red
function Screens.crests(skin)
    local HC = Boot(skin)
    local Crest = HC.Crest
    local COLUMNS, CELL, PAD = 7, 80, 24
    local board = CreateFrame("Frame", "HeyCousinScreensCrests", UIParent)
    board:SetSize(COLUMNS * CELL + PAD * 2, 7 * CELL + PAD * 2)
    board:SetPoint("CENTER")
    HC.Theme.Panel(board, "window")
    local fields = { "gules", "azure", "vert", "purpure", "sanguine", "teal", "tenne", "rose", "celeste", "sable" }
    local count = 0
    local function Place(crest, enemy, surname)
        local column, row = count % COLUMNS, math.floor(count / COLUMNS)
        count = count + 1
        local frame = Crest.Create(board, 64)
        frame:SetPoint("CENTER", board, "TOPLEFT", PAD + (column + 0.5) * CELL, -PAD - (row + 0.5) * CELL)
        frame:SetCrest(crest, surname or "Ashbrook", enemy)
    end
    for _, shape in ipairs(Crest.SHAPES) do
        for _, division in ipairs(Crest.DIVISIONS) do
            Place({ shape = shape, division = division, field = fields[count % #fields + 1],
                second = count % 2 == 0 and "or" or "argent", metal = count % 3 == 0 and "argent" or "or",
                symbol = "initial" })
        end
    end
    for index, charge in ipairs(Crest.CHARGES) do
        Place({ shape = Crest.SHAPES[index % #Crest.SHAPES + 1], division = "Plain", field = fields[index % #fields + 1],
            second = "or", metal = index % 2 == 0 and "argent" or "or", symbol = "charge", charge = charge })
    end
    Place({ shape = "Heater", division = "Plain", field = "teal", second = "or", metal = "or", symbol = "none" })
    Place({ shape = "Round", division = "Fess", field = "azure", second = "argent", metal = "or", symbol = "initial" },
        false, "Борис")
    Place(Crest.DEFAULT, true)
    return { frames = { board } }
end

-- In the world (Forever): Mira is near, under the mouse, and talking; the minimap button counts
-- the family.
function Screens.world(skin)
    local HC = Boot(skin, "forever", { houses = { Ashbrook = {} } })
    local house = HC.Kin.House()
    for first, relative in pairs(HC.TestMode.House().relatives) do
        house.relatives[first] = relative
    end
    HC.Minimap.Refresh()
    local players = {
        MIRA = { name = "Mira", surname = "Ashbrook", class = "MAGE", race = "Gnome", sex = 3 },
        THANE = { name = "Thane", surname = "Ashbrook", class = "WARRIOR", race = "Dwarf", sex = 2 },
        JORA = { name = "Jora", surname = "Fairwind", class = "PRIEST", race = "Human", sex = 3 },
    }
    for key, player in pairs(players) do
        Mock.players["Player-1-" .. key] = player
    end
    local chat = {}
    local function Line(event, text, key)
        local player = players[key]
        local filter = Mock.filters[event] and Mock.filters[event][1]
        local shown = text
        if filter then
            local _, changed = filter(nil, event, text, player.name .. " " .. player.surname, "", "", "", "", 0, 0, "",
                0, #chat + 1, "Player-1-" .. key)
            shown = changed or text
        end
        chat[#chat + 1] = { event = event, name = player.name .. " " .. player.surname, class = player.class,
            text = shown }
    end
    Line("CHAT_MSG_CHANNEL", "LFG Deadmines, need a healer!", "JORA")
    Line("CHAT_MSG_SAY", "Hey cousin! Want to quest together?", "MIRA")
    Line("CHAT_MSG_GUILD", "Family dinner in Goldshire at 8.", "THANE")
    Mock.units.mouseover = { name = "Mira", surname = "Ashbrook", guid = "Player-1-MIRA", class = "MAGE",
        race = "Gnome", level = 23, sex = 3, faction = "Alliance" }
    -- the game's own lines first, then the post-call adds the family's
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:AddLine("Mira Ashbrook", 1, 1, 1)
    GameTooltip:AddLine("Level 23 Gnome Mage (Player)", 1, 1, 1)
    GameTooltip:AddLine("Alliance", 1, 1, 1)
    GameTooltip.unit = "mouseover"
    Mock.postCalls[Enum.TooltipDataType.Unit](GameTooltip, {})
    HC.Kin.MarkNear("Mira")
    HC.Alert.Show({ first = "Mira", relative = house.relatives.Mira, new = false, unit = "mouseover" })
    return { frames = { HeyCousinAlert, Minimap }, full = true, minimap = true, chat = chat, tooltip = true }
end
