-------------------------------------------------------------------------------
-- CooldownHUD - LayoutEngine.lua
-- Row-based layout with scale overrides, drag handle, and combat show/hide
-------------------------------------------------------------------------------

local CH = CooldownHUD

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

CH.activeSpells = {}   -- flat ordered list of spell names currently displayed
CH.rowData      = {}   -- current row definitions: { { scale, spells }, ... }

-------------------------------------------------------------------------------
-- Internal helpers
-------------------------------------------------------------------------------

-- Returns the pixel size for a row given base iconSize and row scale (0-100).
local function RowIconSize(baseSize, scale)
    return math.floor(baseSize * scale / 100)
end

-------------------------------------------------------------------------------
-- CH:LoadLayout()
-- Rebuilds iconFrames and rowData from the preset + db overrides.
-------------------------------------------------------------------------------

function CH:LoadLayout()
    local class = CH.playerClass
    local spec  = CH:GetActiveSpec()

    -- No preset available for this class/spec
    if not class or not spec
       or not CH.Presets
       or not CH.Presets[class]
       or not CH.Presets[class][spec] then
        return
    end

    local preset = CH.Presets[class][spec]

    -- 1. Destroy all existing icon frames
    for name, _ in pairs(CH.iconFrames) do
        CH:DestroyIconFrame(name)
    end
    CH.iconFrames   = {}
    CH.activeSpells = {}
    CH.rowData      = {}

    -- 2. Build rowData from preset rows, applying any db overrides
    local presetRows = preset.rows
    local dbRows     = CH.db.rows or {}
    local baseSize   = CH.db.iconSize or 48

    for rowIdx = 1, table.getn(presetRows) do
        local presetRow = presetRows[rowIdx]
        local override  = dbRows[rowIdx] or {}

        local scale  = override.scale  or presetRow.scale
        local spells = override.spells or presetRow.spells

        local rowEntry = { scale = scale, spells = spells }
        table.insert(CH.rowData, rowEntry)

        -- 3. Create icon frames for each spell at the scaled size
        local iconSize = RowIconSize(baseSize, scale)
        for _, spellName in ipairs(spells) do
            CH:CreateIconFrame(spellName, iconSize)
            table.insert(CH.activeSpells, spellName)
        end
    end

    -- 4. Position everything
    CH:ApplyLayout()
end

-------------------------------------------------------------------------------
-- CH:ApplyLayout()
-- Positions all icon frames based on current db settings and rowData.
-------------------------------------------------------------------------------

function CH:ApplyLayout()
    local posX    = CH.db.posX    or 0
    local posY    = CH.db.posY    or -200
    local baseSize = CH.db.iconSize or 48
    local iconGap  = CH.db.iconGap  or 4
    local rowGap   = CH.db.rowGap   or 4

    -- Calculate the total height of all rows so we can center vertically
    local totalHeight = 0
    for rowIdx = 1, table.getn(CH.rowData) do
        local row      = CH.rowData[rowIdx]
        local rowH     = RowIconSize(baseSize, row.scale)
        totalHeight    = totalHeight + rowH
        if rowIdx < table.getn(CH.rowData) then
            totalHeight = totalHeight + rowGap
        end
    end

    -- Start y from the top of the block; rows go downward
    local startY = posY + math.floor(totalHeight / 2)

    for rowIdx = 1, table.getn(CH.rowData) do
        local row     = CH.rowData[rowIdx]
        local rowH    = RowIconSize(baseSize, row.scale)
        local rowCY   = startY - math.floor(rowH / 2)   -- center-y for this row

        -- Filter to spells that have frames AND are known to the player
        local visible = {}
        for _, spellName in ipairs(row.spells) do
            if CH.iconFrames[spellName] and CH:FindSpell(spellName) then
                table.insert(visible, spellName)
            end
        end

        -- Calculate total row width
        local numVisible = table.getn(visible)
        local rowW = 0
        if numVisible > 0 then
            rowW = numVisible * rowH + (numVisible - 1) * iconGap
        end

        -- Position icons left-to-right
        local startX = posX - math.floor(rowW / 2) + math.floor(rowH / 2)
        for i, spellName in ipairs(visible) do
            local fr   = CH.iconFrames[spellName]
            local iconX = startX + (i - 1) * (rowH + iconGap)

            CH:ResizeIconFrame(spellName, rowH)
            fr:ClearAllPoints()
            fr:SetPoint("CENTER", UIParent, "CENTER", iconX, rowCY)
        end

        -- Hide frames for spells not visible (unknown to player)
        for _, spellName in ipairs(row.spells) do
            if CH.iconFrames[spellName] and not CH:FindSpell(spellName) then
                local fr = CH.iconFrames[spellName]
                fr:Hide()
            end
        end

        -- Advance to next row (move downward)
        startY = startY - rowH - rowGap
    end

    CH:UpdateDragHandle()
