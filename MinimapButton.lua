-- MinimapButton.lua
-- Minimap button for CooldownHUD: drag repositioning, click handlers, tooltip

local CH = CooldownHUD
local isDragging = false

-- Forward declaration
local updatePosition

-- Create the button
local btn = CreateFrame("Button", "CooldownHUD_MinimapBtn", Minimap)
btn:SetWidth(31)
btn:SetHeight(31)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:SetMovable(true)
btn:EnableMouse(true)
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:RegisterForDrag("LeftButton")

-- Highlight texture
local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
highlight:SetAllPoints()

-- Overlay texture (border ring)
local overlay = btn:CreateTexture(nil, "OVERLAY")
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetWidth(56)
overlay:SetHeight(56)
overlay:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

-- Icon texture
local icon = btn:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\Spell_Holy_SealOfMight")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("CENTER", btn, "CENTER", 0, 1)

-- Position update function
updatePosition = function()
    local angle = (CH.db.minimapAngle or 220)
    local rad = math.rad(angle)
    local x = math.cos(rad) * 80
    local y = math.sin(rad) * 80
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Drag handlers
btn:SetScript("OnDragStart", function()
    isDragging = true
end)

btn:SetScript("OnDragStop", function()
    isDragging = false
    updatePosition()
end)

btn:SetScript("OnUpdate", function()
    if not isDragging then return end

    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx = cx / scale
    cy = cy / scale

    local mx = Minimap:GetLeft() + (Minimap:GetWidth() / 2)
    local my = Minimap:GetBottom() + (Minimap:GetHeight() / 2)

    local dx = cx - mx
    local dy = cy - my

    local angle = math.deg(math.atan2(dy, dx))
    CH.db.minimapAngle = angle
    updatePosition()
end)

-- Click handler
btn:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
        CH:FireEvent("TOGGLE_CONFIG")
    elseif arg1 == "RightButton" then
        CH.testMode = not CH.testMode
        CH:FireEvent("TEST_MODE_CHANGED", CH.testMode)
        if CH.testMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffCooldownHUD|r: Test mode |cff00ff00enabled|r.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffCooldownHUD|r: Test mode |cffff4444disabled|r.")
        end
    end
end)

-- Tooltip handlers
btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("CooldownHUD", 1, 1, 1)

    local spec = CH:GetActiveSpec()
    if spec and spec ~= "" then
        GameTooltip:AddLine("Spec: " .. spec, 0.8, 0.8, 0.8)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffeda55fLeft-click|r to open config", 0.2, 1, 0.2)
    GameTooltip:AddLine("|cffeda55fRight-click|r to toggle test mode", 0.2, 1, 0.2)
    GameTooltip:AddLine("|cffeda55fDrag|r to reposition", 0.2, 1, 0.2)
    GameTooltip:Show()
end)

btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Register for INIT event to set initial position
CH:RegisterEvent("INIT", function()
    updatePosition()
end)
