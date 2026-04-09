-------------------------------------------------------------------------------
-- CooldownHUD - ConfigPanel.lua
-- Tabbed configuration panel: General, Spells, Rules
-------------------------------------------------------------------------------

local CH = CooldownHUD

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local PANEL_W      = 420
local PANEL_H      = 600
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
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    popup:SetWidth(w)
    popup:SetBackdropColor(0.1, 0.1, 0.1, 1)
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

-- Creates a checkbox using OptionsCheckButtonTemplate.
-- Returns the CheckButton frame. Label text appears to the right.
local cbCounter = 0
local function MakeCheckbox(parent, label, tooltip)
    cbCounter = cbCounter + 1
    local name = "CooldownHUD_CB" .. cbCounter
    local cb = CreateFrame("CheckButton", name, parent, "OptionsCheckButtonTemplate")
    cb:SetWidth(25)
    cb:SetHeight(25)
    local txt = getglobal(name .. "Text")
    if txt then
        txt:SetText(label or "")
        txt:SetFontObject(GameFontNormalSmall)
    end
    if tooltip then
        cb:SetScript("OnEnter", function()
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, 1)
        end)
        cb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    return cb
end

-- Creates a section header with a horizontal rule and label.
local function MakeSectionHeader(parent, text, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(width or 380)
    f:SetHeight(20)

    local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", f, "LEFT", 0, 0)
    lbl:SetText(text)
    lbl:SetTextColor(1, 0.82, 0)

    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    line:SetTexture(1, 0.82, 0, 0.4)

    return f
end

-- Adds a tooltip to any frame on hover.
local function AddTooltip(frame, text)
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, 1)
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
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

    -- == Specialization ==
    local specHeader = MakeSectionHeader(genPanel, "Specialization", contentW - 20)
    specHeader:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx, y)
    y = y - 24

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

    y = y - 34

    -- == Layout ==
    local layoutHeader = MakeSectionHeader(genPanel, "Layout", contentW - 20)
    layoutHeader:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx, y)
    y = y - 24

    local sliderDefs = {
        { key="iconSize", label="Icon Size",  min=24, max=96,  step=1,  low="24",  high="96",  tip="Size of each cooldown icon in pixels" },
        { key="iconGap",  label="Icon Gap",   min=0,  max=20,  step=1,  low="0",   high="20",  tip="Horizontal spacing between icons" },
        { key="rowGap",   label="Row Gap",    min=0,  max=20,  step=1,  low="0",   high="20",  tip="Vertical spacing between rows" },
    }

    for si, def in ipairs(sliderDefs) do
        local sname = "CooldownHUD_GenSlider_" .. def.key
        local s = MakeSlider(genPanel, sname, 200, def.min, def.max, def.step,
                             def.label, def.low, def.high)
        s:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx + 10, y)
        if def.tip then s.tooltipText = def.tip end
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

    -- == Row Scaling ==
    local rowHeader = MakeSectionHeader(genPanel, "Row Scaling", contentW - 20)
    rowHeader:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx, y)
    y = y - 24

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

    -- == Options ==
    local optHeader = MakeSectionHeader(genPanel, "Options", contentW - 20)
    optHeader:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx, y)
    y = y - 24

    -- Lock Position checkbox
    local lockBtn = MakeCheckbox(genPanel, "Lock Position", "Prevent the HUD from being dragged")
    lockBtn:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx, y)
    lockBtn:SetScript("OnClick", function()
        CH.db.locked = (lockBtn:GetChecked() == 1)
        if CH.db.locked then
            CH:SetDragEnabled(false)
        else
            if CH.testMode then
                CH:SetDragEnabled(true)
            end
        end
    end)

    -- Test Mode checkbox
    local testBtn = MakeCheckbox(genPanel, "Test Mode", "Show all icons with dummy cooldowns for positioning")
    testBtn:SetPoint("LEFT", lockBtn, "RIGHT", 100, 0)
    testBtn:SetScript("OnClick", function()
        CH.testMode = (testBtn:GetChecked() == 1)
        CH:FireEvent("TEST_MODE_CHANGED", CH.testMode)
    end)

    y = y - 32

    -- Reset to Preset button
    local resetBtn = MakeButton(genPanel, 140, 22, "Reset to Preset")
    resetBtn:SetPoint("TOPLEFT", genPanel, "TOPLEFT", lx, y)
    AddTooltip(resetBtn, "Reset layout settings to the default preset values")
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

    -- Lock/Test checkboxes
    genPanel.lockBtn:SetChecked(db.locked)
    genPanel.testBtn:SetChecked(CH.testMode)
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