end

-------------------------------------------------------------------------------
-- Drag Handle
-------------------------------------------------------------------------------

local dragHandle = CreateFrame("Frame", "CooldownHUD_DragHandle", UIParent)
dragHandle:SetFrameStrata("FULLSCREEN")
dragHandle:SetMovable(true)
dragHandle:SetClampedToScreen(true)
dragHandle:SetAlpha(0)
dragHandle:EnableMouse(false)

-- Dragging state
local isDragging = false

dragHandle:SetScript("OnMouseDown", function()
    isDragging = true
    dragHandle:StartMoving()
end)

dragHandle:SetScript("OnMouseUp", function()
    isDragging = false
    dragHandle:StopMovingOrSizing()

    -- Compute new offset from UIParent center
    local fx, fy   = dragHandle:GetCenter()
    local cx, cy   = UIParent:GetCenter()
    CH.db.posX = math.floor(fx - cx + 0.5)
    CH.db.posY = math.floor(fy - cy + 0.5)

    CH:ApplyLayout()
end)

-- OnUpdate tracker: real-time position sync while dragging
local dragTracker = CreateFrame("Frame")
dragTracker:SetScript("OnUpdate", function()
    if not isDragging then return end

    local fx, fy = dragHandle:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if fx and fy and cx and cy then
        CH.db.posX = math.floor(fx - cx + 0.5)
        CH.db.posY = math.floor(fy - cy + 0.5)
        CH:ApplyLayout()
    end
end)

-------------------------------------------------------------------------------
-- CH:UpdateDragHandle()
-- Sizes and positions the drag handle to cover all rows + 20px padding.
-------------------------------------------------------------------------------

function CH:UpdateDragHandle()
    local posX    = CH.db.posX    or 0
    local posY    = CH.db.posY    or -200
    local baseSize = CH.db.iconSize or 48
    local iconGap  = CH.db.iconGap  or 4
    local rowGap   = CH.db.rowGap   or 4

    if table.getn(CH.rowData) == 0 then
        dragHandle:SetWidth(1)
        dragHandle:SetHeight(1)
        dragHandle:ClearAllPoints()
        dragHandle:SetPoint("CENTER", UIParent, "CENTER", posX, posY)
        return
    end

    -- Calculate overall bounding box
    local totalHeight = 0
    local maxRowWidth = 0

    for rowIdx = 1, table.getn(CH.rowData) do
        local row      = CH.rowData[rowIdx]
        local rowH     = RowIconSize(baseSize, row.scale)

        -- Count visible spells for width calculation
        local numVisible = 0
        for _, spellName in ipairs(row.spells) do
            if CH.iconFrames[spellName] and CH:FindSpell(spellName) then
                numVisible = numVisible + 1
            end
        end

        local rowW = 0
        if numVisible > 0 then
            rowW = numVisible * rowH + (numVisible - 1) * iconGap
        end

        if rowW > maxRowWidth then
            maxRowWidth = rowW
        end

        totalHeight = totalHeight + rowH
        if rowIdx < table.getn(CH.rowData) then
            totalHeight = totalHeight + rowGap
        end
    end

    local pad = 20
    local handleW = math.max(1, maxRowWidth + pad * 2)
    local handleH = math.max(1, totalHeight  + pad * 2)

    dragHandle:SetWidth(handleW)
    dragHandle:SetHeight(handleH)
    dragHandle:ClearAllPoints()
    dragHandle:SetPoint("CENTER", UIParent, "CENTER", posX, posY)
end

