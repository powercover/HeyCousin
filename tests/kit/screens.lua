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

-- the shown button whose label reads `text`, under `root` (as the smoke test finds them)
local function ButtonWith(root, text)
    for _, child in ipairs(root.children or {}) do
        if child.label and child.label.text == text and child:IsVisible() then
            return child
        end
        local found = ButtonWith(child, text)
        if found then
            return found
        end
    end
end

local function Boot(skin, client, saved)
    saved = saved or {}
    saved.skin, saved.setupDone = skin, true
    local HC = Mock.Boot(client or "retail", saved)
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
    return { frames = { HeyCousinWindow } }
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
    return { frames = { HeyCousinWindow } }
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

-- the alerts step, reached with Next (the crest step has its check), with one setting changed (so
-- Reset is on)
function Screens.alerts(skin)
    local HC = Boot(skin)
    HC.Setup.Show(1)
    ButtonWith(HeyCousinSetup, "Next"):Click()
    ButtonWith(HeyCousinSetup, "Black sheep too"):Click()
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
