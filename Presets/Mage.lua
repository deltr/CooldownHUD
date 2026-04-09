local CH = CooldownHUD

if not CH.Presets then CH.Presets = {} end

CH.Presets["MAGE"] = {
    Arcane = {
        rows = {
            {
                scale = 100,
                spells = { "Arcane Power", "Presence of Mind", "Counterspell", "Fire Blast" },
            },
            {
                scale = 70,
                spells = { "Blink", "Frost Nova", "Cone of Cold" },
            },
            {
                scale = 55,
                spells = { "Evocation", "Ice Block", "Cold Snap" },
            },
        },
        glowRules = {
            {
                spell = "Arcane Power",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Presence of Mind",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Evocation",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerManaBelow", 20 },
                },
            },
            {
                spell = "Counterspell",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
        },
    },
    Fire = {
        rows = {
            {
                scale = 100,
                spells = { "Combustion", "Fire Blast", "Blast Wave", "Counterspell" },
            },
            {
                scale = 70,
                spells = { "Blink", "Frost Nova", "Cone of Cold" },
            },
            {
                scale = 55,
                spells = { "Evocation", "Ice Block", "Cold Snap" },
            },
        },
        glowRules = {
            {
                spell = "Combustion",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Fire Blast",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Evocation",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerManaBelow", 20 },
                },
            },
            {
                spell = "Ice Block",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 20 },
                },
            },
        },
    },
    Frost = {
        rows = {
            {
                scale = 100,
                spells = { "Ice Barrier", "Frost Nova", "Cone of Cold", "Counterspell" },
            },
            {
                scale = 70,
                spells = { "Blink", "Fire Blast", "Cold Snap" },
            },
            {
                scale = 55,
                spells = { "Ice Block", "Evocation" },
            },
        },
        glowRules = {
            {
                spell = "Ice Barrier",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "playerMissingBuff", "Ice Barrier" },
                },
            },
            {
                spell = "Cold Snap",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
            {
                spell = "Evocation",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerManaBelow", 20 },
                },
            },
        },
    },
}
