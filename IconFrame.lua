-------------------------------------------------------------------------------
-- CooldownHUD - IconFrame.lua
-- Icon frame factory: spell icon, radial sweep cooldown, timer text, glow border
-------------------------------------------------------------------------------

local CH = CooldownHUD

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local GLOW_COLOR        = { 1, 0.85, 0, 1 }  -- gold
local GLOW_BORDER_WIDTH = 3
local DIM_ALPHA         = 0.4
local GLOW_PULSE_SPEED  = 2  -- cycles per second

local FALLBACK_ICON    = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEFAULT_SEAL_ICON = "Interface\\Icons\\Spell_Holy_RighteousnessAura"
local SEAL_FLASH_SPEED = 3  -- flashes per second when no seal active

-------------------------------------------------------------------------------
-- Icon frame registry
-------------------------------------------------------------------------------

CH.iconFrames = {}

-------------------------------------------------------------------------------
-- CH:CreateIconFrame(spellName, size)
-------------------------------------------------------------------------------

function CH:CreateIconFrame(spellName, size)
    local safeName = string.gsub(spellName, "%s", "_")
    local name     = "CooldownHUD_Icon_" .. safeName

    local fr = CreateFrame("Frame", name, UIParent)
    fr:SetWidth(size)
    fr:SetHeight(size)

    -- 1. Texture layer (ARTWORK) ------------------------------------------
    local tex = fr:CreateTexture(name .. "_Tex", "ARTWORK")
    tex:SetAllPoints(fr)
    -- Special tracker spells start with "_"; use default icon, not spellbook
    local iconPath
    if string.sub(spellName, 1, 1) == "_" then
        iconPath = DEFAULT_SEAL_ICON
    else
        iconPath = CH:GetSpellIcon(spellName) or FALLBACK_ICON
    end
    tex:SetTexture(iconPath)
    fr.texture = tex

    -- 2. Cooldown sweep overlay (vertical wipe from top to bottom) --------
    -- WoW 1.12 has no CreateFrame("Cooldown"). We simulate a sweep by
    -- anchoring a dark overlay from top, adjusting its height each tick.
    local cdOverlay = fr:CreateTexture(name .. "_CDOverlay", "OVERLAY")
    cdOverlay:SetTexture(0, 0, 0, 0.6)
    cdOverlay:SetPoint("BOTTOMLEFT", fr, "BOTTOMLEFT", 0, 0)
    cdOverlay:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", 0, 0)
    cdOverlay:SetHeight(size)
    cdOverlay:Hide()
    fr.cooldownOverlay = cdOverlay

    -- 3. Timer text -------------------------------------------------------
    -- Child frame sits above the cooldown model in the frame stack
    local textFrame = CreateFrame("Frame", name .. "_TextFrame", fr)
    textFrame:SetAllPoints(fr)
    textFrame:SetFrameLevel(fr:GetFrameLevel() + 5)

    local fontSize = math.max(12, math.floor(size * 0.55))
    local timerText = textFrame:CreateFontString(name .. "_Timer", "OVERLAY")
    timerText:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    timerText:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
    timerText:SetText("")
    fr.timerText = timerText

    -- 4. Glow border (4 edge textures) ------------------------------------
    local glowEdges = {}

    -- Top edge
    local eTop = fr:CreateTexture(name .. "_GlowTop", "OVERLAY")
    eTop:SetTexture("Interface\\Buttons\\WHITE8x8")
    eTop:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], GLOW_COLOR[4])
    eTop:SetPoint("TOPLEFT",    fr, "TOPLEFT",    -GLOW_BORDER_WIDTH, GLOW_BORDER_WIDTH)
    eTop:SetPoint("TOPRIGHT",   fr, "TOPRIGHT",    GLOW_BORDER_WIDTH, GLOW_BORDER_WIDTH)
    eTop:SetHeight(GLOW_BORDER_WIDTH)
    eTop:Hide()
    glowEdges[1] = eTop

    -- Bottom edge
    local eBot = fr:CreateTexture(name .. "_GlowBottom", "OVERLAY")
    eBot:SetTexture("Interface\\Buttons\\WHITE8x8")
    eBot:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], GLOW_COLOR[4])
    eBot:SetPoint("BOTTOMLEFT",  fr, "BOTTOMLEFT",  -GLOW_BORDER_WIDTH, -GLOW_BORDER_WIDTH)
    eBot:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT",  GLOW_BORDER_WIDTH, -GLOW_BORDER_WIDTH)
    eBot:SetHeight(GLOW_BORDER_WIDTH)
    eBot:Hide()
    glowEdges[2] = eBot

    -- Left edge
    local eLeft = fr:CreateTexture(name .. "_GlowLeft", "OVERLAY")
    eLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
    eLeft:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], GLOW_COLOR[4])
    eLeft:SetPoint("TOPLEFT",    fr, "TOPLEFT",    -GLOW_BORDER_WIDTH,  GLOW_BORDER_WIDTH)
    eLeft:SetPoint("BOTTOMLEFT", fr, "BOTTOMLEFT", -GLOW_BORDER_WIDTH, -GLOW_BORDER_WIDTH)
    eLeft:SetWidth(GLOW_BORDER_WIDTH)
    eLeft:Hide()
    glowEdges[3] = eLeft

    -- Right edge
    local eRight = fr:CreateTexture(name .. "_GlowRight", "OVERLAY")
    eRight:SetTexture("Interface\\Buttons\\WHITE8x8")
    eRight:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], GLOW_COLOR[4])
    eRight:SetPoint("TOPRIGHT",    fr, "TOPRIGHT",     GLOW_BORDER_WIDTH,  GLOW_BORDER_WIDTH)
    eRight:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT",  GLOW_BORDER_WIDTH, -GLOW_BORDER_WIDTH)
    eRight:SetWidth(GLOW_BORDER_WIDTH)
    eRight:Hide()
    glowEdges[4] = eRight

    fr.glowEdges = glowEdges

    -- 5. Glow pulse OnUpdate ------------------------------------------------
    fr:SetScript("OnUpdate", function()
        if fr.glowActive then
            fr.glowElapsed = fr.glowElapsed + arg1
            local alpha = 0.5 + 0.5 * math.sin(fr.glowElapsed * GLOW_PULSE_SPEED * math.pi * 2)
            for i = 1, 4 do
                fr.glowEdges[i]:SetAlpha(alpha)
            end
        end
    end)

    -- 6. Store fields ----------------------------------------------------
    fr.spellName    = spellName
    fr.iconSize     = size
    fr.glowActive   = false
    fr.glowElapsed  = 0

    -- 7. Start hidden ----------------------------------------------------
    fr:SetAlpha(0)
    fr:Hide()

    -- 8. Register in table -----------------------------------------------
    CH.iconFrames[spellName] = fr

    return fr
