local original_perform = ISReadABook.perform

function ISReadABook:perform()
    if self.item:getModule() == "mangaItems" then
        self.character:setReading(false);
        self.item:getContainer():setDrawDirty(true);
        self.item:setJobDelta(0.0);
    
        if not SkillBook[self.item:getSkillTrained()] then
            self.character:ReadLiterature(self.item);
        elseif self.item:getAlreadyReadPages() >= self.item:getNumberOfPages() then
            self.item:setAlreadyReadPages(0);
        end
    
        self.character:playSound("CloseBook")
    
        local manga = self.item:getDisplayName()
        local readManga = self.character:getModData().readManga or {}
        if not table.contains(readManga, manga) then
            table.insert(readManga, manga)
            self.character:getModData().readManga = readManga
        end
    
        if SandboxVars.ReadYourManga.ConsumeOnUse then
            self.character:getInventory():Remove(self.item)
        end
    
        ISBaseTimedAction.perform(self);
    else
        original_perform(self)
    end
end