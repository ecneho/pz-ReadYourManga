local hiddenPrefix = "RyM_"
if not ModLoaderOriginalDirs then
    ModLoaderOriginalDirs = getModDirectoryTable
end
local original = ModLoaderOriginalDirs

getModDirectoryTable = function()
    local dirs = original()
    local result = {}
    local function add(dir)
        local info = getModInfo(dir)
        if info then
            local prefixed = string.sub(info:getId(), 1, #hiddenPrefix) == hiddenPrefix
            if prefixed == (ModLoaderShowAll == true) then
                table.insert(result, dir)
            end
        end
    end
    if type(dirs) == "table" then
        for _, dir in pairs(dirs) do
            add(dir)
        end
    else
        for i = 0, dirs:size() - 1 do
            add(dirs:get(i))
        end
    end
    return result
end