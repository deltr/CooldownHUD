local CH = CooldownHUD
local GCD_THRESHOLD = 1.5
local TICK_RATE = 0.05  -- 50ms

-- Returns remaining, duration, start for a spell's cooldown.
-- Returns 0, 0, 0 if the spell is not found, not on cooldown, or only on GCD.
function CH:GetCooldownInfo(spellName)
    local idx = CH:FindSpell(spellName)
    if not idx then
        return 0, 0, 0
    end

    local start, duration = GetSpellCooldown(idx, BOOKTYPE_SPELL)

    if not start or not duration or (start == 0 and duration == 0) then
        return 0, 0, 0
    end

    -- Filter out GCD
    if duration <= GCD_THRESHOLD then
        return 0, 0, 0
    end

    local remaining = math.max(0, start + duration - GetTime())

    if remaining < 0.05 then
        return 0, 0, 0
    end

    return remaining, duration, start
end

-- Returns true if the spell exists and is not on cooldown.
function CH:IsSpellReady(spellName)
    local remaining = CH:GetCooldownInfo(spellName)
    return remaining == 0
end

-- OnUpdate frame that fires COOLDOWNS_UPDATED every TICK_RATE seconds
-- while in combat or in test mode.
local tickFrame = CreateFrame("Frame")
local elapsed = 0

tickFrame:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed >= TICK_RATE then
        elapsed = 0
        if CH.inCombat or CH.testMode then
            CH:FireEvent("COOLDOWNS_UPDATED")
        end
    end
end)
