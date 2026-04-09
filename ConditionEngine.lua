-------------------------------------------------------------------------------
-- CooldownHUD - ConditionEngine.lua
-- Buff scanning, condition evaluators, rule evaluation, and glow logic
-------------------------------------------------------------------------------

local CH = CooldownHUD

-------------------------------------------------------------------------------
-- Tooltip scanner for buff name resolution (WoW 1.12 has no API for buff names)
-------------------------------------------------------------------------------

local scanTip = CreateFrame("GameTooltip", "CooldownHUD_ScanTip", UIParent, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")

-- Returns the buff name at the given UnitBuff index, or nil.
local function GetBuffName(index)
    local texture = UnitBuff("player", index)
    if not texture then return nil end

    -- GetPlayerBuff returns the buff ID; we use it to set the tooltip.
    local buffId = GetPlayerBuff(index - 1, "HELPFUL")
    if buffId < 0 then return nil end

    scanTip:ClearLines()
    scanTip:SetPlayerBuff(buffId)

    local titleRegion = getglobal("CooldownHUD_ScanTipTextLeft1")
    if titleRegion then
        return titleRegion:GetText()
    end
    return nil
end

-- Returns true if the player currently has a buff whose name matches buffName.
function CH:PlayerHasBuff(buffName)
    if not buffName then return false end
    local i = 1
    while true do
        local texture = UnitBuff("player", i)
        if not texture then break end
        local name = GetBuffName(i)
        if name and name == buffName then
            return true
        end
        i = i + 1
    end
    return false
end

-------------------------------------------------------------------------------
-- Condition evaluators
-- Each function receives (spellName, param) and returns true/false.
-------------------------------------------------------------------------------

local Evaluators = {
    offCooldown = function(spellName, param)
        return CH:IsSpellReady(spellName)
    end,

    playerHasBuff = function(spellName, param)
        return CH:PlayerHasBuff(param)
    end,

    playerMissingBuff = function(spellName, param)
        return not CH:PlayerHasBuff(param)
    end,

    targetHpBelow = function(spellName, param)
        local max = UnitHealthMax("target")
        if not max or max == 0 then return false end
        local pct = UnitHealth("target") / max * 100
        return pct <= param
    end,

    playerHpBelow = function(spellName, param)
        local max = UnitHealthMax("player")
        if not max or max == 0 then return false end
        local pct = UnitHealth("player") / max * 100
        return pct <= param
    end,

    playerManaBelow = function(spellName, param)
        local max = UnitManaMax("player")
        if not max or max == 0 then return false end
        local pct = UnitMana("player") / max * 100
        return pct <= param
    end,

    inCombat = function(spellName, param)
        return CH.inCombat or CH.testMode
    end,

    hasAttackableTarget = function(spellName, param)
        return UnitExists("target")
            and UnitCanAttack("player", "target")
            and not UnitIsDead("target")
    end,
}

-------------------------------------------------------------------------------
-- CH:EvaluateRule(rule)
-- rule = { spell = "SpellName", conditions = { {type, param}, ... } }
-- Returns true only if ALL conditions pass (AND logic).
-------------------------------------------------------------------------------

function CH:EvaluateRule(rule)
    if not rule or not rule.spell or not rule.conditions then return false end
    for i = 1, table.getn(rule.conditions) do
        local cond = rule.conditions[i]
        local condType = cond[1]
        local param    = cond[2]
        local fn = Evaluators[condType]
        if fn then
            if not fn(rule.spell, param) then
                return false
            end
        end
        -- Unknown condition types are silently skipped (treated as passing).
    end
    return true
end

-------------------------------------------------------------------------------
-- CH:GetActiveRules()
-- Returns the merged array of enabled preset rules + all custom rules.
-------------------------------------------------------------------------------

function CH:GetActiveRules()
    local rules = {}

    -- Preset rules for the current class/spec
    local class = CH.playerClass
    local spec  = CH:GetActiveSpec()

    if class and spec
       and CH.Presets
       and CH.Presets[class]
       and CH.Presets[class][spec]
       and CH.Presets[class][spec].glowRules then

        local disabled = CH.db.disabledPresetRules or {}
        local presetRules = CH.Presets[class][spec].glowRules

        for i = 1, table.getn(presetRules) do
            local rule = presetRules[i]
            -- Build the disabled-key from spell + first condition type
            local firstCondType = ""
            if rule.conditions and rule.conditions[1] then
                firstCondType = rule.conditions[1][1] or ""
            end
            local key = rule.spell .. ":" .. firstCondType
            if not disabled[key] then
                table.insert(rules, rule)
            end
        end
    end

    -- Append user custom rules
    if CH.db.customRules then
        for i = 1, table.getn(CH.db.customRules) do
            table.insert(rules, CH.db.customRules[i])
        end
    end

    return rules
end

-------------------------------------------------------------------------------
-- CH:ShouldGlow(spellName)
-- Returns true if any active rule for this spell evaluates to true.
-------------------------------------------------------------------------------

-- Cached rules array, rebuilt on spec/rule changes instead of every frame
local cachedRules = nil

function CH:InvalidateRulesCache()
    cachedRules = nil
end

function CH:ShouldGlow(spellName)
    if not cachedRules then
        cachedRules = CH:GetActiveRules()
    end
    for i = 1, table.getn(cachedRules) do
        local rule = cachedRules[i]
        if rule.spell == spellName and CH:EvaluateRule(rule) then
            return true
        end
    end
    return false
end

-- Invalidate cache when spec or rules change
CH:RegisterEvent("SPEC_CHANGED", function()
    cachedRules = nil
end)

-------------------------------------------------------------------------------
-- CH.conditionTypes
-- Descriptor table used by the Config UI to build condition dropdowns.
-------------------------------------------------------------------------------

CH.conditionTypes = {
    {
        id       = "offCooldown",
        label    = "Spell is off cooldown",
        hasParam = false,
        paramType = nil,
    },
    {
        id       = "playerHasBuff",
        label    = "Player has buff",
        hasParam = true,
        paramType = "buff",
    },
    {
        id       = "playerMissingBuff",
        label    = "Player missing buff",
        hasParam = true,
        paramType = "buff",
    },
    {
        id       = "targetHpBelow",
        label    = "Target HP below %",
        hasParam = true,
        paramType = "percent",
    },
    {
        id       = "playerHpBelow",
        label    = "Player HP below %",
        hasParam = true,
        paramType = "percent",
    },
    {
        id       = "playerManaBelow",
        label    = "Player mana below %",
        hasParam = true,
        paramType = "percent",
    },
    {
        id       = "inCombat",
        label    = "In combat",
        hasParam = false,
        paramType = nil,
    },
    {
        id       = "hasAttackableTarget",
        label    = "Has attackable target",
        hasParam = false,
        paramType = nil,
    },
}