-- ---- Drag-and-Drop support ----
-- Drag state
local dragSpellName = nil      -- spell currently being dragged
local dragSrcRow    = nil      -- source row index
local dragSrcIdx    = nil      -- source spell index within row
local dragStartX, dragStartY = 0, 0
local dragActive    = false    -- true once mouse moved enough to start drag

-- Drag overlay (follows cursor, shows icon + name)
local dragOverlay = CreateFrame("Frame", nil, UIParent)
dragOverlay:SetWidth(180)
dragOverlay:SetHeight(24)
dragOverlay:SetFrameStrata("TOOLTIP")
dragOverlay:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 8,
    insets   = { left = 2, right = 2, top = 2, bottom = 2 },
})
dragOverlay:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
dragOverlay:EnableMouse(false)
dragOverlay:Hide()

local dragIcon = dragOverlay:CreateTexture(nil, "ARTWORK")
dragIcon:SetWidth(18)
dragIcon:SetHeight(18)
dragIcon:SetPoint("LEFT", dragOverlay, "LEFT", 4, 0)

local dragLabel = dragOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
dragLabel:SetPoint("LEFT", dragIcon, "RIGHT", 4, 0)
dragLabel:SetJustifyH("LEFT")

-- Drop indicator line (shows insertion point)
local dropIndicator = CreateFrame("Frame", nil, spellContent)
dropIndicator:SetWidth(contentW - 30)
dropIndicator:SetHeight(2)
dropIndicator:SetFrameStrata("FULLSCREEN")
local dropTex = dropIndicator:CreateTexture(nil, "OVERLAY")
dropTex:SetAllPoints(dropIndicator)
dropTex:SetTexture(1, 0.82, 0, 0.8)
dropIndicator:Hide()

-- Tracking: each entry stores its position info for drop targeting
local spellEntryPositions = {}  -- { {rowIdx, spellIdx, top, bottom, frame}, ... }

-- Find drop target based on cursor Y relative to spellContent
local function FindDropTarget(cursorY)
    -- Convert cursor screen Y to spellContent-relative Y
    local _, contentTop = spellContent:GetCenter()
    local contentH = spellContent:GetHeight()
    local contentTopY = contentTop + contentH / 2
    local relY = contentTopY - cursorY + spellScroll:GetVerticalScroll()

    local bestRow, bestIdx = 1, 1
    local bestDist = 99999

    for _, ep in ipairs(spellEntryPositions) do
        -- Check distance to top edge (insert before)
        local distTop = math.abs(relY - ep.top)
        if distTop < bestDist then
            bestDist = distTop
            bestRow = ep.rowIdx
            bestIdx = ep.spellIdx
        end
        -- Check distance to bottom edge (insert after)
        local distBot = math.abs(relY - ep.bottom)
        if distBot < bestDist then
            bestDist = distBot
            bestRow = ep.rowIdx
            bestIdx = ep.spellIdx + 1
        end
    end

    return bestRow, bestIdx
end

