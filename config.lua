-----------------------------------------------------------------------
-- BUGSWORTH · config.lua
-- Interface options panel
-----------------------------------------------------------------------

local BC = _G.Bugsworth
if not BC then return end

local frame = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
frame.name = "Bugsworth"
frame:Hide()

local function newCheckbox(label, description, onClick)
    local check = CreateFrame("CheckButton", "BugsworthCheck" .. label:gsub("%s", ""), frame, "InterfaceOptionsCheckButtonTemplate")
    check:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        onClick(self, self:GetChecked() and true or false)
    end)
    check.label = _G[check:GetName() .. "Text"]
    check.label:SetText(label)
    check.tooltipText = label
    check.tooltipRequirement = description
    return check
end

-- Widget references for refresh
local autoPopup, chatNotif, muteCheck, filterCheck, throttleCheck, slider
local initialized = false

local function refresh()
    if not initialized then return end
    autoPopup:SetChecked(BugsworthDB.auto)
    chatNotif:SetChecked(BugsworthDB.chatframe)
    muteCheck:SetChecked(BugsworthDB.mute)
    filterCheck:SetChecked(BugsworthDB.filterAddonMistakes)
    throttleCheck:SetChecked(BC:IsThrottling())
    slider:SetValue(BC:GetLimit())
end

frame:SetScript("OnShow", function(self)
    if initialized then
        refresh()
        return
    end

    local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFEDA55fBugs|rworth")

    local subtitle = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", -32, 0)
    subtitle:SetHeight(24)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetJustifyV("TOP")
    subtitle:SetText("Unified error capture, display, and persistence.")

    -- Auto popup
    autoPopup = newCheckbox(
        "Auto-open on error",
        "Automatically open the error viewer when a new bug is captured.",
        function(_, value) BugsworthDB.auto = value end
    )
    autoPopup:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -8)

    -- Chat notification
    chatNotif = newCheckbox(
        "Chat notification",
        "Print a message to chat when a new error is captured.",
        function(_, value) BugsworthDB.chatframe = value end
    )
    chatNotif:SetPoint("TOPLEFT", autoPopup, "BOTTOMLEFT", 0, -4)

    -- Mute sound
    muteCheck = newCheckbox(
        "Mute error sound",
        "Disable the error notification sound.",
        function(_, value) BugsworthDB.mute = value end
    )
    muteCheck:SetPoint("TOPLEFT", chatNotif, "BOTTOMLEFT", 0, -4)

    -- Filter addon mistakes
    filterCheck = newCheckbox(
        "Filter addon action errors",
        "Ignore ADDON_ACTION_BLOCKED/FORBIDDEN events (taint errors).",
        function(_, value)
            BugsworthDB.filterAddonMistakes = value
            if value then
                BC:UnregisterAddonActionEvents()
            else
                BC:RegisterAddonActionEvents()
            end
        end
    )
    filterCheck:SetPoint("TOPLEFT", muteCheck, "BOTTOMLEFT", 0, -4)

    -- Throttle
    throttleCheck = newCheckbox(
        "Throttle excessive errors",
        "Pause error capture if more than 20 errors/sec are detected.",
        function(_, value) BC:UseThrottling(value) end
    )
    throttleCheck:SetPoint("TOPLEFT", filterCheck, "BOTTOMLEFT", 0, -4)

    -- Error limit slider
    local sliderLabel = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sliderLabel:SetJustifyH("LEFT")
    sliderLabel:SetText("Error limit:")
    sliderLabel:SetPoint("TOPLEFT", throttleCheck, "BOTTOMLEFT", 8, -16)

    local sliderValue = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sliderValue:SetJustifyH("LEFT")
    sliderValue:SetText(BC:GetLimit())

    slider = CreateFrame("Slider", nil, self)
    slider:SetHeight(17)
    slider:SetWidth(120)
    slider:SetOrientation("HORIZONTAL")
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        edgeSize = 8, tile = true, tileSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 }
    })
    slider:SetMinMaxValues(10, 1000)
    slider:SetValue(BC:GetLimit())
    slider:SetValueStep(10)
    slider:SetScript("OnValueChanged", function(_, value)
        local v = math.floor(math.abs(value))
        BC:SetLimit(v)
        sliderValue:SetText(v)
    end)
    slider:SetPoint("LEFT", sliderLabel, "RIGHT", 16, 0)
    sliderValue:SetPoint("LEFT", slider, "RIGHT", 8, 0)

    -- Wipe button
    local wipeBtn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    wipeBtn:SetText("Wipe All Errors")
    wipeBtn:SetWidth(140)
    wipeBtn:SetHeight(24)
    wipeBtn:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", -4, -16)
    wipeBtn:SetScript("OnClick", function()
        BC:Reset()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFEDA55fBugs|rworth: All errors cleared.")
        if BC.OnErrorCountChanged then BC:OnErrorCountChanged() end
    end)

    initialized = true
    refresh()
end)

InterfaceOptions_AddCategory(frame)

