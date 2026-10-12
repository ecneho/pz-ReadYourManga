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
    self:drawText(item.item.id, self.width / 2, y + 4, 0.6, 0.6, 0.6, 1, UIFont.Small)
    return y + self.itemheight
end

local function onListMouseDown(self, x, y)
    local row = self:rowAt(x, y)
    if row and row > 0 and self.items[row] then
        local data = self.items[row].item
        data.enabled = not data.enabled
    end
end

function ModLoaderWindow:populate()
    self.allMods = {}
    ModLoaderShowAll = true
    local dirs = getModDirectoryTable()
    ModLoaderShowAll = false
    local active = ActiveMods.getById("default")
    local function add(dir)
        local info = getModInfo(dir)
        if info then
            local id = info:getId()
            table.insert(self.allMods, { name = info:getName(), id = id, enabled = active:isModActive(id) })
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
    self:refresh()
end

function ModLoaderWindow:apply()
    local active = ActiveMods.getById("default")
    local mods = active.getMods and active:getMods()
    if mods then
        mods:clear()
    elseif active.clear then
        active:clear()
    end
    for _, data in ipairs(self.allMods) do
        if data.enabled then
            active:setModActive(data.id, true)
        end
    end
    ActiveMods.setLoadedMods(active)
    if saveModsFile then
        saveModsFile()
    end
    self:close()
    getCore():ResetLua("default", "modsChanged")
end

function ModLoaderWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local win = self
    self.search = ISTextEntryBox:new("", 8, th + 6, self.width - 16, 24)
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
    local t = self.search:getInternalText()
    if t ~= self.lastQuery then
        self.lastQuery = t
        self:refresh()
    end
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
    local w, h = 500, 440
    local core = getCore()
    local win = ModLoaderWindow:new((core:getScreenWidth() - w) / 2, (core:getScreenHeight() - h) / 2, w, h)
    win:initialise()
    win:addToUIManager()
    win:setAlwaysOnTop(true)
    win:bringToTop()
    win.resizable = false
    win:setTitle("Mod Loader")
    ModLoaderWindow.instance = win
end

local function addButton()
    if ModLoaderWindow.button then
        return
    end
    local btn = ISButton:new(20, getCore():getScreenHeight() - 60, 140, 30, "Mod Loader", nil, ModLoaderWindow.open)
    btn:initialise()
    btn:instantiate()
    MainScreen.instance:addChild(btn)
    ModLoaderWindow.button = btn
end

function ModLoaderWindow:onMouseDown(x, y)
    self:bringToTop()
    return ISCollapsableWindow.onMouseDown(self, x, y)
end

Events.OnMainMenuEnter.Add(addButton)