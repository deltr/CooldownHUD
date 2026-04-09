-------------------------------------------------------------------------------
-- CooldownHUD - ConfigPanel.lua
-- Tabbed configuration panel: General, Spells, Rules
-------------------------------------------------------------------------------

local CH = CooldownHUD

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local PANEL_W      = 420
local PANEL_H      = 500
local TAB_H        = 24
local CONTENT_TOP  = -70   -- y-offset from panel top where tab content starts
local CONTENT_PAD  = 14

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function MakeBackdrop(bgFile, edgeFile)
    return {
        bgFile   = bgFile   or "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = edgeFile or "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 32, edgeSize = 32,
        insets   = { left = 11, right = 12, top = 12, bottom = 11 },
    }
end

-- Enables mouse-wheel scrolling on a ScrollFrame
local function EnableScrollWheel(scrollFrame)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function()
        local cur = scrollFrame:GetVerticalScroll()
        local max = scrollFrame:GetVerticalScrollRange()
        local step = 40
        local delta = arg1  -- WoW 1.12 global: +1 up, -1 down
        local newVal = cur - (delta * step)
        if newVal < 0 then newVal = 0 end
        if newVal > max then newVal = max end
        scrollFrame:SetVerticalScroll(newVal)
    end)
end

-- Creates a simple UIPanelButtonTemplate button
local function MakeButton(parent, w, h, text)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetWidth(w)
    btn:SetHeight(h)
    btn:SetText(text)
    return btn
end

-- Creates a slider using OptionsSliderTemplate.
-- Returns slider, textLabel, lowLabel, highLabel
local function MakeSlider(parent, name, w, min, max, step, labelText, lowText, highText)
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetWidth(w)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step or 1)
    s:SetValue(min)
    local lbl  = getglobal(name .. "Text")
    local low  = getglobal(name .. "Low")
    local high = getglobal(name .. "High")
    if lbl  then lbl:SetText(labelText or name) end
    if low  then low:SetText(tostring(lowText  or min)) end
    if high then high:SetText(tostring(highText or max)) end
    return s, lbl, low, high
end

-------------------------------------------------------------------------------
-- Main Config Frame
-------------------------------------------------------------------------------

local cfgFrame = CreateFrame("Frame", "CooldownHUD_ConfigFrame", UIParent)
cfgFrame:SetWidth(PANEL_W)
cfgFrame:SetHeight(PANEL_H)
cfgFrame:SetFrameStrata("DIALOG")
cfgFrame:SetMovable(true)
cfgFrame:SetClampedToScreen(true)
cfgFrame:EnableMouse(true)
cfgFrame:SetBackdrop(MakeBackdrop())

-- Title
local titleText = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
titleText:SetPoint("TOP", cfgFrame, "TOP", 0, -16)
titleText:SetText("CooldownHUD")

-- Spec label (below title)
local specLabel = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
specLabel:SetPoint("TOP", titleText, "BOTTOM", 0, -4)
specLabel:SetText("Spec: Auto-Detect")

-- Close button (top-right)
local closeBtn = CreateFrame("Button", nil, cfgFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", cfgFrame, "TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function()
    cfgFrame:Hide()
end)

-- Drag via title area
cfgFrame:SetScript("OnMouseDown", function()
    cfgFrame:StartMoving()
end)
cfgFrame:SetScript("OnMouseUp", function()
    cfgFrame:StopMovingOrSizing()
    local x, y = cfgFrame:GetLeft(), cfgFrame:GetTop()
    if x and y then
        CH.db.cfgX = x
        CH.db.cfgY = y
    end
end)

cfgFrame:Hide()

-------------------------------------------------------------------------------
-- Tab Buttons
-------------------------------------------------------------------------------

local TAB_NAMES  = { "General", "Spells", "Rules" }
local tabButtons = {}
local tabPanels  = {}
local activeTab  = 1

local function ShowTab(idx)
    activeTab = idx
    for i, panel in ipairs(tabPanels) do
        if i == idx then
            panel:Show()
        else
            panel:Hide()
        end
    end
    -- Refresh active tab content
    if idx == 1 then
        CH:RefreshGeneralTab()
    elseif idx == 2 then
        CH:RefreshSpellsTab()
    elseif idx == 3 then
        CH:RefreshRulesTab()
    end
end

local tabY   = -56
local tabW   = 90
local tabGap = 8
local totalTabW = table.getn(TAB_NAMES) * tabW + (table.getn(TAB_NAMES) - 1) * tabGap
local tabStartX = -(totalTabW / 2) + tabW / 2

for i, name in ipairs(TAB_NAMES) do
    local btn = MakeButton(cfgFrame, tabW, TAB_H, name)
    btn:SetPoint("TOP", cfgFrame, "TOP", tabStartX + (i - 1) * (tabW + tabGap), tabY)
    local idx = i
    btn:SetScript("OnClick", function()
        ShowTab(idx)
    end)
    tabButtons[i] = btn
end

-------------------------------------------------------------------------------
-- Tab Content Panels
-------------------------------------------------------------------------------

local contentY  = CONTENT_TOP
local contentH  = PANEL_H + contentY - 10
local contentW  = PANEL_W - CONTENT_PAD * 2

for i = 1, table.getn(TAB_NAMES) do
    local panel = CreateFrame("Frame", nil, cfgFrame)
    panel:SetPoint("TOPLEFT",  cfgFrame, "TOPLEFT",  CONTENT_PAD, contentY)
    panel:SetPoint("TOPRIGHT", cfgFrame, "TOPRIGHT", -CONTENT_PAD, contentY)
    panel:SetHeight(contentH)
    panel:Hide()
    tabPanels[i] = panel
