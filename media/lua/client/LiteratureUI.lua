-- Below is the most of the vanilla UI code.
-- May cause possible compat issues with other mods using this functions.

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local LITERATURE_HIDDEN = {}

function ISLiteratureUI.SetItemHidden(fullType, hidden)
	if type(fullType) ~= 'string' or not string.contains(fullType, '.') then return end
	LITERATURE_HIDDEN[fullType] = hidden and true or nil
end

ISLiteratureUI.SetItemHidden('Base.BookBlacksmith1', true)
ISLiteratureUI.SetItemHidden('Base.BookBlacksmith2', true)
ISLiteratureUI.SetItemHidden('Base.BookBlacksmith3', true)
ISLiteratureUI.SetItemHidden('Base.BookBlacksmith4', true)
ISLiteratureUI.SetItemHidden('Base.BookBlacksmith5', true)
ISLiteratureUI.SetItemHidden('Base.SmithingMag1', true)
ISLiteratureUI.SetItemHidden('Base.SmithingMag2', true)
ISLiteratureUI.SetItemHidden('Base.SmithingMag3', true)
ISLiteratureUI.SetItemHidden('Base.SmithingMag4', true)

local original_draw = ISLiteratureList.doDrawItem

function ISLiteratureList:doDrawItem(y, item, alt)
    if not item.item:getModule():getName() == "mangaItems" then
        original_draw(self)
    end

	if y + self:getYScroll() >= self.height then return y + item.height end
	if y + item.height + self:getYScroll() <= 0 then return y + item.height end
	self:drawRectBorder(0, y, self:getWidth(), item.height, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)

	local texture = item.item:getNormalTexture()
	if texture then
		local texWidth = texture:getWidthOrig()
		local texHeight = texture:getHeightOrig()
		local a = 1
		if texWidth <= 32 and texHeight <= 32 then
			self:drawTexture(texture,6+(32-texWidth)/2,y+(item.height-texHeight)/2,a,1,1,1)
		else
			self:drawTextureScaledAspect(texture,6,y+(item.height-texHeight)/2,32,32,a,1,1,1)
		end
	end

	local itemPadY = (item.height - self.fontHgt) / 2
	local r,g,b,a = 0.5,0.5,0.5,1.0
	local readManga = self.character:getModData().readManga or {}

    if (table.contains(readManga, item.item:getDisplayName())) then
        r,g,b = 1.0,1.0,1.0
    end
	self:drawText(item.text, 6 + 32 + 6, y+itemPadY, r, g, b, a, self.font)

	y = y + item.height
	return y;
end

function ISLiteratureUI:createChildren()
	ISCollapsableWindowJoypad.createChildren(self)

	local th = self:titleBarHeight()
	local rh = self:resizeWidgetHeight()

	self.tabs = ISTabPanel:new(0, th, self.width, self.height-th-rh)
	self.tabs:setAnchorRight(true)
	self.tabs:setAnchorBottom(true)
	self.tabs:setEqualTabWidth(false)
	self:addChild(self.tabs)

	-- BOOKS

	local listbox1 = ISLiteratureList:new(0, 0, self.tabs.width, self.tabs.height - self.tabs.tabHeight, self.character)
	listbox1:setAnchorRight(true)
	listbox1:setAnchorBottom(true)
	listbox1:setFont(UIFont.Small, 2)
	listbox1.itemheight = math.max(32, FONT_HGT_SMALL) + 2 * 2
	self.tabs:addView(getText("IGUI_LiteratureUI_Skills"), listbox1)
	self.listbox1 = listbox1

	-- RECIPES

	local listbox2 = ISLiteratureList:new(0, 0, self.width, self.tabs.height - self.tabs.tabHeight, self.character)
	listbox2:setAnchorRight(true)
	listbox2:setAnchorBottom(true)
	listbox2:setFont(UIFont.Small, 2)
	listbox2.itemheight = math.max(32, FONT_HGT_SMALL) + 2 * 2
	self.tabs:addView(getText("IGUI_LiteratureUI_Recipes"), listbox2)
	self.listbox2 = listbox2

	-- MANGA -- Simon was here :3
	local listboxManga = ISLiteratureList:new(0, 0, self.width, self.tabs.height - self.tabs.tabHeight, self.character)
	listboxManga:setAnchorRight(true)
	listboxManga:setAnchorBottom(true)
	listboxManga:setFont(UIFont.Small, 2)
	listboxManga.itemheight = math.max(32, FONT_HGT_SMALL) + 2 * 2
	self.tabs:addView("Manga", listboxManga)
	self.listboxManga = listboxManga

	-- RECORDED MEDIA

	local categories = getZomboidRadio():getRecordedMedia():getCategories()
	self.listboxMedia = {}
	for i=1,categories:size() do
		local category = categories:get(i-1)
		local listbox3 = ISLiteratureMediaList:new(0, 0, self.width, self.tabs.height - self.tabs.tabHeight, self.character)
		listbox3:setAnchorRight(true)
		listbox3:setAnchorBottom(true)
		listbox3:setFont(UIFont.Small, 2)
		listbox3.itemheight = math.max(32, FONT_HGT_SMALL) + 2 * 2
		self.tabs:addView(getText("IGUI_LiteratureUI_RecordedMedia_"..category), listbox3)
		self.listboxMedia[i] = listbox3
	end

	self.resizeWidget2:bringToTop()
	self.resizeWidget:bringToTop()

	self:setLists()
