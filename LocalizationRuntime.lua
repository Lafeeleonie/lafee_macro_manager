local addonName = ...
local ACCOUNT_MACRO_LIMIT = MAX_ACCOUNT_MACROS or 120
local text = _G.LafeeMacroManagerText or {}
local coreCopySuffix = GetLocale() == "frFR" and " Copie" or " Copy"

local globalTabName = addonName .. "GlobalTab"
local characterTabName = addonName .. "CharacterTab"
local duplicateSnapshot

local function commonPrefixLength(left, right)
    local limit = math.min(#(left or ""), #(right or ""))
    local index = 0
    while index < limit and left:sub(index + 1, index + 1) == right:sub(index + 1, index + 1) do
        index = index + 1
    end
    return index
end

local function captureMacroScope(startSlot, count)
    local entries = {}
    for offset = 0, count - 1 do
        local slot = startSlot + offset
        local name, _, body = GetMacroInfo(slot)
        if name then
            entries[#entries + 1] = {
                name = name,
                body = body or "",
            }
        end
    end
    return entries
end

local function captureDuplicateSnapshot()
    local accountCount, characterCount = GetNumMacros()
    duplicateSnapshot = {
        accountCount = accountCount,
        characterCount = characterCount,
        account = captureMacroScope(1, accountCount),
        character = captureMacroScope(ACCOUNT_MACRO_LIMIT + 1, characterCount),
    }
end

local function findDuplicateSource(entries, duplicateName, duplicateBody)
    -- First reproduce the exact FR/EN suffix logic still present in the core.
    -- This disambiguates an original macro from an older duplicate with the same body.
    for _, entry in ipairs(entries or {}) do
        if entry.body == duplicateBody
            and (entry.name .. coreCopySuffix):sub(1, 16) == duplicateName
        then
            return entry.name
        end
    end

    -- Fallback for unusual API/name-normalization cases.
    local bestName
    local bestScore = -1
    for _, entry in ipairs(entries or {}) do
        if entry.body == duplicateBody then
            local score = commonPrefixLength(entry.name, duplicateName)
            if score > bestScore then
                bestName = entry.name
                bestScore = score
            end
        end
    end

    return bestName
end

local function localizeCreatedDuplicate()
    local snapshot = duplicateSnapshot
    duplicateSnapshot = nil
    if not snapshot or not text.copySuffix or text.copySuffix == "" then
        return
    end

    local accountCount, characterCount = GetNumMacros()
    local newSlot
    local sourceEntries

    if accountCount == snapshot.accountCount + 1 then
        newSlot = accountCount
        sourceEntries = snapshot.account
    elseif characterCount == snapshot.characterCount + 1 then
        newSlot = ACCOUNT_MACRO_LIMIT + characterCount
        sourceEntries = snapshot.character
    else
        return
    end

    local duplicateName, _, duplicateBody = GetMacroInfo(newSlot)
    if not duplicateName then
        return
    end

    local sourceName = findDuplicateSource(sourceEntries, duplicateName, duplicateBody or "")
    if not sourceName then
        return
    end

    local localizedName = (sourceName .. text.copySuffix):sub(1, 16)
    if localizedName ~= duplicateName then
        -- Blizzard itself uses nil fields with EditMacro to preserve values.
        EditMacro(newSlot, localizedName, nil, nil)
    end
end

local function findDuplicateButton(frame)
    if not frame then
        return nil
    end

    for _, child in ipairs({ frame:GetChildren() }) do
        if child.GetText and child:GetText() == text.buttonDuplicate then
            return child
        end
    end

    return nil
end

function _G.LafeeMacroManagerApplyRuntimeLocalization(frame)
    if not frame then
        return
    end

    local globalTab = _G[globalTabName]
    local characterTab = _G[characterTabName]
    if globalTab and text.globalTab then
        globalTab:SetText(text.globalTab)
    end
    if characterTab and text.characterTab then
        characterTab:SetText(text.characterTab)
    end

    local duplicateButton = findDuplicateButton(frame)
    if duplicateButton and not duplicateButton.LMMRuntimeLocalizationHooked then
        duplicateButton:HookScript("OnMouseDown", function(_, mouseButton)
            if mouseButton == "LeftButton" then
                captureDuplicateSnapshot()
            end
        end)
        duplicateButton:HookScript("OnClick", function(_, mouseButton)
            if mouseButton == "LeftButton" then
                localizeCreatedDuplicate()
            end
        end)
        duplicateButton.LMMRuntimeLocalizationHooked = true
    end
end