end

-------------------------------------------------------------------------------
-- ===== GENERAL TAB =====
-------------------------------------------------------------------------------

local genPanel = tabPanels[1]
local genSliders = {}

do
    local y = -10
    local lx = 10

    -- Spec override button
    local specOverrideLabel = genPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    specOverrideLabel:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx, y)
    specOverrideLabel:SetText("Spec Override:")

    local specBtn = MakeButton(genPanel, 140, 22, "Auto-Detect")
    specBtn:SetPoint("LEFT", specOverrideLabel, "RIGHT", 10, 0)
    specBtn:SetScript("OnClick", function()
        local specNames = CH:GetSpecNames()
        local current   = CH.db.spec or ""
        -- Build ordered list: "", then each spec name
        local opts = { "" }
        for _, v in ipairs(specNames) do
            table.insert(opts, v)
        end
        -- Find current index
        local curIdx = 1
        for i, v in ipairs(opts) do
            if v == current then curIdx = i; break end
        end
        -- Advance
        local nextIdx = (math.mod(curIdx, table.getn(opts))) + 1
        local nextSpec = opts[nextIdx]
        CH:SetSpecOverride(nextSpec)
        if nextSpec == "" then
            specBtn:SetText("Auto-Detect")
        else
            specBtn:SetText(nextSpec)
        end
        CH:RefreshGeneralTab()
    end)

    y = y - 44

    -- Sliders
    local sliderDefs = {
        { key="iconSize", label="Icon Size",  min=24, max=96,  step=1,  low="24",  high="96" },
        { key="iconGap",  label="Icon Gap",   min=0,  max=20,  step=1,  low="0",   high="20" },
        { key="rowGap",   label="Row Gap",    min=0,  max=20,  step=1,  low="0",   high="20" },
    }

    for si, def in ipairs(sliderDefs) do
        local sname = "CooldownHUD_GenSlider_" .. def.key
        local s = MakeSlider(genPanel, sname, 200, def.min, def.max, def.step,
                             def.label, def.low, def.high)
        s:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx + 10, y)
        y = y - 46

        local key = def.key
        local closureLabel = def.label  -- Lua 5.0: capture loop var in local
        s:SetScript("OnValueChanged", function()
            local v = math.floor(this:GetValue() + 0.5)
            if not CH.db then return end
            CH.db[key] = v
            local lbl = getglobal("CooldownHUD_GenSlider_" .. key .. "Text")
            if lbl then lbl:SetText(closureLabel .. ": " .. v) end
            CH:ApplyLayout()
        end)

        genSliders[def.key] = s
    end

    -- Per-row scale sliders
    local rowDefs = {
        { row=1, label="Row 1 Scale (%)", min=25, max=150, step=5, low="25", high="150" },
        { row=2, label="Row 2 Scale (%)", min=25, max=150, step=5, low="25", high="150" },
        { row=3, label="Row 3 Scale (%)", min=25, max=150, step=5, low="25", high="150" },
    }

    for _, def in ipairs(rowDefs) do
        local sname = "CooldownHUD_GenSlider_row" .. def.row
        local s = MakeSlider(genPanel, sname, 200, def.min, def.max, def.step,
                             def.label, def.low, def.high)
        s:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx + 10, y)
        y = y - 46

        local row = def.row
        local closureLabel = def.label  -- Lua 5.0: capture loop var in local
        s:SetScript("OnValueChanged", function()
            local v = math.floor(this:GetValue() + 0.5)
            if not CH.db then return end
            if not CH.db.rows then CH.db.rows = {} end
            if not CH.db.rows[row] then CH.db.rows[row] = {} end
            CH.db.rows[row].scale = v
            local lbl = getglobal("CooldownHUD_GenSlider_row" .. row .. "Text")
            if lbl then lbl:SetText(closureLabel .. ": " .. v .. "%") end
            -- Update rowData live
            if CH.rowData[row] then
                CH.rowData[row].scale = v
            end
            CH:ApplyLayout()
        end)

        genSliders["row" .. row] = s
    end

    y = y - 10

    -- Lock Position button
    local lockBtn = MakeButton(genPanel, 130, 22, "Lock Position: OFF")
    lockBtn:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx, y)
    lockBtn:SetScript("OnClick", function()
        CH.db.locked = not CH.db.locked
        if CH.db.locked then
            lockBtn:SetText("Lock Position: ON")
            CH:SetDragEnabled(false)
        else
            lockBtn:SetText("Lock Position: OFF")
            if CH.testMode then
                CH:SetDragEnabled(true)
            end
        end
    end)

    -- Test Mode button
    local testBtn = MakeButton(genPanel, 130, 22, "Test Mode: OFF")
    testBtn:SetPoint("LEFT", lockBtn, "RIGHT", 10, 0)
    testBtn:SetScript("OnClick", function()
        CH.testMode = not CH.testMode
        if CH.testMode then
            testBtn:SetText("Test Mode: ON")
        else
            testBtn:SetText("Test Mode: OFF")
        end
        CH:FireEvent("TEST_MODE_CHANGED", CH.testMode)
    end)

    y = y - 32

    -- Reset to Preset button
    local resetBtn = MakeButton(genPanel, 140, 22, "Reset to Preset")
    resetBtn:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx, y)
    resetBtn:SetScript("OnClick", function()
        CH:FireEvent("RESET_PRESET")
        CH:RefreshGeneralTab()
    end)

    -- Store references on panel for refresh
    genPanel.specBtn  = specBtn
    genPanel.lockBtn  = lockBtn
    genPanel.testBtn  = testBtn