end

-------------------------------------------------------------------------------
-- Seal tracker support
-------------------------------------------------------------------------------

local SEAL_TEXTURES = {
    "RighteousnessAura",
    "ThunderBolt",
    "HealingAura",
    "SealOfMight",
    "SealOfWrath",
    "InnerRage",
    "SealOfCommand",
}

local hasBuffTimeAPI = (GetPlayerBuff ~= nil and GetPlayerBuffTimeLeft ~= nil)

local function IsSealTexture(texPath)
    if not texPath then return false end
    for _, pattern in ipairs(SEAL_TEXTURES) do
        if string.find(texPath, pattern) then
            return true
        end
    end
    return false
end

-- Exposed on CH so ConditionEngine can use it for seal-related conditions
function CH:GetActiveSeal()
    local i = 1
    while true do
        local tex = UnitBuff("player", i)
        if not tex then break end
        if IsSealTexture(tex) then
            local timeLeft = nil
            if hasBuffTimeAPI then
                local buffIdx = GetPlayerBuff(i - 1, "HELPFUL")
                if buffIdx and buffIdx >= 0 then
                    timeLeft = GetPlayerBuffTimeLeft(buffIdx)
                end
            end
            return tex, timeLeft
        end
        i = i + 1
    end
    return nil, nil
end

function CH:UpdateSealTracker(fr)
    -- Hide outside combat / test mode
    if not (CH.inCombat or CH.testMode) then
        fr:SetAlpha(0)
        fr:Hide()
        return
    end

    fr:Show()
    fr:SetAlpha(1)

    local sealTex, timeLeft = CH:GetActiveSeal()

    if sealTex then
        fr.texture:SetTexture(sealTex)
        fr.cooldownOverlay:Hide()
        fr.texture:SetAlpha(1)
        fr.sealPulsing = false

        if timeLeft and timeLeft > 0 then
            local text = CH:FormatTime(timeLeft)
            fr.timerText:SetText(text)
            fr.timerText:SetTextColor(1, 1, 1)
        else
            fr.timerText:SetText("")
        end
    else
        -- No seal active: pulse the icon opacity to prompt casting a seal
        fr.texture:SetTexture(DEFAULT_SEAL_ICON)
        fr.cooldownOverlay:Hide()
        fr.timerText:SetText("")

        -- Pulse icon alpha between 0.5 and 1.0
        if not fr.sealPulsing then
            fr.sealPulsing = true
            fr.sealPulseElapsed = 0
        end
        fr.sealPulseElapsed = (fr.sealPulseElapsed or 0) + 0.05
        local alpha = 0.75 + 0.25 * math.sin(fr.sealPulseElapsed * 2 * math.pi * 1.5)
        fr.texture:SetAlpha(alpha)
    end

    -- Deactivate glow (not used for seal tracker)
    if fr.glowActive then
        fr.glowActive = false
        for i = 1, 4 do
            fr.glowEdges[i]:Hide()
        end
    end
end

-------------------------------------------------------------------------------
-- CH:UpdateIconState(spellName)
-------------------------------------------------------------------------------

