local addonName = ...
local frameName = addonName .. "Frame"
local minimapButtonName = addonName .. "MinimapButton"
local globalTabName = addonName .. "GlobalTab"
local characterTabName = addonName .. "CharacterTab"

local openedSpellBookByLMM = false
local editorHooked = false
local spellBookHooksInstalled = false
local launchHooksInstalled = false

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
        -- If the player closes Blizzard's panel manually, LMM no longer owns it.
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

    -- The main addon still contains a couple of old FR/EN-only tab labels.
    -- Correct the visible labels from the standalone localization table here.
    local text = _G.LafeeMacroManagerText
    local globalTab = _G[globalTabName]
    local characterTab = _G[characterTabName]
    if text and globalTab and text.globalTab then
        globalTab:SetText(text.globalTab)
    end
    if text and characterTab and text.characterTab then
        characterTab:SetText(text.characterTab)
    end

    if not editorHooked then
        frame:HookScript("OnHide", closeOwnedSpellBook)
        editorHooked = true
    end

    return frame
end

local function syncAfterLauncher()
    local frame = configureEditorFrame()
    if frame and frame:IsShown() then
        openSpellBook()
        -- Reassert the editor level after Blizzard finishes showing its panel.
        frame:SetFrameStrata("HIGH")
        frame:SetFrameLevel(math.max(frame:GetFrameLevel() or 0, 6000))
        frame:Raise()
    end
end

local function installLauncherHooks()
    if launchHooksInstalled then
        return
    end

    local minimapButton = _G[minimapButtonName]
    local slashReady = SlashCmdList and type(SlashCmdList.LAFEEMACROMANAGER) == "function"
    if not minimapButton or not slashReady then
        return
    end

    minimapButton:HookScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            syncAfterLauncher()
        end
    end)

    hooksecurefunc(SlashCmdList, "LAFEEMACROMANAGER", function(message)
        if trim(message) == "" then
            syncAfterLauncher()
        end
    end)

    launchHooksInstalled = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    -- The main file creates the minimap button and slash handler on PLAYER_LOGIN.
    -- Install after that event dispatch completes; no polling/retry loop is needed.
    C_Timer.After(0, installLauncherHooks)
end)