end

-- Refresh General Tab values from db
function CH:RefreshGeneralTab()
    -- Spec button label
    local specNames = CH:GetSpecNames()
    local current = CH.db and CH.db.spec or nil
    if current and current ~= "" then
        genPanel.specBtn:SetText(current)
    else
        genPanel.specBtn:SetText("Auto-Detect")
    end

    -- Spec label at top of window
    local activeSpec = CH:GetActiveSpec()
    if activeSpec then
        specLabel:SetText("Spec: " .. activeSpec)
    else
        specLabel:SetText("Spec: Auto-Detect")
    end

    -- Slider values
    local db = CH.db
    if not db then return end

    local sliderKeys = { "iconSize", "iconGap", "rowGap" }
    for _, key in ipairs(sliderKeys) do
        local s = genSliders[key]
        if s and db[key] then
            s:SetValue(db[key])
        end
    end

    -- Row sliders
    local dbRows = db.rows or {}
    for row = 1, 3 do
        local s = genSliders["row" .. row]
        if s then
            local rowScale = 100
            if dbRows[row] and dbRows[row].scale then
                rowScale = dbRows[row].scale
            elseif CH.rowData[row] then
                rowScale = CH.rowData[row].scale
            end
            s:SetValue(rowScale)
        end
    end

    -- Lock/Test buttons
    if db.locked then
        genPanel.lockBtn:SetText("Lock Position: ON")
    else
        genPanel.lockBtn:SetText("Lock Position: OFF")
    end
    if CH.testMode then
        genPanel.testBtn:SetText("Test Mode: ON")
    else
        genPanel.testBtn:SetText("Test Mode: OFF")
    end
end

-------------------------------------------------------------------------------
-- ===== SPELLS TAB =====
-------------------------------------------------------------------------------

local spellsPanel = tabPanels[2]

-- ScrollFrame for spells list
local spellScroll = CreateFrame("ScrollFrame", "CooldownHUD_SpellScroll", spellsPanel)
spellScroll:SetPoint("TOPLEFT",     spellsPanel, "TOPLEFT",  0, -4)
spellScroll:SetPoint("BOTTOMRIGHT", spellsPanel, "BOTTOMRIGHT", 0, 34)

local spellContent = CreateFrame("Frame", "CooldownHUD_SpellContent", spellScroll)
spellContent:SetWidth(contentW - 10)
spellContent:SetHeight(1)
spellScroll:SetScrollChild(spellContent)
EnableScrollWheel(spellScroll)

-- "+ Add Spell" button at bottom of spells panel
local addSpellBtn = MakeButton(spellsPanel, 110, 22, "+ Add Spell")
addSpellBtn:SetPoint("BOTTOMLEFT", spellsPanel, "BOTTOMLEFT", 4, 4)
addSpellBtn:SetScript("OnClick", function()
    CH:FireEvent("OPEN_SPELL_BROWSER")
end)

-- Rows pool for spell list entries (we recycle/recreate each refresh)
local spellRows = {}

local function ClearSpellRows()
    for _, row in ipairs(spellRows) do
        row:Hide()
    end
    spellRows = {}
end

local function GetRowLabel(rowIdx)
    return "R" .. rowIdx
end

