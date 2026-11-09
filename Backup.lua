local _, HC = ...

-- Backup and restore: everything Hey Cousin! keeps (your houses, cousins, meetings, crests, mottos,
-- achievements and settings) as one line of text to copy and keep anywhere, and that line read back.
-- The game keeps addon data only in your WTF folder: this is how it survives that folder being
-- deleted, or a new computer. The line is read by its own small reader, never run as code, so a
-- backup someone hands you can't do anything but fill these tables.
HC.Backup = {}

local Backup = HC.Backup
local Utils = HC.Utils
local Theme = HC.Theme
local L = HC.L
local C = Theme.C

local HEADER = "HeyCousin1"
-- not kept: what /cousin probe and debug gathered, and the game's own frames Find quiets
local SKIP = { probe = true, debug = true, whoFrames = true }
local DEPTH_MAX = 24
local LENGTH_MAX = 8 * 1024 * 1024
local SURE_FOR = 8  -- seconds the second click of Restore waits

-- --- the line ----------------------------------------------------------------------------------

-- A string's letters as they go in the line: a quote, a backslash, | (the chat box's codes) and the
-- control codes become \ and three digits.
local function Escape(text)
    return (text:gsub('[%z\1-\31\127\\"|]', function(letter)
        return string.format("\\%03d", letter:byte())
    end))
end

