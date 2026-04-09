-------------------------------------------------------------------------------
-- CooldownHUD - Core.lua
-- Namespace, saved variables, event bus, and slash command
-------------------------------------------------------------------------------

-- Global namespace
CooldownHUD = {}
local CH = CooldownHUD

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

local DEFAULTS = {
    spec                = nil,   -- nil = auto-detect
    posX                = 0,
    posY                = -200,
    locked              = false,
    iconSize            = 48,
    iconGap             = 4,
    rowGap              = 4,
    rows                = {},     -- per-row overrides (populated on load)
    customRules         = {},
    disabledPresetRules = {},
    cfgX                = 0,
    cfgY                = 0,
    minimapAngle        = 220,
}
CH.defaults = DEFAULTS

-------------------------------------------------------------------------------
-- Database bootstrap
-------------------------------------------------------------------------------

function CH:InitDB()
    if not CooldownHUDDB then
        CooldownHUDDB = {}
    end
    local db = CooldownHUDDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then
            if type(v) == "table" then
                db[k] = {}
            else
                db[k] = v
            end
        end
    end
    self.db = db
end

-------------------------------------------------------------------------------
-- Migration from PaladinAlerts
-------------------------------------------------------------------------------

function CH:MigrateFromPaladinAlerts()
    if not PaladinAlertsDB then return end
    if self.db._migrated then return end

    local old = PaladinAlertsDB
    if old.rowX then self.db.posX = old.rowX end
    if old.rowY then self.db.posY = old.rowY end
    if old.iconSize then self.db.iconSize = old.iconSize end
    if old.iconGap then self.db.iconGap = old.iconGap end
    if old.rowGap then self.db.rowGap = old.rowGap end

    self.db._migrated = true
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff00ccffCooldownHUD:|r PaladinAlerts has been upgraded to CooldownHUD. "
        .. "Your position and size settings have been preserved."
    )
end

-------------------------------------------------------------------------------
-- Internal event bus
-------------------------------------------------------------------------------

CH._eventListeners = {}

function CH:RegisterEvent(event, callback)
    if not self._eventListeners[event] then
        self._eventListeners[event] = {}
    end
    table.insert(self._eventListeners[event], callback)
end

function CH:FireEvent(event, arg1, arg2, arg3)
    local listeners = self._eventListeners[event]
    if not listeners then return end
    for _, cb in ipairs(listeners) do
        cb(arg1, arg2, arg3)
    end
end

-------------------------------------------------------------------------------
-- State flags
-------------------------------------------------------------------------------

CH.inCombat    = false
CH.testMode    = false
CH.playerClass = nil

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------

-- Returns a formatted time string with colour codes.
-- >60s  : "M:SS"  in red
-- 10-60s: whole seconds in red
-- <10s  : one decimal place in yellow
-- Returns: text, r, g, b (separate values for FontString use)
function CH:FormatTime(remaining)
    if remaining > 60 then
        local m = math.floor(remaining / 60)
        local s = math.floor(remaining - m * 60)
        return string.format("%d:%02d", m, s), 1, 0, 0
    elseif remaining > 10 then
        return tostring(math.ceil(remaining)), 1, 0, 0
    else
        return string.format("%.1f", remaining), 1, 0.8, 0
    end
end

-------------------------------------------------------------------------------
-- Boot frame — WoW event listener
-------------------------------------------------------------------------------

local bootFrame = CreateFrame("Frame", "CooldownHUD_BootFrame")

bootFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
bootFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
bootFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
bootFrame:RegisterEvent("SPELLS_CHANGED")
bootFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
bootFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
bootFrame:RegisterEvent("UNIT_HEALTH")
bootFrame:RegisterEvent("UNIT_MANA")
bootFrame:RegisterEvent("PLAYER_AURAS_CHANGED")

bootFrame:SetScript("OnEvent", function()
    -- In WoW 1.12 the event name is in the global `event`
    if event == "PLAYER_ENTERING_WORLD" then
        -- First-time init
        CH:InitDB()
        CH:MigrateFromPaladinAlerts()

        -- Determine player class
        local _, englishClass = UnitClass("player")
        CH.playerClass = englishClass

        CH:FireEvent("INIT")
        CH:FireEvent("SPELLS_CHANGED")

    elseif event == "PLAYER_REGEN_DISABLED" then
        CH.inCombat = true
        CH:FireEvent("COMBAT_CHANGED", true)

    elseif event == "PLAYER_REGEN_ENABLED" then
        CH.inCombat = false
        CH:FireEvent("COMBAT_CHANGED", false)

    elseif event == "SPELLS_CHANGED" then
        CH:FireEvent("SPELLS_CHANGED")

    elseif event == "CHARACTER_POINTS_CHANGED" then
        CH:FireEvent("TALENTS_CHANGED")

    elseif event == "PLAYER_TARGET_CHANGED" then
        CH:FireEvent("TARGET_CHANGED")

    elseif event == "UNIT_HEALTH" or event == "UNIT_MANA" or event == "PLAYER_AURAS_CHANGED" then
        CH:FireEvent("AURAS_CHANGED")
    end
end)

-------------------------------------------------------------------------------
-- Slash command: /ch
-------------------------------------------------------------------------------

SLASH_COOLDOWNHUD1 = "/ch"

SlashCmdList["COOLDOWNHUD"] = function(msg)
    local cmd = string.lower(string.gsub(msg or "", "^%s+", ""))
    cmd = string.gsub(cmd, "%s+$", "")

    if cmd == "" then
        CH:FireEvent("TOGGLE_CONFIG")
    elseif cmd == "test" then
        CH.testMode = not CH.testMode
        if CH.testMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CooldownHUD:|r Test mode |cff00ff00ON|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CooldownHUD:|r Test mode |cffff4444OFF|r")
        end
        CH:FireEvent("TEST_MODE_CHANGED", CH.testMode)
    elseif cmd == "reset" then
        CH:FireEvent("RESET_PRESET")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00CooldownHUD:|r Commands: /ch | /ch test | /ch reset")
    end
end
