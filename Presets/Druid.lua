local CH = CooldownHUD

if not CH.Presets then
    CH.Presets = {}
end

CH.Presets["DRUID"] = {
    Balance = {
        rows = {
            {
                scale = 100,
                spells = { "Barkskin", "Nature's Swiftness", "Hurricane", "Nature's Grasp" },
            },
            {
                scale = 70,
                spells = { "Bash", "Feral Charge", "Enrage" },
            },
            {
                scale = 55,
                spells = { "Innervate", "Tranquility", "Rebirth" },
            },
        },
        glowRules = {
            {
                spell = "Innervate",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "playerManaBelow", 30 },
                },
            },
            {
                spell = "Barkskin",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 50 },
                },
            },
        },
    },
    Feral = {
        rows = {
            {
                scale = 100,
                spells = { "Feral Charge", "Bash", "Barkskin", "Faerie Fire (Feral)" },
            },
            {
                scale = 70,
                spells = { "Enrage", "Frenzied Regeneration", "Dash", "Nature's Grasp" },
            },
            {
                scale = 55,
                spells = { "Challenging Roar", "Innervate", "Rebirth" },
            },
        },
        glowRules = {
            {
                spell = "Bash",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Frenzied Regeneration",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
            {
                spell = "Barkskin",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 40 },
                },
            },
            {
                spell = "Enrage",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
        },
    },
    Restoration = {
        rows = {
            {
                scale = 100,
                spells = { "Swiftmend", "Nature's Swiftness", "Barkskin" },
            },
            {
                scale = 70,
                spells = { "Nature's Grasp", "Bash", "Feral Charge" },
            },
            {
                scale = 55,
                spells = { "Innervate", "Tranquility", "Rebirth" },
            },
        },
        glowRules = {
            {
                spell = "Innervate",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerManaBelow", 25 },
                },
            },
            {
                spell = "Nature's Swiftness",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Barkskin",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 40 },
                },
            },
            {
                spell = "Swiftmend",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
        },
    },
}
