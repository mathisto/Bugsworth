-----------------------------------------------------------------------
-- BUGSWORTH · viewer.lua
-- GUI error viewer (modernized from BugSack)
-----------------------------------------------------------------------

local BC = _G.Bugsworth
if not BC then return end

-- State
local viewerFrame = nil
local sackCurrent = nil
local currentContents = nil
local currentSession = nil

-- UI element references
local countLabel, sessionLabel, textArea
local nextButton, prevButton
local tabs

-----------------------------------------------------------------------
-- Error formatting + syntax highlighting (from BugSack)
-----------------------------------------------------------------------
function BC:FormatError(err)
    local m = err.message
    if type(m) == "table" then m = table.concat(m, "") end
    return string.format("|cff999999%dx|r %s", err.counter or 1, BC:ColorError(m or ""))
end

function BC:ColorError(err)
    local ret = err
    ret = ret:gsub("|([^chHr])", "||%1")
    ret = ret:gsub("|$", "||")
    ret = ret:gsub("\nLocals:\n", "\n|cFFFFFFFFLocals:|r\n")
    ret = ret:gsub("[Ii][Nn][Tt][Ee][Rr][Ff][Aa][Cc][Ee]\\[Aa][Dd][Dd][Oo][Nn][Ss]\\", "")
    ret = ret:gsub("{%\n +%}", "{}")
    ret = ret:gsub("([ ]-)([%a_][%a_%d]+) = ", "%1|cffffff80%2|r = ")
    ret = ret:gsub("= (%d+)\n", "= |cffff7fff%1|r\n")
    ret = ret:gsub("<function>", "|cffffea00<function>|r")
    ret = ret:gsub("<table>", "|cffffea00<table>|r")
    ret = ret:gsub("= nil\n", "= |cffff7f7fnil|r\n")
    ret = ret:gsub("= true\n", "= |cffff9100true|r\n")
    ret = ret:gsub("= false\n", "= |cffff9100false|r\n")
    ret = ret:gsub("= \"([^\n]+)\"\n", "= |cff8888ff\"%1\"|r\n")
    ret = ret:gsub("defined %@(.-):(%d+)", "@ |cffeda55f%1|r:|cff00ff00%2|r:")
    ret = ret:gsub("\n(.-):(%d+):", "\n|cffeda55f%1|r:|cff00ff00%2|r:")
    ret = ret:gsub("%-%d+%p+.-%\\", "|cffffff00%1|cffeda55f")
    ret = ret:gsub("%(.-%)", "|cff999999%1|r")
    ret = ret:gsub("([`'])(.-)([`'])", "|cff8888ff%1%2%3|r")
    return ret
end

