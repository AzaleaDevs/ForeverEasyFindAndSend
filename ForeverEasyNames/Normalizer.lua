local _, ns = ...

local Normalizer = {}
ns.Normalizer = Normalizer

-- Explicit UTF-8 replacements keep the supported folding behavior reviewable.
-- Unknown characters are preserved instead of being silently discarded.
local REPLACEMENTS = {
    { "À", "a" }, { "Á", "a" }, { "Â", "a" }, { "Ã", "a" }, { "Ä", "a" }, { "Å", "a" },
    { "à", "a" }, { "á", "a" }, { "â", "a" }, { "ã", "a" }, { "ä", "a" }, { "å", "a" },
    { "Æ", "ae" }, { "æ", "ae" },
    { "Ç", "c" }, { "ç", "c" },
    { "È", "e" }, { "É", "e" }, { "Ê", "e" }, { "Ë", "e" },
    { "è", "e" }, { "é", "e" }, { "ê", "e" }, { "ë", "e" },
    { "Ì", "i" }, { "Í", "i" }, { "Î", "i" }, { "Ï", "i" },
    { "ì", "i" }, { "í", "i" }, { "î", "i" }, { "ï", "i" },
    { "Ñ", "n" }, { "ñ", "n" },
    { "Ò", "o" }, { "Ó", "o" }, { "Ô", "o" }, { "Õ", "o" }, { "Ö", "o" }, { "Ø", "o" },
    { "ò", "o" }, { "ó", "o" }, { "ô", "o" }, { "õ", "o" }, { "ö", "o" }, { "ø", "o" },
    { "Œ", "oe" }, { "œ", "oe" },
    { "Ù", "u" }, { "Ú", "u" }, { "Û", "u" }, { "Ü", "u" },
    { "ù", "u" }, { "ú", "u" }, { "û", "u" }, { "ü", "u" },
    { "Ý", "y" }, { "Ÿ", "y" }, { "ý", "y" }, { "ÿ", "y" },
    { "Ð", "d" }, { "ð", "d" }, { "Þ", "th" }, { "þ", "th" }, { "ß", "ss" },
}

local function Lower(value)
    if type(CaseAccentInsensitiveParse) == "function" then
        return CaseAccentInsensitiveParse(value)
    end

    return string.lower(value)
end

local function Fold(value)
    local folded = Lower(value)

    for index = 1, #REPLACEMENTS do
        local replacement = REPLACEMENTS[index]
        folded = string.gsub(folded, replacement[1], replacement[2])
    end

    folded = string.gsub(folded, "%s+", " ")
    folded = string.gsub(folded, "^%s+", "")
    folded = string.gsub(folded, "%s+$", "")

    return folded
end

local function Compact(value)
    return string.gsub(value, "[%s%-'’]", "")
end

local function Tokenize(value)
    local tokens = {}

    for token in string.gmatch(value, "[^%s%-'’]+") do
        tokens[#tokens + 1] = token
    end

    return tokens
end

function Normalizer.Normalize(value)
    local original = type(value) == "string" and value or ""
    local folded = Fold(original)

    return {
        original = original,
        folded = folded,
        compact = Compact(folded),
        tokens = Tokenize(folded),
    }
end

