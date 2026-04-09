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

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

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
    local iconPath = CH:GetSpellIcon(spellName) or FALLBACK_ICON
    tex:SetTexture(iconPath)
    fr.texture = tex

    -- 2. Cooldown model (radial sweep) ------------------------------------
    local cd = CreateFrame("Cooldown", name .. "_CD", fr)
    cd:SetAllPoints(fr)
    fr.cooldownModel = cd

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
-- CH:UpdateIconState(spellName)
-------------------------------------------------------------------------------

function CH:UpdateIconState(spellName)
    local fr = CH.iconFrames[spellName]
    if not fr then return end

    -- Check spell is known
    local idx = CH:FindSpell(spellName)
    if not idx then
        fr.texture:SetTexture(FALLBACK_ICON)
        fr:SetAlpha(0)
        fr:Hide()
        return
    end

    -- Refresh texture from live spellbook data
    local texPath = GetSpellTexture(idx, BOOKTYPE_SPELL) or FALLBACK_ICON
    fr.texture:SetTexture(texPath)

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
        -- Activate radial sweep
        fr.cooldownModel:SetCooldown(start, duration)
        -- Timer text with colour
        local text, r, g, b = CH:FormatTime(remaining)
        fr.timerText:SetText(text)
        fr.timerText:SetTextColor(r, g, b)
        -- Dim icon texture
        fr.texture:SetAlpha(DIM_ALPHA)
    else
        -- Clear cooldown display
        fr.cooldownModel:SetCooldown(0, 0)
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
