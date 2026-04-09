local CH = CooldownHUD

if not CH.Presets then
    CH.Presets = {}
end

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
                spells = { "_SealTracker", "Divine Shield", "Blessing of Freedom", "Blessing of Protection" },
            },
        },
        glowRules = {
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
                spells = { "_SealTracker", "Divine Shield", "Blessing of Sacrifice", "Blessing of Protection", "Blessing of Freedom" },
            },
        },
        glowRules = {
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
                scale = 100,
                spells = { "Holy Shock", "Holy Light", "Flash of Light", "Divine Favor" },
            },
            {
                scale = 70,
                spells = { "Holy Strike", "Hammer of Justice", "Cleanse", "Exorcism" },
            },
            {
                scale = 55,
                spells = { "_SealTracker", "Divine Shield", "Lay on Hands", "Blessing of Protection", "Blessing of Freedom" },
            },
        },
        glowRules = {
            {
                spell = "Holy Shock",
                action = "glow",
                conditions = {
                    { "offCooldown" },
                    { "inCombat" },
                },
            },
            {
                spell = "Divine Favor",
                action = "glow",
                conditions = {
                    { "offCooldown" },
                    { "playerManaBelow", 50 },
                },
            },
            {
                spell = "Lay on Hands",
                action = "pulse",
                conditions = {
                    { "offCooldown" },
                    { "playerHpBelow", 20 },
                },
            },
        },
    },
}
