local _, HC = ...

HC.Utils = {}

local Utils = HC.Utils
local L = HC.L

local ADDON_NAME = "Hey Cousin!"

function Utils.IsSecret(value)
    if type(issecretvalue) ~= "function" then
        return false
    end

    -- a check that fails counts as secret: the value isn't safe to compare or do sums with
    local ok, secret = pcall(issecretvalue, value)
    return not ok or secret == true
end

function Utils.IsUsableNumber(value)
    return type(value) == "number" and not Utils.IsSecret(value)
end

-- Checked for a secret before it's compared: comparing a secret string is itself an error.
function Utils.IsUsableString(value)
    return type(value) == "string" and not Utils.IsSecret(value) and value ~= ""
end

local function Answered(ok, first, ...)
    if not ok or Utils.IsSecret(first) then
        return
    end
    return first, ...
end

-- Calls a Blizzard function that may be missing, fail, or answer with a secret value: nothing
-- comes back then. Every result comes back otherwise, nils in between included.
function Utils.Call(func, ...)
    if type(func) ~= "function" then
        return
    end
    return Answered(pcall(func, ...))
end

-- --- errors ------------------------------------------------------------------------------------

-- Errors the addon caught (Utils.Protect): the last few, each with how often it happened.
-- /heycousin debug lists them.
HC.errors = {}
local MAX_ERRORS = 10

function Utils.NoteError(label, err)
    -- an error carrying a secret value can't be compared with the ones noted before
    local message = Utils.IsSecret(err) and "(secret value)" or tostring(err)
    if Utils.IsSecret(message) then
        message = "(secret value)"
    end
    for _, known in ipairs(HC.errors) do
        if known.message == message then
            known.count = known.count + 1
            return
        end
    end
    if #HC.errors >= MAX_ERRORS then
        table.remove(HC.errors, 1)
    end
    HC.errors[#HC.errors + 1] = { label = label, message = message, count = 1 }
    if HeyCousinDB and HeyCousinDB.debug and type(Utils.Print) == "function" then
        Utils.Print(label .. ": " .. message)
    end
end

local function Settled(label, ok, ...)
    if ok then
        return ...
    end
    Utils.NoteError(label, (...))
end

-- `fn` wrapped so an error in it is caught and noted (Utils.NoteError) instead of reaching the
-- game's error frame, or the Blizzard code that called it when `fn` hooks it: an addon's mistake
-- must never break chat, a tooltip or another addon.
function Utils.Protect(label, fn)
    return function(...)
        return Settled(label, pcall(fn, ...))
    end
end

-- --- the client --------------------------------------------------------------------------------

-- WoW Forever, or another client (Retail runs the addon in test mode: deploy.py --retail).
-- Forever's project is WOW_PROJECT_CAMELOT, but some of its builds report WOW_PROJECT_MAINLINE
-- like Retail, so its interface version (1.60: 16001) decides too.
function Utils.IsForever()
    if WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then
        return true
    end
    local interface = select(4, Utils.Call(GetBuildInfo))
    return Utils.IsUsableNumber(interface) and interface >= 16000 and interface < 17000
end

-- Whether `unit`'s identity is hidden from addons right now (Midnight's rules, in protected
-- content). Missing API: not hidden.
function Utils.UnitHidden(unit)
    local secrets = C_Secrets
    if secrets and type(secrets.ShouldUnitIdentityBeSecret) == "function" then
        local ok, hidden = pcall(secrets.ShouldUnitIdentityBeSecret, unit)
        return not ok or hidden == true
    end
    return false
end

-- The zone you're in, by name.
function Utils.Zone()
    local zone = Utils.Call(GetRealZoneText) or Utils.Call(GetZoneText)
    return Utils.IsUsableString(zone) and zone or nil
end

-- A class's color as { r, g, b } (a neutral gray for an unknown class).
function Utils.ClassColor(classFile)
    local color
    if type(classFile) == "string" then
        if C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
            color = Utils.Call(C_ClassColor.GetClassColor, classFile)
        end
        color = color or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
    end
    if type(color) == "table" and type(color.r) == "number" then
        return { color.r, color.g, color.b }
    end
    return { 0.72, 0.68, 0.6 }
end

-- Puts a class's icon on `texture`: the game's round atlas where it has one, else the old
-- character-creation sheet. False when the game has neither.
function Utils.SetClassIcon(texture, classFile)
    if type(classFile) ~= "string" then
        return false
    end
    local atlas = "classicon-" .. classFile:lower()
    if C_Texture and type(C_Texture.GetAtlasInfo) == "function" and Utils.Call(C_Texture.GetAtlasInfo, atlas) then
        texture:SetAtlas(atlas)
        return true
    end
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if type(coords) == "table" then
        texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        return true
    end
    return false
end

-- A class's name in the game's language (female names where the language has them).
function Utils.ClassName(classFile, sex)
    local names = sex == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
    return type(names) == "table" and names[classFile] or nil
end

-- How long ago `stamp` (time()) was, in a few letters: "now", "5 min", "2 h", "3 days".
function Utils.Ago(stamp)
    if type(stamp) ~= "number" or stamp <= 0 then
        return ""
    end
    local seconds = math.max(0, time() - stamp)
    if seconds < 90 then
        return L["now"]
    elseif seconds < 3600 then
        return string.format(L["%d min"], math.floor(seconds / 60 + 0.5))
    elseif seconds < 86400 then
        return string.format(L["%d h"], math.floor(seconds / 3600 + 0.5))
    end
    local days = math.floor(seconds / 86400 + 0.5)
    return days == 1 and L["1 day"] or string.format(L["%d days"], days)
end

-- `fn` once, `delay` seconds from now, its errors caught.
function Utils.After(delay, label, fn)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay, Utils.Protect(label, fn))
    end
end

-- A function that runs `fn` once, `delay` seconds after the last of any burst of calls.
function Utils.Debounce(delay, label, fn)
    local waiting = false
    local protected = Utils.Protect(label, function()
        waiting = false
        fn()
    end)
    return function()
        if not waiting and C_Timer and type(C_Timer.After) == "function" then
            waiting = true
            C_Timer.After(delay, protected)
        end
    end
end

-- --- saved settings and text -------------------------------------------------------------------

function Utils.CopyDefaults(target, defaults)
    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = Utils.CopyDefaults({}, value)
            else
                target[key] = value
            end
        end
    end

    return target
end

function Utils.Print(message)
    local prefix = "|cffe0b040" .. ADDON_NAME .. "|r"
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. ": " .. tostring(message))
end

-- A value from the game as text, for /heycousin status: a string in quotes (so a space at its end
-- shows), "-" for nothing, and a secret never turned into text.
function Utils.Shown(value)
    if Utils.IsSecret(value) then
        return L["(secret)"]
    end
    if value == nil then
        return "-"
    end
    if type(value) == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end

function Utils.Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end
