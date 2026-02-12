Options = {
  ["SpawnChance"] = 0.0,
  ["AllowModern"] = false,
  ["AllowPre1993"] = false,
  ["IgnoreRoomType"] = false,
  ["RollCount"] = 0
}

SpawnRooms = {}
SpawnContainers = {}
SpawnCandidates = {}

function table.contains(table, element)
	for _, value in pairs(table) do
	  if value == element then
		  return true
	  end
	end
	return false
end

function RollSpawn(chance)
  local roll = ZombRand(10001) / 100
  if roll < chance then
    return true
  else
    return false
  end
end

---@param roomType string
---@param containerType string
---@param container ItemContainer
local function OnFillContainer(roomType, containerType, container)
  for _ = 1, Options["RollCount"] do
    if Options["IgnoreRoomType"] == true or table.contains(SpawnRooms, roomType) then
      if table.contains(SpawnContainers, containerType) then
        if RollSpawn(Options["SpawnChance"]) then
          local id = SpawnCandidates[ZombRand(#SpawnCandidates)+1]
          if id ~= nil then
            container:AddItem("mangaItems."..id)
          end
        end
      end
    end
  end
end

Events.OnFillContainer.Add(OnFillContainer)

function InitSpawnData()
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

  local candidates = {}
  local items = getScriptManager():getAllItems()
  for i = 0, items:size() - 1 do
      local item = items:get(i)
      if item:getModuleName() == "mangaItems" then
          local name = item:getName()
          if string.find(name, "_m_") and Options["AllowModern"] then
              table.insert(candidates, name)
          elseif string.find(name, "_c_") and Options["AllowPre1993"] then
              table.insert(candidates, name)
          end
      end
  end
  SpawnCandidates = candidates
end

function InitSpawnDataSP()
  if not isClient() and not isServer() then
      InitSpawnData()
  end
end

Events.OnServerStarted.Add(InitSpawnData)
Events.OnGameStart.Add(InitSpawnDataSP)