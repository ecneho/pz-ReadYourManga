require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"

ModLoaderWindow = ISCollapsableWindow:derive("ModLoaderWindow")

function ModLoaderWindow:drawItem(y, item, alt)
    if alt then
        self:drawRect(0, y, self.width, self.itemheight, 0.1, 1, 1, 1)
    end
    self:drawRectBorder(8, y + 4, 16, 16, 1, 0.7, 0.7, 0.7)
    if item.item.enabled then
        self:drawRect(11, y + 7, 10, 10, 1, 0.2, 0.9, 0.2)
    end
    self:drawText(item.text, 34, y + 4, 1, 1, 1, 1, UIFont.Small)
    local tag = item.item.workshopId and ("WS " .. item.item.workshopId) or "local"
    self:drawTextRight(tag, self.width - 24, y + 4, 0.6, 0.6, 0.6, 1, UIFont.Small)
    return y + self.itemheight
end

local function onListMouseDown(self, x, y)
    local row = self:rowAt(x, y)
    if row and row > 0 and self.items[row] then
        local data = self.items[row].item
        data.enabled = not data.enabled
    end
end

local HIDE_TAG = "[To hide this mod - Enable Read Your Manga: Core] "

local function stripTag(name)
    local s, e = string.find(name, HIDE_TAG, 1, true)
    if not s then return name end
    return string.sub(name, 1, s - 1) .. string.sub(name, e + 1)
end

local ITEM_MODULE = "mangaItems"

local function countLoadedManga()
    local volumes, items = 0, 0
    local seen = {}
    local all = getScriptManager():getAllItems()
    for i = 0, all:size() - 1 do
        local script = all:get(i)
        if script:getModuleName() == ITEM_MODULE then
            local name = script:getName()
            items = items + 1
            local base = (string.gsub(name, "_[sl]$", ""))
            if not seen[base] then
                seen[base] = true
                volumes = volumes + 1
            end
        end
    end
    return volumes, items
end

function ModLoaderWindow:populate()
    self.loadedVolumes, self.loadedItems = countLoadedManga()
    self.allMods = {}
    ModLoaderShowAll = true
    local dirs = getModDirectoryTable()
    ModLoaderShowAll = false
    local active = ActiveMods.getById("default")
    local serverSet
    self.originalOrder = {}
    if self.serverWin then
        serverSet = {}
        for _, it in ipairs(self.serverWin.listbox.items) do
            serverSet[it.item.modID] = true
            table.insert(self.originalOrder, it.item.modID)
        end
    end
    local function add(dir)
        local info = getModInfo(dir)
        if info then
            local id = info:getId()
            local ok, wid = pcall(function() return info:getWorkshopID() end)
            if not ok or wid == nil or wid == "" then wid = nil else wid = tostring(wid) end
            local on
            if serverSet then on = serverSet[id] == true else on = active:isModActive(id) end
            table.insert(self.allMods, {
                name = stripTag(info:getName()),
                id = id,
                enabled = on,
                workshopId = wid,
                info = info,
            })
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
    table.sort(self.allMods, function(a, b)
        local an, bn = string.lower(a.name), string.lower(b.name)
        if an ~= bn then return an < bn end
        return a.id < b.id
    end)
    self:refresh()
end

function ModLoaderWindow:applyToServer()
    local cmw = self.serverWin
    local settings = cmw and cmw.settings
    if not settings then
        self:close()
        return
    end
    local opts = settings:getServerOptions()

    local byId = {}
    for _, d in ipairs(self.allMods) do byId[d.id] = d end
    local ids, seen = {}, {}
    local function addId(id)
        if not seen[id] then
            seen[id] = true
            table.insert(ids, id)
        end
    end
    for _, id in ipairs(self.originalOrder or {}) do
        local d = byId[id]
        if d == nil or d.enabled then addId(id) end
    end
    for _, d in ipairs(self.allMods) do
        if d.enabled then addId(d.id) end
    end

    local managed, wanted = {}, {}
    for _, d in ipairs(self.allMods) do
        if d.workshopId then
            managed[d.workshopId] = true
            if d.enabled then wanted[d.workshopId] = true end
        end
    end
    local wsOpt = opts:getOptionByName("WorkshopItems")
    local ws, wsSeen = {}, {}
    local function addWs(id)
        if id ~= "" and not wsSeen[id] then
            wsSeen[id] = true
            table.insert(ws, id)
        end
    end
    for _, id in ipairs(string.split(wsOpt:getValue() or "", ";")) do
        if not managed[id] or wanted[id] then addWs(id) end
    end
    for _, d in ipairs(self.allMods) do
        if d.enabled and d.workshopId then addWs(d.workshopId) end
    end

    opts:getOptionByName("Mods"):setValue(table.concat(ids, ";"))
    wsOpt:setValue(table.concat(ws, ";"))
    settings:saveFiles()

    for _, d in ipairs(self.allMods) do
        if cmw.modInfoByID and d.info then cmw.modInfoByID[d.id] = d.info end
    end
    cmw.listbox:clear()
    for _, id in ipairs(ids) do
        cmw:addModToList(id)
    end
    self:close()
