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
        if not param then return false end
        local max = UnitHealthMax("target")
        if not max or max == 0 then return false end
        local pct = UnitHealth("target") / max * 100
        return pct <= param
    end,

    playerHpBelow = function(spellName, param)
        if not param then return false end
        local max = UnitHealthMax("player")
        if not max or max == 0 then return false end
        local pct = UnitHealth("player") / max * 100
        return pct <= param
    end,

    playerManaBelow = function(spellName, param)
        if not param then return false end
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

    targetIsUndead = function(spellName, param)
        if not UnitExists("target") then return false end
        local ctype = UnitCreatureType("target")
        return ctype == "Undead"
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
-- Rule actions — what happens when a rule fires
-------------------------------------------------------------------------------

CH.ruleActions = {
    { id = "glow",      label = "Gold border glow",     desc = "Pulsing gold border around the icon" },
    { id = "pulse",     label = "Pulse icon opacity",    desc = "Icon fades in and out to draw attention" },
    { id = "showOnly",  label = "Show icon only if true", desc = "Icon is hidden unless conditions are met" },
    { id = "hideWhen",  label = "Hide icon when true",   desc = "Icon is hidden when conditions are met" },
}

-------------------------------------------------------------------------------
-- CH:GetSpellActions(spellName)
-- Returns a table of { action, ... } for all matching rules that evaluate true.
-- Each entry is the action string from the rule (default "glow").
-------------------------------------------------------------------------------

-- Cached rules array, rebuilt on spec/rule changes instead of every frame
local cachedRules = nil

function CH:InvalidateRulesCache()
    cachedRules = nil
    -- Persist rule changes to per-spec storage
    if CH.SaveSpecData then CH:SaveSpecData() end
end

-- Extract actions from a rule as a set. Supports both:
--   rule.action  = "glow"           (old single-action format)
--   rule.actions = {"glow","pulse"} (new multi-action format)
local function RuleActionSet(rule)
    local set = {}
    if rule.actions then
        for _, a in ipairs(rule.actions) do
            set[a] = true
        end
    elseif rule.action then
        set[rule.action] = true
    else
        set["glow"] = true
    end
    return set
end

function CH:GetSpellActions(spellName)
    if not cachedRules then
        cachedRules = CH:GetActiveRules()
    end
    local actions = {}
    for i = 1, table.getn(cachedRules) do
        local rule = cachedRules[i]
        if rule.spell == spellName and CH:EvaluateRule(rule) then
            local set = RuleActionSet(rule)
            for a, _ in pairs(set) do
                actions[a] = true
            end
        end
    end
    return actions
end

-- Check if any rule for this spell has a specific action (regardless of conditions)
function CH:HasRuleWithAction(spellName, actionId)
    if not cachedRules then
        cachedRules = CH:GetActiveRules()
    end
    for i = 1, table.getn(cachedRules) do
        local rule = cachedRules[i]
        if rule.spell == spellName then
            local set = RuleActionSet(rule)
            if set[actionId] then return true end
        end
    end
    return false
end

-- Backwards compat wrapper
function CH:ShouldGlow(spellName)
    local actions = self:GetSpellActions(spellName)
    return actions["glow"] == true
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
        desc     = "Glow only when the spell is ready to cast (not on cooldown)",
        hasParam = false,
        paramType = nil,
    },
    {
        id       = "playerHasBuff",
        label    = "Player has buff",
        desc     = "Glow when you have a specific buff active (e.g. Redoubt, Vengeance)",
        hasParam = true,
        paramType = "buff",
    },
    {
        id       = "playerMissingBuff",
        label    = "Player missing buff",
        desc     = "Glow when you do NOT have a specific buff (e.g. no Seal active)",
        hasParam = true,
        paramType = "buff",
    },
    {
        id       = "targetHpBelow",
        label    = "Target HP below %",
        desc     = "Glow when your target's health drops below a threshold (e.g. 20% for execute)",
        hasParam = true,
        paramType = "percent",
    },
    {
        id       = "playerHpBelow",
        label    = "Player HP below %",
        desc     = "Glow when YOUR health drops below a threshold (e.g. panic heal)",
        hasParam = true,
        paramType = "percent",
    },
    {
        id       = "playerManaBelow",
        label    = "Player mana below %",
        desc     = "Glow when your mana drops below a threshold (e.g. use mana cooldowns)",
        hasParam = true,
        paramType = "percent",
    },
    {
        id       = "inCombat",
        label    = "In combat",
        desc     = "Glow only while you are in combat",
        hasParam = false,
        paramType = nil,
    },
    {
        id       = "hasAttackableTarget",
        label    = "Has attackable target",
        desc     = "Glow only when you have a living, hostile target selected",
        hasParam = false,
        paramType = nil,
    },
    {
        id       = "targetIsUndead",
        label    = "Target is undead",
        desc     = "True when your target is an Undead creature type",
        hasParam = false,
        paramType = nil,
    },
}