-- OnUpdate during drag
local function DragOnUpdate()
    if not dragSpellName then return end

    local curX, curY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    curX = curX / scale
    curY = curY / scale

    -- Start dragging only after moving 5px (prevents accidental drags)
    if not dragActive then
        local dx = curX - dragStartX
        local dy = curY - dragStartY
        if (dx * dx + dy * dy) < 25 then return end
        dragActive = true
        dragOverlay:Show()
    end

    -- Move overlay to cursor
    dragOverlay:ClearAllPoints()
    dragOverlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", curX + 20, curY - 10)

    -- Update drop indicator position
    local targetRow, targetIdx = FindDropTarget(curY)
    if targetRow and targetIdx then
        -- Find the Y position for the indicator
        for _, ep in ipairs(spellEntryPositions) do
            if ep.rowIdx == targetRow then
                if ep.spellIdx == targetIdx then
                    -- Insert before this entry
                    dropIndicator:ClearAllPoints()
                    dropIndicator:SetPoint("TOPLEFT", spellContent, "TOPLEFT", 10, -ep.top + 1)
                    dropIndicator:Show()
                    return
                elseif ep.spellIdx == targetIdx - 1 then
                    -- Insert after this entry
                    dropIndicator:ClearAllPoints()
                    dropIndicator:SetPoint("TOPLEFT", spellContent, "TOPLEFT", 10, -ep.bottom - 1)
                    dropIndicator:Show()
                    return
                end
            end
        end
    end
    dropIndicator:Hide()
end

local function StopDrag()
    dragOverlay:Hide()
    dropIndicator:Hide()
    spellScroll:SetScript("OnUpdate", nil)

    if dragActive and dragSpellName then
        local curX, curY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        curY = curY / scale

        local targetRow, targetIdx = FindDropTarget(curY)
        if targetRow and targetIdx and dragSrcRow then
            -- Remove from source
            local srcSpells = CH.rowData[dragSrcRow].spells
            local newSrc = {}
            for _, sn in ipairs(srcSpells) do
                if sn ~= dragSpellName then
                    table.insert(newSrc, sn)
                end
            end
            CH.rowData[dragSrcRow].spells = newSrc

            -- Adjust target index if same row and moving down
            if targetRow == dragSrcRow and targetIdx > dragSrcIdx then
                targetIdx = targetIdx - 1
            end

            -- Insert at target
            local dstSpells = CH.rowData[targetRow].spells
            if targetIdx > table.getn(dstSpells) + 1 then
                targetIdx = table.getn(dstSpells) + 1
            end
            if targetIdx < 1 then targetIdx = 1 end
            table.insert(dstSpells, targetIdx, dragSpellName)

            CH:SaveRowOverrides()
            CH:ApplyLayout()
            CH:RefreshSpellsTab()
        end
    end

    dragSpellName = nil
    dragSrcRow = nil
    dragSrcIdx = nil
    dragActive = false
end

-- Catch mouseup on the content/scroll area for drag drops on empty space
spellContent:EnableMouse(true)
spellContent:SetScript("OnMouseUp", function()
    if dragSpellName then StopDrag() end
end)

-- "+ Add Spell" button at bottom of spells panel
local addSpellBtn = MakeButton(spellsPanel, 110, 22, "+ Add Spell")
addSpellBtn:SetPoint("BOTTOMLEFT", spellsPanel, "BOTTOMLEFT", 4, 4)
AddTooltip(addSpellBtn, "Browse and add spells to track")
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