end

function ModLoaderWindow:apply()
    if self.serverWin then
        return self:applyToServer()
    end
    local active = ActiveMods.getById("default")
    local mods = active.getMods and active:getMods()
    for _, data in ipairs(self.allMods) do
        if data.enabled then
            active:setModActive(data.id, true)
        else
            active:setModActive(data.id, false)
            if mods then
                for _ = 1, 5 do
                    if not mods:contains(data.id) then break end
                    mods:remove(data.id)
                end
            end
        end
    end
    ActiveMods.setLoadedMods(active)
    if saveModsFile then
        saveModsFile()
    end
    self:close()
    getCore():ResetLua("default", "modsChanged")
end

local SEARCH_LABEL_W = 50

function ModLoaderWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local win = self
    self.search = ISTextEntryBox:new("", 8 + SEARCH_LABEL_W, th + 6, self.width - 16 - SEARCH_LABEL_W, 24)
    self.search:initialise()
    self.search:instantiate()
    self:addChild(self.search)
    self.list = ISScrollingListBox:new(0, th + 36, self.width, self.height - th - 76)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 24
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self.list.doDrawItem = ModLoaderWindow.drawItem
    self.list.onMouseDown = onListMouseDown
    self:addChild(self.list)
    local applyW = self.serverWin and 150 or 100
    local applyText = self.serverWin and "Apply to server" or "Apply"
    self.applyBtn = ISButton:new(self.width - applyW - 10, self.height - 34, applyW, 28, applyText, self, ModLoaderWindow.apply)
    self.applyBtn:initialise()
    self.applyBtn:instantiate()
    self:addChild(self.applyBtn)
    self.enableBtn = ISButton:new(10, self.height - 48, 100, 28, "Enable all", self, ModLoaderWindow.enableAll)
    self.enableBtn:initialise()
    self.enableBtn:instantiate()
    self:addChild(self.enableBtn)
    self.disableBtn = ISButton:new(120, self.height - 48, 100, 28, "Disable all", self, ModLoaderWindow.disableAll)
    self.disableBtn:initialise()
    self.disableBtn:instantiate()
    self:addChild(self.disableBtn)
    self:populate()
end

function ModLoaderWindow:refresh()
    self.list:clear()
    local q = string.lower(self.lastQuery or "")
    for _, data in ipairs(self.allMods) do
        if q == "" or string.find(string.lower(data.name), q, 1, true) or string.find(string.lower(data.id), q, 1, true) then
            self.list:addItem(data.name, data)
        end
    end
end

function ModLoaderWindow:prerender()
    ISCollapsableWindow.prerender(self)

    local th = self:titleBarHeight()
    self.search:setWidth(self.width - 16 - SEARCH_LABEL_W)
    self.list:setWidth(self.width)
    self.list:setHeight(self.height - th - 90)
    self.applyBtn:setX(self.width - self.applyBtn.width - 18)
    self.applyBtn:setY(self.height - 48)
    self.enableBtn:setY(self.height - 48)
    self.disableBtn:setY(self.height - 48)
    local t = self.search:getInternalText()
    if t ~= self.lastQuery then
        self.lastQuery = t
        self:refresh()
    end
end