-------------------------------------------------------------------------------
-- CH:SetDragEnabled(enabled)
-- Controls mouse interaction and visual feedback on the drag handle.
-------------------------------------------------------------------------------

function CH:SetDragEnabled(enabled)
    if CH.db.locked and not enabled then
        dragHandle:EnableMouse(false)
        dragHandle:SetAlpha(0)
    elseif enabled then
        dragHandle:EnableMouse(true)
        dragHandle:SetAlpha(0.3)
    else
        dragHandle:EnableMouse(false)
        dragHandle:SetAlpha(0)
    end
end

-------------------------------------------------------------------------------
-- CH:UpdateAllIcons()
-- Refreshes cooldown / glow state for every active spell.
-------------------------------------------------------------------------------

function CH:UpdateAllIcons()
    for i = 1, table.getn(CH.activeSpells) do
        CH:UpdateIconState(CH.activeSpells[i])
    end
end

-------------------------------------------------------------------------------
-- CH:ShowAllIcons()
-- Makes all frames for known spells visible.
-------------------------------------------------------------------------------

function CH:ShowAllIcons()
    for i = 1, table.getn(CH.activeSpells) do
        local spellName = CH.activeSpells[i]
        local fr = CH.iconFrames[spellName]
        if fr and CH:FindSpell(spellName) then
            fr:Show()
            fr:SetAlpha(1)
        end
    end
end

-------------------------------------------------------------------------------
-- CH:HideAllIcons()
-- Hides all frames and clears cooldown models, timer text, and glow.
-------------------------------------------------------------------------------

function CH:HideAllIcons()
    for i = 1, table.getn(CH.activeSpells) do
        local spellName = CH.activeSpells[i]
        local fr = CH.iconFrames[spellName]
        if fr then
            fr:Hide()
            fr:SetAlpha(0)

            -- Clear cooldown sweep
            if fr.cooldownModel then
                fr.cooldownModel:SetCooldown(0, 0)
            end

            -- Clear timer text
            if fr.timerText then
                fr.timerText:SetText("")
            end

            -- Clear glow
            fr.glowActive = false
            if fr.glowEdges then
                for j = 1, 4 do
                    fr.glowEdges[j]:Hide()
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- CH:ResetToPreset()
-- Clears per-row overrides and custom rules, then reloads the layout.
-------------------------------------------------------------------------------

function CH:ResetToPreset()
    CH.db.rows                = {}
    CH.db.customRules         = {}
    CH.db.disabledPresetRules = {}
    CH:LoadLayout()
end

-------------------------------------------------------------------------------
-- Event registrations
-------------------------------------------------------------------------------

-- INIT: load layout, then hide if not in combat
CH:RegisterEvent("INIT", function()
    CH:LoadLayout()
    if not CH.inCombat then
        CH:HideAllIcons()
    end
end)

-- SPEC_CHANGED: reload layout, hide if not in combat/test mode
CH:RegisterEvent("SPEC_CHANGED", function()
    CH:LoadLayout()
    if not CH.inCombat and not CH.testMode then
        CH:HideAllIcons()
    end
end)

-- SPELLS_CHANGED: re-apply layout to refresh which spells are known
CH:RegisterEvent("SPELLS_CHANGED", function()
    CH:ApplyLayout()
end)

-- COOLDOWNS_UPDATED: refresh all icon states
CH:RegisterEvent("COOLDOWNS_UPDATED", function()
    CH:UpdateAllIcons()
end)

-- COMBAT_CHANGED: show+update on enter, hide on leave
CH:RegisterEvent("COMBAT_CHANGED", function(entering)
    if entering then
        CH:ShowAllIcons()
        CH:UpdateAllIcons()
    else
        if not CH.testMode then
            CH:HideAllIcons()
        end
    end
end)

-- TEST_MODE_CHANGED: enable drag when test, show/hide accordingly
CH:RegisterEvent("TEST_MODE_CHANGED", function(enabled)
    CH:SetDragEnabled(enabled)
    if enabled then
        CH:ShowAllIcons()
        CH:UpdateAllIcons()
    else
        if not CH.inCombat then
            CH:HideAllIcons()
        end
    end
end)

-- RESET_PRESET: wipe overrides and reload
CH:RegisterEvent("RESET_PRESET", function()
    CH:ResetToPreset()
end)
