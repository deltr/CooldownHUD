local CH = CooldownHUD

if not CH.Presets then CH.Presets = {} end

CH.Presets["SHAMAN"] = {
    Elemental = {
        rows = {
            {
                scale = 100,
                spells = { "Elemental Mastery", "Earth Shock", "Fire Nova Totem" },
            },
            {
                scale = 70,
                spells = { "Grounding Totem", "Frost Shock", "Flame Shock" },
            },
            {
                scale = 55,
                spells = { "Nature's Swiftness", "Bloodlust" },
            },
        },
        glowRules = {
            {
                spell = "Elemental Mastery",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Earth Shock",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Grounding Totem",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
        },
    },
    Enhancement = {
        rows = {
            {
                scale = 100,
                spells = { "Stormstrike", "Earth Shock", "Bloodlust", "Fire Nova Totem" },
            },
            {
                scale = 70,
                spells = { "Grounding Totem", "Frost Shock", "Flame Shock" },
            },
            {
                scale = 55,
                spells = { "Feral Spirit", "Hex" },
            },
        },
        glowRules = {
            {
                spell = "Stormstrike",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Bloodlust",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Earth Shock",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
        },
    },
    Restoration = {
        rows = {
            {
                scale = 100,
                spells = { "Nature's Swiftness", "Spirit Link", "Earth Shock" },
            },
            {
                scale = 70,
                spells = { "Grounding Totem", "Fire Nova Totem", "Frost Shock" },
            },
            {
                scale = 55,
                spells = { "Hex", "Feral Spirit" },
            },
        },
        glowRules = {
            {
                spell = "Nature's Swiftness",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Spirit Link",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
            {
                spell = "Earth Shock",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Grounding Totem",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
        },
    },
}
