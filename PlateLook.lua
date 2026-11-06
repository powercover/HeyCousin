local _, HC = ...

-- What your nameplates really look like, for the settings' samples. No addon can ask another to draw a
-- plate for nobody, so this reads a real plate while one is on screen: whatever addon drew it, the
-- bars, borders and words hanging on the game's plate frame, and where they are from that frame's
-- center, the point your crest is placed from. A friendly player's and an enemy player's are kept
-- apart, since addons draw them differently, and a creature's stands in until a player's is seen.
-- Saved, so the page shows them when nobody's around. It only ever reads other addons' frames.
-- Names aren't kept: a sample shows its own, and of the other words only numbers (a level, a percent).
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

local function Saved()
    if type(HeyCousinDB.plateLook) ~= "table" then
        HeyCousinDB.plateLook = {}
    end
    return HeyCousinDB.plateLook
end

-- The look saved for "friend" or "enemy", or nothing.
function PlateLook.Get(kind)
    local look = Saved()[kind]
    return type(look) == "table" and type(look.pieces) == "table" and look or nil
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

-- Where a region is, from the plate's center and in the plate's own points. Nothing if it's not on
-- screen, or the game won't say.
local function Box(region, plate)
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

local function Seen(region)
    if not region:IsVisible() then
        return false
    end
    local alpha = region:GetEffectiveAlpha()
    return Utils.IsUsableNumber(alpha) and alpha > 0.01, alpha
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
        return
    end
    local file, atlas = Art(texture)
    local x, y, width, height = Box(texture, plate)
    if (not file and not atlas) or not x or width <= 0 or height <= 0 then
        return
    end
    local coords = { texture:GetTexCoord() }
    local r, g, b, a = texture:GetVertexColor()
    if not Usable(r, g, b) or not Usable(unpack(coords)) then
        return
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
        return
    end
    local file, atlas = Art(fill)
    local x, y, width, height = Box(bar, plate)
    if (not file and not atlas) or not x or width <= 0 or height <= 0 then
        return
    end
    local r, g, b, a = Utils.Call(bar.GetStatusBarColor, bar)
    if not Usable(r, g, b) then
        r, g, b, a = fill:GetVertexColor()
    end
    if not Usable(r, g, b) then
        return
    end
    local value = bar:GetValue()
    local least, most = bar:GetMinMaxValues()
    local share = Usable(value, least, most) and most > least and (value - least) / (most - least) or nil
    return { x = x, y = y, w = width, h = height, file = file, atlas = atlas, coords = { fill:GetTexCoord() }, r = r, g = g,
        b = b, a = (Utils.IsUsableNumber(a) and a or 1) * alpha, layer = "ARTWORK", sublevel = 0,
        level = level, bar = true, share = share }
end

local function ReadText(text, plate, level, first)
    local shown, alpha = Seen(text)
    if not shown then
        return
    end
    local words = text:GetText()
    if not Utils.IsUsableString(words) then
        return
    end
    local plain = words:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local isName = first ~= nil and plain:find(first, 1, true) ~= nil
    if not isName and not plain:match("^[%d%s%.,%%/%+%-%?kKmM]+$") then
        return
    end
    local x, y, width, height = Box(text, plate)
    local font, size, flags = text:GetFont()
    local r, g, b, a = text:GetTextColor()
    if not x or not Usable(r, g, b) then
        return
    end
    local shadowX, shadowY = text:GetShadowOffset()
    local shadowR, shadowG, shadowB, shadowA = text:GetShadowColor()
    return { x = x, y = y, w = width, h = height, text = true, name = isName or nil, words = not isName and plain or nil,
        font = Utils.IsUsableString(font) and font or nil, size = Utils.IsUsableNumber(size) and size or nil,
        flags = Utils.IsUsableString(flags) and flags or nil, r = r, g = g, b = b,
        a = (Utils.IsUsableNumber(a) and a or 1) * alpha, layer = text:GetDrawLayer(), justify = text:GetJustifyH(),
        shadowX = Utils.IsUsableNumber(shadowX) and shadowX or nil, shadowY = Utils.IsUsableNumber(shadowY) and shadowY or nil,
        shadow = Usable(shadowR, shadowG, shadowB) and { shadowR, shadowG, shadowB, Utils.IsUsableNumber(shadowA) and shadowA or 1 } or nil,
        level = level }
end