-----------------------------------------------------------------------
-- Get errors for a specific session or all
-----------------------------------------------------------------------
function BC:GetErrors(sessionId)
    local db = BC:GetDB()
    if not sessionId then return db end
    local result = {}
    for _, err in ipairs(db) do
        if err.session == sessionId then
            result[#result + 1] = err
        end
    end
    return result
end

-----------------------------------------------------------------------
-- Session navigation
-----------------------------------------------------------------------
local function findPreviousSessionWithBugs(current)
    for i = (current - 1), 0, -1 do
        local bugs = BC:GetErrors(i)
        if #bugs > 0 then return i, bugs end
    end
end

local sessionFormat = "%s - |cffff4411%s|r - Session |cff44ff44%d|r"
local countFormat = "%d/%d"

local function updateSack()
    if not currentContents or #currentContents == 0 then return end
    if sackCurrent < 1 then sackCurrent = 1 end
    if sackCurrent > #currentContents then sackCurrent = #currentContents end

    local eo = currentContents[sackCurrent]
    local size = #currentContents

    local source = eo.source and ("Sent by " .. eo.source) or "Local"
    local timeStr = (eo.session == BC:GetSessionId()) and "Today" or (eo.time or "unknown")
    sessionLabel:SetText(sessionFormat:format(timeStr, source, eo.session))
    countLabel:SetText(countFormat:format(sackCurrent, size))
    textArea:SetText(BC:FormatError(eo))

    nextButton[sackCurrent >= size and "Disable" or "Enable"](nextButton)
    prevButton[sackCurrent <= 1 and "Disable" or "Enable"](prevButton)
end

-----------------------------------------------------------------------
-- Tab click handler
-----------------------------------------------------------------------
local function setActiveTab(tab)
    if not tab.bugs then
        -- All bugs
        currentContents = BC:GetErrors()
        currentSession = nil
    elseif tab.bugs == 0 then
        -- Current session
        local session = BC:GetSessionId()
        currentContents = BC:GetErrors(session)
        currentSession = session
    else
        -- Previous session
        local session = tab.bugs == -1 and BC:GetSessionId() or tab.bugs
        local s, b = findPreviousSessionWithBugs(session)
        if not s or not b or #b == 0 then
            tab.bugs = -1
            return
        end
        tab.bugs, currentContents = s, b
        currentSession = s
    end

    for _, t in ipairs(tabs) do
        if t == tab then
            t:SetNormalFontObject(GameFontHighlight)
        else
            t:SetNormalFontObject(GameFontNormal)
        end
    end

    sackCurrent = nil
    BC:OpenViewer()
end

-----------------------------------------------------------------------
-- Create the viewer frame (lazy init)
-----------------------------------------------------------------------
local function createViewer()
    local window = CreateFrame("Frame", "BugsworthFrame", UIParent)
    UIPanelWindows["BugsworthFrame"] = { area = "center", pushable = 0, whileDead = 1 }
    HideUIPanel(window)

    window:SetFrameStrata("FULLSCREEN_DIALOG")
    window:SetWidth(520)
    window:SetHeight(380)
    window:SetPoint("CENTER")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetScript("OnShow", function() PlaySound("igQuestLogOpen") end)
    window:SetScript("OnHide", function() PlaySound("igQuestLogClose") end)

    -- Dark backdrop
    window:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    window:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
    window:SetBackdropBorderColor(0.6, 0.2, 0.2, 0.9)

    -- Title bar
    local titleBg = window:CreateTexture(nil, "BORDER")
    titleBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    titleBg:SetPoint("TOPLEFT", 6, -6)
    titleBg:SetPoint("TOPRIGHT", -6, -6)
    titleBg:SetHeight(22)
    titleBg:SetVertexColor(0.4, 0.1, 0.1, 0.8)

    local titleText = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", titleBg, 8, -3)
    titleText:SetText("|cFFEDA55fBugs|rworth")
    titleText:SetTextColor(1, 1, 1, 1)

    -- Close button
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 1)
    close:SetScript("OnClick", function() BC:CloseViewer() end)

    -- Session label
    sessionLabel = window:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    sessionLabel:SetJustifyH("LEFT")
    sessionLabel:SetPoint("TOPLEFT", titleBg, "BOTTOMLEFT", 4, -4)
    sessionLabel:SetTextColor(0.8, 0.8, 0.8, 1)

    -- Count label
    countLabel = window:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    countLabel:SetPoint("TOPRIGHT", titleBg, "BOTTOMRIGHT", -4, -4)
    countLabel:SetJustifyH("RIGHT")
    countLabel:SetTextColor(1, 0.8, 0.2, 1)

    -- Bottom buttons
    nextButton = CreateFrame("Button", "BugsworthNextButton", window, "UIPanelButtonTemplate")
    nextButton:SetPoint("BOTTOMRIGHT", window, -12, 12)
    nextButton:SetWidth(100)
    nextButton:SetHeight(22)
    nextButton:SetText("Next >")
    nextButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            sackCurrent = #currentContents
        else
            sackCurrent = sackCurrent + 1
        end
        updateSack()
    end)

    prevButton = CreateFrame("Button", "BugsworthPrevButton", window, "UIPanelButtonTemplate")
    prevButton:SetPoint("BOTTOMLEFT", window, 12, 12)
    prevButton:SetWidth(100)
    prevButton:SetHeight(22)
    prevButton:SetText("< Previous")
    prevButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            sackCurrent = 1
        else
            sackCurrent = sackCurrent - 1
        end
        updateSack()
    end)

    -- Scroll frame
    local scroll = CreateFrame("ScrollFrame", "BugsworthScroll", window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", window, 12, -52)
    scroll:SetPoint("BOTTOMRIGHT", nextButton, "TOPRIGHT", -24, 6)

    -- Text area (editable for copy-paste)
    textArea = CreateFrame("EditBox", "BugsworthScrollText", scroll)
    textArea:SetAutoFocus(false)
    textArea:SetMultiLine(true)
    textArea:SetFontObject(GameFontHighlightSmall)
    textArea:SetMaxLetters(99999)
    textArea:EnableMouse(true)
    textArea:SetScript("OnEscapePressed", textArea.ClearFocus)
    textArea:SetWidth(460)
    scroll:SetScrollChild(textArea)

    -- Tabs
    local allTab = CreateFrame("Button", "BugsworthTabAll", window, "CharacterFrameTabButtonTemplate")
    allTab:SetFrameStrata("FULLSCREEN")
    allTab:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 0, 8)
    allTab:SetText("All Bugs")
    allTab:SetScript("OnLoad", nil)
    allTab:SetScript("OnShow", nil)
    allTab:SetScript("OnClick", setActiveTab)
    allTab:SetNormalFontObject(GameFontNormal)
    allTab.bugs = nil

    local sessionTab = CreateFrame("Button", "BugsworthTabSession", window, "CharacterFrameTabButtonTemplate")
    sessionTab:SetFrameStrata("FULLSCREEN")
    sessionTab:SetPoint("LEFT", allTab, "RIGHT")
    sessionTab:SetText("This Session")
    sessionTab:SetScript("OnLoad", nil)
    sessionTab:SetScript("OnShow", nil)
    sessionTab:SetScript("OnClick", setActiveTab)
    sessionTab:SetNormalFontObject(GameFontHighlight)
    sessionTab.bugs = 0

    local prevTab = CreateFrame("Button", "BugsworthTabPrev", window, "CharacterFrameTabButtonTemplate")
    prevTab:SetFrameStrata("FULLSCREEN")
    prevTab:SetPoint("LEFT", sessionTab, "RIGHT")
    prevTab:SetText("Previous")
    prevTab:SetScript("OnLoad", nil)
    prevTab:SetScript("OnShow", nil)
    prevTab:SetScript("OnClick", setActiveTab)
    prevTab:SetNormalFontObject(GameFontNormal)
    prevTab.bugs = -1

    tabs = { allTab, sessionTab, prevTab }
    local tabWidth = 520 / 3
    for _, t in ipairs(tabs) do
        PanelTemplates_TabResize(t, nil, tabWidth, tabWidth)
        PanelTemplates_DeselectTab(t)
    end

    viewerFrame = window
    return window
