local _, ns = ...

local Database = {}
ns.Database = Database

local CURRENT_SCHEMA_VERSION = 2

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
    "guild",
    "zone",
    "favorite",
    "firstSeen",
    "lastSeen",
}

local database
local byGUID = {}
local byActionName = {}
local changeHandler
local batchDepth = 0
local batchDirty = false
local batchSearchDirty = false
local batchProfileStartedAt
local batchProfileUpserts = 0

local SEARCH_FIELDS = {
    "actionName",
    "displayName",
    "firstName",
    "surname",
    "level",
    "race",
    "class",
    "classFile",
}

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

local function NotifyChanged(searchChanged)
    if batchDepth > 0 then
        batchDirty = true
        batchSearchDirty = batchSearchDirty or searchChanged == true
    elseif changeHandler then
        changeHandler(searchChanged == true)
    end
end

local function SearchFieldsChanged(character, previous)
    for fieldIndex = 1, #SEARCH_FIELDS do
        local field = SEARCH_FIELDS[fieldIndex]
        if character[field] ~= previous[field] then
            return true
        end
    end
    return false
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
    local startedAt = ns.Performance and ns.Performance.Start()
    if type(incoming) ~= "table" or type(incoming.actionName) ~= "string" or incoming.actionName == "" then
        if startedAt then
            ns.Performance.Stop("Database.Upsert", startedAt)
        end
        return nil, "actionName is required"
    end

    if startedAt and batchDepth > 0 then
        batchProfileUpserts = batchProfileUpserts + 1
    end

    local character = FindExisting(incoming)
    local created = false

    if not character then
        character = CreateCharacter()
        created = true
    end

    local previous = {}
    for fieldIndex = 1, #SEARCH_FIELDS do
        local field = SEARCH_FIELDS[fieldIndex]
        previous[field] = character[field]
    end
    local previousGUID = character.guid
    local previousActionName = character.actionName

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

    if previousGUID and previousGUID ~= character.guid and byGUID[previousGUID] == character then
        byGUID[previousGUID] = nil
    end
    if previousActionName
        and previousActionName ~= character.actionName
        and byActionName[previousActionName] == character then
        byActionName[previousActionName] = nil
    end
    if character.guid then
        byGUID[character.guid] = character
    end
    byActionName[character.actionName] = character

    local searchChanged = created or SearchFieldsChanged(character, previous)
    if searchChanged then
        NotifyChanged(true)
    end
    if startedAt then
        ns.Performance.Stop("Database.Upsert", startedAt)
    end
    return character, nil, created
end

function Database.SetFavorite(character, favorite)
    if type(character) ~= "table" then
        return false
    end

    local persistent = character.id and database.characters[character.id]
    if persistent ~= character then
        return false
    end

    local newValue = favorite == true
    if character.favorite == newValue then
        return true
    end

    character.favorite = newValue
    NotifyChanged(false)
    return true
end

function Database.SetChangeHandler(handler)
    changeHandler = type(handler) == "function" and handler or nil
end

function Database.BeginBatch()
    if batchDepth == 0 then
        batchProfileStartedAt = ns.Performance and ns.Performance.Start()
        batchProfileUpserts = 0
    end
    batchDepth = batchDepth + 1
end

function Database.EndBatch()
    if batchDepth == 0 then
        return false
    end

    batchDepth = batchDepth - 1
    local notified = false
    local searchChanged = false
    if batchDepth == 0 and batchDirty then
        searchChanged = batchSearchDirty
        batchDirty = false
        batchSearchDirty = false
        notified = true
        if changeHandler then
            changeHandler(searchChanged)
        end
    end
    if batchDepth == 0 and batchProfileStartedAt then
        ns.Performance.Stop("Database.Batch", batchProfileStartedAt, {
            upserts = batchProfileUpserts,
            notified = notified,
            searchChanged = searchChanged,
        })
        batchProfileStartedAt = nil
        batchProfileUpserts = 0
    end
    return true
end

function Database.RequestRefresh(searchChanged)
    NotifyChanged(searchChanged == true)
end

function Database.GetPersistentRecords()
    local records = {}

    for _, character in pairs(database.characters) do
        records[#records + 1] = character
    end

    return records
end

function Database.GetSearchRecords()
    return Database.GetPersistentRecords()
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