function CH:UpdateIconState(spellName)
    local fr = CH.iconFrames[spellName]
    if not fr then return end

    -- Special tracker spells (start with "_Seal")
    if string.sub(spellName, 1, 5) == "_Seal" then
        CH:UpdateSealTracker(fr)
        return
    end

    -- Check spell is known
    local idx = CH:FindSpell(spellName)
    if not idx then
        fr.texture:SetTexture(FALLBACK_ICON)
        fr:SetAlpha(0)
        fr:Hide()
        return
    end

    -- Refresh texture from live spellbook data; if GetSpellTexture returns nil,
    -- use the fallback icon but still show the icon normally
    local texPath = GetSpellTexture(idx, BOOKTYPE_SPELL)
    if texPath then
        fr.texture:SetTexture(texPath)
    else
        fr.texture:SetTexture(FALLBACK_ICON)
    end

    -- Get active rule actions for this spell
    local actions = CH:GetSpellActions(spellName)

    -- In test mode, skip show/hide rules so all icons remain visible
    if not CH.testMode then
        -- "showOnly" action: hide icon unless rule fires
        if actions["showOnly"] then
            -- conditions met — show it (handled below)
        elseif CH:HasRuleWithAction(spellName, "showOnly") then
            -- has a showOnly rule but conditions NOT met — hide
            fr:SetAlpha(0)
            fr:Hide()
            return
        end

        -- "hideWhen" action: hide icon when rule fires
        if actions["hideWhen"] then
            fr:SetAlpha(0)
            fr:Hide()
            return
        end
    end

    -- Hide outside combat / test mode
    if not (CH.inCombat or CH.testMode) then
        fr:SetAlpha(0)
        fr:Hide()
        return
    end

    fr:Show()
    fr:SetAlpha(1)

    -- Cooldown state
    local remaining, duration, start = CH:GetCooldownInfo(spellName)
    local onCD = (remaining > 0)

    if onCD then
        -- Show dark overlay and timer
        fr.cooldownOverlay:Show()
        local text, r, g, b = CH:FormatTime(remaining)
        fr.timerText:SetText(text)
        fr.timerText:SetTextColor(r, g, b)
        fr.texture:SetAlpha(DIM_ALPHA)
        -- Sweep: overlay height shrinks as cooldown expires (top-to-bottom reveal)
        local progress = 1 - (remaining / duration)
        local h = (1 - progress) * fr.iconSize
        if h < 2 then h = 2 end
        fr.cooldownOverlay:SetHeight(h)
    else
        -- Clear cooldown display
        fr.cooldownOverlay:Hide()
        fr.timerText:SetText("")
        fr.texture:SetAlpha(1)
    end

    -- Greyscale Judgement when no seal is active (WoW 1.12: use SetVertexColor)
    if spellName == "Judgement" and not onCD then
        local sealTex = CH:GetActiveSeal()
        if not sealTex then
            fr.texture:SetVertexColor(0.4, 0.4, 0.4)
            fr.desaturated = true
        else
            fr.texture:SetVertexColor(1, 1, 1)
            fr.desaturated = false
        end
    elseif fr.desaturated then
        fr.texture:SetVertexColor(1, 1, 1)
        fr.desaturated = false
    end

    -- "pulse" action: pulse icon opacity when not on CD
    if actions["pulse"] and not onCD then
        if not fr.actionPulsing then
            fr.actionPulsing = true
            fr.actionPulseElapsed = 0
        end
        fr.actionPulseElapsed = (fr.actionPulseElapsed or 0) + 0.05
        local alpha = 0.75 + 0.25 * math.sin(fr.actionPulseElapsed * 2 * math.pi * 1.5)
        fr.texture:SetAlpha(alpha)
    else
        fr.actionPulsing = false
    end

    -- "glow" action: gold border when not on CD
    if actions["glow"] and not onCD then
        if not fr.glowActive then
            fr.glowElapsed = 0
            fr.glowActive  = true
        end
        for i = 1, 4 do
            fr.glowEdges[i]:Show()
        end
    else
        fr.glowActive = false
        for i = 1, 4 do
            fr.glowEdges[i]:Hide()
        end
    end
end

-------------------------------------------------------------------------------
-- CH:ResizeIconFrame(spellName, newSize)
-------------------------------------------------------------------------------

function CH:ResizeIconFrame(spellName, newSize)
    local fr = CH.iconFrames[spellName]
    if not fr then return end

    fr:SetWidth(newSize)
    fr:SetHeight(newSize)
    fr.iconSize = newSize

    local fontSize = math.max(12, math.floor(newSize * 0.55))
    local fontFace, _, fontFlags = fr.timerText:GetFont()
    fr.timerText:SetFont(fontFace or "Fonts\\FRIZQT__.TTF", fontSize, fontFlags or "OUTLINE")
end

-------------------------------------------------------------------------------
-- CH:DestroyIconFrame(spellName)
-------------------------------------------------------------------------------

function CH:DestroyIconFrame(spellName)
    local fr = CH.iconFrames[spellName]
    if not fr then return end

    fr:Hide()
    fr:SetScript("OnUpdate", nil)
    CH.iconFrames[spellName] = nil
end
