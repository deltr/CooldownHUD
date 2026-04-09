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
local CONTENT_TOP  = -86   -- y-offset from panel top where tab content starts (below tabs)
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

-- Creates a reusable dropdown selector.
-- parent: parent frame
-- w, h: button dimensions
-- getOptions: function() returning { {label="X", value=Y}, ... }
-- onSelect: function(value, label) called when user picks an option
-- Returns: the trigger button (call btn:SetText() to update display)
--
-- Usage: local btn = MakeDropdown(parent, 120, 20,
--   function() return { {label="A",value=1}, {label="B",value=2} } end,
--   function(val, lbl) doStuff(val) end)
local activeDropdown = nil  -- only one dropdown open at a time

local function MakeDropdown(parent, w, h, getOptions, onSelect)
    local btn = MakeButton(parent, w, h, "")

    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    popup:SetWidth(w)
    popup:EnableMouse(true)
    popup:Hide()
    btn._dropdown = popup

    btn:SetScript("OnClick", function()
        -- Close any other open dropdown
        if activeDropdown and activeDropdown ~= popup then
            activeDropdown:Hide()
        end
        if popup:IsVisible() then
            popup:Hide()
            activeDropdown = nil
            return
        end

        -- Clear old children
        local old = { popup:GetChildren() }
        for _, c in ipairs(old) do c:Hide() end

        local opts = getOptions()
        local numOpts = table.getn(opts)
        if numOpts == 0 then return end

        local optH = 20
        local pad = 6
        popup:SetHeight(numOpts * optH + pad * 2)
        popup:SetWidth(math.max(w, 80))
        popup:ClearAllPoints()
        popup:SetPoint("TOP", btn, "BOTTOM", 0, -2)

        for i = 1, numOpts do
            local opt = opts[i]
            local optBtn = CreateFrame("Button", nil, popup)
            optBtn:SetWidth(popup:GetWidth() - pad * 2)
            optBtn:SetHeight(optH)
            optBtn:SetPoint("TOPLEFT", popup, "TOPLEFT", pad, -pad - (i - 1) * optH)

            -- Highlight on hover
            local hl = optBtn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(optBtn)
            hl:SetTexture(1, 1, 1, 0.15)

            local lbl = optBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", optBtn, "LEFT", 4, 0)
            lbl:SetText(opt.label)
            lbl:SetJustifyH("LEFT")

            local closureVal = opt.value
            local closureLbl = opt.label
            optBtn:SetScript("OnClick", function()
                btn:SetText(closureLbl)
                popup:Hide()
                activeDropdown = nil
                if onSelect then
                    onSelect(closureVal, closureLbl)
                end
            end)
        end

        popup:Show()
        activeDropdown = popup
    end)

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
    if CH.testMode then
        CH.testMode = false
        CH:FireEvent("TEST_MODE_CHANGED", false)
    end
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

    local specBtn = MakeDropdown(genPanel, 140, 22,
        function()
            local out = { { label = "Auto-Detect", value = "" } }
            local specNames = CH:GetSpecNames()
            for _, v in ipairs(specNames) do
                table.insert(out, { label = v, value = v })
            end
            return out
        end,
        function(val, lbl)
            CH:SetSpecOverride(val)
            CH:RefreshGeneralTab()
        end
    )
    specBtn:SetText("Auto-Detect")
    specBtn:SetPoint("LEFT", specOverrideLabel, "RIGHT", 10, 0)

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

        -- Separator line above row header (skip first row)
        if rowIdx > 1 then
            local sep = CreateFrame("Frame", nil, spellContent)
            sep:SetWidth(contentW - 20)
            sep:SetHeight(1)
            sep:SetPoint("TOPLEFT", spellContent, "TOPLEFT", 10, -y)
            local sepTex = sep:CreateTexture(nil, "BACKGROUND")
            sepTex:SetAllPoints(sep)
            sepTex:SetTexture(0.4, 0.4, 0.4, 0.5)
            table.insert(spellRows, sep)
            y = y + 6
        end

        -- Row header label
        local headerH  = 20
        local headerFr = CreateFrame("Frame", nil, spellContent)
        headerFr:SetWidth(contentW - 10)
        headerFr:SetHeight(headerH)
        headerFr:SetPoint("TOPLEFT", spellContent, "TOPLEFT", 0, -y)

        local hLabel = headerFr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hLabel:SetPoint("LEFT", headerFr, "LEFT", 4, 0)
        hLabel:SetText("|cffffff00Row " .. rowIdx .. "|r  |cff888888Scale: " .. (row.scale or 100) .. "%|r")

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

            -- Row assignment dropdown
            local closureSpellName = spellName
            local closureRowIdx = rowIdx
            local rowBtn = MakeDropdown(entryFr, 42, 18,
                function()
                    local out = {}
                    for ri = 1, table.getn(CH.rowData) do
                        table.insert(out, { label = "R" .. ri, value = ri })
                    end
                    return out
                end,
                function(targetRow)
                    -- Remove from current row
                    local curRow = nil
                    for ri, rd in ipairs(CH.rowData) do
                        for _, sn in ipairs(rd.spells) do
                            if sn == closureSpellName then curRow = ri; break end
                        end
                        if curRow then break end
                    end
                    if not curRow or curRow == targetRow then return end
                    local newOld = {}
                    for _, sn in ipairs(CH.rowData[curRow].spells) do
                        if sn ~= closureSpellName then table.insert(newOld, sn) end
                    end
                    CH.rowData[curRow].spells = newOld
                    table.insert(CH.rowData[targetRow].spells, closureSpellName)
                    CH:SaveRowOverrides()
                    CH:ApplyLayout()
                    CH:RefreshSpellsTab()
                end
            )
            rowBtn:SetText(GetRowLabel(rowIdx))
            rowBtn:SetPoint("LEFT", nameLabel, "RIGHT", 6, 0)

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