-- Every piece under `frame`. A part that can't be read is left out, and the rest still counts.
local function Walk(frame, plate, skip, depth, first, pieces)
    if depth > MOST_DEPTH or #pieces >= MOST_PIECES or Utils.Call(frame.IsForbidden, frame) == true then
        return
    end
    local level = Utils.Call(frame.GetFrameLevel, frame) or 0
    local kind = Utils.Call(frame.GetObjectType, frame)
    local fill
    if kind == "StatusBar" then
        fill = Utils.Call(frame.GetStatusBarTexture, frame)
        pieces[#pieces + 1] = Utils.Call(ReadBar, frame, plate, level)
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region ~= fill and #pieces < MOST_PIECES then
            local what = Utils.Call(region.GetObjectType, region)
            if what == "Texture" then
                pieces[#pieces + 1] = Utils.Call(ReadTexture, region, plate, level)
            elseif what == "FontString" then
                pieces[#pieces + 1] = Utils.Call(ReadText, region, plate, level, first)
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

local function Copy(unit, kind, player)
    if not Everyday(unit) then
        return false
    end
    local plate = C_NamePlate and Utils.Call(C_NamePlate.GetNamePlateForUnit, unit)
    if not plate or Utils.Call(plate.IsForbidden, plate) == true then
        return false
    end
    local first = Names.Unit(unit) or Utils.Call(UnitName, unit)
    local pieces = {}
    -- (a frame that won't answer ends the walk, not the page)
    pcall(Walk, plate, plate, HC.Plates.CrestOn(unit), 1, first, pieces)
    SettleBars(pieces)
    if #pieces == 0 then
        return false
    end
    Saved()[kind] = { player = player, pieces = pieces }
    return true
end

local function Told()
    for _, fn in ipairs(listeners) do
        fn()
    end
end

-- A plate came on screen. The first of each kind this session is copied, a moment later, once its addon
-- has drawn it. A creature's only until a player's is known.
function PlateLook.Seen(unit)
    local kind, player = KindOf(unit)
    if not kind then
        return
    end
    local key = kind .. (player and "Player" or "Creature")
    local look = PlateLook.Get(kind)
    if done[key] or waiting[key] or (tries[key] or 0) >= MOST_TRIES or (not player and look and look.player) then
        return
    end
    waiting[key] = true
    tries[key] = (tries[key] or 0) + 1
    local guid = Utils.Call(UnitGUID, unit)
    Utils.After(WAIT, "nameplate look", function()
        waiting[key] = nil
        -- (the same plate's token can belong to someone else by now)
        if guid and Utils.Call(UnitGUID, unit) == guid and Copy(unit, kind, player) then
            done[key] = true
            Told()
        end
    end)
end

-- Every plate on screen, now: the page has just opened, and you may have changed your nameplate addon.
-- A player's first, for each kind.
function PlateLook.Scan()
    for _, wanted in ipairs({ true, false }) do
        local copied = {}
        for index = 1, MOST_PLATES do
            local unit = "nameplate" .. index
            local kind, player = KindOf(unit)
            local look = kind and PlateLook.Get(kind)
            if kind and player == wanted and not copied[kind] and (player or not (look and look.player))
                and Copy(unit, kind, player) then
                copied[kind] = true
                done[kind .. (player and "Player" or "Creature")] = true
            end
        end
    end
end

-- --- drawing it ----------------------------------------------------------------------------------

local function PaintTexture(texture, piece, holder)
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
    texture:SetVertexColor(piece.r, piece.g, piece.b, piece.a or 1)
    texture:SetSize(piece.w, piece.h)
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", holder, "CENTER", piece.x, piece.y)
    texture:Show()
end

-- (the font first, on no words: letters set before a change of font can turn to boxes)
local function PaintText(text, piece, holder, name)
    text:SetText("")
    if piece.font and piece.size and piece.size > 0 then
        pcall(text.SetFont, text, piece.font, piece.size, piece.flags or "")
    end
    text:SetDrawLayer(piece.layer or "OVERLAY")
    text:SetTextColor(piece.r, piece.g, piece.b, piece.a or 1)
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

-- Draws a copied look on `holder`, with `name` for the name on it. One frame per level, as on the plate,
-- so what lay on top still does; drawn again, it reuses what it made.
function PlateLook.Draw(holder, look, name)
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
                pcall(PaintText, text, piece, holder, name)
            else
                layer.usedTextures = layer.usedTextures + 1
                local texture = layer.textures[layer.usedTextures]
                if not texture then
                    texture = layer:CreateTexture(nil, "ARTWORK")
                    layer.textures[layer.usedTextures] = texture
                end
                pcall(PaintTexture, texture, piece, holder)
            end
        end
    end
end
