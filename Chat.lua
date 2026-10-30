local _, HC = ...

HC.Chat = {}

local Chat = HC.Chat
local Utils = HC.Utils
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin

-- A relative's chat lines start with your crest. The game lets addons change a line's text,
-- not the name before it (that taints the chat), so the crest leads the message itself.
local cache, cached = {}, 0 -- [guid] = the crest to put first, or false: not family
local CACHE_MAX = 2000

local function Decorate(_, event, text, author, ...)
    if type(HeyCousinDB) ~= "table" or HeyCousinDB.chatCrest == false then
        return false
    end
    if type(text) ~= "string" or Utils.IsSecret(text) or Utils.IsSecret(author) then
        return false
    end
    local kind = HC.Radar.CHATS[event]
    if kind and not HC.Radar.Watches(kind) then
        return false
    end
    local guid = select(10, ...)
    if not Utils.IsUsableString(guid) then
        return false
    end
    local icon = cache[guid]
    if icon == nil then
        local first, surname = Names.FromGUID(guid)
        if not first then
            -- the game doesn't know this player yet; ask again next line
            return false
        end
        local house, mine = Kin.House()
        icon = false
        if house and Names.Same(surname, mine) and not Names.Same(first, (Names.Me())) then
            icon = Crest.ChatIcon(house.crest, Kin.IsBlackSheep(house.relatives[first]))
        end
        if cached >= CACHE_MAX then
            cache, cached = {}, 0
        end
        cache[guid], cached = icon, cached + 1
    end
    if icon then
        return false, icon .. " " .. text, author, ...
    end
    return false
end

-- A new crest, a new relative: the cache starts over.
function Chat.Reset()
    cache, cached = {}, 0
end

function Chat.Start()
    if Chat.started or not Names.HaveSurnames() then
        return
    end
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if type(add) ~= "function" then
        return
    end
    Chat.started = true
    local filter = Utils.Protect("chat crest", Decorate)
    for event in pairs(HC.Radar.CHATS) do
        -- through securecall, as other addons that work on Forever do
        if type(securecall) == "function" then
            securecall(add, event, filter)
        else
            add(event, filter)
        end
    end
    Kin.OnChange(Chat.Reset)
end