function ModLoaderWindow:render()
    ISCollapsableWindow.render(self)

    local th = self:titleBarHeight()
    local fh = getTextManager():getFontHeight(UIFont.Small)
    self:drawText("Search:", 8, th + 6 + (24 - fh) / 2, 1, 1, 1, 1, UIFont.Small)

    local enabled = 0
    for _, data in ipairs(self.allMods or {}) do
        if data.enabled then enabled = enabled + 1 end
    end

    local text
    if self.serverWin then
        local wsCount, wsSeen = 0, {}
        for _, data in ipairs(self.allMods or {}) do
            if data.enabled and data.workshopId and not wsSeen[data.workshopId] then
                wsSeen[data.workshopId] = true
                wsCount = wsCount + 1
            end
        end
        text = string.format("Server: %d/%d mods  |  %d workshop items", enabled, #(self.allMods or {}), wsCount)
    else
        text = string.format("Loaded: %d volumes (%d items)  |  Selected: %d/%d submods",
            self.loadedVolumes or 0, self.loadedItems or 0, enabled, #(self.allMods or {}))
    end
    self:drawText(text, 235, self.height - 42, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function ModLoaderWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
    ModLoaderWindow.instance = nil
end

local function openWindow(serverWin)
    if ModLoaderWindow.instance then
        ModLoaderWindow.instance:close()
        return
    end
    local w, h = 750, 440
    local core = getCore()
    local win = ModLoaderWindow:new((core:getScreenWidth() - w) / 2, (core:getScreenHeight() - h) / 2, w, h)
    win.serverWin = serverWin
    win:initialise()
    win:addToUIManager()
    win:setAlwaysOnTop(true)
    win:bringToTop()
    win.resizable = true
    win:setTitle(serverWin and "Read Your Manga - Server Mod Selection" or "Read Your Manga Submod Manager")
    ModLoaderWindow.instance = win
end

function ModLoaderWindow.open()
    openWindow(nil)
end

function ModLoaderWindow.openServer(chooseModsWindow)
    openWindow(chooseModsWindow)
end

local function otherScreenOpen()
    if ModSelector and ModSelector.instance and ModSelector.instance:isVisible() then
        return true
    end

    local main = MainScreen.instance
    if not main or not main.children then return false end

    local core = getCore()
    local sw, sh = core:getScreenWidth(), core:getScreenHeight()

    for _, child in pairs(main.children) do
        if child ~= ModLoaderWindow.button
            and child.isVisible and child:isVisible()
            and child.width and child.height
            and child.width >= sw * 0.6 and child.height >= sh * 0.6 then
            return true
        end
    end
    return false
end

local function addButton()
    if ModLoaderWindow.button then
        return
    end

    local btn = ISButton:new(20, 20, 140, 30, "Read Your Manga", nil, ModLoaderWindow.open)
    btn:initialise()
    btn:instantiate()

    local basePrerender  = btn.prerender
    local baseRender     = btn.render
    local baseMouseDown  = btn.onMouseDown
    local baseMouseUp    = btn.onMouseUp
    local baseMouseMove  = btn.onMouseMove

    function btn:prerender()
        self.hiddenByScreen = otherScreenOpen()
        if self.hiddenByScreen then return end
        basePrerender(self)
    end

    function btn:render()
        if self.hiddenByScreen then return end
        baseRender(self)
    end

    function btn:onMouseDown(x, y)
        if self.hiddenByScreen then return false end
        return baseMouseDown(self, x, y)
    end

    function btn:onMouseUp(x, y)
        if self.hiddenByScreen then return false end
        return baseMouseUp(self, x, y)
    end

    function btn:onMouseMove(dx, dy)
        if self.hiddenByScreen then return false end
        return baseMouseMove(self, dx, dy)
    end

    MainScreen.instance:addChild(btn)
    ModLoaderWindow.button = btn
end

local function removeButton()
    if ModLoaderWindow.button then
        ModLoaderWindow.button:removeFromUIManager()
        if ModLoaderWindow.button.parent then
            ModLoaderWindow.button.parent:removeChild(ModLoaderWindow.button)
        end
        ModLoaderWindow.button = nil
    end
end

function ModLoaderWindow:enableAll()
    for _, data in ipairs(self.allMods) do
        data.enabled = true
    end
end

function ModLoaderWindow:disableAll()
    for _, data in ipairs(self.allMods) do
        data.enabled = false
    end
end

function ModLoaderWindow:onMouseDown(x, y)
    self:bringToTop()
    return ISCollapsableWindow.onMouseDown(self, x, y)
end

Events.OnMainMenuEnter.Add(addButton)
Events.OnGameStart.Add(removeButton)

local infoCache
local function resolveInfo(id)
    local ok, info = pcall(getModInfoByID, id)
    if ok and info then return info end
    if not infoCache then
        infoCache = {}
        ModLoaderShowAll = true
        local dirs = getModDirectoryTable()
        ModLoaderShowAll = false
        for _, dir in ipairs(dirs) do
            local mi = getModInfo(dir)
            if mi then infoCache[mi:getId()] = mi end
        end
    end
    return infoCache[id]
end

local function patchListBox(lb)
    if not lb or lb.mangaPatched then return end
    lb.mangaPatched = true
    local base = lb.doDrawItem
    lb.doDrawItem = function(self, y, item, alt)
        local d = item and item.item
        if d and d.modID then
            if not d.modInfo then d.modInfo = resolveInfo(d.modID) end
            if d.modInfo then
                item.text = stripTag(d.modInfo:getName())
            else
                item.text = stripTag(item.text)
            end
        elseif item and item.text then
            item.text = stripTag(item.text)
        end
        return base(self, y, item, alt)
    end
end

local function addServerButton(screen)
    local cmw = screen and screen.pageEdit and screen.pageEdit.chooseModsWindow
    if cmw then patchListBox(cmw.listbox) end
    if screen and screen.pageEdit and screen.pageEdit.customui then
        for _, panel in ipairs(screen.pageEdit.customui) do
            if panel.Type == "ServerSettingsScreenModsPanel" then patchListBox(panel.listbox) end
        end
    end
    if not cmw or cmw.mangaButton or not cmw.buttonMods then return end
    local btn = ISButton:new(cmw.buttonMods.x + cmw.buttonMods.width + 10, cmw.buttonMods.y,
        150, cmw.buttonMods.height, "Read Your Manga", cmw, ModLoaderWindow.openServer)
    btn:initialise()
    btn:instantiate()
    btn:setAnchorLeft(true)
    btn:setAnchorTop(false)
    btn:setAnchorBottom(true)
    btn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    cmw:addChild(btn)
    cmw.mangaButton = btn
end

if ServerSettingsScreen and not ServerSettingsScreen.mangaHooked then
    ServerSettingsScreen.mangaHooked = true
    local baseAboutToShow = ServerSettingsScreen.aboutToShow
    function ServerSettingsScreen:aboutToShow()
        baseAboutToShow(self)
        addServerButton(self)
    end
end