local function Write(out, value, depth)
    local kind = type(value)
    if kind == "string" then
        out[#out + 1] = '"' .. Escape(value) .. '"'
    elseif kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            value = 0
        end
        out[#out + 1] = "n" .. string.format("%.17g", value)
    elseif kind == "boolean" then
        out[#out + 1] = value and "T" or "F"
    elseif kind == "table" and depth < DEPTH_MAX then
        out[#out + 1] = "{"
        for key, item in pairs(value) do
            local keyKind, itemKind = type(key), type(item)
            if (keyKind == "string" or keyKind == "number") and not (depth == 0 and SKIP[key])
                and (itemKind == "string" or itemKind == "number" or itemKind == "boolean" or itemKind == "table") then
                Write(out, key, depth + 1)
                out[#out + 1] = "="
                Write(out, item, depth + 1)
                out[#out + 1] = ";"
            end
        end
        out[#out + 1] = "}"
    else
        out[#out + 1] = "F"
    end
end

-- A check of the whole line, so a backup copied only in part is told apart.
local function Sum(text)
    local a, b = 1, 0
    for start = 1, #text, 4096 do
        local bytes = { text:byte(start, math.min(start + 4095, #text)) }
        for _, byte in ipairs(bytes) do
            a = (a + byte) % 65521
            b = (b + a) % 65521
        end
    end
    return b * 65536 + a
end

-- Everything as one line.
function Backup.Make()
    local out = {}
    Write(out, type(HeyCousinDB) == "table" and HeyCousinDB or {}, 0)
    local body = table.concat(out)
    return HEADER .. ":" .. #body .. ":" .. Sum(body) .. ":" .. body
end

-- The tables in a line, or nothing and why: "not" (not a backup) or "cut" (only part of one).
function Backup.Read(text)
    if type(text) ~= "string" or Utils.IsSecret(text) or #text > LENGTH_MAX then
        return nil, "not"
    end
    local length, sum, body = Utils.Trim(text):match("^" .. HEADER .. ":(%d+):(%d+):(.*)$")
    if not length then
        return nil, "not"
    end
    if #body ~= tonumber(length) or Sum(body) ~= tonumber(sum) then
        return nil, "cut"
    end
    local at = 1
    local function Fail()
        error("bad backup", 0)
    end
    local function Value(depth)
        local letter = body:sub(at, at)
        if letter == '"' then
            local close = body:find('"', at + 1, true) or Fail()
            local raw = body:sub(at + 1, close - 1)
            at = close + 1
            return (raw:gsub("\\(%d%d%d)", function(digits)
                local byte = tonumber(digits)
                return byte <= 255 and string.char(byte) or Fail()
            end))
        elseif letter == "n" then
            local digits = body:match("^[%-%d%.eE%+]+", at + 1) or Fail()
            at = at + 1 + #digits
            return tonumber(digits) or Fail()
        elseif letter == "T" or letter == "F" then
            at = at + 1
            return letter == "T"
        elseif letter == "{" then
            if depth >= DEPTH_MAX then
                Fail()
            end
            at = at + 1
            local result = {}
            while body:sub(at, at) ~= "}" do
                local key = Value(depth + 1)
                if body:sub(at, at) ~= "=" then
                    Fail()
                end
                at = at + 1
                local item = Value(depth + 1)
                if body:sub(at, at) ~= ";" then
                    Fail()
                end
                at = at + 1
                if type(key) == "string" or type(key) == "number" then
                    result[key] = item
                end
            end
            at = at + 1
            return result
        end
        Fail()
    end
    local ok, data = pcall(Value, 0)
    if not ok or type(data) ~= "table" or at ~= #body + 1 then
        return nil, "not"
    end
    return data
end

-- Puts a backup's tables in place of what's kept now; the game's interface reloads to start from them.
function Backup.Restore(data)
    for key in pairs(HeyCousinDB) do
        if not SKIP[key] then
            HeyCousinDB[key] = nil
        end
    end
    for key, value in pairs(data) do
        if not SKIP[key] then
            HeyCousinDB[key] = value
        end
    end
    if type(ReloadUI) == "function" then
        ReloadUI()
    end
end

-- --- the window --------------------------------------------------------------------------------

local window, box, status, make, restore, sureUntil

local function Say(text, color)
    status:SetText(text)
    color = color or C.text2
    status:SetTextColor(color[1], color[2], color[3])
end

local function Build()
    window = Theme.Window("HeyCousinBackup", 480, 262)
    window:SetFrameStrata("DIALOG")
    local heading = Theme.Text(window, "Title")
    heading:SetPoint("TOPLEFT", 20, -20)
    heading:SetPoint("RIGHT", window.close, "LEFT", -8, 0)
    heading:SetText(L["Backup"])
    local title = Theme.Title()
    heading:SetTextColor(title[1], title[2], title[3])
    local about = Theme.Text(window, "Small", C.text2)
    about:SetPoint("TOPLEFT", 20, -54)
    about:SetPoint("RIGHT", window, "RIGHT", -20, 0)
    about:SetWordWrap(true)
    about:SetJustifyH("LEFT")
    about:SetText(L["Your family, meetings, crest, achievements and settings, as one line of text. Keep it somewhere safe, and paste it back after a new computer or a deleted WTF folder."])
    box = Theme.EditBox(window, 440, L["A backup line"])
    -- (under the words, however many lines they take in your language)
    box:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -12)
    -- (no limit: a big family's line is long)
    box.edit:SetMaxLetters(0)
    status = Theme.Text(window, "Small", C.text2)
    status:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
    status:SetPoint("RIGHT", window, "RIGHT", -20, 0)
    status:SetWordWrap(true)
    status:SetJustifyH("LEFT")
    make = Theme.Button(window, L["Make a backup"], "primary", 150, 30)
    make:SetPoint("BOTTOMLEFT", 20, 20)
    Theme.Fit(make, 14, 130)
    Theme.OnClick(make, "make a backup", function()
        sureUntil = nil
        restore.label:SetText(L["Restore"])
        box.edit:SetText(Backup.Make())
        box.edit:SetFocus()
        box.edit:HighlightText()
        Say(L["Press Ctrl+C to copy it all, then keep it somewhere safe: a note, Discord, a cloud drive."])
    end)
    restore = Theme.Button(window, L["Restore"], "secondary", 150, 30)
    restore:SetPoint("LEFT", make, "RIGHT", 8, 0)
    Theme.Fit(restore, 14, 130)
    Theme.OnClick(restore, "restore a backup", function()
        local data, problem = Backup.Read(box.edit:GetText())
        if not data then
            sureUntil = nil
            restore.label:SetText(L["Restore"])
            Say(problem == "cut" and L["Only part of a backup is here. Copy all of it, then paste it again."]
                or L["Paste a backup line in the box first (Ctrl+V)."], C.enemy)
            return
        end
        if not sureUntil or GetTime() > sureUntil then
            sureUntil = GetTime() + SURE_FOR
            restore.label:SetText(L["Click again to restore"])
            Theme.Fit(restore, 14, 130)
            Say(L["This replaces what Hey Cousin! keeps on this account with the backup, then reloads the game's interface."],
                C.gold)
            return
        end
        Backup.Restore(data)
    end)
    window:HookScript("OnHide", function()
        box.edit:ClearFocus()
    end)
end

function Backup.Show()
    if not window then
        Build()
    end
    sureUntil = nil
    restore.label:SetText(L["Restore"])
    box.edit:SetText("")
    Say(L["Make a backup to copy it, or paste one and click Restore."])
    window:Show()
end

-- A new look: the window is built again in it.
Theme.OnSkin(function()
    if not window then
        return
    end
    local shown = window:IsShown()
    window:Hide()
    window = nil
    if shown then
        Backup.Show()
    end
end)
