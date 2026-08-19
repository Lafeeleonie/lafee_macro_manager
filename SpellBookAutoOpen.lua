local addonName = ...
local frameName = addonName .. "Frame"
local minimapButtonName = addonName .. "MinimapButton"

local openedSpellBookByLMM = false
local editorHooked = false
local spellBookHooksInstalled = false
local launchersWrapped = false

local function trim(text)
    return (text or ""):match("^%s*(.-)%s*$") or ""
end

local function ensurePlayerSpellsLoaded()
    if PlayerSpellsFrame and PlayerSpellsUtil then
        return true
    end

    if type(PlayerSpellsFrame_LoadUI) == "function" then
        local ok, loaded = pcall(PlayerSpellsFrame_LoadUI)
        if ok and loaded ~= false and PlayerSpellsFrame and PlayerSpellsUtil then
            return true
        end
    end

    if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        pcall(C_AddOns.LoadAddOn, "Blizzard_PlayerSpells")
    end

    return PlayerSpellsFrame ~= nil and PlayerSpellsUtil ~= nil
end

local function isSpellBookActive()
    return PlayerSpellsFrame
        and PlayerSpellsFrame:IsShown()
        and PlayerSpellsUtil
        and PlayerSpellsUtil.FrameTabs
        and type(PlayerSpellsFrame.IsFrameTabActive) == "function"
        and PlayerSpellsFrame:IsFrameTabActive(PlayerSpellsUtil.FrameTabs.SpellBook)
end

local function installSpellBookHooks()
    if spellBookHooksInstalled or not PlayerSpellsFrame then
        return
    end

    PlayerSpellsFrame:HookScript("OnHide", function()
        -- A manual close means LMM must no longer claim ownership of the panel.
        openedSpellBookByLMM = false
    end)

    if type(PlayerSpellsFrame.SetTab) == "function" then
        hooksecurefunc(PlayerSpellsFrame, "SetTab", function(frame)
            -- Switching away from the spellbook transfers control back to the player.
            if openedSpellBookByLMM
                and PlayerSpellsUtil
                and PlayerSpellsUtil.FrameTabs
                and type(frame.IsFrameTabActive) == "function"
                and not frame:IsFrameTabActive(PlayerSpellsUtil.FrameTabs.SpellBook)
            then
                openedSpellBookByLMM = false
            end
        end)
    end

    spellBookHooksInstalled = true
end

local function openSpellBook()
    if not ensurePlayerSpellsLoaded() then
        return false
    end

    if not PlayerSpellsUtil or type(PlayerSpellsUtil.OpenToSpellBookTab) ~= "function" then
        return false
    end

    local panelWasShown = PlayerSpellsFrame:IsShown()

    installSpellBookHooks()
    PlayerSpellsUtil.OpenToSpellBookTab()

    openedSpellBookByLMM = (not panelWasShown) and isSpellBookActive()
    return isSpellBookActive()
end

local function closeOwnedSpellBook()
    local shouldClose = openedSpellBookByLMM and isSpellBookActive()
    openedSpellBookByLMM = false

    if shouldClose then
        HideUIPanel(PlayerSpellsFrame)
    end
end

local function configureEditorFrame()
    local frame = _G[frameName]
    if not frame then
        return nil
    end

    -- PlayerSpellsFrame uses very high internal frame levels. Keep LMM above it
    -- without entering DIALOG strata, so real Blizzard dialogs still win.
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(math.max(frame:GetFrameLevel() or 0, 6000))
    frame:SetToplevel(true)

    if type(_G.LafeeMacroManagerApplyRuntimeLocalization) == "function" then
        _G.LafeeMacroManagerApplyRuntimeLocalization(frame)
    end

    if not editorHooked then
        frame:HookScript("OnHide", closeOwnedSpellBook)
        editorHooked = true
    end

    return frame
end

local function finishOpeningEditor()
    local frame = configureEditorFrame()
    if frame and frame:IsShown() then
        frame:SetFrameStrata("HIGH")
        frame:SetFrameLevel(math.max(frame:GetFrameLevel() or 0, 6000))
        frame:Raise()
    end
end

local function installLauncherWrappers()
    if launchersWrapped then
        return
    end

    local minimapButton = _G[minimapButtonName]
    local originalSlashHandler = SlashCmdList and SlashCmdList.LAFEEMACROMANAGER
    if not minimapButton or type(originalSlashHandler) ~= "function" then
        return
    end

    local originalOnClick = minimapButton:GetScript("OnClick")
    if type(originalOnClick) ~= "function" then
        return
    end

    -- Opening PlayerSpellsFrame after LMM can hide the editor through Blizzard's
    -- panel management. Open the spellbook first, then run LMM's native toggle.
    minimapButton:SetScript("OnClick", function(button, mouseButton, ...)
        if mouseButton ~= "LeftButton" then
            return originalOnClick(button, mouseButton, ...)
        end

        local editorFrame = _G[frameName]
        if editorFrame and editorFrame:IsShown() then
            return originalOnClick(button, mouseButton, ...)
        end

        openSpellBook()
        originalOnClick(button, mouseButton, ...)
        finishOpeningEditor()
    end)

    SlashCmdList.LAFEEMACROMANAGER = function(message)
        if trim(message) ~= "" then
            return originalSlashHandler(message)
        end

        local editorFrame = _G[frameName]
        if editorFrame and editorFrame:IsShown() then
            return originalSlashHandler(message)
        end

        openSpellBook()
        originalSlashHandler(message)
        finishOpeningEditor()
    end

    launchersWrapped = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    -- The main file creates both launchers on PLAYER_LOGIN. Defer once so we can
    -- wrap the final native handlers without polling or repeated timers.
    C_Timer.After(0, installLauncherWrappers)
end)