-- Rebuild the spells scroll content from CH.rowData
function CH:RefreshSpellsTab()
    ClearSpellRows()
    spellEntryPositions = {}

    local rowData = CH.rowData or {}
    local y       = 0

    -- Drag instructions
    local helpLbl = spellContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpLbl:SetPoint("TOPLEFT", spellContent, "TOPLEFT", 4, 0)
    helpLbl:SetTextColor(0.6, 0.6, 0.6)
    helpLbl:SetText("Drag spells to reorder or move between rows.")
    local helpFr = CreateFrame("Frame", nil, spellContent)
    helpFr:SetWidth(contentW)
    helpFr:SetHeight(16)
    helpFr:SetPoint("TOPLEFT", spellContent, "TOPLEFT", 0, 0)
    table.insert(spellRows, helpFr)
    y = y + 18

    for rowIdx = 1, table.getn(rowData) do
        local row    = rowData[rowIdx]
        local spells = row.spells or {}

        -- Row section header
        if rowIdx > 1 then y = y + 6 end
        local headerFr = MakeSectionHeader(spellContent,
            "Row " .. rowIdx .. "  |cff888888Scale: " .. (row.scale or 100) .. "%|r",
            contentW - 10)
        headerFr:SetPoint("TOPLEFT", spellContent, "TOPLEFT", 4, -y)
        table.insert(spellRows, headerFr)
        y = y + 22

        for spellIdx = 1, table.getn(spells) do
            local spellName = spells[spellIdx]
            local entryH    = 24
            local entryFr   = CreateFrame("Frame", nil, spellContent)
            entryFr:SetWidth(contentW - 10)
            entryFr:SetHeight(entryH)
            entryFr:SetPoint("TOPLEFT", spellContent, "TOPLEFT", 0, -y)
            entryFr:EnableMouse(true)

            -- Drag handle icon (grip dots)
            local grip = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            grip:SetPoint("LEFT", entryFr, "LEFT", 4, 0)
            grip:SetText("|cff666666:::|r")

            -- Icon thumbnail
            local iconTex = entryFr:CreateTexture(nil, "ARTWORK")
            iconTex:SetWidth(18)
            iconTex:SetHeight(18)
            iconTex:SetPoint("LEFT", grip, "RIGHT", 4, 0)
            local iconPath = CH:GetSpellIcon(spellName)
            if iconPath then
                iconTex:SetTexture(iconPath)
            else
                iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            -- Spell name label
            local nameLabel = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameLabel:SetPoint("LEFT", iconTex, "RIGHT", 4, 0)
            nameLabel:SetWidth(150)
            nameLabel:SetJustifyH("LEFT")
            nameLabel:SetText(CH:GetSpellDisplayName(spellName))

            -- Highlight on hover
            local hoverTex = entryFr:CreateTexture(nil, "HIGHLIGHT")
            hoverTex:SetAllPoints(entryFr)
            hoverTex:SetTexture(1, 1, 1, 0.08)

            -- Drag tooltip
            entryFr:SetScript("OnEnter", function()
                GameTooltip:SetOwner(entryFr, "ANCHOR_RIGHT")
                GameTooltip:SetText("Drag to reorder or move between rows", 1, 1, 1, 1, 1)
            end)
            entryFr:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            -- Drag handlers
            local closureSpellName = spellName
            local closureRowIdx = rowIdx
            local closureSpellIdx = spellIdx
            entryFr:SetScript("OnMouseDown", function()
                if arg1 == "LeftButton" then
                    dragSpellName = closureSpellName
                    dragSrcRow = closureRowIdx
                    dragSrcIdx = closureSpellIdx
                    dragActive = false
                    local cx, cy = GetCursorPosition()
                    local s = UIParent:GetEffectiveScale()
                    dragStartX = cx / s
                    dragStartY = cy / s
                    -- Set up overlay
                    local tex = CH:GetSpellIcon(closureSpellName)
                    dragIcon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
                    dragLabel:SetText(closureSpellName)
                    spellScroll:SetScript("OnUpdate", DragOnUpdate)
                end
            end)
            entryFr:SetScript("OnMouseUp", function()
                if dragSpellName then StopDrag() end
            end)

            -- Track entry positions for drop targeting
            table.insert(spellEntryPositions, {
                rowIdx = rowIdx,
                spellIdx = spellIdx,
                top = y,
                bottom = y + entryH,
            })

            -- X (remove) button
            local xBtn = MakeButton(entryFr, 22, 18, "X")
            xBtn:SetPoint("RIGHT", entryFr, "RIGHT", -4, 0)
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
AddTooltip(addRuleBtn, "Create a custom rule with conditions and actions")
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
    return ActionLabel(rule.action)
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
        local hFr = MakeSectionHeader(rulesContent, "Preset Rules", contentW - 10)
        hFr:SetPoint("TOPLEFT", rulesContent, "TOPLEFT", 4, -y)
        table.insert(ruleRows, hFr)
        y = y + 24

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

            -- Toggle checkbox
            local togBtn = MakeCheckbox(entryFr, nil, "Enable or disable this rule")
            togBtn:SetPoint("TOPLEFT", entryFr, "TOPLEFT", 4, -2)
            togBtn:SetChecked(enabled)
            local closureKey = key
            local closureNameLbl  -- forward ref for color update
            togBtn:SetScript("OnClick", function()
                if not CH.db.disabledPresetRules then
                    CH.db.disabledPresetRules = {}
                end
                if CH.db.disabledPresetRules[closureKey] then
                    CH.db.disabledPresetRules[closureKey] = nil
                    if closureNameLbl then closureNameLbl:SetTextColor(1, 0.82, 0, 1) end
                else
                    CH.db.disabledPresetRules[closureKey] = true
                    if closureNameLbl then closureNameLbl:SetTextColor(0.5, 0.5, 0.5, 1) end
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
            nameLbl:SetText(CH:GetSpellDisplayName(rule.spell))
            closureNameLbl = nameLbl
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

            -- Resize entry to fit wrapped text
            local textH = condLbl:GetHeight() or 12
            local totalH = 22 + textH + 6  -- name line + desc + padding
            if totalH < entryH then totalH = entryH end
            entryFr:SetHeight(totalH)

            table.insert(ruleRows, entryFr)
            y = y + totalH + 4
        end
    end

    -- ---- Custom rules section ----
    local customRules = CH.db.customRules or {}

    if table.getn(customRules) > 0 then
        y = y + 6
        local hFr = MakeSectionHeader(rulesContent, "Custom Rules", contentW - 10)
        hFr:SetPoint("TOPLEFT", rulesContent, "TOPLEFT", 4, -y)
        table.insert(ruleRows, hFr)
        y = y + 24

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
            nameLbl:SetText(CH:GetSpellDisplayName(rule.spell or "?"))
            nameLbl:SetTextColor(0.5, 0.8, 1, 1)

            -- Condition description (second line)
            local condLbl = entryFr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            condLbl:SetPoint("TOPLEFT", nameLbl, "BOTTOMLEFT", 0, -2)
            condLbl:SetWidth(contentW - 80)
            condLbl:SetJustifyH("LEFT")
            condLbl:SetText("|cffffff00" .. ActionsLabel(rule) .. "|r when: " .. ConditionSummary(rule.conditions))
            condLbl:SetTextColor(0.7, 0.7, 0.7, 1)

            -- Resize entry to fit wrapped text
            local textH = condLbl:GetHeight() or 12
            local totalH = 22 + textH + 6
            if totalH < entryH then totalH = entryH end
            entryFr:SetHeight(totalH)

            table.insert(ruleRows, entryFr)
            y = y + totalH + 4
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
        local displayName = CH:GetSpellDisplayName(spellName)
        if searchText ~= "" and not string.find(string.lower(displayName), searchText, 1, true) then
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
            nameLbl:SetText(displayName)

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
ruleEditor:SetHeight(400)
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

-- Spell icon preview
local reSpellIcon = ruleEditor:CreateTexture(nil, "ARTWORK")
reSpellIcon:SetWidth(22)
reSpellIcon:SetHeight(22)
reSpellIcon:SetPoint("LEFT", reSpellLabel, "RIGHT", 8, 0)
reSpellIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

local function UpdateReSpellIcon()
    local name = reSpellNames[reSpellIndex]
    if name then
        local tex = CH:GetSpellIcon(name)
        if tex then
            reSpellIcon:SetTexture(tex)
            return
        end
    end
    reSpellIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
end

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
        UpdateReSpellIcon()
    end
)
reSpellBtn:SetPoint("LEFT", reSpellIcon, "RIGHT", 6, 0)