end

-----------------------------------------------------------------------
-- Public API
-----------------------------------------------------------------------
function BC:OpenViewer()
    if not viewerFrame then createViewer() end

    if not currentContents then
        currentContents = BC:GetErrors(BC:GetSessionId())
    end

    local size = #currentContents
    if size == 0 then
        if countLabel then countLabel:SetText("") end
        if sessionLabel then sessionLabel:SetText("Session " .. BC:GetSessionId()) end
        if textArea then textArea:SetText("|cff44ff44No bugs captured. Nice work!|r") end
        if nextButton then nextButton:Disable() end
        if prevButton then prevButton:Disable() end
    else
        sackCurrent = sackCurrent or size
        if sackCurrent > size then sackCurrent = size end
        if sackCurrent < 1 then sackCurrent = 1 end
        updateSack()
    end

    ShowUIPanel(BugsworthFrame)
end

function BC:CloseViewer()
    if viewerFrame then HideUIPanel(BugsworthFrame) end
end

-----------------------------------------------------------------------
-- Error notification (sound + chat + auto-open)
-----------------------------------------------------------------------
local lastErrorTime = nil
function BC:OnError()
    if not lastErrorTime or GetTime() > (lastErrorTime + 2) then
        -- Sound
        if not BugsworthDB.mute then
            PlaySoundFile("Interface\\AddOns\\BUGSWORTH\\Media\\error.wav")
        end
        -- Auto-open
        if BugsworthDB.auto then
            self:OpenViewer()
        end
        -- Chat notification
        if BugsworthDB.chatframe then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFEDA55fBugs|rworth: There's a bug in your soup!")
        end
        lastErrorTime = GetTime()
    end
    -- Update minimap icon
    if BC.OnErrorCountChanged then
        BC:OnErrorCountChanged()
    end
end

-----------------------------------------------------------------------
-- Register for error callbacks
-----------------------------------------------------------------------
local function initViewerCallbacks()
    if not LibStub then return end
    local CBH = LibStub("CallbackHandler-1.0", true)
    if not CBH then return end

    -- Wait for core to set up callbacks, then register
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")

        -- Register for error events
        if BC.RegisterCallback then
            BC:RegisterCallback("Bugsworth_BugGrabbed", function() BC:OnError() end)
            BC:RegisterCallback("Bugsworth_EventGrabbed", function() BC:OnError() end)
        end

        -- Show any startup errors
        local session = BC:GetErrors(BC:GetSessionId())
        if #session > 0 then
            BC:OnError()
        end
    end)
end
initViewerCallbacks()
