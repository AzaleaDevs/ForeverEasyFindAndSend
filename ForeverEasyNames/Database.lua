local _, ns = ...

local Database = {}
ns.Database = Database

local CURRENT_SCHEMA_VERSION = 1

-- Development-only records. They are merged into the runtime search index but
-- are never inserted into ForeverEasyNamesDB.
local DEVELOPMENT_FIXTURES = {
    {
        actionName = "Amigo Kebab",
        displayName = "Amigo Kebab",
        firstName = "Amigo",
        surname = "Kebab",
        level = 60,
        race = "Orc",
        class = "SHAMAN",
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
        classID = 1,
        isDevelopmentFixture = true,
    },
}

local database
local byGUID = {}
local byActionName = {}

local function CopyKnownFields(target, source)
    local fields = {
        "actionName",
        "displayName",
        "firstName",
        "surname",
        "guid",
        "level",
        "race",
        "class",
        "classID",
    }

    for index = 1, #fields do
        local field = fields[index]
        if source[field] ~= nil then
            target[field] = source[field]
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

function Database.Initialize()
    if type(ForeverEasyNamesDB) ~= "table" then
        ForeverEasyNamesDB = {}
    end

    database = ForeverEasyNamesDB
    database.schemaVersion = database.schemaVersion or CURRENT_SCHEMA_VERSION
    database.nextCharacterID = database.nextCharacterID or 1
    database.characters = type(database.characters) == "table" and database.characters or {}
    database.settings = type(database.settings) == "table" and database.settings or {}

    RebuildIndexes()
end

function Database.Upsert(incoming)
    if type(incoming) ~= "table" or type(incoming.actionName) ~= "string" or incoming.actionName == "" then
        return nil, "actionName is required"
    end

    local character

    if incoming.guid then
        character = byGUID[incoming.guid]
    end

    if not character then
        local sameName = byActionName[incoming.actionName]
        if sameName and (not incoming.guid or not sameName.guid or sameName.guid == incoming.guid) then
            character = sameName
        end
    end

    if not character then
        local id = tostring(database.nextCharacterID)
        database.nextCharacterID = database.nextCharacterID + 1
        character = { id = id, sources = {} }
        database.characters[id] = character
    end

    CopyKnownFields(character, incoming)
    character.displayName = character.displayName or character.actionName
    character.sources = type(character.sources) == "table" and character.sources or {}

    if incoming.source then
        character.sources[incoming.source] = true
    end

    RebuildIndexes()
    return character
end

function Database.GetSearchRecords()
    local records = {}

    for _, character in pairs(database.characters) do
        records[#records + 1] = character
    end

    for index = 1, #DEVELOPMENT_FIXTURES do
        records[#records + 1] = DEVELOPMENT_FIXTURES[index]
    end

    return records
end

function Database.GetSchemaVersion()
    return database and database.schemaVersion or nil
end

