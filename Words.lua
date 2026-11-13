local _, HC = ...

-- Bad words in what cousins send, masked with *: family chat, group posts, calls for help, mottos,
-- professions and a guild's welcome. The game's own filter works only in its own chat and never sees
-- addon messages, and an addon can't call it; so this does it, and follows the game's own switch:
-- with its Mature Language Filter off, nothing is masked. A short list in each language the addon
-- speaks; it can't catch everything.
HC.Words = {}

local Words = HC.Words
local Utils = HC.Utils

-- Each word: masked where it starts a word (so "disputa" keeps its "puta"), or `anywhere` for the ones
-- nothing innocent holds. A word in a Latin or Cyrillic text goes whole; in Korean or Chinese, written
-- without spaces, only the bad part.
local LIST = {
    -- English
    { "fuck", anywhere = true }, { "shit", anywhere = true }, { "nigger", anywhere = true }, { "nigga", anywhere = true },
    { "faggot", anywhere = true }, { "cunt" }, { "bitch" }, { "asshole" }, { "dickhead" }, { "pussy" }, { "retard" },
    { "whore" }, { "slut" }, { "motherf" },
    -- German
    { "scheiße" }, { "scheisse" }, { "fotze" }, { "hurensohn", anywhere = true }, { "wichser" }, { "schlampe" },
    { "arschloch" },
    -- French
    { "putain" }, { "connard" }, { "salope" }, { "enculé" }, { "encule" }, { "merde" },
    -- Spanish
    { "puta" }, { "mierda" }, { "coño" }, { "cabrón" }, { "gilipollas" }, { "pendejo" }, { "joder" },
    -- Portuguese
    { "porra" }, { "caralho" }, { "foda" }, { "buceta" },
    -- Italian
    { "cazzo" }, { "stronzo" }, { "vaffanculo" }, { "puttana" },
    -- Russian and Ukrainian (lower case and with a capital: Small() knows only A to Z)
    { "хуй", anywhere = true }, { "Хуй", anywhere = true }, { "хуе", anywhere = true }, { "Хуе", anywhere = true },
    { "пизд", anywhere = true }, { "Пизд", anywhere = true }, { "ебан", anywhere = true }, { "Ебан", anywhere = true },
    { "ебат", anywhere = true }, { "Ебат", anywhere = true }, { "бляд", anywhere = true }, { "Бляд", anywhere = true },
    { "блять" }, { "Блять" }, { "сука" }, { "Сука" }, { "суки" }, { "мудак" }, { "Мудак" }, { "пидор", anywhere = true },
    { "Пидор", anywhere = true }, { "пидар" }, { "гандон" }, { "ёб" }, { "Ёб" },
    -- Korean
    { "씨발", anywhere = true }, { "시발", anywhere = true }, { "병신", anywhere = true }, { "개새끼", anywhere = true },
    { "좆", anywhere = true },
    -- Chinese
    { "操你", anywhere = true }, { "傻逼", anywhere = true }, { "他妈的", anywhere = true }, { "草泥马", anywhere = true },
    { "肏", anywhere = true },
}

-- Whether to mask: the game's Mature Language Filter, on unless the player turned it off.
function Words.On()
    return Utils.Call(GetCVar, "profanityFilter") ~= "0"
end

-- The letter (one UTF-8 character) that ends just before `at`, and where it starts.
local function Before(text, at)
    local start = at - 1
    while start > 1 and text:byte(start) >= 128 and text:byte(start) < 192 do
        start = start - 1
    end
    return start >= 1 and text:sub(start, at - 1) or "", start
end

-- The letter that starts at `at`, and where the next one starts.
local function After(text, at)
    local byte = text:byte(at)
    if not byte then
        return "", at
    end
    local size = byte >= 240 and 4 or byte >= 224 and 3 or byte >= 192 and 2 or 1
    return text:sub(at, at + size - 1), at + size
end

-- A letter of a word written with spaces between words: A to Z, digits, and two-byte letters (the
-- accented Latin ones, Cyrillic). Korean and Chinese are three bytes: never part of a "word" here.
local function WordLetter(letter)
    return (#letter == 1 and letter:match("%w") ~= nil) or #letter == 2
end

local function Stars(word)
    local first, at = After(word, 1)
    local count = 0
    while at <= #word do
        local _, nextAt = After(word, at)
        count, at = count + 1, nextAt
    end
    return first .. string.rep("*", count)
end

-- A to Z made small, and nothing else: string.lower can follow the computer's language and change
-- the bytes of other letters, so a Cyrillic word would never match.
local function Small(text)
    return (text:gsub("[A-Z]", function(letter)
        return string.char(letter:byte() + 32)
    end))
end

-- `text` with the bad words masked; as it is when masking is off.
function Words.Clean(text)
    if type(text) ~= "string" or text == "" or not Words.On() then
        return text
    end
    local lower = Small(text)
    for _, entry in ipairs(LIST) do
        local bad = entry[1]
        local start = 1
        while true do
            local from, to = lower:find(bad, start, true)
            if not from then
                break
            end
            local inWord = WordLetter((Before(lower, from)))
            if inWord and not entry.anywhere then
                start = to + 1
            else
                -- (a Latin or Cyrillic word goes whole, from its start to its end)
                if WordLetter(After(lower, from)) then
                    while from > 1 do
                        local letter, at = Before(lower, from)
                        if not WordLetter(letter) then
                            break
                        end
                        from = at
                    end
                    while to < #lower do
                        local letter, at = After(lower, to + 1)
                        if not WordLetter(letter) then
                            break
                        end
                        to = at - 1
                    end
                end
                local masked = Stars(text:sub(from, to))
                text = text:sub(1, from - 1) .. masked .. text:sub(to + 1)
                lower = lower:sub(1, from - 1) .. masked .. lower:sub(to + 1)
                start = from + #masked
            end
        end
    end
    return text
end