-- Tracks which rule is being edited (nil = new rule)
-- { source = "preset"/"custom", index = N, key = "...", rule = {...} }
local reEditingRule = nil

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

-- Get human-readable action label
local function ActionLabel(actionId)
    local id = actionId or "glow"
    for _, a in ipairs(CH.ruleActions) do
        if a.id == id then return a.label end
    end
    return id
end

-- Build label for multiple actions
local function ActionsLabel(rule)
    if rule.actions then
        local parts = {}
        for _, aid in ipairs(rule.actions) do
            table.insert(parts, ActionLabel(aid))
        end
        if table.getn(parts) == 0 then return ActionLabel("glow") end
        local s = parts[1]
        for i = 2, table.getn(parts) do
            s = s .. " + " .. parts[i]
        end
        return s
    end
    return ActionsLabel(rule)
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

    -- Explanation header
    local explainFr = CreateFrame("Frame", nil, rulesContent)
    explainFr:SetWidth(contentW - 10)
    explainFr:SetHeight(48)
    explainFr:SetPoint("TOPLEFT", rulesContent, "TOPLEFT", 0, -y)

    local explainLbl = explainFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    explainLbl:SetPoint("TOPLEFT", explainFr, "TOPLEFT", 4, 0)
    explainLbl:SetWidth(contentW - 20)
    explainLbl:SetJustifyH("LEFT")
    explainLbl:SetText(
        "Rules control how spell icons react when conditions are met. "
        .. "Actions include: gold border glow, icon opacity pulsing, showing/hiding icons conditionally. "
        .. "Create rules to highlight synergies, execute phases, or important cooldowns."
    )
    table.insert(ruleRows, explainFr)
    y = y + 52

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

        for pi, rule in ipairs(presetRules) do
            local firstCondType = ""
            if rule.conditions and rule.conditions[1] then
                firstCondType = rule.conditions[1][1] or ""
            end
            local key     = rule.spell .. ":" .. firstCondType
            local enabled = not disabled[key]

            local entryH  = 38
            local entryFr = CreateFrame("Frame", nil, rulesContent)
            entryFr:SetWidth(contentW - 10)
            entryFr:SetHeight(entryH)
            entryFr:SetPoint("TOPLEFT", rulesContent, "TOPLEFT", 0, -y)

            -- Toggle button
            local togBtn = MakeButton(entryFr, 50, 18, enabled and "ON" or "OFF")
            togBtn:SetPoint("TOPLEFT", entryFr, "TOPLEFT", 4, -2)
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
                CH:InvalidateRulesCache()
            end)

            -- Edit button (top right)
            local editBtn = MakeButton(entryFr, 36, 18, "Edit")
            editBtn:SetPoint("TOPRIGHT", entryFr, "TOPRIGHT", -4, -2)
            local closurePI  = pi
            local closureRule = rule
            local closurePresetKey = key
            editBtn:SetScript("OnClick", function()
                reEditingRule = {
                    source = "preset",
                    index  = closurePI,
                    key    = closurePresetKey,
                    rule   = closureRule,
                }
                CH:FireEvent("OPEN_RULE_EDITOR")
            end)

            -- Spell name (top line)
            local nameLbl = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameLbl:SetPoint("LEFT", togBtn, "RIGHT", 6, 0)
            nameLbl:SetText(rule.spell)
            if not enabled then
                nameLbl:SetTextColor(0.5, 0.5, 0.5, 1)
            else
                nameLbl:SetTextColor(1, 0.82, 0, 1)
            end

            -- Condition description (second line)
            local condLbl = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            condLbl:SetPoint("TOPLEFT", togBtn, "BOTTOMLEFT", 56, -2)
            condLbl:SetWidth(contentW - 110)
            condLbl:SetJustifyH("LEFT")
            condLbl:SetText("|cffffff00" .. ActionsLabel(rule) .. "|r when: " .. ConditionSummary(rule.conditions))
            condLbl:SetTextColor(0.7, 0.7, 0.7, 1)

            table.insert(ruleRows, entryFr)
            y = y + entryH + 4
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
            local entryH  = 38
            local entryFr = CreateFrame("Frame", nil, rulesContent)
            entryFr:SetWidth(contentW - 10)
            entryFr:SetHeight(entryH)
            entryFr:SetPoint("TOPLEFT", rulesContent, "TOPLEFT", 0, -y)

            -- Delete button (top right)
            local delBtn = MakeButton(entryFr, 22, 18, "X")
            delBtn:SetPoint("TOPRIGHT", entryFr, "TOPRIGHT", -4, -2)
            local closureIdx = ci
            local closureRule = rule
            delBtn:SetScript("OnClick", function()
                table.remove(CH.db.customRules, closureIdx)
                CH:InvalidateRulesCache()
                CH:RefreshRulesTab()
            end)

            -- Edit button (left of delete)
            local editBtn = MakeButton(entryFr, 36, 18, "Edit")
            editBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
            editBtn:SetScript("OnClick", function()
                reEditingRule = {
                    source = "custom",
                    index  = closureIdx,
                    rule   = closureRule,
                }
                CH:FireEvent("OPEN_RULE_EDITOR")
            end)

            -- Spell name (top line)
            local nameLbl = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameLbl:SetPoint("TOPLEFT", entryFr, "TOPLEFT", 4, -2)
            nameLbl:SetText(rule.spell or "?")
            nameLbl:SetTextColor(0.5, 0.8, 1, 1)

            -- Condition description (second line)
            local condLbl = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            condLbl:SetPoint("TOPLEFT", nameLbl, "BOTTOMLEFT", 0, -2)
            condLbl:SetWidth(contentW - 80)
            condLbl:SetJustifyH("LEFT")
            condLbl:SetText("|cffffff00" .. ActionsLabel(rule) .. "|r when: " .. ConditionSummary(rule.conditions))
            condLbl:SetTextColor(0.7, 0.7, 0.7, 1)

            table.insert(ruleRows, entryFr)
            y = y + entryH + 4
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