-- ---- Action Selector (checkboxes) ----
local reActionLabel = ruleEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
reActionLabel:SetPoint("TOPLEFT", ruleEditor, "TOPLEFT", 14, -68)
reActionLabel:SetText("Actions:")

local reSelectedActions = {}  -- actionId -> true/false
local reActionChecks = {}     -- actionId -> CheckButton

local numActions = table.getn(CH.ruleActions)
for ai = 1, numActions do
    local a = CH.ruleActions[ai]
    local cb = MakeCheckbox(ruleEditor, a.label, a.desc)
    -- Layout: 2 columns, rows stacked
    local col = math.mod(ai - 1, 2)
    local row = math.floor((ai - 1) / 2)
    cb:SetPoint("TOPLEFT", ruleEditor, "TOPLEFT", 14 + col * 160, -88 - row * 24)

    local closureId = a.id
    cb:SetScript("OnClick", function()
        reSelectedActions[closureId] = (cb:GetChecked() == 1)
    end)
    reActionChecks[a.id] = cb
end

local function UpdateActionCheckboxes()
    for ai = 1, numActions do
        local a = CH.ruleActions[ai]
        reActionChecks[a.id]:SetChecked(reSelectedActions[a.id])
    end
end

-- ---- Condition Rows ----
local reCondHeader = MakeSectionHeader(ruleEditor, "Conditions", 310)
reCondHeader:SetPoint("TOPLEFT", ruleEditor, "TOPLEFT", 14, -136)

