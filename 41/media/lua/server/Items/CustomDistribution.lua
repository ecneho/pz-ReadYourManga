Options = {
  ["SpawnChance"] = 0.0,
  ["AllowModern"] = false,
  ["AllowPre1993"] = false,
  ["IgnoreRoomType"] = false,
  ["RollCount"] = 0
}

SpawnRooms = {}
SpawnContainers = {}

function table.contains(table, element)
	for _, value in pairs(table) do
	  if value == element then
		  return true
	  end
	end
	return false
end

function RollSpawn(chance) -- get roll status
  local roll = ZombRand(10001) / 100
  if roll < chance then
    return true
  else
    return false
  end
end

function GenModern()  -- get random manga id from modern pack
  return "mangamodern_" .. ZombRand(2323)+1
end

function GenPre1993() -- get random manga id from pre1993 pack
  return "mangapre1993_" .. ZombRand(390) + 1
end

---@param roomType string
---@param containerType string
---@param container ItemContainer
local function OnFillContainer(roomType, containerType, container)
  local function generateID()
    local availableMethods = {}

    if Options["AllowModern"] then -- add modern manga pool
      table.insert(availableMethods, GenModern)
    end

    if Options["AllowPre1993"] then -- add pre1993 manga pool
      table.insert(availableMethods, GenPre1993)
    end

    if #availableMethods > 0 then
      return availableMethods[ZombRand(#availableMethods)+1]() -- select random allowed manga pool
    else
      return nil
    end
  end

  for _ = 1, Options["RollCount"] do
    if Options["IgnoreRoomType"] == true or table.contains(SpawnRooms, roomType) then
      if table.contains(SpawnContainers, containerType) then
        if RollSpawn(Options["SpawnChance"]) then
          local id = generateID()
          if id ~= nil then
            container:AddItem("mangaItems."..id)
          end
        end
      end
    end
  end
end

Events.OnFillContainer.Add(OnFillContainer)

function InitSpawnRooms()
  Options["SpawnChance"]    = SandboxVars.ReadYourManga.SpawnChance
  Options["AllowModern"]    = SandboxVars.ReadYourManga.AllowModern
  Options["AllowPre1993"]   = SandboxVars.ReadYourManga.AllowPre1993
  Options["IgnoreRoomType"] = SandboxVars.ReadYourManga.IgnoreRoomType
  Options["RollCount"]      = SandboxVars.ReadYourManga.RollCount

  local rooms = {}
  for word in string.gmatch(SandboxVars.ReadYourManga.SpawnRooms, "[^;]+") do
    word = word:match("^%s*(.-)%s*$")
    table.insert(rooms, word)
  end
  SpawnRooms = rooms

  local containers = {}
  for word in string.gmatch(SandboxVars.ReadYourManga.SpawnContainers, "[^;]+") do
    word = word:match("^%s*(.-)%s*$")
    table.insert(containers, word)
  end
  SpawnContainers = containers
end

function InitSpawnRoomsSP()
  if not isClient() and not isServer() then
      InitSpawnRooms()
  end
end

Events.OnServerStarted.Add(InitSpawnRooms)
Events.OnGameStart.Add(InitSpawnRoomsSP)