-- "Search:" label
local sbSearchLabel = spellBrowser:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sbSearchLabel:SetPoint("TOPLEFT", spellBrowser, "TOPLEFT", 14, -38)
sbSearchLabel:SetText("Search:")

-- Search box (OnTextChanged wired after RefreshSpellBrowser is defined below)
local sbSearchBox = CreateFrame("EditBox", "CooldownHUD_SBSearch", spellBrowser, "InputBoxTemplate")
sbSearchBox:SetWidth(190)
sbSearchBox:SetHeight(20)
sbSearchBox:SetPoint("LEFT", sbSearchLabel, "RIGHT", 6, 0)
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

local sbTargetRow = 1
local sbRowBtn = MakeButton(spellBrowser, 60, 20, "Row 1")
sbRowBtn:SetPoint("LEFT", sbRowLabel, "RIGHT", 6, 0)

-- Dropdown popup frame
local sbRowDropdown = CreateFrame("Frame", nil, spellBrowser)
sbRowDropdown:SetWidth(60)
sbRowDropdown:SetFrameStrata("TOOLTIP")
sbRowDropdown:SetBackdrop(MakeBackdrop())
sbRowDropdown:SetPoint("TOP", sbRowBtn, "BOTTOM", 0, -2)
sbRowDropdown:Hide()

