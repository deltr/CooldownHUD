local CH = CooldownHUD

if not CH.Presets then CH.Presets = {} end

CH.Presets["ROGUE"] = {
    Assassination = {
        rows = {
            {
                scale = 100,
                spells = { "Cold Blood", "Kidney Shot", "Kick", "Blade Flurry" },
            },
            {
                scale = 70,
                spells = { "Gouge", "Blind", "Sprint" },
            },
            {
                scale = 55,
                spells = { "Evasion", "Vanish" },
            },
        },
        glowRules = {
            {
                spell = "Cold Blood",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Kick",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Evasion",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
            {
                spell = "Vanish",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 20 },
                },
            },
        },
    },
    Combat = {
        rows = {
            {
                scale = 100,
                spells = { "Adrenaline Rush", "Blade Flurry", "Kick", "Riposte" },
            },
            {
                scale = 70,
                spells = { "Kidney Shot", "Gouge", "Sprint", "Blind" },
            },
            {
                scale = 55,
                spells = { "Evasion", "Vanish" },
            },
        },
        glowRules = {
            {
                spell = "Adrenaline Rush",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Blade Flurry",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Evasion",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
        },
    },
    Subtlety = {
        rows = {
            {
                scale = 100,
                spells = { "Preparation", "Kick", "Kidney Shot", "Blade Flurry" },
            },
            {
                scale = 70,
                spells = { "Gouge", "Blind", "Sprint", "Cold Blood" },
            },
            {
                scale = 55,
                spells = { "Evasion", "Vanish" },
            },
        },
        glowRules = {
            {
                spell = "Preparation",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Kick",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Evasion",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
            {
                spell = "Vanish",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 20 },
                },
            },
        },
    },
}
