local _, HC = ...

-- What your nameplates really look like, for the settings' samples. No addon can ask another to draw a
-- plate for nobody, so this reads a real plate while one is on screen: whatever addon drew it, the
-- bars, borders and words hanging on the game's plate frame, and where they are from that frame's
-- center, the point your crest is placed from. Only players' plates, since crests only go on players:
-- a friendly player's and an enemy player's, kept apart, since addons draw them differently (often a
-- friendly player is only a name). Saved, so the page shows them when nobody's around. It only ever
-- reads other addons' frames. The game won't let an addon measure a restricted part of a plate ("Can't
-- measure restricted regions"), so such a part is placed by how it's anchored: its font, words and color
-- can still be read. A plate whose bar can't be placed isn't kept: half a plate is worse than a plain one.
-- Names aren't kept: a sample shows its own, and of the other words only numbers (a level, a percent).
-- Often the game keeps a plate's words secret: their font and place still count, and the biggest is
-- taken for the name. A color that's the copied player's class is marked, so a sample can show its own.
HC.PlateLook = {}

local PlateLook = HC.PlateLook
local Utils = HC.Utils
local Theme = HC.Theme
local Names = HC.Names

local MOST_PIECES, MOST_DEPTH, MOST_PLATES = 80, 8, 40
-- a plate's own addon has drawn it by then
local WAIT = 0.5
-- plates seen per session, per kind, before giving up: this addon can't read them
local MOST_TRIES = 5
-- what isn't part of the plate's look: a timer's sweep, a 3D model
local SKIP_KINDS = { Cooldown = true, Model = true, PlayerModel = true }

local tries, done, waiting = {}, {}, {}
local listeners = {}
-- while /cousin plates asks: what was read, what was left out and why
local trace
-- bars on the plate being read that couldn't be placed
local unplaced = 0
-- the class color of the player on the plate being read
local theirColor

local function Why(reason)
    if trace then
        trace.why[reason] = (trace.why[reason] or 0) + 1
    end
end

-- One piece, read; one that fails is left out, and /cousin plates says what the game answered.
local function Try(fn, ...)
    local ok, piece = pcall(fn, ...)
    if not ok then
        if trace then
            trace.errors = trace.errors + 1
            trace.lastError = tostring(piece)
        end
        return nil
    end
    return piece
end

local function Saved()
    if type(HeyCousinDB.plateLook) ~= "table" then
        HeyCousinDB.plateLook = {}
    end
    return HeyCousinDB.plateLook
end

-- The look saved for "friend" or "enemy", or nothing.
function PlateLook.Get(kind)
    local look = Saved()[kind]
    return type(look) == "table" and look.player == true and type(look.pieces) == "table" and look or nil
end

-- A new look copied: `fn` runs.
function PlateLook.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function Usable(...)
    for index = 1, select("#", ...) do
        if not Utils.IsUsableNumber((select(index, ...))) then
            return false
        end
    end
    return true
end

-- Whether the game forbids measuring a region. (A secret answer counts as yes.)
local function Restricted(region)
    if not region.IsAnchoringRestricted then
        return false
    end
    local ok, restricted = pcall(region.IsAnchoringRestricted, region)
    return not ok or Utils.IsSecret(restricted) or restricted == true
end

-- Where a region is, measured, from the plate's center and in the plate's own points. Nothing if it's
-- not on screen, or the game won't say.
local function Measured(region, plate)
    local x, y = region:GetCenter()
    local width, height = region:GetWidth(), region:GetHeight()
    local scale = region:GetEffectiveScale()
    local plateX, plateY = plate:GetCenter()
    local plateScale = plate:GetEffectiveScale()
    if not Usable(x, y, width, height, scale, plateX, plateY, plateScale) or plateScale <= 0 then
        return
    end
    return (x * scale - plateX * plateScale) / plateScale, (y * scale - plateY * plateScale) / plateScale,
        width * scale / plateScale, height * scale / plateScale
end

-- Where a region is by its anchors, added up to the plate: close, not exact, since what a point means
-- depends on sizes nobody can measure. Nothing if the chain doesn't reach the plate, or the game won't say.
local function Anchored(region, plate)
    local x, y, at = 0, 0, region
    for _ = 1, MOST_DEPTH do
        local ok, _, to, _, offX, offY = pcall(at.GetPoint, at, 1)
        if not ok or not Usable(offX, offY) or Utils.IsSecret(to) then
            return
        end
        x, y = x + offX, y + offY
        to = to or at:GetParent()
        if to == plate then
            return x, y
        elseif not to then
            return
        end
        at = to
    end
end

local function Length(region, method)
    local ok, value = pcall(region[method], region)
    return ok and Utils.IsUsableNumber(value) and value or nil
end

-- Where a region is: x and y from the plate's center, its width and height. Measured when the game
-- allows it, otherwise whatever its anchors and size can tell; any of them can be nothing.
local function Box(region, plate)
    if not Restricted(region) and not Restricted(plate) then
        local ok, x, y, width, height = pcall(Measured, region, plate)
        if ok and x then
            return x, y, width, height
        end
    end
    Why("restricted")
    local x, y = Anchored(region, plate)
    return x, y, Length(region, "GetWidth"), Length(region, "GetHeight")
end

-- How solid a region is on screen. Only frames can say: text and textures are their own alpha times
-- their frame's.
local function Solidity(region)
    if region.GetEffectiveAlpha then
        return region:GetEffectiveAlpha()
    end
    local own, frame = region:GetAlpha(), region:GetParent():GetEffectiveAlpha()
    return Usable(own, frame) and own * frame or nil
end

-- Whether a region shows, and how solid. (An alpha the game keeps secret, a fade by distance: it shows.)
local function Seen(region)
    if not region:IsVisible() then
        return false
    end
    local alpha = Solidity(region)
    if not Utils.IsUsableNumber(alpha) then
        return true, 1
    end
    return alpha > 0.01, alpha
end

-- Whether a color is the copied player's class color.
local function ByClass(r, g, b)
    if not theirColor then
        return nil
    end
    local near = math.abs(r - theirColor[1]) < 0.02 and math.abs(g - theirColor[2]) < 0.02 and math.abs(b - theirColor[3]) < 0.02
    return near or nil
end

-- A plain color (SetColorTexture) can't be read back, so it's left out: painting it would come out white.
local function Art(texture)
    local atlas = texture:GetAtlas()
    if Utils.IsUsableString(atlas) then
        return nil, atlas
    end
    local file = texture:GetTexture()
    if Utils.IsUsableNumber(file) or (Utils.IsUsableString(file) and not file:find("^Color%-")) then
        return file
    end
end

local function ReadTexture(texture, plate, level)
    local shown, alpha = Seen(texture)
    if not shown then
        return Why("hidden")
    end
    local file, atlas = Art(texture)
    if not file and not atlas then
        return Why("plain color")
    end
    local x, y, width, height = Box(texture, plate)
    if not x or not width or not height or width <= 0 or height <= 0 then
        return Why("no place")
    end
    local coords = { texture:GetTexCoord() }
    local r, g, b, a = texture:GetVertexColor()
    if not Usable(r, g, b) or not Usable(unpack(coords)) then
        return Why("secret color")
    end
    local layer, sublevel = texture:GetDrawLayer()
    return { x = x, y = y, w = width, h = height, file = file, atlas = atlas, coords = coords, r = r, g = g, b = b,
        a = (Utils.IsUsableNumber(a) and a or 1) * alpha, layer = layer, sublevel = sublevel,
        blend = texture:GetBlendMode(), level = level }
end

-- A bar, as its frame and its color: how full it is doesn't matter (it may be secret, too).
local function ReadBar(bar, plate, level)
    local fill = bar:GetStatusBarTexture()
    local shown, alpha = Seen(bar)
    if not fill or not shown or not Seen(fill) then
        return Why("hidden")
    end
    local file, atlas = Art(fill)
    if not file and not atlas then
        return Why("plain color")
    end
    local x, y, width, height = Box(bar, plate)
    if not x or not width or not height or width <= 0 or height <= 0 then
        unplaced = unplaced + 1
        return Why("no place")
    end
    local r, g, b, a = Utils.Call(bar.GetStatusBarColor, bar)
    if not Usable(r, g, b) then
        r, g, b, a = fill:GetVertexColor()
    end
    if not Usable(r, g, b) then
        return Why("secret color")
    end
    local value = bar:GetValue()
    local least, most = bar:GetMinMaxValues()
    local share = Usable(value, least, most) and most > least and (value - least) / (most - least) or nil
    return { x = x, y = y, w = width, h = height, file = file, atlas = atlas, coords = { fill:GetTexCoord() }, r = r, g = g,
        b = b, a = (Utils.IsUsableNumber(a) and a or 1) * alpha, layer = "ARTWORK", sublevel = 0,
        level = level, bar = true, share = share, byClass = ByClass(r, g, b) }
end

local function ReadText(text, plate, level, first)
    local shown, alpha = Seen(text)
    if not shown then
        return Why("hidden")
    end
    local words = text:GetText()
    local secret = Utils.IsSecret(words)
    if not secret and not Utils.IsUsableString(words) then
        return Why("no words")
    end
    local plain = not secret and words:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or nil
    local isName = plain ~= nil and first ~= nil and plain:find(first, 1, true) ~= nil
    if plain and not isName and not plain:match("^[%d%s%.,%%/%+%-%?kKmM]+$") then
        return Why("other words")
    end
    -- (words show even if nobody can say where: they go in the middle)
    local x, y, width, height = Box(text, plate)
    local font, size, flags = Utils.Call(text.GetFont, text)
    local r, g, b, a = Utils.Call(text.GetTextColor, text)
    if not Usable(r, g, b) then
        r, g, b, a = 1, 1, 1, 1
    end
    local shadowX, shadowY = Utils.Call(text.GetShadowOffset, text)
    local shadowR, shadowG, shadowB, shadowA = Utils.Call(text.GetShadowColor, text)
    return { x = x or 0, y = y or 0, w = width or 0, h = height or 0, text = true, name = isName or nil,
        guess = secret or nil, byClass = ByClass(r, g, b), words = not isName and plain or nil, font = Utils.IsUsableString(font) and font or nil,
        size = Utils.IsUsableNumber(size) and size or nil, flags = Utils.IsUsableString(flags) and flags or nil,
        r = r, g = g, b = b, a = (Utils.IsUsableNumber(a) and a or 1) * alpha,
        layer = (Utils.Call(text.GetDrawLayer, text)), justify = (Utils.Call(text.GetJustifyH, text)),
        shadowX = Utils.IsUsableNumber(shadowX) and shadowX or nil, shadowY = Utils.IsUsableNumber(shadowY) and shadowY or nil,
        shadow = Usable(shadowR, shadowG, shadowB) and { shadowR, shadowG, shadowB, Utils.IsUsableNumber(shadowA) and shadowA or 1 } or nil,
        level = level }
end

-- Every piece under `frame`. A part that can't be read is left out, and the rest still counts.
local function Walk(frame, plate, skip, depth, first, pieces)
    if depth > MOST_DEPTH or #pieces >= MOST_PIECES or Utils.Call(frame.IsForbidden, frame) == true then
        return
    end
    if trace then
        trace.frames = trace.frames + 1
    end
    local level = Utils.Call(frame.GetFrameLevel, frame) or 0
    local kind = Utils.Call(frame.GetObjectType, frame)
    local fill
    if kind == "StatusBar" then
        fill = Utils.Call(frame.GetStatusBarTexture, frame)
        pieces[#pieces + 1] = Try(ReadBar, frame, plate, level)
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region ~= fill and #pieces < MOST_PIECES then
            local what = Utils.Call(region.GetObjectType, region)
            if what == "Texture" then
                pieces[#pieces + 1] = Try(ReadTexture, region, plate, level)
            elseif what == "FontString" then
                pieces[#pieces + 1] = Try(ReadText, region, plate, level, first)
            end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child ~= skip and Utils.Call(child.IsVisible, child) == true
            and not SKIP_KINDS[Utils.Call(child.GetObjectType, child) or ""] then
            Walk(child, plate, skip, depth + 1, first, pieces)
        end
    end
end

-- The biggest bar is the plate's own: drawn full. A smaller one shows as full as it is, or not at all
-- when nobody can tell (a shield's, an empty cast's).
local function SettleBars(pieces)
    local main
    for _, piece in ipairs(pieces) do
        if piece.bar and (not main or piece.w * piece.h > main.w * main.h) then
            main = piece
        end
    end
    for index = #pieces, 1, -1 do
        local piece = pieces[index]
        if piece.bar and piece ~= main then
            if piece.share and piece.share > 0 then
                local cut = piece.w * (1 - piece.share)
                piece.x, piece.w = piece.x - cut / 2, piece.w - cut
            else
                table.remove(pieces, index)
            end
        end
        piece.share = nil
    end
end

-- Words the game keeps secret: with no name read, the biggest is the name. The rest can't be shown.
local function SettleNames(pieces)
    local best
    local named = false
    for _, piece in ipairs(pieces) do
        named = named or piece.name == true
        if piece.guess and (not best or (piece.size or 0) > (best.size or 0)) then
            best = piece
        end
    end
    if best and not named then
        best.name = true
    end
    for index = #pieces, 1, -1 do
        local piece = pieces[index]
        if piece.guess and not piece.name then
            table.remove(pieces, index)
        end
        piece.guess = nil
    end
end

-- "friend" or "enemy", and whether it's a player; nothing for you, or a unit the game hides.
local function KindOf(unit)
    if Utils.Call(UnitExists, unit) ~= true or Utils.Call(UnitIsUnit, unit, "player") == true or Utils.UnitHidden(unit) then
        return
    end
    return Utils.Call(UnitIsFriend, "player", unit) == true and "friend" or "enemy", Utils.Call(UnitIsPlayer, unit) == true
end

-- Whether this plate shows its everyday look: not in a fight or a dungeon (where the game hides what
-- it can), not your target's or the mouse's (those light up), and no cast bar on it.
local function Everyday(unit)
    if Utils.Call(InCombatLockdown) == true or Utils.Call(IsInInstance) == true then
        return false
    end
    return Utils.Call(UnitIsUnit, unit, "target") ~= true and Utils.Call(UnitIsUnit, unit, "mouseover") ~= true
        and not Utils.Call(UnitCastingInfo, unit) and not Utils.Call(UnitChannelInfo, unit)
end

-- What a plate's made of now, or nothing and why.
local function Read(unit)
    local plate = C_NamePlate and Utils.Call(C_NamePlate.GetNamePlateForUnit, unit)
    if not plate then
        return nil, "the game gives no plate frame"
    elseif Utils.Call(plate.IsForbidden, plate) == true then
        return nil, "the game keeps this plate to itself"
    end
    local first = Names.Unit(unit) or Utils.Call(UnitName, unit)
    local pieces = {}
    unplaced = 0
    local _, class = Utils.Call(UnitClass, unit)
    -- (raw: as the game has it, as a plate shows it)
    theirColor = Utils.IsUsableString(class) and Utils.ClassColor(class, true) or nil
    -- (a frame that won't answer ends the walk, not the page)
    local ok, problem = pcall(Walk, plate, plate, HC.Plates.CrestOn(unit), 1, first, pieces)
    if not ok and trace then
        trace.errors = trace.errors + 1
        trace.lastError = tostring(problem)
    end
    SettleBars(pieces)
    SettleNames(pieces)
    return pieces
end

local function Copy(unit, kind)
    if not Everyday(unit) then
        return false
    end
    local pieces = Read(unit)
    if not pieces or #pieces == 0 or unplaced > 0 then
        return false
    end
    Saved()[kind] = { player = true, pieces = pieces }
    return true
end

local function Told()
    for _, fn in ipairs(listeners) do
        fn()
    end
end

-- A plate came on screen. The first player's of each kind this session is copied, a moment later, once
-- its addon has drawn it.
function PlateLook.Seen(unit)
    local kind, player = KindOf(unit)
    if not kind or not player or done[kind] or waiting[kind] or (tries[kind] or 0) >= MOST_TRIES then
        return
    end
    waiting[kind] = true
    tries[kind] = (tries[kind] or 0) + 1
    local guid = Utils.Call(UnitGUID, unit)
    Utils.After(WAIT, "nameplate look", function()
        waiting[kind] = nil
        -- (the same plate's token can belong to someone else by now; a GUID the game keeps secret can't tell)
        local now = Utils.Call(UnitGUID, unit)
        local nowKind, nowPlayer = KindOf(unit)
        if nowKind == kind and nowPlayer and (not guid or not now or now == guid) and Copy(unit, kind) then
            done[kind] = true
            Told()
        end
    end)
end

-- Every player's plate on screen, now: the page has just opened, and you may have changed your
-- nameplate addon.
function PlateLook.Scan()
    local copied = {}
    for index = 1, MOST_PLATES do
        local unit = "nameplate" .. index
        local kind, player = KindOf(unit)
        if kind and player and not copied[kind] and Copy(unit, kind) then
            copied[kind] = true
            done[kind] = true
        end
    end
end

-- /cousin plates: what the addon sees on the plates around you, and why it copies them or not. English
-- only: it's for reading out when something is wrong. No names.
function PlateLook.Check()
    local function Setting(name)
        return tostring(Utils.Call(GetCVar, name))
    end
    Utils.Print("Plates: friendly players " .. Setting("nameplateShowFriendlyPlayers")
        .. ", only names " .. Setting("nameplateShowOnlyNameForFriendlyPlayerUnits")
        .. ", class-colored names " .. Setting("nameplateUseClassColorForFriendlyPlayerUnitNames")
        .. ", enemies " .. Setting("nameplateShowEnemies"))
    local shown = 0
    for index = 1, MOST_PLATES do
        local unit = "nameplate" .. index
        local kind, player = KindOf(unit)
        if Utils.Call(UnitExists, unit) == true and shown < 8 then
            shown = shown + 1
            trace = { frames = 0, why = {}, errors = 0 }
            local pieces, problem
            if kind then
                pieces, problem = Read(unit)
            end
            local bars, texts, art = 0, 0, 0
            for _, piece in ipairs(pieces or {}) do
                if piece.bar then
                    bars = bars + 1
                elseif piece.text then
                    texts = texts + 1
                else
                    art = art + 1
                end
            end
            local left = {}
            for reason, count in pairs(trace.why) do
                left[#left + 1] = reason .. " " .. count
            end
            table.sort(left)
            Utils.Print(string.format("  %s: %s, %s, everyday %s. %d frames: kept %d bars, %d art, %d words%s%s%s",
                unit, kind or "hidden from addons", player and "player" or "not a player", tostring(kind ~= nil and Everyday(unit)),
                trace.frames, bars, art, texts, #left > 0 and ". Left out: " .. table.concat(left, ", ") or "",
                problem and ". " .. problem or "",
                trace.errors > 0 and ". Errors " .. trace.errors .. ": " .. tostring(trace.lastError) or ""))
            trace = nil
        end
    end
    if shown == 0 then
        Utils.Print("Plates: none on screen right now.")
    end
    PlateLook.Scan()
    for _, kind in ipairs({ "friend", "enemy" }) do
        local look = PlateLook.Get(kind)
        Utils.Print("Plates: " .. kind .. " player look: " .. (look and (#look.pieces .. " pieces copied") or "not copied yet"))
    end
    Told()
end

-- --- drawing it ----------------------------------------------------------------------------------

local function PaintTexture(texture, piece, holder, classColor)
    if piece.atlas then
        texture:SetAtlas(piece.atlas)
    else
        texture:SetTexture(piece.file)
        if piece.coords and #piece.coords == 8 then
            texture:SetTexCoord(unpack(piece.coords))
        end
    end
    texture:SetDrawLayer(piece.layer or "ARTWORK", piece.sublevel or 0)
    texture:SetBlendMode(piece.blend or "BLEND")
    local tint = piece.byClass and classColor or { piece.r, piece.g, piece.b }
    texture:SetVertexColor(tint[1], tint[2], tint[3], piece.a or 1)
    texture:SetSize(piece.w, piece.h)
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", holder, "CENTER", piece.x, piece.y)
    texture:Show()
end

-- (the font first, on no words: letters set before a change of font can turn to boxes)
local function PaintText(text, piece, holder, name, nameColor, classColor)
    text:SetText("")
    if piece.font and piece.size and piece.size > 0 then
        pcall(text.SetFont, text, piece.font, piece.size, piece.flags or "")
    end
    text:SetDrawLayer(piece.layer or "OVERLAY")
    local tint = piece.name and nameColor or piece.byClass and classColor or { piece.r, piece.g, piece.b }
    text:SetTextColor(tint[1], tint[2], tint[3], piece.a or 1)
    if piece.shadowX and piece.shadowY then
        text:SetShadowOffset(piece.shadowX, piece.shadowY)
    end
    if piece.shadow then
        text:SetShadowColor(piece.shadow[1], piece.shadow[2], piece.shadow[3], piece.shadow[4])
    end
    -- a different name is longer or shorter: it grows from where the plate's own starts
    local justify = piece.justify
    text:ClearAllPoints()
    text:SetJustifyH(justify == "LEFT" and "LEFT" or justify == "RIGHT" and "RIGHT" or "CENTER")
    if justify == "LEFT" then
        text:SetPoint("LEFT", holder, "CENTER", piece.x - piece.w / 2, piece.y)
    elseif justify == "RIGHT" then
        text:SetPoint("RIGHT", holder, "CENTER", piece.x + piece.w / 2, piece.y)
    else
        text:SetPoint("CENTER", holder, "CENTER", piece.x, piece.y)
    end
    text:SetText(piece.name and name or piece.words or "")
    text:Show()
end

local function LevelOf(piece)
    return type(piece) == "table" and type(piece.level) == "number" and piece.level or 0
end

-- Draws a copied look on `holder`, with `name` for the name on it. `nameColor` and `classColor`, if given,
-- replace the copied player's: the sample isn't them. One frame per level, as on the plate, so what lay on
-- top still does; drawn again, it reuses what it made.
function PlateLook.Draw(holder, look, name, nameColor, classColor)
    holder.layers = holder.layers or {}
    for _, layer in ipairs(holder.layers) do
        for _, region in ipairs(layer.textures) do
            region:Hide()
        end
        for _, region in ipairs(layer.texts) do
            region:Hide()
        end
        layer.usedTextures, layer.usedTexts = 0, 0
    end
    local ranks, levels = {}, {}
    for _, piece in ipairs(look.pieces) do
        local level = LevelOf(piece)
        if not ranks[level] then
            ranks[level] = true
            levels[#levels + 1] = level
        end
    end
    table.sort(levels)
    for rank, level in ipairs(levels) do
        ranks[level] = rank
        if not holder.layers[rank] then
            local layer = CreateFrame("Frame", nil, holder)
            layer:SetAllPoints(holder)
            layer:SetFrameLevel(holder:GetFrameLevel() + rank)
            layer.textures, layer.texts, layer.usedTextures, layer.usedTexts = {}, {}, 0, 0
            holder.layers[rank] = layer
        end
    end
    for _, piece in ipairs(look.pieces) do
        if type(piece) == "table" then
            local layer = holder.layers[ranks[LevelOf(piece)]]
            if piece.text then
                layer.usedTexts = layer.usedTexts + 1
                local text = layer.texts[layer.usedTexts]
                if not text then
                    text = Theme.Text(layer, "Body")
                    layer.texts[layer.usedTexts] = text
                end
                -- (a broken saved piece is one piece less)
                pcall(PaintText, text, piece, holder, name, nameColor, classColor)
            else
                layer.usedTextures = layer.usedTextures + 1
                local texture = layer.textures[layer.usedTextures]
                if not texture then
                    texture = layer:CreateTexture(nil, "ARTWORK")
                    layer.textures[layer.usedTextures] = texture
                end
                pcall(PaintTexture, texture, piece, holder, classColor)
            end
        end
    end
end