-- Rebuild the spells scroll content from CH.rowData
function CH:RefreshSpellsTab()
    ClearSpellRows()

    local rowData = CH.rowData or {}
    local y       = 0

    for rowIdx = 1, table.getn(rowData) do
        local row    = rowData[rowIdx]
        local spells = row.spells or {}

        -- Row header label
        local headerH  = 20
        local headerFr = CreateFrame("Frame", nil, spellContent)
        headerFr:SetWidth(contentW - 10)
        headerFr:SetHeight(headerH)
        headerFr:SetPoint("TOPLEFT", spellContent, "TOPLEFT", 0, -y)

        local hLabel = headerFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hLabel:SetPoint("LEFT", headerFr, "LEFT", 4, 0)
        hLabel:SetText("-- Row " .. rowIdx .. " (scale: " .. (row.scale or 100) .. "%) --")
        hLabel:SetTextColor(0.8, 0.8, 0.2, 1)

        table.insert(spellRows, headerFr)
        y = y + headerH + 2

        for spellIdx = 1, table.getn(spells) do
            local spellName = spells[spellIdx]
            local entryH    = 24
            local entryFr   = CreateFrame("Frame", nil, spellContent)
            entryFr:SetWidth(contentW - 10)
            entryFr:SetHeight(entryH)
            entryFr:SetPoint("TOPLEFT", spellContent, "TOPLEFT", 0, -y)

            -- Icon thumbnail
            local iconTex = entryFr:CreateTexture(nil, "ARTWORK")
            iconTex:SetWidth(18)
            iconTex:SetHeight(18)
            iconTex:SetPoint("LEFT", entryFr, "LEFT", 4, 0)
            local iconPath = CH:GetSpellIcon(spellName)
            if iconPath then
                iconTex:SetTexture(iconPath)
            else
                iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            -- Spell name label
            local nameLabel = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameLabel:SetPoint("LEFT", iconTex, "RIGHT", 4, 0)
            nameLabel:SetWidth(130)
            nameLabel:SetJustifyH("LEFT")
            nameLabel:SetText(spellName)

            -- Row assignment button (cycles R1->R2->R3->R1)
            local numRows = table.getn(rowData)
            local rowBtn  = MakeButton(entryFr, 36, 18, GetRowLabel(rowIdx))
            rowBtn:SetPoint("LEFT", nameLabel, "RIGHT", 6, 0)
            local closureRowIdx   = rowIdx
            local closureSpellIdx = spellIdx
            local closureSpellName = spellName
            rowBtn:SetScript("OnClick", function()
                -- Find current row
                local curRow = nil
                for ri, rd in ipairs(CH.rowData) do
                    for si, sn in ipairs(rd.spells) do
                        if sn == closureSpellName then
                            curRow = ri
                            break
                        end
                    end
                    if curRow then break end
                end
                if not curRow then return end
                -- Cycle to next row
                local nextRow = (math.mod(curRow, table.getn(CH.rowData))) + 1
                -- Remove from current row
                local oldSpells = CH.rowData[curRow].spells
                local newOld = {}
                for _, sn in ipairs(oldSpells) do
                    if sn ~= closureSpellName then
                        table.insert(newOld, sn)
                    end
                end
                CH.rowData[curRow].spells = newOld
                -- Add to next row
                table.insert(CH.rowData[nextRow].spells, closureSpellName)
                CH:SaveRowOverrides()
                CH:ApplyLayout()
                CH:RefreshSpellsTab()
            end)

            -- Up button
            local upBtn = MakeButton(entryFr, 24, 18, "^")
            upBtn:SetPoint("LEFT", rowBtn, "RIGHT", 4, 0)
            upBtn:SetScript("OnClick", function()
                local curRow, curIdx = nil, nil
                for ri, rd in ipairs(CH.rowData) do
                    for si, sn in ipairs(rd.spells) do
                        if sn == closureSpellName then
                            curRow = ri; curIdx = si; break
                        end
                    end
                    if curRow then break end
                end
                if not curRow or curIdx <= 1 then return end
                local spellList = CH.rowData[curRow].spells
                local tmp = spellList[curIdx - 1]
                spellList[curIdx - 1] = spellList[curIdx]
                spellList[curIdx]     = tmp
                CH:SaveRowOverrides()
                CH:ApplyLayout()
                CH:RefreshSpellsTab()
            end)

            -- Down button
            local dnBtn = MakeButton(entryFr, 24, 18, "v")
            dnBtn:SetPoint("LEFT", upBtn, "RIGHT", 2, 0)
            dnBtn:SetScript("OnClick", function()
                local curRow, curIdx = nil, nil
                for ri, rd in ipairs(CH.rowData) do
                    for si, sn in ipairs(rd.spells) do
                        if sn == closureSpellName then
                            curRow = ri; curIdx = si; break
                        end
                    end
                    if curRow then break end
                end
                if not curRow then return end
                local spellList = CH.rowData[curRow].spells
                if curIdx >= table.getn(spellList) then return end
                local tmp = spellList[curIdx + 1]
                spellList[curIdx + 1] = spellList[curIdx]
                spellList[curIdx]     = tmp
                CH:SaveRowOverrides()
                CH:ApplyLayout()
                CH:RefreshSpellsTab()
            end)

            -- X (remove) button
            local xBtn = MakeButton(entryFr, 22, 18, "X")
            xBtn:SetPoint("LEFT", dnBtn, "RIGHT", 2, 0)
            xBtn:SetScript("OnClick", function()
                local curRow = nil
                for ri, rd in ipairs(CH.rowData) do
                    for _, sn in ipairs(rd.spells) do
                        if sn == closureSpellName then curRow = ri; break end
                    end
                    if curRow then break end
                end
                if not curRow then return end
                local newSpells = {}
                for _, sn in ipairs(CH.rowData[curRow].spells) do
                    if sn ~= closureSpellName then
                        table.insert(newSpells, sn)
                    end
                end
                CH.rowData[curRow].spells = newSpells
                -- Also remove from activeSpells
                local newActive = {}
                for _, sn in ipairs(CH.activeSpells) do
                    if sn ~= closureSpellName then
                        table.insert(newActive, sn)
                    end
                end
                CH.activeSpells = newActive
                CH:DestroyIconFrame(closureSpellName)
                CH:SaveRowOverrides()
                CH:ApplyLayout()
                CH:RefreshSpellsTab()
            end)

            table.insert(spellRows, entryFr)
            y = y + entryH + 2
        end

        y = y + 6
    end

    -- Resize content frame to fit
    if y < 10 then y = 10 end
    spellContent:SetHeight(y)
end

-------------------------------------------------------------------------------
-- ===== RULES TAB =====
-------------------------------------------------------------------------------

local rulesPanel = tabPanels[3]

-- ScrollFrame for rules list
local rulesScroll = CreateFrame("ScrollFrame", "CooldownHUD_RulesScroll", rulesPanel)
rulesScroll:SetPoint("TOPLEFT",     rulesPanel, "TOPLEFT",  0, -4)
rulesScroll:SetPoint("BOTTOMRIGHT", rulesPanel, "BOTTOMRIGHT", 0, 34)

local rulesContent = CreateFrame("Frame", "CooldownHUD_RulesContent", rulesScroll)
rulesContent:SetWidth(contentW - 10)
rulesContent:SetHeight(1)
rulesScroll:SetScrollChild(rulesContent)
EnableScrollWheel(rulesScroll)