local NUM_CONDITIONS = 3
local reCondTypes  = {}   -- current condition type index per condition row
local reCondBoxes  = {}   -- EditBox per condition row
local reCondBtns   = {}   -- type cycle button per condition row
local reAndLabels  = {}   -- AND labels between rows
local reVisibleConds = 1  -- how many condition rows are shown
local reAddCondBtn           -- forward declaration (created after UpdateCondRowVisibility)
local reRemoveBtns = {}      -- "X" remove buttons per condition row

local function GetCondLabel(typeIdx)
    local ct = CH.conditionTypes[typeIdx]
    if ct then return ct.label end
    return "(none)"
end

local condStartY = -154
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

    -- "X" remove button (only for rows 2+)
    if ci > 1 then
        local removeBtn = MakeButton(ruleEditor, 20, 20, "X")
        removeBtn:SetPoint("LEFT", eb, "RIGHT", 6, 0)
        removeBtn:Hide()
        local closureRemoveCI = ci
        removeBtn:SetScript("OnClick", function()
            -- Shift conditions from closureRemoveCI+1..reVisibleConds down by one
            for si = closureRemoveCI, reVisibleConds - 1 do
                reCondTypes[si] = reCondTypes[si + 1]
                reCondBtns[si]:SetText(reCondBtns[si + 1]:GetText())
                reCondBoxes[si]:SetText(reCondBoxes[si + 1]:GetText())
            end
            -- Clear the last visible row
            reCondTypes[reVisibleConds] = 0
            reCondBtns[reVisibleConds]:SetText("(none)")
            reCondBoxes[reVisibleConds]:SetText("")
            reVisibleConds = reVisibleConds - 1
            if reVisibleConds < 1 then reVisibleConds = 1 end
            UpdateCondRowVisibility()
        end)
        reRemoveBtns[ci] = removeBtn
    end

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
            if ci > 1 and reRemoveBtns[ci] then
                reRemoveBtns[ci]:Show()
            end
        else
            reCondBtns[ci]:Hide()
            reCondBoxes[ci]:Hide()
            if reAndLabels[ci] then
                reAndLabels[ci]:Hide()
            end
            if reRemoveBtns[ci] then
                reRemoveBtns[ci]:Hide()
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
reAddCondBtn = MakeButton(ruleEditor, 120, 20, "+ Add Condition")
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
    if activeDropdown then activeDropdown:Hide(); activeDropdown = nil end
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
    if activeDropdown then activeDropdown:Hide(); activeDropdown = nil end
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
        UpdateReSpellIcon()
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
        UpdateActionCheckboxes()
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
        UpdateReSpellIcon()
        -- Reset actions — default glow selected
        reSelectedActions = { glow = true }
        UpdateActionCheckboxes()
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
