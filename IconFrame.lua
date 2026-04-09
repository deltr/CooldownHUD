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
local DEFAULT_SEAL_ICON = "Interface\\Icons\\Spell_Holy_SealOfMight"

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

    -- 2. Cooldown overlay (dark tint when on CD) --------------------------
    -- WoW 1.12 does not have CreateFrame("Cooldown"). We use a dark overlay
    -- texture that covers the icon when on cooldown, plus the timer text.
    local cdOverlay = fr:CreateTexture(name .. "_CDOverlay", "OVERLAY")
    cdOverlay:SetAllPoints(fr)
    cdOverlay:SetTexture(0, 0, 0, 0.6)
    cdOverlay:Hide()
    fr.cooldownOverlay = cdOverlay

    -- 3. Timer text -------------------------------------------------------
    -- Child frame sits above the cooldown model in the frame stack
    local textFrame = CreateFrame("Frame", name .. "_TextFrame", fr)
    textFrame:SetAllPoints(fr)
    textFrame:SetFrameLevel(fr:GetFrameLevel() + 5)

    local fontSize = math.max(12, math.min(48, math.floor(size * 0.45)))
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

    -- 5. Glow pulse OnUpdate ---------------------------------------------
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

local function GetActiveSeal()
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

    local sealTex, timeLeft = GetActiveSeal()

    if sealTex then
        fr.texture:SetTexture(sealTex)
        fr.cooldownOverlay:Hide()
        fr.texture:SetAlpha(1)

        if timeLeft and timeLeft > 0 then
            local text, r, g, b = CH:FormatTime(timeLeft)
            fr.timerText:SetText(text)
            fr.timerText:SetTextColor(r, g, b)
        else
            fr.timerText:SetText("")
        end
    else
        fr.texture:SetTexture(DEFAULT_SEAL_ICON)
        fr.cooldownOverlay:Hide()
        fr.texture:SetAlpha(DIM_ALPHA)
        fr.timerText:SetText("")
    end

    -- No glow for seal tracker
    fr.glowActive = false
    for i = 1, 4 do
        fr.glowEdges[i]:Hide()
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
    else
        -- Clear cooldown display
        fr.cooldownOverlay:Hide()
        fr.timerText:SetText("")
        fr.texture:SetAlpha(1)
    end

    -- Glow logic: only glow when spell is ready (not on CD)
    if CH:ShouldGlow(spellName) and not onCD then
        -- Activate glow
        if not fr.glowActive then
            fr.glowElapsed = 0
            fr.glowActive  = true
        end
        for i = 1, 4 do
            fr.glowEdges[i]:Show()
        end
    else
        -- Deactivate glow
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

    local fontSize = math.max(12, math.min(48, math.floor(newSize * 0.45)))
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
