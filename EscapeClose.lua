local addonName = ...
local frameName = addonName .. "Frame"
local minimapButtonName = addonName .. "MinimapButton"
local openedSpellBookByLMM = false
local spellBookHideHooked = false
local frameVisibilityHooked = false
local slashWrapped = false

-- Let Escape close the standalone macro editor like a native Blizzard panel.
if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, frameName)
end

local function isSpellBookOpen()
    return PlayerSpellsFrame
        and PlayerSpellsFrame:IsShown()
        and PlayerSpellsUtil
        and PlayerSpellsUtil.FrameTabs
        and PlayerSpellsFrame.IsFrameTabActive
        and PlayerSpellsFrame:IsFrameTabActive(PlayerSpellsUtil.FrameTabs.SpellBook)
end

local function hookSpellBookHide()
    if spellBookHideHooked or not PlayerSpellsFrame then
        return
    end

    PlayerSpellsFrame:HookScript("OnHide", function()
        local editorFrame = _G[frameName]
        if editorFrame and editorFrame:IsShown() then
            -- The player closed the spellbook manually while LMM stayed open.
            -- Do not later close a spellbook they may reopen themselves.
            openedSpellBookByLMM = false
        end
    end)
    spellBookHideHooked = true
end

local function openSpellBookForEditor()
    if not PlayerSpellsUtil or type(PlayerSpellsUtil.OpenToSpellBookTab) ~= "function" then
        return
    end

    local playerSpellsWasShown = PlayerSpellsFrame and PlayerSpellsFrame:IsShown() or false
    local spellBookWasOpen = isSpellBookOpen()

    PlayerSpellsUtil.OpenToSpellBookTab()
    hookSpellBookHide()

    -- Only claim ownership when LMM actually opened the Blizzard panel.
    -- If talents/specs (or the spellbook itself) were already open, leave
    -- that panel under the player's control when LMM closes.
    openedSpellBookByLMM = not playerSpellsWasShown and not spellBookWasOpen and isSpellBookOpen()
end

local function closeSpellBookForEditor()
    local shouldClose = openedSpellBookByLMM
    openedSpellBookByLMM = false

    if shouldClose and isSpellBookOpen() then
        HideUIPanel(PlayerSpellsFrame)
    end
end

local function syncEditorVisibility()
    local editorFrame = _G[frameName]
    if not editorFrame then
        return
    end

    if not frameVisibilityHooked then
        editorFrame:HookScript("OnShow", openSpellBookForEditor)
        editorFrame:HookScript("OnHide", closeSpellBookForEditor)
        frameVisibilityHooked = true
    end

    if editorFrame:IsShown() then
        openSpellBookForEditor()
    else
        closeSpellBookForEditor()
    end
end

local function installLauncherHooks()
    local minimapButton = _G[minimapButtonName]
    if minimapButton and not minimapButton.LMMSpellBookHooked then
        minimapButton:HookScript("OnClick", function(_, mouseButton)
            if mouseButton == "LeftButton" then
                syncEditorVisibility()
            end
        end)
        minimapButton.LMMSpellBookHooked = true
    end

    if not slashWrapped and SlashCmdList and type(SlashCmdList.LAFEEMACROMANAGER) == "function" then
        local originalSlashHandler = SlashCmdList.LAFEEMACROMANAGER
        SlashCmdList.LAFEEMACROMANAGER = function(message)
            local editorFrame = _G[frameName]
            local wasShown = editorFrame and editorFrame:IsShown() or false

            originalSlashHandler(message)

            editorFrame = _G[frameName]
            local isShown = editorFrame and editorFrame:IsShown() or false
            if wasShown ~= isShown then
                syncEditorVisibility()
            end
        end
        slashWrapped = true
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    -- Lafee_macro_manager.lua also initializes its launchers on PLAYER_LOGIN.
    -- Run on the next tick so its minimap button and slash handler exist first.
    C_Timer.After(0, installLauncherHooks)
end)
