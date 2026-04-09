local CH = CooldownHUD

if not CH.Presets then CH.Presets = {} end

CH.Presets["WARLOCK"] = {
    Affliction = {
        rows = {
            {
                scale = 100,
                spells = { "Dark Harvest", "Death Coil", "Howl of Terror" },
            },
            {
                scale = 70,
                spells = { "Shadowburn", "Fel Domination", "Amplify Curse" },
            },
            {
                scale = 55,
                spells = { "Soulstone", "Inferno", "Ritual of Doom" },
            },
        },
        glowRules = {
            {
                spell = "Dark Harvest",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Death Coil",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
            {
                spell = "Howl of Terror",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 40 },
                },
            },
        },
    },
    Demonology = {
        rows = {
            {
                scale = 100,
                spells = { "Death Coil", "Howl of Terror", "Shadowburn" },
            },
            {
                scale = 70,
                spells = { "Fel Domination" },
            },
            {
                scale = 55,
                spells = { "Inferno", "Ritual of Doom", "Soulstone" },
            },
        },
        glowRules = {
            {
                spell = "Death Coil",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
            {
                spell = "Fel Domination",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Howl of Terror",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 40 },
                },
            },
        },
    },
    Destruction = {
        rows = {
            {
                scale = 100,
                spells = { "Conflagrate", "Shadowburn", "Death Coil", "Shadowfury" },
            },
            {
                scale = 70,
                spells = { "Howl of Terror" },
            },
            {
                scale = 55,
                spells = { "Soulstone", "Inferno", "Ritual of Doom" },
            },
        },
        glowRules = {
            {
                spell = "Conflagrate",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Shadowburn",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "targetHpBelow", 20 },
                },
            },
            {
                spell = "Death Coil",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
        },
    },
}
