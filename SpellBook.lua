-------------------------------------------------------------------------------
-- CooldownHUD - SpellBook.lua
-- Spellbook scanner with cached name -> index lookups
-------------------------------------------------------------------------------

local CH = CooldownHUD

-- Cache: spellName (string) -> spellbook index (number)
CH.spellCache = {}

-------------------------------------------------------------------------------
-- Scan the entire spellbook and populate the cache
-------------------------------------------------------------------------------

function CH:ScanSpellBook()
    -- Reset existing cache
    self.spellCache = {}

    local MAX_SPELLS = 1024
    for i = 1, MAX_SPELLS do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then
            break
        end
        -- Store first occurrence only (highest-rank entries share the same
        -- name on 1.12; we want the highest-rank slot which appears later,
        -- so we always overwrite to get the last/highest entry)
        self.spellCache[name] = i
    end
end

-------------------------------------------------------------------------------
-- Lookup helpers
-------------------------------------------------------------------------------

-- Returns the cached spellbook index for spellName, or nil if not known.
function CH:FindSpell(spellName)
    return self.spellCache[spellName]
end

-- Returns the spell icon texture path for spellName, or nil.
function CH:GetSpellIcon(spellName)
    local index = self:FindSpell(spellName)
    if not index then return nil end
    return GetSpellTexture(index, BOOKTYPE_SPELL)
end

-- Returns a sorted array of all spell names currently in the cache.
-- Special tracker entries (starting with "_") are appended at the end.
function CH:GetAllSpellNames()
    local names = {}
    for name, _ in pairs(self.spellCache) do
        table.insert(names, name)
    end
    table.sort(names)
    -- Append special trackers
    table.insert(names, "_SealTracker")
    return names
end

-------------------------------------------------------------------------------
-- Auto-rescan when the spellbook changes
-------------------------------------------------------------------------------

CH:RegisterEvent("SPELLS_CHANGED", function()
    CH:ScanSpellBook()
end)
