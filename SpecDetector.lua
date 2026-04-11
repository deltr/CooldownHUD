-------------------------------------------------------------------------------
-- CooldownHUD - SpecDetector.lua
-- Talent-tree spec detection with manual override support
-------------------------------------------------------------------------------

local CH = CooldownHUD

-------------------------------------------------------------------------------
-- Tree name mapping per class
-- Only PALADIN trees are needed for the initial preset set, but the structure
-- is open to extension for other classes.
-------------------------------------------------------------------------------

local TREE_NAMES = {
    PALADIN = { "Holy", "Protection", "Retribution" },
    DRUID   = { "Balance", "Feral", "Restoration" },
    WARRIOR = { "Arms", "Fury", "Protection" },
    MAGE    = { "Arcane", "Fire", "Frost" },
    WARLOCK = { "Affliction", "Demonology", "Destruction" },
    PRIEST  = { "Discipline", "Holy", "Shadow" },
    ROGUE   = { "Assassination", "Combat", "Subtlety" },
    HUNTER  = { "Beast Mastery", "Marksmanship", "Survival" },
    SHAMAN  = { "Elemental", "Enhancement", "Restoration" },
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

CH.detectedSpec = nil   -- auto-detected spec name (string)
CH.activeSpec   = nil   -- resolved spec name (override or detected)

-------------------------------------------------------------------------------
-- Detect the dominant talent tree
-------------------------------------------------------------------------------

function CH:DetectSpec()
    local trees = TREE_NAMES[self.playerClass]
    if not trees then
        self.detectedSpec = nil
        return
    end

    local numTabs = GetNumTalentTabs()
    if not numTabs or numTabs == 0 then
        -- Talent data not yet available; default to last tree
        self.detectedSpec = trees[table.getn(trees)]
        return
    end

    local bestTree  = table.getn(trees)   -- default: last tree (Retribution for Paladin)
    local bestCount = -1
    local tie       = false

    for tab = 1, numTabs do
        local tabTotal = 0
        local numTalents = GetNumTalents(tab)
        if numTalents then
            for t = 1, numTalents do
                local _, _, _, _, rank = GetTalentInfo(tab, t)
                if rank then
                    tabTotal = tabTotal + rank
                end
            end
        end

        if tabTotal > bestCount then
            bestCount = tabTotal
            bestTree  = tab
            tie       = false
        elseif tabTotal == bestCount then
            tie = true
        end
    end

    -- On a tie default to the last tree (index = table.getn(trees))
    if tie then
        bestTree = table.getn(trees)
    end

    self.detectedSpec = trees[bestTree]
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

-- Returns the active spec: manual override (db.spec) if set, else detectedSpec.
function CH:GetActiveSpec()
    if self.db and self.db.spec and self.db.spec ~= "" then
        return self.db.spec
    end
    return self.detectedSpec
end

-- Sets (or clears) a manual spec override and fires SPEC_CHANGED if it changed.
function CH:SetSpecOverride(specName)
    local prev = self:GetActiveSpec()
    if self.db then
        self.db.spec = (specName ~= "" and specName) or nil
    end
    local new = self:GetActiveSpec()
    if new ~= prev then
        self.activeSpec = new
        self:FireEvent("SPEC_CHANGED", new)
    end
end

-- Returns the list of spec names available for the current player class.
function CH:GetSpecNames()
    if not self.playerClass then return {} end
    return TREE_NAMES[self.playerClass] or {}
end

-------------------------------------------------------------------------------
-- Hook into the internal event bus
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Key-spell fallback detection
-- When talent point counts are unreliable (e.g. right after respec), check
-- for signature spells that are only available in specific specs.
-------------------------------------------------------------------------------

local KEY_SPELLS = {
    PALADIN = {
        { spell = "Holy Shock",      spec = "Holy" },
        { spell = "Holy Shield",     spec = "Protection" },
        { spell = "Repentance",      spec = "Retribution" },
        { spell = "Crusader Strike", spec = "Retribution" },
        { spell = "Avenger's Shield", spec = "Protection" },
    },
    DRUID = {
        { spell = "Swiftmend",         spec = "Restoration" },
        { spell = "Nature's Swiftness", spec = "Restoration" },
        { spell = "Feral Charge",      spec = "Feral" },
    },
    WARRIOR = {
        { spell = "Mortal Strike",    spec = "Arms" },
        { spell = "Bloodthirst",      spec = "Fury" },
        { spell = "Shield Slam",      spec = "Protection" },
    },
    MAGE = {
        { spell = "Arcane Power",     spec = "Arcane" },
        { spell = "Presence of Mind", spec = "Arcane" },
        { spell = "Combustion",       spec = "Fire" },
        { spell = "Ice Barrier",      spec = "Frost" },
    },
    WARLOCK = {
        { spell = "Dark Harvest",  spec = "Affliction" },
        { spell = "Conflagrate",   spec = "Destruction" },
        { spell = "Shadowfury",    spec = "Destruction" },
        { spell = "Fel Domination", spec = "Demonology" },
    },
    PRIEST = {
        { spell = "Power Infusion", spec = "Discipline" },
        { spell = "Silence",        spec = "Shadow" },
        { spell = "Pain Spike",     spec = "Shadow" },
    },
    ROGUE = {
        { spell = "Cold Blood",      spec = "Assassination" },
        { spell = "Adrenaline Rush",  spec = "Combat" },
        { spell = "Preparation",      spec = "Subtlety" },
    },
    HUNTER = {
        { spell = "Bestial Wrath",  spec = "Beast Mastery" },
        { spell = "Intimidation",   spec = "Beast Mastery" },
        { spell = "Scatter Shot",   spec = "Marksmanship" },
        { spell = "Deterrence",     spec = "Survival" },
    },
    SHAMAN = {
        { spell = "Elemental Mastery", spec = "Elemental" },
        { spell = "Stormstrike",       spec = "Enhancement" },
        { spell = "Nature's Swiftness", spec = "Restoration" },
    },
}

function CH:DetectSpecByKeySpells()
    local class = self.playerClass
    if not class or not KEY_SPELLS[class] then return nil end
    for _, entry in ipairs(KEY_SPELLS[class]) do
        if self:FindSpell(entry.spell) then
            return entry.spec
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Combined detection: try talents first, fall back to key spells
-------------------------------------------------------------------------------

local function RunDetection()
    local prev = CH:GetActiveSpec()
    CH:DetectSpec()
    -- If talent detection is ambiguous or tied, try key-spell fallback
    local keySpec = CH:DetectSpecByKeySpells()
    if keySpec and keySpec ~= CH.detectedSpec then
        -- Key spell is more specific than talent-count tie-breaker
        CH.detectedSpec = keySpec
    end
    local new = CH:GetActiveSpec()
    if new ~= prev then
        CH.activeSpec = new
        CH:FireEvent("SPEC_CHANGED", new)
    end
end

-------------------------------------------------------------------------------
-- Hook into the internal event bus
-------------------------------------------------------------------------------

CH:RegisterEvent("INIT", function()
    CH:DetectSpec()
    local keySpec = CH:DetectSpecByKeySpells()
    if keySpec then CH.detectedSpec = keySpec end
    CH.activeSpec = CH:GetActiveSpec()
end)

CH:RegisterEvent("TALENTS_CHANGED", RunDetection)

-- Also re-detect on spellbook changes (fires after respec + trainer visit)
CH:RegisterEvent("SPELLS_CHANGED", RunDetection)
