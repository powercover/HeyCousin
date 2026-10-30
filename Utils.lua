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