sbRowBtn:SetScript("OnClick", function()
    if sbRowDropdown:IsVisible() then
        sbRowDropdown:Hide()
    else
        -- Hide any existing child buttons
        local children = { sbRowDropdown:GetChildren() }
        for _, c in ipairs(children) do c:Hide() end
        local numRows = table.getn(CH.rowData)
        if numRows < 1 then numRows = 1 end
        sbRowDropdown:SetHeight(numRows * 22 + 10)
        for ri = 1, numRows do
            local rowOpt = MakeButton(sbRowDropdown, 50, 20, "Row " .. ri)
            rowOpt:SetPoint("TOP", sbRowDropdown, "TOP", 0, -5 - (ri - 1) * 22)
            local closureRI = ri
            rowOpt:SetScript("OnClick", function()
                sbTargetRow = closureRI
                sbRowBtn:SetText("Row " .. closureRI)
                sbRowDropdown:Hide()
            end)
        end
        sbRowDropdown:Show()
    end
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

-- (reEditingRule declared earlier in file)

local ruleEditor = CreateFrame("Frame", "CooldownHUD_RuleEditor", UIParent)
ruleEditor:SetWidth(340)
ruleEditor:SetHeight(340)
ruleEditor:SetFrameStrata("FULLSCREEN")
ruleEditor:SetMovable(true)
ruleEditor:SetClampedToScreen(true)
ruleEditor:EnableMouse(true)
ruleEditor:SetBackdrop(MakeBackdrop())
ruleEditor:Hide()

-- Title
local reTitle = ruleEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
reTitle:SetPoint("TOP", ruleEditor, "TOP", 0, -14)
reTitle:SetText("New Rule")

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

local reSpellBtn = MakeDropdown(ruleEditor, 200, 22,
    function()
        local out = {}
        for i = 1, table.getn(reSpellNames) do
            local n = reSpellNames[i]
            table.insert(out, { label = n, value = i })
        end
        return out
    end,
    function(val)
        reSpellIndex = val
        reSpellBtn:SetText(reSpellNames[val] or "")
    end
)
reSpellBtn:SetPoint("LEFT", reSpellLabel, "RIGHT", 8, 0)

-- ---- Action Selector (multi-select toggle buttons) ----
local reActionLabel = ruleEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
reActionLabel:SetPoint("TOPLEFT", ruleEditor, "TOPLEFT", 14, -68)
reActionLabel:SetText("Actions:")

local reSelectedActions = {}  -- actionId -> true/false
local reActionToggles = {}    -- actionId -> button

local function UpdateActionToggleAppearance()
    for _, a in ipairs(CH.ruleActions) do
        local btn = reActionToggles[a.id]
        if btn then
            if reSelectedActions[a.id] then
                btn:SetText("|cffffff00" .. a.label .. "|r")
            else
                btn:SetText("|cff666666" .. a.label .. "|r")
            end
        end
    end
end

local actionBtnY = -68
for ai = 1, table.getn(CH.ruleActions) do
    local a = CH.ruleActions[ai]
    local togBtn = MakeButton(ruleEditor, 150, 18, a.label)
    togBtn:SetPoint("TOPLEFT", ruleEditor, "TOPLEFT", 70 + (math.mod(ai - 1, 2)) * 140, actionBtnY)
    if ai == 3 then actionBtnY = actionBtnY - 22 end

    local closureId = a.id
    togBtn:SetScript("OnClick", function()
        reSelectedActions[closureId] = not reSelectedActions[closureId]
        UpdateActionToggleAppearance()
    end)

    reActionToggles[a.id] = togBtn
    if math.mod(ai, 2) == 0 then
        actionBtnY = actionBtnY - 22
    end
end

-- ---- Condition Rows ----
local NUM_CONDITIONS = 3
local reCondTypes  = {}   -- current condition type index per condition row
local reCondBoxes  = {}   -- EditBox per condition row
local reCondBtns   = {}   -- type cycle button per condition row
local reAndLabels  = {}   -- AND labels between rows
local reVisibleConds = 1  -- how many condition rows are shown

local function GetCondLabel(typeIdx)
    local ct = CH.conditionTypes[typeIdx]
    if ct then return ct.label end
    return "(none)"
end

local condStartY = -120
local condRowH   = 44

for ci = 1, NUM_CONDITIONS do
    if ci > 1 then
        local andLbl = ruleEditor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        andLbl:SetPoint("TOPLEFT", ruleEditor, "TOPLEFT", 14, condStartY - (ci - 1) * condRowH - 6)
        andLbl:SetText("AND")
        andLbl:SetTextColor(0.6, 0.6, 0.6, 1)
        andLbl:Hide()
        reAndLabels[ci] = andLbl
    end

    local condY = condStartY - (ci - 1) * condRowH

    reCondTypes[ci] = 0
    local typeBtnY = condY - 16
    local closureCI = ci
    local typeBtn = MakeDropdown(ruleEditor, 190, 20,
        function()
            local out = { { label = "(none)", value = 0 } }
            for ti = 1, table.getn(CH.conditionTypes) do
                table.insert(out, { label = CH.conditionTypes[ti].label, value = ti })
            end
            return out
        end,
        function(val)
            reCondTypes[closureCI] = val
            if val == 0 then
                reCondBtns[closureCI]:SetText("(none)")
                reCondBoxes[closureCI]:Hide()
            else
                reCondBtns[closureCI]:SetText(GetCondLabel(val))
                local ct = CH.conditionTypes[val]
                if ct and ct.hasParam then
                    reCondBoxes[closureCI]:Show()
                else
                    reCondBoxes[closureCI]:Hide()
                end
            end
        end
    )
    typeBtn:SetText("(none)")
    typeBtn:SetPoint("TOPLEFT", ruleEditor, "TOPLEFT", 14, typeBtnY)
    reCondBtns[ci] = typeBtn

    local eb = CreateFrame("EditBox", "CooldownHUD_RECondBox" .. ci, ruleEditor, "InputBoxTemplate")
    eb:SetWidth(80)
    eb:SetHeight(18)
    eb:SetPoint("LEFT", typeBtn, "RIGHT", 8, 0)
    eb:SetAutoFocus(false)
    eb:Hide()
    reCondBoxes[ci] = eb

    -- Hide rows 2+ by default
    if ci > 1 then
        typeBtn:Hide()
        eb:Hide()
    end
end

-- Show/hide condition rows based on reVisibleConds
local function UpdateCondRowVisibility()
    for ci = 1, NUM_CONDITIONS do
        if ci <= reVisibleConds then
            reCondBtns[ci]:Show()
            -- Show param box only if condition has param
            if reCondTypes[ci] and reCondTypes[ci] > 0 then
                local ct = CH.conditionTypes[reCondTypes[ci]]
                if ct and ct.hasParam then
                    reCondBoxes[ci]:Show()
                end
            end
            if ci > 1 and reAndLabels[ci] then
                reAndLabels[ci]:Show()
            end
        else
            reCondBtns[ci]:Hide()
            reCondBoxes[ci]:Hide()
            if reAndLabels[ci] then
                reAndLabels[ci]:Hide()
            end
        end
    end
    -- Show/hide the add button
    if reVisibleConds < NUM_CONDITIONS then
        reAddCondBtn:Show()
        reAddCondBtn:ClearAllPoints()
        local btnY = condStartY - reVisibleConds * condRowH - 6
        reAddCondBtn:SetPoint("TOPLEFT", ruleEditor, "TOPLEFT", 14, btnY)
    else
        reAddCondBtn:Hide()
    end
end

-- "+ Add Condition" button
local reAddCondBtn = MakeButton(ruleEditor, 120, 20, "+ Add Condition")
reAddCondBtn:SetScript("OnClick", function()
    if reVisibleConds < NUM_CONDITIONS then
        reVisibleConds = reVisibleConds + 1
        UpdateCondRowVisibility()
    end
end)

-- ---- Save Button ----
local reSaveBtn = MakeButton(ruleEditor, 80, 22, "Save")
reSaveBtn:SetPoint("BOTTOMRIGHT", ruleEditor, "BOTTOMRIGHT", -14, 14)
reSaveBtn:SetScript("OnClick", function()
    if table.getn(reSpellNames) == 0 then return end
    local spellName = reSpellNames[reSpellIndex]
    if not spellName or spellName == "" then return end

    local conditions = {}
    for ci = 1, NUM_CONDITIONS do
        local typeIdx = reCondTypes[ci]
        -- Skip empty/none conditions (index 0 or nil)
        if typeIdx and typeIdx > 0 then
            local ct = CH.conditionTypes[typeIdx]
            if ct then
                local param = nil
                if ct.hasParam then
                    local rawVal = reCondBoxes[ci]:GetText()
                    if rawVal and rawVal ~= "" then
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
    end

    -- Collect selected actions
    local actionsList = {}
    for _, a in ipairs(CH.ruleActions) do
        if reSelectedActions[a.id] then
            table.insert(actionsList, a.id)
        end
    end
    -- Default to glow if nothing selected
    if table.getn(actionsList) == 0 then
        table.insert(actionsList, "glow")
    end
    local newRule = { spell = spellName, actions = actionsList, conditions = conditions }
    if not CH.db.customRules then CH.db.customRules = {} end

    if reEditingRule then
        if reEditingRule.source == "custom" then
            -- Edit custom rule in place
            CH.db.customRules[reEditingRule.index] = newRule
        elseif reEditingRule.source == "preset" then
            -- Create a custom override; disable the original preset
            table.insert(CH.db.customRules, newRule)
            if not CH.db.disabledPresetRules then CH.db.disabledPresetRules = {} end
            CH.db.disabledPresetRules[reEditingRule.key] = true
        end
        reEditingRule = nil
    else
        table.insert(CH.db.customRules, newRule)
    end
    CH:InvalidateRulesCache()

    ruleEditor:Hide()
    CH:RefreshRulesTab()
end)

-- ---- Cancel Button ----
local reCancelBtn = MakeButton(ruleEditor, 80, 22, "Cancel")
reCancelBtn:SetPoint("RIGHT", reSaveBtn, "LEFT", -8, 0)
reCancelBtn:SetScript("OnClick", function()
    reEditingRule = nil
    ruleEditor:Hide()
end)

-- Event: OPEN_RULE_EDITOR
CH:RegisterEvent("OPEN_RULE_EDITOR", function()
    -- Refresh spell list
    reSpellNames = CH.activeSpells or {}
    reSpellIndex = 1

    if reEditingRule then
        reTitle:SetText("Edit Rule")
        -- Pre-populate spell
        local editSpell = reEditingRule.rule.spell or ""
        local foundIdx = 1
        for i, sn in ipairs(reSpellNames) do
            if sn == editSpell then foundIdx = i; break end
        end
        reSpellIndex = foundIdx
        if table.getn(reSpellNames) > 0 then
            reSpellBtn:SetText(reSpellNames[reSpellIndex] or editSpell)
        else
            reSpellBtn:SetText(editSpell ~= "" and editSpell or "(no spells)")
        end
        -- Pre-populate actions (multi-select)
        reSelectedActions = {}
        if reEditingRule.rule.actions then
            for _, a in ipairs(reEditingRule.rule.actions) do
                reSelectedActions[a] = true
            end
        elseif reEditingRule.rule.action then
            reSelectedActions[reEditingRule.rule.action] = true
        else
            reSelectedActions["glow"] = true
        end
        UpdateActionToggleAppearance()
        -- Pre-populate conditions
        local editConds = reEditingRule.rule.conditions or {}
        local numEditConds = table.getn(editConds)
        reVisibleConds = math.max(1, numEditConds)
        for ci = 1, NUM_CONDITIONS do
            local cond = editConds[ci]
            if cond then
                local condTypeId = cond[1]
                local condParam  = cond[2]
                local typeIdx = 1
                for ti, ct in ipairs(CH.conditionTypes) do
                    if ct.id == condTypeId then typeIdx = ti; break end
                end
                reCondTypes[ci] = typeIdx
                reCondBtns[ci]:SetText(GetCondLabel(typeIdx))
                local ct = CH.conditionTypes[typeIdx]
                if ct and ct.hasParam then
                    reCondBoxes[ci]:SetText(condParam ~= nil and tostring(condParam) or "")
                else
                    reCondBoxes[ci]:SetText("")
                end
            else
                reCondTypes[ci] = 0
                reCondBtns[ci]:SetText("(none)")
                reCondBoxes[ci]:SetText("")
            end
        end
        UpdateCondRowVisibility()
    else
        reTitle:SetText("New Rule")
        if table.getn(reSpellNames) > 0 then
            reSpellBtn:SetText(reSpellNames[1])
        else
            reSpellBtn:SetText("(no spells)")
        end
        -- Reset actions — default glow selected
        reSelectedActions = { glow = true }
        UpdateActionToggleAppearance()
        -- Reset conditions — start with 1 visible row
        reVisibleConds = 1
        for ci = 1, NUM_CONDITIONS do
            reCondTypes[ci] = 0
            reCondBtns[ci]:SetText("(none)")
            reCondBoxes[ci]:SetText("")
        end
        UpdateCondRowVisibility()
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
