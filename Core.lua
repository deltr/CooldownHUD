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
    iconSize            = 36,
    iconGap             = 4,
    rowGap              = 4,
    rows                = 2,
    customRules         = {},
    disabledPresetRules = {},
    cfgX                = 100,
    cfgY                = -200,
    minimapAngle        = 225,
}

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
    local src = PaladinAlertsDB
    local db  = self.db

    -- Migrate position
    if src.posX ~= nil and db.posX == DEFAULTS.posX then
        db.posX = src.posX
    end
    if src.posY ~= nil and db.posY == DEFAULTS.posY then
        db.posY = src.posY
    end

    -- Migrate icon size
    if src.iconSize ~= nil and db.iconSize == DEFAULTS.iconSize then
        db.iconSize = src.iconSize
    end

    -- Migrate locked state
    if src.locked ~= nil and db.locked == DEFAULTS.locked then
        db.locked = src.locked
    end
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

function CH:FireEvent(event, ...)
    local listeners = self._eventListeners[event]
    if not listeners then return end
    for _, cb in ipairs(listeners) do
        cb(...)
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
function CH:FormatTime(remaining)
    if remaining > 60 then
        local m = math.floor(remaining / 60)
        local s = math.floor(remaining % 60)
        return string.format("|cffff0000%d:%02d|r", m, s)
    elseif remaining >= 10 then
        return string.format("|cffff0000%d|r", math.floor(remaining))
    else
        return string.format("|cffffff00%.1f|r", remaining)
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