-- "+ New Rule" button
local addRuleBtn = MakeButton(rulesPanel, 110, 22, "+ New Rule")
addRuleBtn:SetPoint("BOTTOMLEFT", rulesPanel, "BOTTOMLEFT", 4, 4)
addRuleBtn:SetScript("OnClick", function()
    CH:FireEvent("OPEN_RULE_EDITOR")
end)

local ruleRows = {}

local function ClearRuleRows()
    for _, row in ipairs(ruleRows) do
        row:Hide()
    end
    ruleRows = {}
end

-- Build a one-line condition summary
local function ConditionSummary(conditions)
    if not conditions or table.getn(conditions) == 0 then
        return "(no conditions)"
    end
    local parts = {}
    for _, cond in ipairs(conditions) do
        local condType = cond[1]
        local param    = cond[2]
        local label    = condType
        -- Find label in conditionTypes
        for _, ct in ipairs(CH.conditionTypes) do
            if ct.id == condType then
                label = ct.label
                break
            end
        end
        if param then
            table.insert(parts, label .. " [" .. tostring(param) .. "]")
        else
            table.insert(parts, label)
        end
    end
    local s = parts[1] or ""
    for i = 2, table.getn(parts) do
        s = s .. " AND " .. parts[i]
    end
    return s
end

function CH:RefreshRulesTab()
    ClearRuleRows()

    local y = 0

    -- ---- Preset rules section ----
    local class = CH.playerClass
    local spec  = CH:GetActiveSpec()

    local presetRules = {}
    if class and spec
       and CH.Presets
       and CH.Presets[class]
       and CH.Presets[class][spec]
       and CH.Presets[class][spec].glowRules then
        presetRules = CH.Presets[class][spec].glowRules
    end

    if table.getn(presetRules) > 0 then
        -- Section header
        local hFr = CreateFrame("Frame", nil, rulesContent)
        hFr:SetWidth(contentW - 10)
        hFr:SetHeight(18)
        hFr:SetPoint("TOPLEFT", rulesContent, "TOPLEFT", 0, -y)
        local hLbl = hFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hLbl:SetPoint("LEFT", hFr, "LEFT", 4, 0)
        hLbl:SetText("Preset Rules")
        hLbl:SetTextColor(0.8, 0.8, 0.2, 1)
        table.insert(ruleRows, hFr)
        y = y + 20

        local disabled = CH.db.disabledPresetRules or {}

        for _, rule in ipairs(presetRules) do
            local firstCondType = ""
            if rule.conditions and rule.conditions[1] then
                firstCondType = rule.conditions[1][1] or ""
            end
            local key     = rule.spell .. ":" .. firstCondType
            local enabled = not disabled[key]

            local entryH  = 22
            local entryFr = CreateFrame("Frame", nil, rulesContent)
            entryFr:SetWidth(contentW - 10)
            entryFr:SetHeight(entryH)
            entryFr:SetPoint("TOPLEFT", rulesContent, "TOPLEFT", 0, -y)

            -- Toggle button
            local togBtn = MakeButton(entryFr, 50, 18, enabled and "ON" or "OFF")
            togBtn:SetPoint("LEFT", entryFr, "LEFT", 4, 0)
            local closureKey = key
            togBtn:SetScript("OnClick", function()
                if not CH.db.disabledPresetRules then
                    CH.db.disabledPresetRules = {}
                end
                if CH.db.disabledPresetRules[closureKey] then
                    CH.db.disabledPresetRules[closureKey] = nil
                    togBtn:SetText("ON")
                else
                    CH.db.disabledPresetRules[closureKey] = true
                    togBtn:SetText("OFF")
                end
            end)

            -- Spell name
            local nameLbl = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameLbl:SetPoint("LEFT", togBtn, "RIGHT", 6, 0)
            nameLbl:SetWidth(90)
            nameLbl:SetJustifyH("LEFT")
            nameLbl:SetText(rule.spell)
            if not enabled then
                nameLbl:SetTextColor(0.5, 0.5, 0.5, 1)
            end

            -- Condition summary
            local condLbl = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            condLbl:SetPoint("LEFT", nameLbl, "RIGHT", 4, 0)
            condLbl:SetWidth(170)
            condLbl:SetJustifyH("LEFT")
            condLbl:SetText(ConditionSummary(rule.conditions))
            condLbl:SetTextColor(0.7, 0.7, 0.7, 1)

            table.insert(ruleRows, entryFr)
            y = y + entryH + 2
        end
    end

    -- ---- Custom rules section ----
    local customRules = CH.db.customRules or {}

    if table.getn(customRules) > 0 then
        y = y + 6
        -- Section header
        local hFr = CreateFrame("Frame", nil, rulesContent)
        hFr:SetWidth(contentW - 10)
        hFr:SetHeight(18)
        hFr:SetPoint("TOPLEFT", rulesContent, "TOPLEFT", 0, -y)
        local hLbl = hFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hLbl:SetPoint("LEFT", hFr, "LEFT", 4, 0)
        hLbl:SetText("Custom Rules")
        hLbl:SetTextColor(0.8, 0.8, 0.2, 1)
        table.insert(ruleRows, hFr)
        y = y + 20

        for ci, rule in ipairs(customRules) do
            local entryH  = 22
            local entryFr = CreateFrame("Frame", nil, rulesContent)
            entryFr:SetWidth(contentW - 10)
            entryFr:SetHeight(entryH)
            entryFr:SetPoint("TOPLEFT", rulesContent, "TOPLEFT", 0, -y)

            -- Spell name
            local nameLbl = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameLbl:SetPoint("LEFT", entryFr, "LEFT", 4, 0)
            nameLbl:SetWidth(100)
            nameLbl:SetJustifyH("LEFT")
            nameLbl:SetText(rule.spell or "?")

            -- Condition summary
            local condLbl = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            condLbl:SetPoint("LEFT", nameLbl, "RIGHT", 4, 0)
            condLbl:SetWidth(200)
            condLbl:SetJustifyH("LEFT")
            condLbl:SetText(ConditionSummary(rule.conditions))
            condLbl:SetTextColor(0.7, 0.7, 0.7, 1)

            -- Delete button
            local delBtn = MakeButton(entryFr, 22, 18, "X")
            delBtn:SetPoint("RIGHT", entryFr, "RIGHT", -4, 0)
            local closureIdx = ci
            delBtn:SetScript("OnClick", function()
                table.remove(CH.db.customRules, closureIdx)
                CH:RefreshRulesTab()
            end)

            table.insert(ruleRows, entryFr)
            y = y + entryH + 2
        end
    end

    if y < 10 then y = 10 end
    rulesContent:SetHeight(y)
