local module = "mangaItems"

-- each 1.0 => 100% of 1 item
local RULES = {
    -- comic stores
    { "comic",      "counter",      0.80 },
    { "comic",      "display",      1.00 },
    { "comic",      "rack",         1.00 },
    { "comic",      "shelf",        1.50 },
    { "comic",      "shelves",      1.50 },
    { "comic",      "crate",        1.00 },
    { "comic",      nil,            0.80 },

    -- book stores
    { "bookstore",  "counter",      0.50 },
    { "bookstore",  "rack",         0.80 },
    { "bookstore",  "shelf",        0.80 },
    { "bookstore",  "shelves",      0.80 },
    { "bookstore",  nil,            0.50 },

    -- libraries
    { "library",    "counter",      0.40 },
    { "library",    "rack",         0.60 },
    { "library",    "shelf",        0.80 },
    { "library",    "shelves",      0.80 },
    { "library",    "bookcase",     0.80 },
    { "library",    nil,            0.40 },

    -- schools
    { "classroom",  "desk",         0.30 },
    { "classroom",  "shelf",        0.40 },
    { "classroom",  "shelves",      0.40 },
    { "classroom",  nil,            0.15 },
    { "daycare",    nil,            0.30 },
    { "school",     "locker",       0.35 },
    { "school",     nil,            0.20 },

    -- homes
    { "bedroom",    "sidetable",    0.30 },
    { "bedroom",    "shelf",        0.30 },
    { "bedroom",    "shelves",      0.30 },
    { "bedroom",    "desk",         0.30 },
    { "bedroom",    "dresser",      0.15 },
    { "bedroom",    "wardrobe",     0.10 },
    { "bedroom",    nil,            0.10 },
    { "livingroom", "shelf",        0.35 },
    { "livingroom", "shelves",      0.35 },
    { "livingroom", "sidetable",    0.25 },
    { "livingroom", "rack",         0.50 },
    { "livingroom", nil,            0.10 },
    { "bathroom",   "shelf",        0.15 },
    { "bathroom",   "shelves",      0.15 },
    { "closet",     "shelf",        0.15 },
    { "closet",     "shelves",      0.15 },

    -- misc
    { "postoffice", nil,            0.20 },
    { "cafe",       nil,            0.20 },
    { "salon",      "rack",         0.40 },
    { "hospital",   "rack",         0.40 },
    { "waiting",    nil,            0.30 },
    { "movierental",nil,            0.30 },
    { "breakroom",  nil,            0.10 },
    { "office",     "desk",         0.20 },

    -- anywhere else
    { nil,          "magazinerack", 0.80 },
    { nil,          "rack",         0.50 },
    { nil,          "bookcase",     0.40 },
    { nil,          "crate",        0.25 },
    { nil,          "locker",       0.10 },
    { nil,          "shelf",        0.10 },
    { nil,          "shelves",      0.10 },
    { nil,          "desk",         0.10 },
    { nil,          "sidetable",    0.10 },
}

local function readBoolOption(name)
    local vars = SandboxVars and SandboxVars.ReadYourManga
    if vars and vars[name] ~= nil then
        return vars[name] == true
    end
    return true
end

local SPAWN_RATES = { 0, 0.25, 0.5, 1, 1.5, 2, 3, 5, 10 }

local function spawnRate()
    local vars = SandboxVars and SandboxVars.ReadYourManga
    local level = vars and tonumber(vars.SpawnAmountRate)
    return SPAWN_RATES[level] or 1
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

local function findExpected(room, containerType)
    for _, rule in ipairs(RULES) do
        local roomPat, contPat, expected = rule[1], rule[2], rule[3]
        local roomOk = (roomPat == nil) or string.find(room, roomPat, 1, true)
        local contOk = (contPat == nil) or string.find(containerType, contPat, 1, true)
        if roomOk and contOk then
            return expected
        end
    end
    return 0
end

local function rollCount(expected)
    local count = math.floor(expected)
    local frac = expected - count
    if frac > 0 and ZombRand(1000) < frac * 1000 then
        count = count + 1
    end
    return count
end

local function OnFillContainer(roomType, containerType, container)
    local room = string.lower(tostring(roomType or ""))
    local ctype = string.lower(tostring(containerType or ""))

    local expected = findExpected(room, ctype) * spawnRate()
    if expected <= 0 then return end

    local count = rollCount(expected)
    if count <= 0 then return end

    local p = buildPools()

    local choices = {}
    if readBoolOption("AllowModern") and #p.modern > 0 then
        table.insert(choices, p.modern)
    end
    if readBoolOption("AllowPre1993") and #p.pre1993 > 0 then
        table.insert(choices, p.pre1993)
    end
    if #choices == 0 then return end

    for _ = 1, count do
        local pool = choices[ZombRand(#choices) + 1]
        local id = pool[ZombRand(#pool) + 1]
        container:AddItem(module .. "." .. id)
    end
end

Events.OnFillContainer.Add(OnFillContainer)