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
    -- self:drawText(item.item.id, self.width / 2, y + 4, 0.6, 0.6, 0.6, 1, UIFont.Small)
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
    local function add(dir)
        local info = getModInfo(dir)
        if info then
            local id = info:getId()
            table.insert(self.allMods, {
                name = stripTag(info:getName()),
                id = id,
                enabled = active:isModActive(id),
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

function ModLoaderWindow:apply()
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
    self.applyBtn = ISButton:new(self.width - 110, self.height - 34, 100, 28, "Apply", self, ModLoaderWindow.apply)
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
    self.applyBtn:setX(self.width - 118)
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

    local text = string.format("Loaded: %d volumes (%d items)  |  Selected: %d/%d submods",
        self.loadedVolumes or 0, self.loadedItems or 0, enabled, #(self.allMods or {}))
    self:drawText(text, 235, self.height - 42, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function ModLoaderWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
    ModLoaderWindow.instance = nil
end

function ModLoaderWindow.open()
    if ModLoaderWindow.instance then
        ModLoaderWindow.instance:close()
        return
    end
    local w, h = 750, 440
    local core = getCore()
    local win = ModLoaderWindow:new((core:getScreenWidth() - w) / 2, (core:getScreenHeight() - h) / 2, w, h)
    win:initialise()
    win:addToUIManager()
    win:setAlwaysOnTop(true)
    win:bringToTop()
    win.resizable = true
    win:setTitle("Read Your Manga Submod Manager")
    ModLoaderWindow.instance = win
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