end

-------------------------------------------------------------------------------
-- ===== SPELL BROWSER POPUP =====
-------------------------------------------------------------------------------

local spellBrowser = CreateFrame("Frame", "CooldownHUD_SpellBrowser", UIParent)
spellBrowser:SetWidth(280)
spellBrowser:SetHeight(350)
spellBrowser:SetFrameStrata("FULLSCREEN")
spellBrowser:SetMovable(true)
spellBrowser:SetClampedToScreen(true)
spellBrowser:EnableMouse(true)
spellBrowser:SetBackdrop(MakeBackdrop())
spellBrowser:Hide()

-- Title
local sbTitle = spellBrowser:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
sbTitle:SetPoint("TOP", spellBrowser, "TOP", 0, -14)
sbTitle:SetText("Add Spell")

-- Drag
spellBrowser:SetScript("OnMouseDown", function() spellBrowser:StartMoving() end)
spellBrowser:SetScript("OnMouseUp",   function() spellBrowser:StopMovingOrSizing() end)

-- Close button
local sbClose = CreateFrame("Button", nil, spellBrowser, "UIPanelCloseButton")
sbClose:SetPoint("TOPRIGHT", spellBrowser, "TOPRIGHT", -4, -4)
sbClose:SetScript("OnClick", function() spellBrowser:Hide() end)

-- Search box (OnTextChanged wired after RefreshSpellBrowser is defined below)
local sbSearchBox = CreateFrame("EditBox", "CooldownHUD_SBSearch", spellBrowser, "InputBoxTemplate")
sbSearchBox:SetWidth(220)
sbSearchBox:SetHeight(20)
sbSearchBox:SetPoint("TOPLEFT", spellBrowser, "TOPLEFT", 14, -36)
sbSearchBox:SetAutoFocus(false)
sbSearchBox:SetMaxLetters(64)
sbSearchBox:SetScript("OnEscapePressed", function()
    sbSearchBox:SetText("")
    sbSearchBox:ClearFocus()
end)

-- Target row selector
local sbRowLabel = spellBrowser:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sbRowLabel:SetPoint("TOPLEFT", spellBrowser, "TOPLEFT", 14, -62)
sbRowLabel:SetText("Add to:")

local sbTargetRow   = 1
local sbRowBtn = MakeButton(spellBrowser, 46, 20, "Row 1")
sbRowBtn:SetPoint("LEFT", sbRowLabel, "RIGHT", 6, 0)
sbRowBtn:SetScript("OnClick", function()
    local numRows = math.max(1, table.getn(CH.rowData))
    sbTargetRow = (math.mod(sbTargetRow, numRows)) + 1
    sbRowBtn:SetText("Row " .. sbTargetRow)
end)

-- Scroll frame for spell list
local sbScroll = CreateFrame("ScrollFrame", "CooldownHUD_SBScroll", spellBrowser)
sbScroll:SetPoint("TOPLEFT",  spellBrowser, "TOPLEFT",  10, -88)
sbScroll:SetPoint("BOTTOMRIGHT", spellBrowser, "BOTTOMRIGHT", -10, 10)

local sbContent = CreateFrame("Frame", "CooldownHUD_SBContent", sbScroll)
sbContent:SetWidth(250)
sbContent:SetHeight(1)
sbScroll:SetScrollChild(sbContent)
EnableScrollWheel(sbScroll)

local sbRows = {}

local function ClearSBRows()
    for _, row in ipairs(sbRows) do row:Hide() end
    sbRows = {}
end

