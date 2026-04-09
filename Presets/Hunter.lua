local CH = CooldownHUD

if not CH.Presets then CH.Presets = {} end

CH.Presets["HUNTER"] = {
    ["Beast Mastery"] = {
        rows = {
            {
                scale = 100,
                spells = { "Bestial Wrath", "Intimidation", "Aimed Shot", "Multi-Shot" },
            },
            {
                scale = 70,
                spells = { "Arcane Shot", "Concussive Shot", "Scatter Shot", "Feign Death" },
            },
            {
                scale = 55,
                spells = { "Rapid Fire", "Freezing Trap", "Deterrence" },
            },
        },
        glowRules = {
            {
                spell = "Bestial Wrath",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Intimidation",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Rapid Fire",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Feign Death",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
        },
    },
    Marksmanship = {
        rows = {
            {
                scale = 100,
                spells = { "Aimed Shot", "Multi-Shot", "Steady Shot", "Readiness" },
            },
            {
                scale = 70,
                spells = { "Scatter Shot", "Arcane Shot", "Concussive Shot", "Feign Death" },
            },
            {
                scale = 55,
                spells = { "Rapid Fire", "Freezing Trap", "Deterrence" },
            },
        },
        glowRules = {
            {
                spell = "Readiness",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Aimed Shot",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Rapid Fire",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Feign Death",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
        },
    },
    Survival = {
        rows = {
            {
                scale = 100,
                spells = { "Aimed Shot", "Multi-Shot", "Scatter Shot", "Deterrence" },
            },
            {
                scale = 70,
                spells = { "Concussive Shot", "Arcane Shot", "Feign Death", "Freezing Trap" },
            },
            {
                scale = 55,
                spells = { "Rapid Fire", "Explosive Trap", "Immolation Trap" },
            },
        },
        glowRules = {
            {
                spell = "Deterrence",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
            {
                spell = "Scatter Shot",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Feign Death",
                actions = { "glow", "pulse" },
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 30 },
                },
            },
            {
                spell = "Rapid Fire",
                actions = { "glow" },
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
        },
    },
}
