require "TimedActions/ISBaseTimedAction"

ISMangaSwapAction = ISBaseTimedAction:derive("ISMangaSwapAction")

local MODULE = "mangaItems"

local function getSwappedType(fullType)
    local suffix = fullType:sub(-2)
    if suffix == "_s" then
        return fullType:sub(1, -3) .. "_l"
    elseif suffix == "_l" then
        return fullType:sub(1, -3) .. "_s"
    end
    return nil
end

function ISMangaSwapAction:isValid()
    if isClient() and self.item then
        return true
    end
    return self.item ~= nil and self.item:getContainer() ~= nil
end

function ISMangaSwapAction:update()
end

function ISMangaSwapAction:start()
end

function ISMangaSwapAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISMangaSwapAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISMangaSwapAction:complete()
    local item = self.item
    if not item or item:getModule() ~= MODULE then return false end

    local newType = getSwappedType(item:getFullType())
    if not newType then return false end

    local container = item:getContainer()
    if not container then return false end

    local newItem = instanceItem(newType)
    if not newItem then return false end

    newItem:setCondition(item:getCondition())
    newItem:setFavorite(item:isFavorite())

    container:Remove(item)
    container:AddItem(newItem)

    if isServer() then
        sendRemoveItemFromContainer(container, item)
        sendAddItemToContainer(container, newItem)
    end

    return true
end

function ISMangaSwapAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.stopOnWalk = false
    o.stopOnRun = false
    o.stopOnAim = false
    o.maxTime = 1
    return o
end
