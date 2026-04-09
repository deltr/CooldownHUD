local CH = CooldownHUD

if not CH.Presets then CH.Presets = {} end

CH.Presets["PRIEST"] = {
    Discipline = {
        rows = {
            {
                scale = 100,
                spells = { "Power Infusion", "Inner Focus", "Mind Blast", "Fear Ward" },
            },
            {
                scale = 70,
                spells = { "Psychic Scream", "Silence", "Fade", "Pain Spike" },
            },
            {
                scale = 55,
                spells = { "Desperate Prayer" },
            },
        },
        glowRules = {
            {
                spell = "Power Infusion",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Inner Focus",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "playerManaBelow", 50 },
                },
            },
            {
                spell = "Fear Ward",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "playerMissingBuff", "Fear Ward" },
                },
            },
            {
                spell = "Psychic Scream",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
        },
    },
    Holy = {
        rows = {
            {
                scale = 100,
                spells = { "Inner Focus", "Mind Blast", "Fear Ward" },
            },
            {
                scale = 70,
                spells = { "Psychic Scream", "Fade", "Pain Spike" },
            },
            {
                scale = 55,
                spells = { "Desperate Prayer" },
            },
        },
        glowRules = {
            {
                spell = "Inner Focus",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "playerManaBelow", 40 },
                },
            },
            {
                spell = "Desperate Prayer",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 20 },
                },
            },
            {
                spell = "Fade",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
        },
    },
    Shadow = {
        rows = {
            {
                scale = 100,
                spells = { "Mind Blast", "Pain Spike", "Silence" },
            },
            {
                scale = 70,
                spells = { "Psychic Scream", "Fade", "Fear Ward", "Inner Focus" },
            },
            {
                scale = 55,
                spells = { "Desperate Prayer" },
            },
        },
        glowRules = {
            {
                spell = "Mind Blast",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Pain Spike",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Silence",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Psychic Scream",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
        },
    },
}
