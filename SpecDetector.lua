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
    -- Additional classes can be added here when their presets are written.
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

CH:RegisterEvent("INIT", function()
    CH:DetectSpec()
    CH.activeSpec = CH:GetActiveSpec()
end)

CH:RegisterEvent("TALENTS_CHANGED", function()
    local prev = CH:GetActiveSpec()
    CH:DetectSpec()
    local new = CH:GetActiveSpec()
    if new ~= prev then
        CH.activeSpec = new
        CH:FireEvent("SPEC_CHANGED", new)
    end
end)
