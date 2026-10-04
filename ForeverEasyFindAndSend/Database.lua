local _, ns = ...

local Database = {}
ns.Database = Database

local CURRENT_SCHEMA_VERSION = 2

-- Development-only records. They participate in autocomplete tests but are
-- never inserted into ForeverEasyFindAndSendDB.
local DEVELOPMENT_FIXTURES = {
    {
        actionName = "Amigo Kebab",
        displayName = "Amigo Kebab",
        firstName = "Amigo",
        surname = "Kebab",
        level = 60,
        race = "Orc",
        class = "SHAMAN",
        classFile = "SHAMAN",
        classID = 7,
        isDevelopmentFixture = true,
    },
    {
        actionName = "Amigö Kebäck",
        displayName = "Amigö Kebäck",
        firstName = "Amigö",
        surname = "Kebäck",
        level = 47,
        race = "Human",
        class = "MAGE",
        classFile = "MAGE",
        classID = 8,
        isDevelopmentFixture = true,
    },
    {
        actionName = "Âmïgø Këbäck",
        displayName = "Âmïgø Këbäck",
        firstName = "Âmïgø",
        surname = "Këbäck",
        level = 60,
        race = "Troll",
        class = "WARRIOR",
        classFile = "WARRIOR",
        classID = 1,
        isDevelopmentFixture = true,
    },
}

local KNOWN_FIELDS = {
    "actionName",
    "displayName",
    "firstName",
    "surname",
    "guid",
    "level",
    "race",
    "class",
    "classFile",
    "classID",
    "favorite",
    "firstSeen",
    "lastSeen",
}

local database
local byGUID = {}
local byActionName = {}

local function Now()
    if type(GetServerTime) == "function" then
        return GetServerTime()
    end

    return time()
end

local function CopyKnownFields(target, source, overwrite)
    for index = 1, #KNOWN_FIELDS do
        local field = KNOWN_FIELDS[index]
        if source[field] ~= nil and (overwrite or target[field] == nil) then
            target[field] = source[field]
        end
    end
end

local function CopySources(target, source)
    target.sources = type(target.sources) == "table" and target.sources or {}
    if type(source.sources) == "table" then
        for sourceName, present in pairs(source.sources) do
            if present then
                target.sources[sourceName] = true
            end
        end
    end
end

local function RebuildIndexes()
    wipe(byGUID)
    wipe(byActionName)

    for _, character in pairs(database.characters) do
        if character.guid then
            byGUID[character.guid] = character
        end
        if character.actionName then
            byActionName[character.actionName] = character
        end
    end
end

local function FindExisting(incoming)
    if incoming.guid and byGUID[incoming.guid] then
        return byGUID[incoming.guid]
    end

    local sameName = incoming.actionName and byActionName[incoming.actionName]
    if sameName and (not incoming.guid or not sameName.guid or sameName.guid == incoming.guid) then
        return sameName
    end

    return nil
end

local function CreateCharacter()
    local id = tostring(database.nextCharacterID)
    while database.characters[id] do
        database.nextCharacterID = database.nextCharacterID + 1
        id = tostring(database.nextCharacterID)
    end
    database.nextCharacterID = database.nextCharacterID + 1

    local character = {
        id = id,
        sources = {},
        favorite = false,
    }
    database.characters[id] = character
    return character
end

local function ImportLegacyDatabase()
    database.migrations = type(database.migrations) == "table" and database.migrations or {}
    if database.migrations.foreverEasyNames then
        return
    end

    local legacyAvailable = type(ForeverEasyNamesDB) == "table" and ForeverEasyNamesDB ~= database
    if legacyAvailable then
        if type(ForeverEasyNamesDB.characters) == "table" then
            for _, legacyCharacter in pairs(ForeverEasyNamesDB.characters) do
                if type(legacyCharacter) == "table" and type(legacyCharacter.actionName) == "string" then
                    local existing = FindExisting(legacyCharacter)
                    if not existing then
                        local imported = CreateCharacter()
                        CopyKnownFields(imported, legacyCharacter, true)
                        CopySources(imported, legacyCharacter)
                        imported.displayName = imported.displayName or imported.actionName
                        if imported.guid then
                            byGUID[imported.guid] = imported
                        end
                        byActionName[imported.actionName] = imported
                    end
                end
            end
        end

        if type(ForeverEasyNamesDB.settings) == "table" then
            for key, value in pairs(ForeverEasyNamesDB.settings) do
                if database.settings[key] == nil then
                    database.settings[key] = value
                end
            end
        end
    end

    database.migrations.foreverEasyNames = legacyAvailable
    RebuildIndexes()
end

function Database.Initialize()
    if type(ForeverEasyFindAndSendDB) ~= "table" then
        ForeverEasyFindAndSendDB = {}
    end

    database = ForeverEasyFindAndSendDB
    database.nextCharacterID = database.nextCharacterID or 1
    database.characters = type(database.characters) == "table" and database.characters or {}
    database.settings = type(database.settings) == "table" and database.settings or {}

    RebuildIndexes()
    ImportLegacyDatabase()
    database.schemaVersion = CURRENT_SCHEMA_VERSION
end

function Database.Upsert(incoming)
    if type(incoming) ~= "table" or type(incoming.actionName) ~= "string" or incoming.actionName == "" then
        return nil, "actionName is required"
    end

    local character = FindExisting(incoming)
    local created = false

    if not character then
        character = CreateCharacter()
        created = true
    end

    CopyKnownFields(character, incoming, true)
    CopySources(character, incoming)
    character.displayName = character.displayName or character.actionName
    character.favorite = character.favorite == true

    local seenAt = incoming.seenAt or Now()
    character.firstSeen = character.firstSeen or seenAt
    character.lastSeen = seenAt

    if incoming.source then
        character.sources[incoming.source] = true
    end

    RebuildIndexes()
    return character, nil, created
end

function Database.SetFavorite(character, favorite)
    if type(character) ~= "table" or character.isDevelopmentFixture then
        return false
    end

    local persistent = character.id and database.characters[character.id]
    if persistent ~= character then
        return false
    end

    character.favorite = favorite == true
    return true
end

function Database.GetPersistentRecords()
    local records = {}

    for _, character in pairs(database.characters) do
        records[#records + 1] = character
    end

    return records
end

function Database.GetSearchRecords()
    local records = Database.GetPersistentRecords()

    for index = 1, #DEVELOPMENT_FIXTURES do
        records[#records + 1] = DEVELOPMENT_FIXTURES[index]
    end

    return records
end

function Database.GetFavoriteRecords()
    local records = {}

    for _, character in pairs(database.characters) do
        if character.favorite then
            records[#records + 1] = character
        end
    end

    return records
end

function Database.GetStats()
    local contacts = 0
    local favorites = 0

    for _, character in pairs(database.characters) do
        contacts = contacts + 1
        if character.favorite then
            favorites = favorites + 1
        end
    end

    return {
        contacts = contacts,
        favorites = favorites,
    }
end

function Database.GetSettings()
    return database.settings
end

function Database.GetSchemaVersion()
    return database and database.schemaVersion or nil
end
