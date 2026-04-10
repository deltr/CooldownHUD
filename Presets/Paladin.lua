local CH = CooldownHUD

if not CH.Presets then
    CH.Presets = {}
end

-- Shared rule: Seal tracker glows + pulses when no seal is active and has target
local sealAlertRule = {
    spell = "_SealTracker",
    actions = { "glow", "pulse" },
    conditions = {
        { "playerMissingSeal" },
        { "hasAttackableTarget" },
    },
}

CH.Presets["PALADIN"] = {
    Retribution = {
        rows = {
            {
                scale = 100,
                spells = { "Crusader Strike", "Judgement", "Consecration", "Hammer of Wrath" },
            },
            {
                scale = 70,
                spells = { "Repentance", "Hammer of Justice", "Exorcism", "Holy Wrath" },
            },
            {
                scale = 55,
                spells = { "_SealTracker", "Divine Shield" },
            },
        },
        glowRules = {
            sealAlertRule,
            {
                spell = "Hammer of Wrath",
                actions = { "glow", "pulse", "showOnly" },
                conditions = {
                    { "targetHpBelow", 20 },
                    { "offCooldown" },
                },
            },
            {
                spell = "Exorcism",
                actions = { "glow" },
                conditions = {
                    { "targetIsUndead" },
                    { "offCooldown" },
                },
            },
        },
    },
    Protection = {
        rows = {
            {
                scale = 100,
                spells = { "Holy Shield", "Consecration", "Judgement", "Avenger's Shield" },
            },
            {
                scale = 70,
                spells = { "Hand of Reckoning", "Hammer of Justice", "Exorcism", "Holy Wrath" },
            },
            {
                scale = 55,
                spells = { "_SealTracker", "Divine Shield" },
            },
        },
        glowRules = {
            sealAlertRule,
            {
                spell = "Holy Shield",
                action = "glow",
                conditions = {
                    { "offCooldown" },
                    { "playerHasBuff", "Redoubt" },
                },
            },
            {
                spell = "Consecration",
                action = "glow",
                conditions = {
                    { "offCooldown" },
                    { "hasAttackableTarget" },
                },
            },
            {
                spell = "Avenger's Shield",
                action = "glow",
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
        },
    },
    Holy = {
        rows = {
            {
                scale = 120,
                spells = { "Hammer of Wrath" },
            },
            {
                scale = 100,
                spells = { "_SealTracker", "Judgement", "Holy Strike", "Holy Shock" },
            },
            {
                scale = 75,
                spells = { "Hammer of Justice", "Divine Shield", "Lay on Hands", "Exorcism", "Consecration" },
            },
        },
        glowRules = {
            sealAlertRule,
            {
                spell = "Hammer of Wrath",
                actions = { "glow", "showOnly" },
                conditions = {
                    { "targetHpBelow", 20 },
                    { "offCooldown" },
                },
            },
        },
    },
}
