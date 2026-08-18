local addonName = ...
local frameName = addonName .. "Frame"
local minimapButtonName = addonName .. "MinimapButton"

local openedSpellBookByLMM = false
local editorFrameHooked = false
local minimapWrapped = false
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
            -- The player closed the spellbook manually while LMM stayed open.
            openedSpellBookByLMM = false
        end
    end)

    spellBookHideHooked = true
end

local function openSpellBook()
    local playerSpellsWasShown = PlayerSpellsFrame and PlayerSpellsFrame:IsShown() or false

    if not ensurePlayerSpellsLoaded() then
        return false
    end

    if not PlayerSpellsUtil or type(PlayerSpellsUtil.OpenToSpellBookTab) ~= "function" then
        return false
    end

    PlayerSpellsUtil.OpenToSpellBookTab()
    hookSpellBookHide()

    local opened = isSpellBookShown()
    openedSpellBookByLMM = (not playerSpellsWasShown) and opened
    return opened
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
        editorFrame:HookScript("OnHide", closeSpellBook)
        editorFrameHooked = true
    end

    return true
end

local function openEditorAfterSpellBook(openEditor)
    -- ShowUIPanel(PlayerSpellsFrame) can alter Blizzard panel state. Let it
    -- finish first, then show LMM on the next UI tick so both remain visible.
    openSpellBook()

    C_Timer.After(0, function()
        openEditor()
        hookEditorFrame()
    end)
end

local function installLauncherWrappers()
    installAttempts = installAttempts + 1

    local minimapButton = _G[minimapButtonName]
    if minimapButton and not minimapWrapped then
        local originalOnClick = minimapButton:GetScript("OnClick")
        if type(originalOnClick) == "function" then
            minimapButton:SetScript("OnClick", function(button, mouseButton, ...)
                if mouseButton ~= "LeftButton" then
                    return originalOnClick(button, mouseButton, ...)
                end

                local editorFrame = _G[frameName]
                if editorFrame and editorFrame:IsShown() then
                    return originalOnClick(button, mouseButton, ...)
                end

                local args = { ... }
                openEditorAfterSpellBook(function()
                    originalOnClick(button, mouseButton, unpack(args))
                end)
            end)
            minimapWrapped = true
        end
    end

    if not slashWrapped and SlashCmdList and type(SlashCmdList.LAFEEMACROMANAGER) == "function" then
        local originalSlashHandler = SlashCmdList.LAFEEMACROMANAGER
        SlashCmdList.LAFEEMACROMANAGER = function(message)
            local command = (message or ""):match("^%s*(.-)%s*$")
            if command ~= "" then
                return originalSlashHandler(message)
            end

            local editorFrame = _G[frameName]
            if editorFrame and editorFrame:IsShown() then
                return originalSlashHandler(message)
            end

            openEditorAfterSpellBook(function()
                originalSlashHandler(message)
            end)
        end
        slashWrapped = true
    end

    if minimapWrapped and slashWrapped then
        return
    end

    -- PLAYER_LOGIN ordering can vary between frames. Retry briefly instead
    -- of silently giving up when the main addon has not created its launchers yet.
    if installAttempts < 30 then
        C_Timer.After(0.1, installLauncherWrappers)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    C_Timer.After(0, installLauncherWrappers)
end)