end

local function getMangaInfo(s)
    local volPos = string.find(s, " Vol.")
    if volPos then
        local title = string.sub(s, 1, volPos - 1)
        local volStr = string.sub(s, volPos + 5)
        local vol = tonumber(volStr) or math.huge
        return vol, title
    else
        return math.huge, s
    end
end

local function mangaSort(a, b)
    local volA, titleA = getMangaInfo(a:getDisplayName())
    local volB, titleB = getMangaInfo(b:getDisplayName())

    if titleA ~= titleB then
        return titleA < titleB
    end

    return volA < volB
end

function ISLiteratureUI:setLists()
	local skillBooks = {}
	local other = {}
	local media = {}
	local manga = {}
	local allItems = getScriptManager():getAllItems()
	for i=1,allItems:size() do
		local item = allItems:get(i-1)
		if item:getType() == Type.Literature then
			if SkillBook[item:getSkillTrained()] then
				table.insert(skillBooks, item)
			elseif item:getTeachedRecipes() ~= nil then
				table.insert(other, item)
			elseif item:getModule():getName() == "mangaItems" and not string.find(item:getFullName(), "-standing") then
				if Options["AllowModern"] == true and string.find(item:getFullName(), "modern") then
					table.insert(manga, item)
				elseif Options["AllowPre1993"] == true and string.find(item:getFullName(), "pre1993") then
					table.insert(manga, item)
				end
			end
		end
		local mediaCategory = item:getRecordedMediaCat()
		if mediaCategory then
			media[mediaCategory] = media[mediaCategory] or {}
			table.insert(media[mediaCategory], item)
		end
	end

	local sortFunc = function(a,b)
		return not string.sort(a:getDisplayName(), b:getDisplayName())
	end

	table.sort(skillBooks, sortFunc)
	self.listbox1:clear()
	for _,item in ipairs(skillBooks) do
		if not LITERATURE_HIDDEN[item:getFullName()] then
			self.listbox1:addItem(item:getDisplayName(), item)
		end
	end

	table.sort(other, sortFunc)
	self.listbox2:clear()
	for _,item in ipairs(other) do
		if not LITERATURE_HIDDEN[item:getFullName()] then
			self.listbox2:addItem(item:getDisplayName(), item)
		end
	end

	-- Simon was here :3
	table.sort(manga, mangaSort)
	self.listboxManga:clear()
	for _,item in ipairs(manga) do
		if not LITERATURE_HIDDEN[item:getFullName()] then
			self.listboxManga:addItem(item:getDisplayName(), item)
		end
	end

	self:setMediaLists(media)
end