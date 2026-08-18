local addonName = ...
local frameName = addonName .. "Frame"
local minimapButtonName = addonName .. "MinimapButton"

local openedSpellBookByLMM = false
local editorFrameHooked = false
local minimapHooked = false
local slashWrapped = false
local spellBookHideHooked = false
local installAttempts = 0

local function ensurePlayerSpellsLoaded()
    if PlayerSpellsFrame and PlayerSpellsUtil then
        return true
    end

    if type(PlayerSpellsFrame_LoadUI) == "function" then
        pcall(PlayerSpellsFrame_LoadUI)
    end

    if (not PlayerSpellsFrame or not PlayerSpellsUtil)
        and C_AddOns
        and type(C_AddOns.LoadAddOn) == "function"
    then
        pcall(C_AddOns.LoadAddOn, "Blizzard_PlayerSpells")
    end

    return PlayerSpellsFrame ~= nil and PlayerSpellsUtil ~= nil
end

local function isSpellBookShown()
    if not PlayerSpellsFrame or not PlayerSpellsFrame:IsShown() then
        return false
    end

    if not PlayerSpellsUtil or not PlayerSpellsUtil.FrameTabs then
        return false
    end

    if type(PlayerSpellsFrame.IsFrameTabActive) ~= "function" then
        return true
    end

    return PlayerSpellsFrame:IsFrameTabActive(PlayerSpellsUtil.FrameTabs.SpellBook)
end

local function hookSpellBookHide()
    if spellBookHideHooked or not PlayerSpellsFrame then
        return
    end

    PlayerSpellsFrame:HookScript("OnHide", function()
        local editorFrame = _G[frameName]
        if editorFrame and editorFrame:IsShown() then
            -- The player closed the spellbook while LMM stayed open.
            -- Do not claim ownership if they later reopen it themselves.
            openedSpellBookByLMM = false
        end
    end)

    spellBookHideHooked = true
end

local function openSpellBook()
    local playerSpellsWasShown = PlayerSpellsFrame and PlayerSpellsFrame:IsShown() or false

    if not ensurePlayerSpellsLoaded() then
        return
    end

    local opened = false

    if PlayerSpellsUtil and type(PlayerSpellsUtil.OpenToSpellBookTab) == "function" then
        PlayerSpellsUtil.OpenToSpellBookTab()
        opened = isSpellBookShown()
    elseif type(TogglePlayerSpellsFrame) == "function"
        and PlayerSpellsUtil
        and PlayerSpellsUtil.FrameTabs
    then
        TogglePlayerSpellsFrame(PlayerSpellsUtil.FrameTabs.SpellBook)
        opened = isSpellBookShown()
    end

    hookSpellBookHide()
    openedSpellBookByLMM = (not playerSpellsWasShown) and opened
end

local function closeSpellBook()
    local shouldClose = openedSpellBookByLMM
    openedSpellBookByLMM = false

    if shouldClose and PlayerSpellsFrame and PlayerSpellsFrame:IsShown() then
        HideUIPanel(PlayerSpellsFrame)
    end
end

local function hookEditorFrame()
    local editorFrame = _G[frameName]
    if not editorFrame then
        return false
    end

    if not editorFrameHooked then
        editorFrame:HookScript("OnShow", openSpellBook)
        editorFrame:HookScript("OnHide", closeSpellBook)
        editorFrameHooked = true

        -- The first hook is installed after the first launcher click, so the
        -- frame may already be visible. Open the spellbook immediately then.
        if editorFrame:IsShown() then
            openSpellBook()
        end
    end

    return true
end

local function installLauncherHooks()
    installAttempts = installAttempts + 1

    local minimapButton = _G[minimapButtonName]
    if minimapButton and not minimapHooked then
        minimapButton:HookScript("OnClick", function(_, mouseButton)
            if mouseButton == "LeftButton" then
                hookEditorFrame()
            end
        end)
        minimapHooked = true
    end

    if not slashWrapped and SlashCmdList and type(SlashCmdList.LAFEEMACROMANAGER) == "function" then
        local originalSlashHandler = SlashCmdList.LAFEEMACROMANAGER
        SlashCmdList.LAFEEMACROMANAGER = function(message)
            originalSlashHandler(message)
            hookEditorFrame()
        end
        slashWrapped = true
    end

    if minimapHooked and slashWrapped then
        return
    end

    -- PLAYER_LOGIN ordering can vary between frames. Retry briefly instead
    -- of silently giving up when the main addon has not created its launchers yet.
    if installAttempts < 30 then
        C_Timer.After(0.1, installLauncherHooks)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    C_Timer.After(0, installLauncherHooks)
end)
