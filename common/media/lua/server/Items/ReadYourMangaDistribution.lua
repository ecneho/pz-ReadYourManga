require "Items/ProceduralDistributions"

local module = "mangaItems"
local spawner_modern  = module .. ".manga_spawner_modern"
local spawner_pre1993 = module .. ".manga_spawner_pre1993"

local spawn_targets = {
    { "BedroomSidetable",            3 },
    { "BedroomSidetableChild",       4 },
    { "BedroomSidetableClassy",      2 },
    { "BedroomSidetableRedneck",     3 },

    { "LivingRoomShelf",             3 },
    { "LivingRoomShelfClassy",       2 },
    { "LivingRoomShelfNoTapes",      3 },
    { "LivingRoomShelfRedneck",      3 },
    { "LivingRoomSideTable",         2 },
    { "LivingRoomSideTableClassy",   1 },
    { "LivingRoomSideTableNoRemote", 2 },
    { "LivingRoomSideTableRedneck",  2 },
    { "RecRoomShelf",                3 },

    { "ShelfGeneric",                1 },
    { "DeskGeneric",                 1 },
    { "OfficeDeskHome",              2 },
    { "MagazineRackMixed",           4 },
    { "MagazineRackPaperback",       6 },

    { "LibraryBooks",                5 },
    { "LibraryChilds",               5 },
    { "LibraryCounter",              3 },
    { "LibraryPersonal",             3 },
    { "UniversityLibraryBooks",      4 },

    { "BookstoreBooks",              4 },
    { "BookStoreCounter",            2 },
    { "BookstoreChilds",             4 },
    { "ComicStoreCounter",           6 },
    { "ComicStoreDisplayBooks",      8 },
    { "ComicStoreDisplayComics",     8 },
    { "ComicStoreShelfComics",      10 },
    { "ComicStoreShelfFantasy",      6 },
    { "ComicStoreShelfSciFi",        6 },

    { "ClassroomDesk",               2 },
    { "ClassroomSecondaryDesk",      2 },
    { "ClassroomShelves",            2 },
    { "ClassroomSecondaryShelves",   2 },
    { "KidsDesk",                    3 },
    { "SchoolLockers",               3 },
    { "UniversitySideTable",         1 },

    { "Locker",                      2 },
    { "PostOfficeBoxes",             2 },
    { "CrateComics",                 8 },
    { "CrateBooks",                  3 },
}

local function injectSpawner(containerName, item, weight)
    local container = ProceduralDistributions.list[containerName]
    if not container then
        return
    end
    table.insert(container.items, item)
    table.insert(container.items, weight)
end

for _, entry in ipairs(spawn_targets) do
    injectSpawner(entry[1], spawner_modern,  entry[2])
    injectSpawner(entry[1], spawner_pre1993, entry[2])
end

local pools = nil

local function buildPools()
    if pools then return pools end

    local built = { modern = {}, pre1993 = {} }
    local seen = {}
    local all = getScriptManager():getAllItems()

    for i = 0, all:size() - 1 do
        local script = all:get(i)
        if script:getModuleName() == module then
            local name = script:getName()
            if not string.find(name, "spawner", 1, true) then
                local base = (string.gsub(name, "_[sl]$", ""))
                if not seen[base] then
                    seen[base] = true
                    if string.find(name, "_m_", 1, true) then
                        table.insert(built.modern, name)
                    elseif string.find(name, "_c_", 1, true) then
                        table.insert(built.pre1993, name)
                    end
                end
            end
        end
    end

    if #built.modern > 0 or #built.pre1993 > 0 then
        pools = built
    end
    return built
end

local function readBoolOption(name)
    local vars = SandboxVars and SandboxVars.ReadYourManga
    if vars and vars[name] ~= nil then
        return vars[name] == true
    end
    return true
end

local function allowPre1993() return readBoolOption("AllowPre1993") end
local function allowModern()  return readBoolOption("AllowModern")  end

---@param roomType string
---@param containerType string
---@param container ItemContainer
local function OnFillContainer(roomType, containerType, container)
    local contents = container:getItems()
    local spawners = nil

    for i = 0, contents:size() - 1 do
        local item = contents:get(i)
        local full = item:getFullType()
        if full == spawner_modern or full == spawner_pre1993 then
            spawners = spawners or {}
            table.insert(spawners, item)
        end
    end

    if not spawners then return end

    local pre1993Enabled = allowPre1993()
    local modernEnabled  = allowModern()
    local p = buildPools()

    for _, spawner in ipairs(spawners) do
        local isModern = spawner:getFullType() == spawner_modern
        container:Remove(spawner)

        if (isModern and modernEnabled) or (not isModern and pre1993Enabled) then
            local pool = isModern and p.modern or p.pre1993
            if #pool > 0 then
                local id = pool[ZombRand(#pool) + 1]
                container:AddItem(module .. "." .. id)
            end
        end
    end
end

Events.OnFillContainer.Add(OnFillContainer)