local function RefreshSpellBrowser()
    ClearSBRows()

    -- Build set of already-tracked spells
    local tracked = {}
    for _, rd in ipairs(CH.rowData or {}) do
        for _, sn in ipairs(rd.spells or {}) do
            tracked[sn] = true
        end
    end

    -- Get search filter text (sbSearchBox declared earlier in this scope)
    local searchText = ""
    if sbSearchBox then
        searchText = string.lower(sbSearchBox:GetText() or "")
    end

    local allSpells = CH:GetAllSpellNames()
    local y = 0

    for _, spellName in ipairs(allSpells) do
        -- Apply search filter
        if searchText ~= "" and not string.find(string.lower(spellName), searchText, 1, true) then
            -- skip: doesn't match search
        elseif not tracked[spellName] then
            local entryH  = 24
            local entryFr = CreateFrame("Frame", nil, sbContent)
            entryFr:SetWidth(250)
            entryFr:SetHeight(entryH)
            entryFr:SetPoint("TOPLEFT", sbContent, "TOPLEFT", 0, -y)

            -- Icon
            local iconTex = entryFr:CreateTexture(nil, "ARTWORK")
            iconTex:SetWidth(18)
            iconTex:SetHeight(18)
            iconTex:SetPoint("LEFT", entryFr, "LEFT", 4, 0)
            local iconPath = CH:GetSpellIcon(spellName)
            if iconPath then
                iconTex:SetTexture(iconPath)
            else
                iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            -- Name
            local nameLbl = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameLbl:SetPoint("LEFT", iconTex, "RIGHT", 4, 0)
            nameLbl:SetWidth(160)
            nameLbl:SetJustifyH("LEFT")
            nameLbl:SetText(spellName)

            -- "+" button
            local addBtn = MakeButton(entryFr, 24, 18, "+")
            addBtn:SetPoint("RIGHT", entryFr, "RIGHT", -4, 0)
            local closureName = spellName
            addBtn:SetScript("OnClick", function()
                -- Ensure target row exists
                if not CH.rowData[sbTargetRow] then sbTargetRow = 1 end
                if not CH.rowData[sbTargetRow] then return end

                -- Add spell to row
                table.insert(CH.rowData[sbTargetRow].spells, closureName)
                table.insert(CH.activeSpells, closureName)

                -- Create icon frame
                local baseSize  = CH.db.iconSize or 48
                local rowScale  = CH.rowData[sbTargetRow].scale or 100
                local iconSize  = math.floor(baseSize * rowScale / 100)
                CH:CreateIconFrame(closureName, iconSize)

                CH:SaveRowOverrides()
                CH:ApplyLayout()
                CH:RefreshSpellsTab()
                -- Refresh browser to remove just-added spell
                RefreshSpellBrowser()
            end)

            table.insert(sbRows, entryFr)
            y = y + entryH + 2
        end
    end

    if y < 10 then y = 10 end
    sbContent:SetHeight(y)
end

-- Wire search box OnTextChanged now that RefreshSpellBrowser is defined
sbSearchBox:SetScript("OnTextChanged", function()
    RefreshSpellBrowser()
end)

-- Event: OPEN_SPELL_BROWSER
CH:RegisterEvent("OPEN_SPELL_BROWSER", function()
    sbTargetRow = 1
    sbRowBtn:SetText("Row 1")
    sbSearchBox:SetText("")
    RefreshSpellBrowser()
    spellBrowser:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    spellBrowser:Show()
end)

-------------------------------------------------------------------------------
-- ===== RULE EDITOR POPUP =====
-------------------------------------------------------------------------------

local ruleEditor = CreateFrame("Frame", "CooldownHUD_RuleEditor", UIParent)
ruleEditor:SetWidth(340)
ruleEditor:SetHeight(280)
ruleEditor:SetFrameStrata("FULLSCREEN")
ruleEditor:SetMovable(true)
ruleEditor:SetClampedToScreen(true)
ruleEditor:EnableMouse(true)
ruleEditor:SetBackdrop(MakeBackdrop())
ruleEditor:Hide()

-- Title
local reTitle = ruleEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
reTitle:SetPoint("TOP", ruleEditor, "TOP", 0, -14)
reTitle:SetText("New Glow Rule")

-- Drag
ruleEditor:SetScript("OnMouseDown", function() ruleEditor:StartMoving() end)
ruleEditor:SetScript("OnMouseUp",   function() ruleEditor:StopMovingOrSizing() end)

-- Close button
local reClose = CreateFrame("Button", nil, ruleEditor, "UIPanelCloseButton")
reClose:SetPoint("TOPRIGHT", ruleEditor, "TOPRIGHT", -4, -4)
reClose:SetScript("OnClick", function() ruleEditor:Hide() end)

-- ---- Spell Selector ----
local reSpellLabel = ruleEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
reSpellLabel:SetPoint("TOPLEFT", ruleEditor, "TOPLEFT", 14, -40)
reSpellLabel:SetText("Spell:")

local reSpellIndex  = 1
local reSpellNames  = {}

local reSpellBtn = MakeButton(ruleEditor, 200, 22, "")
reSpellBtn:SetPoint("LEFT", reSpellLabel, "RIGHT", 8, 0)
reSpellBtn:SetScript("OnClick", function()
    if table.getn(reSpellNames) == 0 then return end
    reSpellIndex = (math.mod(reSpellIndex, table.getn(reSpellNames))) + 1
    reSpellBtn:SetText(reSpellNames[reSpellIndex] or "")
end)

-- ---- Condition Rows ----
local NUM_CONDITIONS = 3
local reCondTypes  = {}   -- current condition type index per condition row
local reCondBoxes  = {}   -- EditBox per condition row
local reCondBtns   = {}   -- type cycle button per condition row

local function GetCondLabel(typeIdx)
    local ct = CH.conditionTypes[typeIdx]
    if ct then return ct.label end
    return "None"
end

local condStartY = -72
local condRowH   = 44

