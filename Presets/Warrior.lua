local CH = CooldownHUD

if not CH.Presets then CH.Presets = {} end

CH.Presets["WARRIOR"] = {
    Arms = {
        rows = {
            {
                scale = 100,
                spells = { "Mortal Strike", "Overpower", "Sweeping Strikes", "Whirlwind" },
            },
            {
                scale = 70,
                spells = { "Charge", "Intercept", "Intimidating Shout", "Pummel", "Spell Reflection" },
            },
            {
                scale = 55,
                spells = { "Retaliation", "Recklessness", "Shield Wall", "Berserker Rage" },
            },
        },
        glowRules = {
            {
                spell = "Mortal Strike",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Sweeping Strikes",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Recklessness",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "targetHpBelow", 20 },
                },
            },
        },
    },
    Fury = {
        rows = {
            {
                scale = 100,
                spells = { "Bloodthirst", "Whirlwind", "Berserker Rage", "Death Wish" },
            },
            {
                scale = 70,
                spells = { "Intercept", "Pummel", "Intimidating Shout", "Charge", "Spell Reflection" },
            },
            {
                scale = 55,
                spells = { "Recklessness", "Retaliation", "Shield Wall" },
            },
        },
        glowRules = {
            {
                spell = "Bloodthirst",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Death Wish",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Recklessness",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "targetHpBelow", 20 },
                },
            },
        },
    },
    Protection = {
        rows = {
            {
                scale = 100,
                spells = { "Shield Slam", "Revenge", "Shield Block", "Concussion Blow" },
            },
            {
                scale = 70,
                spells = { "Spell Reflection", "Shield Bash", "Charge", "Intimidating Shout" },
            },
            {
                scale = 55,
                spells = { "Shield Wall", "Recklessness", "Retaliation", "Berserker Rage" },
            },
        },
        glowRules = {
            {
                spell = "Shield Block",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Shield Wall",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 25 },
                },
            },
            {
                spell = "Spell Reflection",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
        },
    },
}