for ci = 1, NUM_CONDITIONS do
    if ci > 1 then
        -- AND label
        local andLbl = ruleEditor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        andLbl:SetPoint("TOPLEFT", ruleEditor, "TOPLEFT", 14, condStartY - (ci - 1) * condRowH - 6)
        andLbl:SetText("AND")
        andLbl:SetTextColor(0.6, 0.6, 0.6, 1)
    end

    local condY = condStartY - (ci - 1) * condRowH

    -- Condition type cycle button
    reCondTypes[ci] = 1
    local typeBtnY = condY - 16
    local typeBtn  = MakeButton(ruleEditor, 190, 20, GetCondLabel(1))
    typeBtn:SetPoint("TOPLEFT", ruleEditor, "TOPLEFT", 14, typeBtnY)
    local closureCI = ci
    typeBtn:SetScript("OnClick", function()
        local numTypes = table.getn(CH.conditionTypes)
        reCondTypes[closureCI] = (math.mod(reCondTypes[closureCI], numTypes)) + 1
        typeBtn:SetText(GetCondLabel(reCondTypes[closureCI]))
        -- Show/hide param box based on hasParam
        local ct = CH.conditionTypes[reCondTypes[closureCI]]
        if ct and ct.hasParam then
            reCondBoxes[closureCI]:Show()
        else
            reCondBoxes[closureCI]:Hide()
        end
    end)
    reCondBtns[ci] = typeBtn

    -- Param EditBox
    local eb = CreateFrame("EditBox", "CooldownHUD_RECondBox" .. ci, ruleEditor, "InputBoxTemplate")
    eb:SetWidth(80)
    eb:SetHeight(18)
    eb:SetPoint("LEFT", typeBtn, "RIGHT", 8, 0)
    eb:SetAutoFocus(false)
    eb:Hide()   -- hidden until condition hasParam = true
    reCondBoxes[ci] = eb
end

-- ---- Save Button ----
local reSaveBtn = MakeButton(ruleEditor, 80, 22, "Save")
reSaveBtn:SetPoint("BOTTOMRIGHT", ruleEditor, "BOTTOMRIGHT", -14, 14)
reSaveBtn:SetScript("OnClick", function()
    if table.getn(reSpellNames) == 0 then return end
    local spellName = reSpellNames[reSpellIndex]
    if not spellName or spellName == "" then return end

    local conditions = {}
    for ci = 1, NUM_CONDITIONS do
        local ct = CH.conditionTypes[reCondTypes[ci]]
        if ct then
            local param = nil
            if ct.hasParam then
                local rawVal = reCondBoxes[ci]:GetText()
                if rawVal and rawVal ~= "" then
                    -- Try to tonumber for percent types
                    local n = tonumber(rawVal)
                    if n then
                        param = n
                    else
                        param = rawVal
                    end
                end
            end
            table.insert(conditions, { ct.id, param })
        end
    end

    local newRule = { spell = spellName, conditions = conditions }
    if not CH.db.customRules then CH.db.customRules = {} end
    table.insert(CH.db.customRules, newRule)

    ruleEditor:Hide()
    CH:RefreshRulesTab()
end)

-- ---- Cancel Button ----
local reCancelBtn = MakeButton(ruleEditor, 80, 22, "Cancel")
reCancelBtn:SetPoint("RIGHT", reSaveBtn, "LEFT", -8, 0)
reCancelBtn:SetScript("OnClick", function()
    ruleEditor:Hide()
end)

-- Event: OPEN_RULE_EDITOR
CH:RegisterEvent("OPEN_RULE_EDITOR", function()
    -- Refresh spell list
    reSpellNames = CH.activeSpells or {}
    reSpellIndex = 1
    if table.getn(reSpellNames) > 0 then
        reSpellBtn:SetText(reSpellNames[1])
    else
        reSpellBtn:SetText("(no spells)")
    end
    -- Reset conditions
    for ci = 1, NUM_CONDITIONS do
        reCondTypes[ci] = 1
        reCondBtns[ci]:SetText(GetCondLabel(1))
        reCondBoxes[ci]:SetText("")
        reCondBoxes[ci]:Hide()
    end
    ruleEditor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ruleEditor:Show()
end)

-------------------------------------------------------------------------------
-- CH:SaveRowOverrides()
-- Persist current rowData spells and scales to db.rows
-------------------------------------------------------------------------------

function CH:SaveRowOverrides()
    if not CH.db then return end
    CH.db.rows = {}
    for i, row in ipairs(CH.rowData) do
        CH.db.rows[i] = {
            scale  = row.scale,
            spells = {},
        }
        for _, sn in ipairs(row.spells) do
            table.insert(CH.db.rows[i].spells, sn)
        end
    end
end

-------------------------------------------------------------------------------
-- CH:ToggleConfig()
-------------------------------------------------------------------------------

function CH:ToggleConfig()
    if cfgFrame:IsShown() then
        cfgFrame:Hide()
    else
        -- Restore saved position
        local db = CH.db
        if db then
            if db.cfgX and db.cfgX ~= 0 then
                cfgFrame:ClearAllPoints()
                cfgFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.cfgX, db.cfgY)
            else
                cfgFrame:ClearAllPoints()
                cfgFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        end
        cfgFrame:Show()
        ShowTab(activeTab)
    end
end

-------------------------------------------------------------------------------
-- Event Registration
-------------------------------------------------------------------------------

CH:RegisterEvent("TOGGLE_CONFIG", function()
    CH:ToggleConfig()
end)

CH:RegisterEvent("SPEC_CHANGED", function()
    if cfgFrame:IsShown() then
        local activeSpec = CH:GetActiveSpec()
        if activeSpec then
            specLabel:SetText("Spec: " .. activeSpec)
        else
            specLabel:SetText("Spec: Auto-Detect")
        end
        if activeTab == 1 then
            CH:RefreshGeneralTab()
        elseif activeTab == 3 then
            CH:RefreshRulesTab()
        end
    end
end)
