local addonName = ...
local DISPLAY_NAME = "Lafee Macro Manager"
local MINIMAP_BROKER_NAME = "Lafee Macro Manager"

local ADDON = {}
local CHARACTER_MACRO_LIMIT = MAX_CHARACTER_MACROS or 30
local ACCOUNT_MACRO_LIMIT = MAX_ACCOUNT_MACROS or 120
local MACRO_FALLBACK_ICON = "INV_Misc_QuestionMark"
local MINIMAP_ICON = "Interface\\Icons\\INV_Scroll_03"
local ROWS_PER_PAGE = 10
local DEFAULT_MINIMAP_ANGLE = 225
local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")
local ADDON_VERSION = "0.5.7"
local IS_FRENCH = GetLocale() == "frFR"
local DEBUG_SPELLBOOK = false
local TEXT = IS_FRENCH and {
    scopeGlobal = "Generales",
    scopeCharacter = "Personnage",
    scopeSwitched = "Onglet actif: %s.",
    scopeEditing = "Edition des macros %s",
    scopeGlobalLong = "generales",
    scopeCharacterLong = "personnage",
    editorTitle = "Editeur",
    subtitle = "Editeur direct des macros generales et personnage",
    macros = "Macros",
    noMacro = "0 macro",
    newMacro = "Nouvelle macro",
    editingMacro = "Edition: %s",
    name = "Nom",
    icon = "Icone / FileID",
    body = "Contenu",
    buttonNew = "Nouveau",
    buttonSave = "Sauver",
    buttonDelete = "Supprimer",
    buttonDuplicate = "Dupliquer",
    buttonImport = "Importer",
    macroNameRequired = "Le nom de la macro est requis.",
    cannotModifyCombat = "Impossible de modifier les macros en combat.",
    macroLimitReached = "Limite de macros %s atteinte (%d).",
    macroSaved = "Macro %s sauvegardee.",
    selectMacroDelete = "Selectionne une macro a supprimer.",
    selectMacroDuplicate = "Selectionne une macro a dupliquer.",
    macroDeleted = "Macro supprimee.",
    macroDuplicated = "Macro dupliquee.",
    syntaxOk = "Commandes de macro reconnues.",
    syntaxUnknown = "Commandes inconnues: %s",
    syntaxHint = "Commandes en jaune, conditions en vert et sorts valides en bleu.",
    sourceCurrent = "Personnage actuel",
    sourceLabel = "Source",
    importOnly = "Lecture seule: import uniquement depuis un autre personnage.",
    importedFrom = "Macro importee depuis %s.",
    noImportSource = "Selectionne une macro d'un autre personnage a importer.",
    noCachedCharacters = "Aucun autre personnage synchronise.",
    tooltipOpen = "Clic gauche: ouvrir l'editeur",
    tooltipSwitch = "Clic droit: changer d'onglet",
    tooltipDrag = "Glisser: deplacer sur la minimap",
    hint = "Commande: /lmm. La molette fait defiler la liste de gauche. Utilise les onglets macros generales et personnage.",
    rangeFormat = "%d-%d / %d",
    spellInserted = "Sort ajoute dans l'editeur: %s",
    macroOperationFailed = "L'operation sur la macro a echoue.",
    positionReset = "Position de la fenetre reinitialisee.",
    minimapShown = "Bouton de la minicarte affiche.",
    minimapHidden = "Bouton de la minicarte masque. Utilise /lmm minimap pour le restaurer.",
    help = "Commandes: /lmm, /lmm global, /lmm character, /lmm reset, /lmm minimap, /lmm help.",
} or {
    scopeGlobal = "Global",
    scopeCharacter = "Character",
    scopeSwitched = "Active tab: %s.",
    scopeEditing = "Editing %s macros",
    scopeGlobalLong = "global",
    scopeCharacterLong = "character",
    editorTitle = "Editor",
    subtitle = "Direct editor for character and global macros",
    macros = "Macros",
    noMacro = "0 macro",
    newMacro = "New macro",
    editingMacro = "Editing: %s",
    name = "Name",
    icon = "Icon / FileID",
    body = "Body",
    buttonNew = "New",
    buttonSave = "Save",
    buttonDelete = "Delete",
    buttonDuplicate = "Duplicate",
    buttonImport = "Import",
    macroNameRequired = "Macro name is required.",
    cannotModifyCombat = "Cannot modify macros during combat.",
    macroLimitReached = "%s macro limit reached (%d).",
    macroSaved = "%s macro saved.",
    selectMacroDelete = "Select a macro to delete.",
    selectMacroDuplicate = "Select a macro to duplicate.",
    macroDeleted = "Macro deleted.",
    macroDuplicated = "Macro duplicated.",
    syntaxOk = "Known macro commands detected.",
    syntaxUnknown = "Unknown commands: %s",
    syntaxHint = "Commands are yellow, conditions green, and valid spells blue.",
    sourceCurrent = "Current character",
    sourceLabel = "Source",
    importOnly = "Read-only: import only from another character.",
    importedFrom = "Macro imported from %s.",
    noImportSource = "Select a macro from another character to import.",
    noCachedCharacters = "No other synced characters found.",
    tooltipOpen = "Left-click: open editor",
    tooltipSwitch = "Right-click: switch tab",
    tooltipDrag = "Drag: move on minimap",
    hint = "Slash command: /lmm. Mouse wheel scrolls the left list. Use the tabs for general and character macros.",
    rangeFormat = "%d-%d / %d",
    spellInserted = "Inserted spell into editor: %s",
    macroOperationFailed = "The macro operation failed.",
    positionReset = "Window position reset.",
    minimapShown = "Minimap button shown.",
    minimapHidden = "Minimap button hidden. Use /lmm minimap to restore it.",
    help = "Commands: /lmm, /lmm global, /lmm character, /lmm reset, /lmm minimap, /lmm help.",
}
TEXT = _G.LafeeMacroManagerText or TEXT

local function trim(text)
    if not text then
        return ""
    end

    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function buildMacroSignature(name, body)
    return string.format("%s\031%s", trim(name or ""), body or "")
end

local function normalizeIconToken(text)
    local value = trim(text or "")
    if value == "" then
        return ""
    end

    local compact = value:lower():gsub("[_%-%s]", "")
    if value == "?" or compact == "auto" or compact == "invmiscquestionmark" or compact == "invquestionmark" then
        return MACRO_FALLBACK_ICON
    end

    return value
end

local function isQuestionMarkIcon(text)
    return normalizeIconToken(text) == MACRO_FALLBACK_ICON
end

local function sortMacros(macros)
    table.sort(macros, function(left, right)
        return (left.name or ""):lower() < (right.name or ""):lower()
    end)
end

local KNOWN_MACRO_COMMANDS = {
    ["/cast"] = true, ["/use"] = true, ["/castsequence"] = true, ["/target"] = true,
    ["/focus"] = true, ["/targetenemy"] = true, ["/targetenemyplayer"] = true,
    ["/assist"] = true, ["/petattack"] = true, ["/petfollow"] = true, ["/petpassive"] = true,
    ["/startattack"] = true, ["/stopattack"] = true, ["/stopcasting"] = true,
    ["/cancelaura"] = true, ["/click"] = true, ["/equip"] = true, ["/equipslot"] = true,
    ["/swapactionbar"] = true, ["/changeactionbar"] = true, ["/dismount"] = true,
    ["/clearfocus"] = true, ["/cleartarget"] = true, ["/follow"] = true, ["/run"] = true,
    ["/script"] = true, ["/say"] = true, ["/yell"] = true, ["/party"] = true,
    ["/raid"] = true, ["/rw"] = true, ["/stopmacro"] = true, ["/console"] = true,
    ["/castrandom"] = true, ["/userandom"] = true, ["/targetlasttarget"] = true,
    ["/targetfriend"] = true, ["/targetparty"] = true, ["/targetraid"] = true,
    ["/petassist"] = true, ["/petdefensive"] = true, ["/petautocaston"] = true,
    ["/petautocastoff"] = true, ["/cancelform"] = true, ["/cancelqueuedspell"] = true,
    ["/leavevehicle"] = true, ["/mount"] = true, ["/guild"] = true, ["/officer"] = true,
    ["/instance"] = true, ["/whisper"] = true, ["/reply"] = true, ["/emote"] = true,
}

local ICONS_PER_PAGE = 24

local SPELL_HIGHLIGHT_COMMANDS = {
    ["#show"] = true,
    ["#showtooltip"] = true,
    ["/cast"] = true,
    ["/castrandom"] = true,
    ["/castsequence"] = true,
    ["/cancelaura"] = true,
    ["/cancelqueuedspell"] = true,
    ["/petautocastoff"] = true,
    ["/petautocaston"] = true,
    ["/use"] = true,
}
local SPELL_NAME_CACHE = {}

local function escapeColorText(text)
    return (text or ""):gsub("|", "||")
end

local function getSpellNameFromAPI(token)
    local normalized = trim(token or ""):gsub("^!", "")
    if normalized == "" then
        return nil
    end

    if SPELL_NAME_CACHE[normalized] ~= nil then
        return SPELL_NAME_CACHE[normalized] or nil
    end

    local spellName
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, name = pcall(function()
            local info = C_Spell.GetSpellInfo(normalized)
            if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
                return info.name
            end
        end)
        if ok then
            spellName = name
        end
    end

    if not spellName and GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, normalized)
        if ok and type(name) == "string" and name ~= "" then
            spellName = name
        end
    end

    SPELL_NAME_CACHE[normalized] = spellName or false
    return spellName
end

local function extractMacroClausePrefix(clause)
    local working = clause or ""
    local prefix = ""

    while true do
        local condition = working:match("^(%s*%b[]%s*)")
        if not condition then
            break
        end
        prefix = prefix .. condition
        working = working:sub(#condition + 1)
    end

    return prefix, working
end

local function colorizeSpellToken(token)
    local rawToken = trim(token or "")
    if rawToken == "" or rawToken:find("=", 1, true) then
        return token
    end

    if getSpellNameFromAPI(rawToken) then
        return "|cff82c5ff" .. token .. "|r"
    end

    return token
end


local function colorizeSpellClause(clause, isSequence)
    local prefix, remainder = extractMacroClausePrefix(clause)
    if trim(remainder) == "" then
        return clause
    end

    local directive = ""
    if isSequence then
        directive, remainder = remainder:match("^(%s*reset=%S+%s+)(.*)$")
        directive = directive or ""
        remainder = remainder or ""
    end

    if isSequence then
        local parts = {}
        for segment, delimiter in remainder:gmatch("([^,]*)(,?)") do
            if segment == "" and delimiter == "" then
                break
            end
            local leading = segment:match("^(%s*)") or ""
            local core = trim(segment)
            local trailing = segment:match("(%s*)$") or ""
            parts[#parts + 1] = leading .. colorizeSpellToken(core) .. trailing .. delimiter
            if delimiter == "" then
                break
            end
        end
        return prefix .. directive .. table.concat(parts)
    end

    local leading = remainder:match("^(%s*)") or ""
    local core = trim(remainder)
    local trailing = remainder:match("(%s*)$") or ""
    return prefix .. leading .. colorizeSpellToken(core) .. trailing
end

local function colorizeMacroCommand(line)
    local prefix, command, rest = (line or ""):match("^(%s*)([#/]%S+)(.*)$")
    if not command then
        return line
    end

    local isKnown = command:sub(1, 1) == "#" or KNOWN_MACRO_COMMANDS[command:lower()]
    local color = isKnown and "|cffffd166" or "|cffff6b6b"
    return prefix .. color .. command .. "|r" .. rest
end

local function colorizeSpellArguments(text)
    return (text or ""):gsub("([^\r\n]+)", function(line)
        local prefix, command, rest = line:match("^(%s*)([#/]%S+)(.*)$")
        local commandKey = command and command:lower()
        if not commandKey or not SPELL_HIGHLIGHT_COMMANDS[commandKey] then
            return line
        end

        local output = {}
        local remainder = rest or ""
        local isSequence = commandKey == "/castsequence" or commandKey == "/castrandom"

        for clause, delimiter in remainder:gmatch("([^;]*)(;?)") do
            if clause == "" and delimiter == "" then
                break
            end
            output[#output + 1] = colorizeSpellClause(clause, isSequence) .. delimiter
            if delimiter == "" then
                break
            end
        end

        return prefix .. command .. table.concat(output)
    end)
end

local function colorizeMacroText(text)
    local escaped = escapeColorText(text)
    escaped = colorizeSpellArguments(escaped)
    escaped = escaped:gsub("([^\r\n]+)", colorizeMacroCommand)
    escaped = escaped:gsub("(%b[])", "|cff8fe388%1|r")
    return escaped
end

local function validateMacroText(text)
    local unknown = {}
    for line in (text or ""):gmatch("[^\r\n]+") do
        local command = line:match("^%s*(/%S+)")
        if command and not KNOWN_MACRO_COMMANDS[command:lower()] then
            unknown[command:lower()] = true
        end
    end

    local ordered = {}
    for command in pairs(unknown) do
        ordered[#ordered + 1] = command
    end
    table.sort(ordered)
    return ordered
end

local function collectMacroIcons()
    local seen = {}
    local icons = {}

    local function addIcon(icon)
        if icon and icon ~= "" and not seen[icon] then
            seen[icon] = true
            icons[#icons + 1] = icon
        end
    end

    addIcon(MACRO_FALLBACK_ICON)

    local okMacro, macroIcons = pcall(GetMacroIcons)
    if okMacro and type(macroIcons) == "table" then
        for _, icon in ipairs(macroIcons) do
            addIcon(icon)
        end
    end

    local okItem, itemIcons = pcall(GetMacroItemIcons)
    if okItem and type(itemIcons) == "table" then
        for _, icon in ipairs(itemIcons) do
            addIcon(icon)
        end
    end

    return icons
end

function ADDON:GetCharacterLabel()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    local className = select(2, UnitClass("player")) or "UNKNOWN"
    return string.format("%s - %s (%s)", name, realm, className)
end

function ADDON:GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    return string.format("%s-%s", name, realm)
end

function ADDON:RefreshCharacterIdentity()
    self:EnsureDB()

    local actualKey = self:GetCharacterKey()
    local actualLabel = self:GetCharacterLabel()
    local previousKey = LafeeMacroManagerDB.characterKey

    if previousKey and previousKey ~= actualKey and LafeeMacroManagerGlobalDB and LafeeMacroManagerGlobalDB.characters then
        local previousStore = LafeeMacroManagerGlobalDB.characters[previousKey]
        if previousStore and not LafeeMacroManagerGlobalDB.characters[actualKey] then
            LafeeMacroManagerGlobalDB.characters[actualKey] = previousStore
        end
        if previousKey ~= actualKey then
            LafeeMacroManagerGlobalDB.characters[previousKey] = nil
        end
    end

    LafeeMacroManagerDB.characterKey = actualKey
    LafeeMacroManagerDB.character = actualLabel

    if not self.selectedSourceKey or self.selectedSourceKey == previousKey then
        self.selectedSourceKey = actualKey
    end
end

function ADDON:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff69ccf0%s|r: %s", DISPLAY_NAME, message))
end

function ADDON:Debug(message)
    if not DEBUG_SPELLBOOK then
        return
    end

    self:Print("|cffffaa00DEBUG|r " .. tostring(message))
end

function ADDON:EnsureDB()
    LafeeMacroManagerDB = LafeeMacroManagerDB or {}
    LafeeMacroManagerDB.version = 2
    LafeeMacroManagerDB.character = LafeeMacroManagerDB.character or self:GetCharacterLabel()
    LafeeMacroManagerDB.lastScope = LafeeMacroManagerDB.lastScope or "character"
    LafeeMacroManagerDB.windowPosition = LafeeMacroManagerDB.windowPosition or {}
    LafeeMacroManagerDB.autoIconCache = LafeeMacroManagerDB.autoIconCache or {
        global = {},
        character = {},
    }

    LafeeMacroManagerGlobalDB = LafeeMacroManagerGlobalDB or {}
    LafeeMacroManagerGlobalDB.version = 2
    LafeeMacroManagerGlobalDB.minimap = LafeeMacroManagerGlobalDB.minimap or {
        angle = DEFAULT_MINIMAP_ANGLE,
        minimapPos = DEFAULT_MINIMAP_ANGLE,
        hide = false,
    }
    local minimap = LafeeMacroManagerGlobalDB.minimap
    minimap.hide = minimap.hide == true
    minimap.minimapPos = tonumber(minimap.minimapPos) or tonumber(minimap.angle) or DEFAULT_MINIMAP_ANGLE
    minimap.angle = minimap.minimapPos
    LafeeMacroManagerGlobalDB.characters = LafeeMacroManagerGlobalDB.characters or {}
    LafeeMacroManagerDB.characterKey = LafeeMacroManagerDB.characterKey or self:GetCharacterKey()
end

function ADDON:GetAutoIconCache(scope)
    self:EnsureDB()
    local normalizedScope = scope == "global" and "global" or "character"
    LafeeMacroManagerDB.autoIconCache[normalizedScope] = LafeeMacroManagerDB.autoIconCache[normalizedScope] or {}
    return LafeeMacroManagerDB.autoIconCache[normalizedScope]
end

function ADDON:IsAutoIconMacro(scope, name, body)
    return self:GetAutoIconCache(scope)[buildMacroSignature(name, body)] == true
end

function ADDON:SetAutoIconMacro(scope, name, body, enabled)
    local cache = self:GetAutoIconCache(scope)
    cache[buildMacroSignature(name, body)] = enabled == true or nil
end

function ADDON:IsBusy()
    return InCombatLockdown()
end

function ADDON:RunMacroOperation(operation, requireResult, ...)
    if type(operation) ~= "function" then
        self:Print(TEXT.macroOperationFailed)
        return false
    end

    local ok, result = pcall(operation, ...)
    if not ok or (requireResult and (result == nil or result == false or result == 0)) then
        self:Debug(ok and "Macro API returned no valid slot" or result)
        self:Print(TEXT.macroOperationFailed)
        return false
    end

    return true, result
end

function ADDON:SelectMacroBySlot(slot)
    self.selectedIndex = nil
    if not slot then
        return
    end

    for index, entry in ipairs(self.currentMacros or {}) do
        if entry.slot == slot then
            self.selectedIndex = index
            return
        end
    end
end

function ADDON:ApplyWindowPosition()
    if not self.frame then return end
    self:EnsureDB()

    local position = LafeeMacroManagerDB.windowPosition
    self.frame:ClearAllPoints()
    if position and position.point and position.relativePoint and position.x and position.y then
        self.frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function ADDON:SaveWindowPosition()
    if not self.frame then return end
    self:EnsureDB()

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    LafeeMacroManagerDB.windowPosition = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = math.floor((x or 0) + 0.5),
        y = math.floor((y or 0) + 0.5),
    }
end

function ADDON:ResetWindowPosition()
    self:EnsureDB()
    LafeeMacroManagerDB.windowPosition = {}
    self:ApplyWindowPosition()
    self:Print(TEXT.positionReset)
end

function ADDON:GetScope()
    self:EnsureDB()
    return LafeeMacroManagerDB.lastScope or "character"
end

function ADDON:SetScope(scope)
    LafeeMacroManagerDB.lastScope = scope == "global" and "global" or "character"
    self.selectedIndex = nil
    self.scrollOffset = 0
    self:RefreshUI()
end

function ADDON:GetScrollOffsetMax()
    local total = #(self.currentMacros or self:GetCurrentMacros())
    return math.max(0, total - ROWS_PER_PAGE)
end

function ADDON:SetScrollOffset(offset)
    self.scrollOffset = math.min(math.max(offset or 0, 0), self:GetScrollOffsetMax())
    self:RefreshList()
end

function ADDON:ScrollList(delta)
    self:SetScrollOffset((self.scrollOffset or 0) + delta)
end

function ADDON:GetScopeConfig(scope)
    if scope == "global" then
        return {
            label = TEXT.scopeGlobal,
            longLabel = TEXT.scopeGlobalLong,
            perCharacter = false,
            startSlot = 1,
            limit = ACCOUNT_MACRO_LIMIT,
        }
    end

    return {
        label = TEXT.scopeCharacter,
        longLabel = TEXT.scopeCharacterLong,
        perCharacter = true,
        startSlot = ACCOUNT_MACRO_LIMIT + 1,
        limit = CHARACTER_MACRO_LIMIT,
    }
end

function ADDON:EnumerateMacros(scope)
    local macros = {}
    local accountCount, characterCount = GetNumMacros()
    local activeScope = scope or self:GetScope()
    local config = self:GetScopeConfig(activeScope)
    local count = config.perCharacter and characterCount or accountCount

    for macroIndex = 1, count do
        local slot = config.startSlot + macroIndex - 1
        local name, icon, body = GetMacroInfo(slot)

        if name and name ~= "" then
            local autoIcon = self:IsAutoIconMacro(activeScope, name, body or "")
            macros[#macros + 1] = {
                slot = slot,
                name = name,
                icon = icon or MACRO_FALLBACK_ICON,
                body = body or "",
                autoIcon = autoIcon,
                iconInput = autoIcon and MACRO_FALLBACK_ICON or tostring(icon or MACRO_FALLBACK_ICON),
            }
        end
    end

    sortMacros(macros)
    return macros
end

function ADDON:GetCurrentMacros()
    if self:IsViewingRemoteSource() then
        self.currentMacros = self:GetRemoteMacros(self.selectedSourceKey, self:GetScope())
    else
        self.currentMacros = self:EnumerateMacros(self:GetScope())
    end
    return self.currentMacros
end

function ADDON:GetCurrentSourceKey()
    self:EnsureDB()
    return self.selectedSourceKey or LafeeMacroManagerDB.characterKey
end

function ADDON:IsViewingRemoteSource()
    self:EnsureDB()
    return self:GetCurrentSourceKey() ~= LafeeMacroManagerDB.characterKey
end

function ADDON:GetCharacterStore(key)
    self:EnsureDB()
    return LafeeMacroManagerGlobalDB.characters[key]
end

function ADDON:GetRemoteMacros(key, scope)
    local store = self:GetCharacterStore(key)
    if not store then
        return {}
    end

    local macros = {}
    local source = scope == "global" and (store.globalMacros or {}) or (store.characterMacros or {})
    for index, entry in ipairs(source) do
        macros[index] = {
            name = entry.name,
            icon = entry.icon or MACRO_FALLBACK_ICON,
            body = entry.body or "",
            autoIcon = entry.autoIcon == true,
            iconInput = entry.autoIcon and MACRO_FALLBACK_ICON or tostring(entry.icon or MACRO_FALLBACK_ICON),
        }
    end

    sortMacros(macros)
    return macros
end

function ADDON:SyncCurrentCharacterToAccount()
    self:EnsureDB()

    local key = LafeeMacroManagerDB.characterKey
    LafeeMacroManagerGlobalDB.characters[key] = {
        key = key,
        label = LafeeMacroManagerDB.character or self:GetCharacterLabel(),
        name = UnitName("player") or "Unknown",
        realm = GetRealmName() or "Unknown",
        classTag = select(2, UnitClass("player")) or "UNKNOWN",
        globalMacros = self:EnumerateMacros("global"),
        characterMacros = self:EnumerateMacros("character"),
        updatedAt = time(),
    }
end

function ADDON:GetAvailableSourceList()
    self:EnsureDB()

    local items = {
        {
            key = LafeeMacroManagerDB.characterKey,
            label = TEXT.sourceCurrent,
        }
    }

    local extra = {}
    for key, store in pairs(LafeeMacroManagerGlobalDB.characters) do
        if key ~= LafeeMacroManagerDB.characterKey then
            extra[#extra + 1] = {
                key = key,
                label = store.label or key,
            }
        end
    end

    table.sort(extra, function(left, right)
        return left.label:lower() < right.label:lower()
    end)

    for _, item in ipairs(extra) do
        items[#items + 1] = item
    end

    return items
end

function ADDON:GetSelectedEntry()
    if not self.selectedIndex then
        return nil
    end

    return (self.currentMacros or self:GetCurrentMacros())[self.selectedIndex]
end

function ADDON:GetScopeMacroCount(scope)
    local accountCount, characterCount = GetNumMacros()
    return scope == "global" and accountCount or characterCount
end

function ADDON:RefreshFromGame()
    self.selectedIndex = nil
    self.scrollOffset = 0
    self.selectedSourceKey = LafeeMacroManagerDB and LafeeMacroManagerDB.characterKey or self.selectedSourceKey
    self:GetCurrentMacros()
    self:SyncCurrentCharacterToAccount()
    self:RefreshUI()
end

function ADDON:SaveEditorToGame()
    if self:IsViewingRemoteSource() then
        self:Print(TEXT.importOnly)
        return
    end

    if self:IsBusy() then
        self:Print(TEXT.cannotModifyCombat)
        return
    end

    local name = trim(self.nameEditBox:GetText())
    local body = trim(self:GetBodyEditorText())
    local icon = normalizeIconToken(self.iconEditBox:GetText())
    local scope = self:GetScope()
    local config = self:GetScopeConfig(scope)

    if name == "" then
        self:Print(TEXT.macroNameRequired)
        return
    end

    local selectedEntry = self:GetSelectedEntry()
    local useAutoIcon = icon == "" or isQuestionMarkIcon(icon) or (selectedEntry and selectedEntry.autoIcon and icon == tostring(selectedEntry.icon or ""))
    local iconValue = useAutoIcon and MACRO_FALLBACK_ICON or (tonumber(icon) or icon)
    if iconValue == "" then
        iconValue = MACRO_FALLBACK_ICON
    end

    name = name:sub(1, 16)
    body = body:sub(1, 255)

    local operationSucceeded, macroSlot
    if selectedEntry and selectedEntry.slot then
        operationSucceeded, macroSlot = self:RunMacroOperation(EditMacro, true, selectedEntry.slot, name, iconValue, body)
        if not operationSucceeded then
            return
        end
        if selectedEntry.name ~= name or selectedEntry.body ~= body then
            self:SetAutoIconMacro(scope, selectedEntry.name, selectedEntry.body, false)
        end
    else
        local count = self:GetScopeMacroCount(scope)
        if count >= config.limit then
            self:Print(string.format(TEXT.macroLimitReached, config.longLabel, config.limit))
            return
        end

        operationSucceeded, macroSlot = self:RunMacroOperation(CreateMacro, true, name, iconValue, body, config.perCharacter)
        if not operationSucceeded then
            return
        end
    end

    self:SetAutoIconMacro(scope, name, body, useAutoIcon)

    self:GetCurrentMacros()
    self:SelectMacroBySlot(macroSlot or (selectedEntry and selectedEntry.slot))

    self:RefreshUI()
    self:Print(string.format(TEXT.macroSaved, config.longLabel))
    self:SyncCurrentCharacterToAccount()
end

function ADDON:DeleteSelectedMacroFromGame()
    self:EnsureDB()

    if self:IsViewingRemoteSource() then
        self:Print(TEXT.importOnly)
        return
    end

    if self:IsBusy() then
        self:Print(TEXT.cannotModifyCombat)
        return
    end

    local selectedEntry = self:GetSelectedEntry()
    if not selectedEntry or not selectedEntry.slot then
        self:Print(TEXT.selectMacroDelete)
        return
    end

    local operationSucceeded = self:RunMacroOperation(DeleteMacro, false, selectedEntry.slot)
    if not operationSucceeded then
        return
    end
    self:SetAutoIconMacro(self:GetScope(), selectedEntry.name, selectedEntry.body, false)
    self.selectedIndex = nil
    self:GetCurrentMacros()
    self:RefreshUI()
    self:Print(TEXT.macroDeleted)
    self:SyncCurrentCharacterToAccount()
end

function ADDON:DuplicateSelectedMacro()
    if self:IsViewingRemoteSource() then
        self:Print(TEXT.importOnly)
        return
    end

    if self:IsBusy() then
        self:Print(TEXT.cannotModifyCombat)
        return
    end

    local selectedEntry = self:GetSelectedEntry()
    if not selectedEntry then
        self:Print(TEXT.selectMacroDuplicate)
        return
    end

    local scope = self:GetScope()
    local config = self:GetScopeConfig(scope)
    local count = self:GetScopeMacroCount(scope)
    if count >= config.limit then
        self:Print(string.format(TEXT.macroLimitReached, config.longLabel, config.limit))
        return
    end

    local suffix = IS_FRENCH and " Copie" or " Copy"
    local duplicateName = (trim(selectedEntry.name or "") .. suffix):sub(1, 16)
    local duplicateBody = (selectedEntry.body or ""):sub(1, 255)
    local duplicateIcon = selectedEntry.autoIcon and MACRO_FALLBACK_ICON or (selectedEntry.icon or MACRO_FALLBACK_ICON)

    local operationSucceeded, macroSlot = self:RunMacroOperation(
        CreateMacro,
        true,
        duplicateName,
        duplicateIcon,
        duplicateBody,
        config.perCharacter
    )
    if not operationSucceeded then
        return
    end
    self:SetAutoIconMacro(scope, duplicateName, duplicateBody, selectedEntry.autoIcon)
    self:GetCurrentMacros()
    self:SelectMacroBySlot(macroSlot)

    self:RefreshUI()
    self:Print(TEXT.macroDuplicated)
    self:SyncCurrentCharacterToAccount()
end

function ADDON:ImportSelectedRemoteMacro()
    if not self:IsViewingRemoteSource() then
        self:Print(TEXT.noImportSource)
        return
    end

    if self:IsBusy() then
        self:Print(TEXT.cannotModifyCombat)
        return
    end

    local selectedEntry = self:GetSelectedEntry()
    if not selectedEntry then
        self:Print(TEXT.noImportSource)
        return
    end

    local scope = self:GetScope()
    local config = self:GetScopeConfig(scope)
    local count = self:GetScopeMacroCount(scope)
    if count >= config.limit then
        self:Print(string.format(TEXT.macroLimitReached, config.longLabel, config.limit))
        return
    end

    local importedName = (selectedEntry.name or ""):sub(1, 16)
    local importedBody = (selectedEntry.body or ""):sub(1, 255)
    local operationSucceeded, macroSlot = self:RunMacroOperation(
        CreateMacro,
        true,
        importedName,
        selectedEntry.autoIcon and MACRO_FALLBACK_ICON or (selectedEntry.icon or MACRO_FALLBACK_ICON),
        importedBody,
        config.perCharacter
    )
    if not operationSucceeded then
        return
    end
    self:SetAutoIconMacro(
        scope,
        importedName,
        importedBody,
        selectedEntry.autoIcon
    )

    local sourceStore = self:GetCharacterStore(self.selectedSourceKey)
    local sourceLabel = sourceStore and sourceStore.label or self.selectedSourceKey or "?"
    self.selectedSourceKey = LafeeMacroManagerDB.characterKey
    self:GetCurrentMacros()
    self:SelectMacroBySlot(macroSlot)
    self:RefreshUI()
    self:SyncCurrentCharacterToAccount()
    self:Print(string.format(TEXT.importedFrom, sourceLabel))
end

function ADDON:SelectMacro(index)
    self.selectedIndex = index
    self:RefreshUI()
end

function ADDON:PopulateEditor(entry)
    if not entry then
        self.nameEditBox:SetText("")
        self.iconEditBox:SetText(MACRO_FALLBACK_ICON)
        self:SetBodyEditorText("")
        if self.bodyEditBox.SetCursorPosition then
            self.bodyEditBox:SetCursorPosition(0)
        end
        self.selectedLabel:SetText(TEXT.newMacro)
        if self.iconPreview then
            self.iconPreview:SetTexture(MACRO_FALLBACK_ICON)
        end
        self:RefreshSyntaxState()
        return
    end

    self.nameEditBox:SetText(entry.name or "")
    self.iconEditBox:SetText(entry.iconInput or tostring(entry.icon or ""))
    self:SetBodyEditorText(entry.body or "")
    if self.bodyEditBox.SetCursorPosition then
        self.bodyEditBox:SetCursorPosition(0)
    end
    self.selectedLabel:SetText(string.format(TEXT.editingMacro, entry.name or "Macro"))
    if self.iconPreview then
        self.iconPreview:SetTexture(entry.autoIcon and MACRO_FALLBACK_ICON or (entry.icon or MACRO_FALLBACK_ICON))
    end
    self:RefreshSyntaxState()
end

function ADDON:ClearEditor()
    self.selectedIndex = nil
    self:PopulateEditor(nil)
    self:RefreshList()
end

function ADDON:RefreshList()
    if not self.rows then
        return
    end

    self:GetCurrentMacros()
    self.scrollOffset = math.min(math.max(self.scrollOffset or 0, 0), self:GetScrollOffsetMax())
    local startIndex = self.scrollOffset + 1

    for visibleIndex, row in ipairs(self.rows) do
        local index = startIndex + visibleIndex - 1
        local entry = self.currentMacros[index]

        if entry then
            row.index = index
            row.name:SetText(entry.name)
            row.icon:SetTexture(entry.icon or MACRO_FALLBACK_ICON)
            row:SetShown(true)

            if self.selectedIndex == index then
                row.Highlight:Show()
            else
                row.Highlight:Hide()
            end
        else
            row.index = nil
            row:SetShown(false)
            row.Highlight:Hide()
        end
    end

    if self.pageLabel then
        local total = #self.currentMacros
        if total == 0 then
            self.pageLabel:SetText(TEXT.noMacro)
        else
            local lastVisible = math.min(startIndex + ROWS_PER_PAGE - 1, total)
            self.pageLabel:SetText(string.format(TEXT.rangeFormat, startIndex, lastVisible, total))
        end
    end
end

function ADDON:RefreshControlState()
    if not self.frame then
        return
    end

    local isRemote = self:IsViewingRemoteSource()
    local canModify = not isRemote and not self:IsBusy()
    if self.newButton then
        self.newButton:SetEnabled(canModify)
        self.newButton:SetShown(not isRemote)
    end
    if self.saveButton then
        self.saveButton:SetEnabled(canModify)
        self.saveButton:SetShown(not isRemote)
    end
    if self.duplicateButton then
        self.duplicateButton:SetEnabled(canModify)
        self.duplicateButton:SetShown(not isRemote)
    end
    if self.deleteButton then
        self.deleteButton:SetEnabled(canModify)
        self.deleteButton:SetShown(not isRemote)
    end
    if self.importButton then
        self.importButton:SetEnabled(isRemote and not self:IsBusy())
        self.importButton:SetShown(isRemote)
    end
    if self.nameEditBox then self.nameEditBox:SetEnabled(canModify) end
    if self.iconEditBox then self.iconEditBox:SetEnabled(canModify) end
    if self.bodyEditBox then
        -- Keep the body enabled so its text can always be selected and copied.
        -- Save/import buttons still enforce combat and remote-source rules.
        self.bodyEditBox:SetEnabled(true)
        self:UpdateBodyEditorVisualState()
    end
    if self.iconPickerFrame and not canModify then
        self.iconPickerFrame:Hide()
    end

    if self.remoteHintLabel then
        self.remoteHintLabel:SetShown(isRemote)
    end
end

function ADDON:UpdateBodyEditorVisualState()
    if not self.bodyEditBox then
        return
    end

    -- The raw EditBox remains the sole interactive control.  Its glyphs are
    -- nearly transparent so the colored, non-interactive preview beneath can
    -- stay visible while typing; native selection highlighting remains active.
    self.bodyEditBox:SetTextColor(1, 1, 1, 0.01)
    if self.syntaxPreview then
        self.syntaxPreview:Show()
    end
    if self.bodyEditorCaret then
        self.bodyEditorCaret:SetShown(self.bodyEditBox:HasFocus())
    end
end

function ADDON:RefreshUI()
    if not self.frame then
        return
    end

    self:EnsureDB()
    local scope = self:GetScope()
    local scopeLabel = self:GetScopeConfig(scope).label
    self.title:SetText(string.format("Lafee Macro Manager v%s - %s", ADDON_VERSION, LafeeMacroManagerDB.character or self:GetCharacterLabel()))
    self.scopeLabel:SetText(string.format(TEXT.scopeEditing, scopeLabel))
    PanelTemplates_SetTab(self.frame, scope == "global" and 1 or 2)
    if self.sourceDropdownText then
        local currentSourceKey = self:GetCurrentSourceKey()
        local currentLabel = TEXT.sourceCurrent
        if currentSourceKey ~= LafeeMacroManagerDB.characterKey then
            local store = self:GetCharacterStore(currentSourceKey)
            currentLabel = (store and store.label) or currentSourceKey
        end
        self.sourceDropdownText:SetText(currentLabel)
    end

    self:RefreshControlState()

    self:RefreshList()
    self:PopulateEditor(self:GetSelectedEntry())
    self:RefreshSyntaxState()
end

function ADDON:RefreshSyntaxState()
    if not self.bodyEditBox then
        return
    end

    local text = self:GetBodyEditorText()
    if self.syntaxPreview then
        self.syntaxPreview:SetText(colorizeMacroText(text))
    end
    if not self.syntaxLabel then
        return
    end

    local unknown = validateMacroText(text)
    if #unknown > 0 then
        self.syntaxLabel:SetText(string.format(TEXT.syntaxUnknown, table.concat(unknown, ", ")))
        self.syntaxLabel:SetTextColor(1, 0.4, 0.4)
    else
        self.syntaxLabel:SetText(TEXT.syntaxOk)
        self.syntaxLabel:SetTextColor(0.55, 0.9, 0.55)
    end
end

function ADDON:GetBodyEditorText()
    if self.bodyEditorRawText ~= nil then
        return self.bodyEditorRawText
    end

    if not self.bodyEditBox then
        return ""
    end

    return self.bodyEditBox:GetText() or ""
end

function ADDON:RefreshBodyEditorDisplay(cursorPosition)
    if not self.bodyEditBox or self.isUpdatingBodyEditorDisplay then
        return
    end

    self.isUpdatingBodyEditorDisplay = true
    local rawText = self.bodyEditorRawText or ""
    local previousScroll = (self.bodyScroll and self.bodyScroll.GetVerticalScroll) and self.bodyScroll:GetVerticalScroll() or 0
    self.bodyEditBox:SetText(rawText)

    if self.bodyEditBox.SetCursorPosition then
        self.bodyEditBox:SetCursorPosition(math.max(0, math.min(cursorPosition or 0, #rawText)))
    end

    if self.syntaxPreview then
        self.syntaxPreview:SetText(colorizeMacroText(rawText))
    end

    if self.bodyScroll and self.bodyScroll.UpdateScrollChildRect then
        self.bodyScroll:UpdateScrollChildRect()
    end
    if self.bodyScroll and self.bodyScroll.SetVerticalScroll then
        self.bodyScroll:SetVerticalScroll(previousScroll or 0)
    end

    self.isUpdatingBodyEditorDisplay = false
end

function ADDON:SetBodyEditorText(text)
    self.bodyEditorRawText = text or ""
    self:RefreshBodyEditorDisplay(0)
end

function ADDON:RefreshIconPreview()
    if not self.iconPreview or not self.iconEditBox then
        return
    end

    local iconValue = normalizeIconToken(self.iconEditBox:GetText())
    if iconValue == "" then
        iconValue = MACRO_FALLBACK_ICON
    end
    self.iconPreview:SetTexture(tonumber(iconValue) or iconValue)
end

function ADDON:SelectIcon(icon)
    if not self.iconEditBox then
        return
    end

    self.iconEditBox:SetText(tostring(icon or MACRO_FALLBACK_ICON))
    self:RefreshIconPreview()
    if self.iconPickerFrame then
        self.iconPickerFrame:Hide()
    end
end

function ADDON:RefreshIconPicker()
    if not self.iconPickerFrame then
        return
    end

    self.iconChoices = self.iconChoices or collectMacroIcons()
    local totalPages = math.max(1, math.ceil(#self.iconChoices / ICONS_PER_PAGE))
    self.iconPickerPage = math.min(math.max(1, self.iconPickerPage or 1), totalPages)
    local startIndex = ((self.iconPickerPage - 1) * ICONS_PER_PAGE) + 1
    local currentIcon = trim(self.iconEditBox and self.iconEditBox:GetText() or "")
    if currentIcon == "" then
        currentIcon = MACRO_FALLBACK_ICON
    end

    for visibleIndex, button in ipairs(self.iconPickerButtons) do
        local icon = self.iconChoices[startIndex + visibleIndex - 1]
        if icon then
            button.iconValue = icon
            button.icon:SetTexture(icon)
            button:Show()
            if tostring(icon) == currentIcon then
                button.Highlight:Show()
            else
                button.Highlight:Hide()
            end
        else
            button.iconValue = nil
            button:Hide()
            button.Highlight:Hide()
        end
    end

    self.iconPickerPageLabel:SetText(string.format("%d / %d", self.iconPickerPage, totalPages))
    self.iconPickerPrev:SetEnabled(self.iconPickerPage > 1)
    self.iconPickerNext:SetEnabled(self.iconPickerPage < totalPages)
end

function ADDON:ToggleIconPicker()
    if not self.iconPickerFrame then
        return
    end

    if self.iconPickerFrame:IsShown() then
        self.iconPickerFrame:Hide()
        return
    end

    self.iconChoices = self.iconChoices or collectMacroIcons()
    self.iconPickerPage = 1
    self:RefreshIconPicker()
    self.iconPickerFrame:Show()
end

function ADDON:CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(260, 28)
    row:SetPoint("TOPLEFT", 8, -8 - ((index - 1) * 30))
    row:RegisterForClicks("LeftButtonUp")
    row:RegisterForDrag("LeftButton")
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    row:SetBackdropColor(0.08, 0.08, 0.1, 0.9)
    row:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)

    row.Highlight = row:CreateTexture(nil, "BACKGROUND")
    row.Highlight:SetAllPoints()
    row.Highlight:SetColorTexture(0.15, 0.35, 0.6, 0.35)
    row.Highlight:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 8, 0)
    row.icon:SetTexture(MACRO_FALLBACK_ICON)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetPoint("RIGHT", -8, 0)
    row.name:SetJustifyH("LEFT")

    row:SetScript("OnClick", function(button)
        if button.index then
            ADDON:SelectMacro(button.index)
        end
    end)
    row:SetScript("OnDragStart", function(button)
        if not button.index then
            return
        end

        local entry = ADDON.currentMacros and ADDON.currentMacros[button.index]
        if entry and entry.slot then
            if ADDON:IsBusy() then
                ADDON:Print(TEXT.cannotModifyCombat)
                return
            end
            PickupMacro(entry.slot)
        end
    end)

    return row
end

function ADDON:CreateButton(parent, label, width, point, relativeTo, relativePoint, offsetX, offsetY, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(label)
    button:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    button:SetScript("OnClick", onClick)
    return button
end

function ADDON:CreateEditBox(parent, width, height, multiline)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(width, height)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    container:SetBackdropColor(0.02, 0.02, 0.02, 0.95)
    container:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)

    if multiline then
        local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", container, "TOPLEFT", 6, -6)
        scroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -28, 6)
        container.scrollFrame = scroll

        -- Keep one native EditBox as the direct scroll child.  The preview is
        -- a non-interactive child of that EditBox, so it cannot steal clicks.
        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetSize(width - 42, height - 16)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:EnableMouse(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetTextColor(1, 1, 1, 0.01)
        editBox:SetJustifyH("LEFT")
        editBox:SetJustifyV("TOP")
        editBox:SetMaxLetters(255)
        editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
        if editBox.SetCountInvisibleLetters then
            editBox:SetCountInvisibleLetters(false)
        end
        if editBox.SetTextInsets then
            editBox:SetTextInsets(4, 4, 4, 4)
        end
        if editBox.SetHighlightColor then
            editBox:SetHighlightColor(0.2, 0.55, 1, 0.75)
        end

        local syntaxPreview = editBox:CreateFontString(nil, "BACKGROUND", "ChatFontNormal")
        syntaxPreview:SetPoint("TOPLEFT", editBox, "TOPLEFT", 4, -4)
        syntaxPreview:SetWidth(width - 50)
        syntaxPreview:SetJustifyH("LEFT")
        syntaxPreview:SetJustifyV("TOP")
        syntaxPreview:SetSpacing(0)
        syntaxPreview:SetTextColor(1, 1, 1, 1)
        self.syntaxPreview = syntaxPreview

        local caret = editBox:CreateTexture(nil, "OVERLAY", nil, 7)
        caret:SetColorTexture(1, 0.82, 0, 1)
        caret:SetSize(2, 14)
        caret:SetPoint("TOPLEFT", editBox, "TOPLEFT", 4, -4)
        caret:Hide()
        self.bodyEditorCaret = caret

        editBox:SetScript("OnTextChanged", function(box)
            if not ADDON.isUpdatingBodyEditorDisplay then
                if ADDON:IsViewingRemoteSource() then
                    local cursorPosition = box.GetCursorPosition and box:GetCursorPosition() or 0
                    ADDON:RefreshBodyEditorDisplay(cursorPosition)
                    return
                end
                ADDON.bodyEditorRawText = box:GetText() or ""
            end
            local targetHeight = math.max((scroll.GetHeight and scroll:GetHeight() or 0), box:GetNumLines() * 14 + 16)
            box:SetHeight(targetHeight)
            if ADDON.syntaxPreview then
                ADDON.syntaxPreview:SetText(colorizeMacroText(box:GetText() or ""))
                ADDON.syntaxPreview:SetHeight(targetHeight)
            end
            if scroll.UpdateScrollChildRect then
                scroll:UpdateScrollChildRect()
            end
            ADDON:RefreshSyntaxState()
        end)

        editBox:SetScript("OnCursorChanged", function(_, x, y, _, cursorHeight)
            local cursorTop = -(y or 0)
            caret:ClearAllPoints()
            caret:SetPoint("TOPLEFT", editBox, "TOPLEFT", (x or 0) + 4, (y or 0) - 1)
            caret:SetSize(2, math.max(14, cursorHeight or 14))
            caret:SetShown(editBox:HasFocus())

            local offset = scroll:GetVerticalScroll()
            if cursorTop < offset then
                scroll:SetVerticalScroll(cursorTop)
            else
                local cursorBottom = cursorTop + (cursorHeight or 0) - scroll:GetHeight()
                if cursorBottom > offset then
                    scroll:SetVerticalScroll(cursorBottom)
                end
            end
        end)

        editBox:SetScript("OnEditFocusGained", function()
            ADDON:UpdateBodyEditorVisualState()
        end)
        editBox:SetScript("OnEditFocusLost", function()
            ADDON:UpdateBodyEditorVisualState()
        end)
        scroll:SetScrollChild(editBox)
        editBox:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
        self.bodyEditContent = editBox
        return container, editBox
    end

    local editBox = CreateFrame("EditBox", nil, container)
    editBox:SetPoint("TOPLEFT", 6, -6)
    editBox:SetPoint("BOTTOMRIGHT", -6, 6)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetTextColor(1, 0.82, 0, 1)
    editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
    return container, editBox
end

function ADDON:ApplyElvUISkin()
    if self.elvUISkinned or not self.frame then
        return
    end

    local engine = _G.ElvUI
    if not engine then
        return
    end

    local E = unpack(engine)
    if not E or not E.Skins then
        return
    end

    local S = E.Skins
    if S.HandleFrame then
        S:HandleFrame(self.frame)
        if self.nameEditContainer then
            S:HandleFrame(self.nameEditContainer)
        end
        if self.iconEditContainer then
            S:HandleFrame(self.iconEditContainer)
        end
        if self.bodyEditContainer then
            S:HandleFrame(self.bodyEditContainer)
        end
    end

    if S.HandleButton then
        local buttons = { self.newButton, self.saveButton, self.duplicateButton, self.deleteButton, self.importButton }
        for _, button in ipairs(buttons) do
            if button then
                S:HandleButton(button)
            end
        end
    end

    if S.HandleTab then
        if self.globalTab then
            S:HandleTab(self.globalTab)
        end
        if self.characterTab then
            S:HandleTab(self.characterTab)
        end
    end

    if self.sourceDropdown then
        if self.sourceDropdown.Left then self.sourceDropdown.Left:Hide() end
        if self.sourceDropdown.Middle then self.sourceDropdown.Middle:Hide() end
        if self.sourceDropdown.Right then self.sourceDropdown.Right:Hide() end

        if self.sourceDropdownButton then
            if self.sourceDropdownButton.NormalTexture then
                self.sourceDropdownButton.NormalTexture:SetAlpha(0)
            end
            if self.sourceDropdownButton.PushedTexture then
                self.sourceDropdownButton.PushedTexture:SetAlpha(0)
            end
            if self.sourceDropdownButton.HighlightTexture then
                self.sourceDropdownButton.HighlightTexture:SetAlpha(0)
            end
            if S.HandleButton then
                S:HandleButton(self.sourceDropdownButton)
            end
        end

        if self.sourceDropdown.backdrop and self.sourceDropdown.backdrop.SetTemplate then
            self.sourceDropdown.backdrop:SetTemplate("Transparent")
        elseif self.sourceDropdown.SetTemplate then
            self.sourceDropdown:SetTemplate("Transparent")
        end
    end

    if self.bodyScroll and self.bodyScroll.ScrollBar and S.HandleScrollBar then
        S:HandleScrollBar(self.bodyScroll.ScrollBar)
    end

    self.elvUISkinned = true
end

function ADDON:GetActiveEditorBox()
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() or nil
    if focus == self.nameEditBox or focus == self.iconEditBox or focus == self.bodyEditBox then
        return focus
    end

    return self.bodyEditBox or self.nameEditBox
end

function ADDON:InsertTextIntoEditor(text)
    if not text or text == "" or not self.frame or not self.frame:IsShown() or self:IsViewingRemoteSource() then
        return false
    end

    local editBox = self:GetActiveEditorBox()
    if not editBox or not editBox:IsEnabled() then
        return false
    end

    if editBox == self.bodyEditBox then
        -- The body EditBox contains raw macro text.  Native Insert preserves
        -- the mouse cursor and replaces the current selection when present.
        editBox:SetFocus()
        editBox:Insert(text)
        self.bodyEditorRawText = editBox:GetText() or ""
        self:RefreshSyntaxState()
        return true
    end

    editBox:SetFocus()
    editBox:Insert(text)
    return true
end

function ADDON:GetSpellNameFromSpellbookItem(spellItem)
    if not spellItem then
        return nil
    end

    local itemInfo = spellItem.spellBookItemInfo
    if itemInfo and itemInfo.name and itemInfo.name ~= "" then
        return itemInfo.name
    end

    local elementData = spellItem.elementData
    local slotIndex = spellItem.slotIndex or (elementData and elementData.slotIndex)
    local spellBank = spellItem.spellBank or (elementData and elementData.spellBank)
    if slotIndex and spellBank ~= nil and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
        local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, slotIndex, spellBank)
        if ok and info and info.name and info.name ~= "" then
            return info.name
        end
    end

    return nil
end

function ADDON:HandleSpellbookModifiedClick(spellItem, mouseButton)
    self:Debug("SpellBookItemMixin.OnModifiedClick mouse=" .. tostring(mouseButton) .. " shift=" .. tostring(IsShiftKeyDown()))
    if not IsShiftKeyDown() then
        return
    end

    local spellName = self:GetSpellNameFromSpellbookItem(spellItem)
    if not spellName or spellName == "" then
        self:Debug("Spellbook click ignored: no spell name")
        return
    end

    if self:InsertTextIntoEditor(spellName) then
        self:Debug("InsertTextIntoEditor success -> " .. tostring(spellName))
        self:Print(string.format(TEXT.spellInserted, spellName))
    else
        self:Debug("InsertTextIntoEditor failed -> " .. tostring(spellName))
    end
end

function ADDON:RegisterSpellbookCallback()
    if self.spellbookCallbackRegistered then
        return
    end

    if not EventRegistry or type(EventRegistry.RegisterCallback) ~= "function" then
        self:Debug("EventRegistry unavailable; spellbook insertion disabled")
        return
    end

    EventRegistry:RegisterCallback("SpellBookItemMixin.OnModifiedClick", function(_, spellItem, mouseButton)
        ADDON:HandleSpellbookModifiedClick(spellItem, mouseButton)
    end, self)
    self.spellbookCallbackRegistered = true
end

function ADDON:UpdateMinimapButtonPosition()
    if not DBIcon:IsRegistered(MINIMAP_BROKER_NAME) then
        return
    end

    self:EnsureDB()
    local minimap = LafeeMacroManagerGlobalDB.minimap
    minimap.angle = tonumber(minimap.minimapPos) or minimap.angle
    DBIcon:Refresh(MINIMAP_BROKER_NAME, minimap)
    if minimap.hide then
        DBIcon:Hide(MINIMAP_BROKER_NAME)
    else
        DBIcon:Show(MINIMAP_BROKER_NAME)
    end
    self.minimapButton = DBIcon:GetMinimapButton(MINIMAP_BROKER_NAME)
end

function ADDON:CreateMinimapButton()
    self:EnsureDB()
    if not self.minimapDataObject then
        self.minimapDataObject = LDB:NewDataObject(MINIMAP_BROKER_NAME, {
            type = "launcher",
            text = DISPLAY_NAME,
            icon = MINIMAP_ICON,
            OnClick = function(_, mouseButton)
                if mouseButton == "RightButton" then
                    if self:GetScope() == "character" then
                        self:SetScope("global")
                    else
                        self:SetScope("character")
                    end
                    self:Print(string.format(TEXT.scopeSwitched, self:GetScopeConfig(self:GetScope()).label))
                elseif mouseButton == "LeftButton" then
                    self:ToggleUI()
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine(DISPLAY_NAME)
                tooltip:AddLine(TEXT.tooltipOpen, 0.9, 0.9, 0.9)
                tooltip:AddLine(TEXT.tooltipSwitch, 0.9, 0.9, 0.9)
                tooltip:AddLine(TEXT.tooltipDrag, 0.9, 0.9, 0.9)
            end,
        })
    end
    if not DBIcon:IsRegistered(MINIMAP_BROKER_NAME) then
        DBIcon:Register(MINIMAP_BROKER_NAME, self.minimapDataObject, LafeeMacroManagerGlobalDB.minimap)
    end
    self:UpdateMinimapButtonPosition()
end

function ADDON:CreateUI()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", addonName .. "Frame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(720, 560)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    local dragHandle = CreateFrame("Frame", nil, frame)
    dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -2)
    dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -2)
    dragHandle:SetHeight(22)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    dragHandle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        ADDON:SaveWindowPosition()
    end)
    frame.dragHandle = dragHandle
    frame:Hide()

    self.frame = frame
    self:ApplyWindowPosition()
    if UISpecialFrames then
        table.insert(UISpecialFrames, frame:GetName())
    end
    self.title = frame.TitleText
    self.title:SetText("Lafee Macro Manager")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", 16, -34)
    subtitle:SetText(TEXT.subtitle)

    local listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    listLabel:SetPoint("TOPLEFT", 16, -62)
    listLabel:SetText(TEXT.macros)

    local sourceLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sourceLabel:SetPoint("TOPLEFT", 16, -88)
    sourceLabel:SetText(TEXT.sourceLabel)

    local sourceDropdown = CreateFrame("Frame", addonName .. "SourceDropdown", frame, "UIDropDownMenuTemplate")
    sourceDropdown:SetPoint("TOPLEFT", 8, -100)
    UIDropDownMenu_SetWidth(sourceDropdown, 236)
    UIDropDownMenu_JustifyText(sourceDropdown, "LEFT")
    UIDropDownMenu_Initialize(sourceDropdown, function(dropdown, level)
        for _, item in ipairs(ADDON:GetAvailableSourceList()) do
            local info = UIDropDownMenu_CreateInfo()
            local isSelected = (ADDON:GetCurrentSourceKey() == item.key)
            info.text = isSelected and ("|cffffd100" .. item.label .. "|r") or item.label
            info.func = function()
                ADDON.selectedSourceKey = item.key
                ADDON.selectedIndex = nil
                ADDON.scrollOffset = 0
                UIDropDownMenu_SetText(sourceDropdown, item.label)
                ADDON:RefreshUI()
            end
            info.notCheckable = true
            info.keepShownOnClick = false
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self.sourceDropdown = sourceDropdown
    self.sourceDropdownText = _G[sourceDropdown:GetName() .. "Text"]
    self.sourceDropdownLeft = _G[sourceDropdown:GetName() .. "Left"]
    self.sourceDropdownMiddle = _G[sourceDropdown:GetName() .. "Middle"]
    self.sourceDropdownRight = _G[sourceDropdown:GetName() .. "Right"]
    self.sourceDropdownButton = _G[sourceDropdown:GetName() .. "Button"]
    sourceDropdown.Left = self.sourceDropdownLeft
    sourceDropdown.Middle = self.sourceDropdownMiddle
    sourceDropdown.Right = self.sourceDropdownRight
    if self.sourceDropdownText then
        self.sourceDropdownText:ClearAllPoints()
        self.sourceDropdownText:SetPoint("LEFT", 16, 1)
        self.sourceDropdownText:SetPoint("RIGHT", -34, 1)
        self.sourceDropdownText:SetJustifyH("LEFT")
    end
    local sourceClickArea = CreateFrame("Button", nil, sourceDropdown)
    sourceClickArea:SetFrameLevel(sourceDropdown:GetFrameLevel() + 1)
    sourceClickArea:SetPoint("TOPLEFT", 10, -4)
    sourceClickArea:SetPoint("BOTTOMRIGHT", -26, 10)
    sourceClickArea:RegisterForClicks("LeftButtonUp")
    sourceClickArea:SetScript("OnClick", function()
        ToggleDropDownMenu(1, nil, sourceDropdown, sourceDropdown, 20, 0)
    end)
    self.sourceDropdownClickArea = sourceClickArea

    local globalTab = CreateFrame("Button", addonName .. "GlobalTab", frame, "PanelTabButtonTemplate")
    globalTab:SetID(1)
    globalTab:SetText(IS_FRENCH and "Macros générales" or "General macros")
    globalTab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 14, 2)
    globalTab:SetScript("OnClick", function(tabButton)
        PanelTemplates_SetTab(frame, tabButton:GetID())
        ADDON:SetScope("global")
    end)

    local characterTab = CreateFrame("Button", addonName .. "CharacterTab", frame, "PanelTabButtonTemplate")
    characterTab:SetID(2)
    characterTab:SetText(IS_FRENCH and "Macros personnage" or "Character macros")
    characterTab:SetPoint("LEFT", globalTab, "RIGHT", -14, 0)
    characterTab:SetScript("OnClick", function(tabButton)
        PanelTemplates_SetTab(frame, tabButton:GetID())
        ADDON:SetScope("character")
    end)

    PanelTemplates_SetNumTabs(frame, 2)
    PanelTemplates_SetTab(frame, self:GetScope() == "global" and 1 or 2)
    self.globalTab = globalTab
    self.characterTab = characterTab

    local editorLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    editorLabel:SetPoint("TOPLEFT", 310, -96)
    editorLabel:SetText(TEXT.editorTitle)

    self.scopeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.scopeLabel:SetPoint("TOPLEFT", 310, -120)
    self.scopeLabel:SetText(string.format(TEXT.scopeEditing, TEXT.scopeCharacter))

    local footerContainer = CreateFrame("Frame", nil, frame)
    footerContainer:SetSize(276, 68)
    footerContainer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 34)

    local listContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listContainer:SetPoint("TOPLEFT", 16, -138)
    listContainer:SetPoint("BOTTOMLEFT", footerContainer, "TOPLEFT", 0, 10)
    listContainer:SetPoint("BOTTOMRIGHT", footerContainer, "TOPRIGHT", 0, 10)
    listContainer:EnableMouseWheel(true)
    listContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    listContainer:SetBackdropColor(0.04, 0.04, 0.05, 0.95)
    listContainer:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
    listContainer:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            ADDON:ScrollList(-1)
        elseif delta < 0 then
            ADDON:ScrollList(1)
        end
    end)

    self.rows = {}
    for index = 1, ROWS_PER_PAGE do
        self.rows[index] = self:CreateRow(listContainer, index)
    end

    local hint = footerContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", footerContainer, "BOTTOMLEFT", 0, 0)
    hint:SetWidth(236)
    hint:SetJustifyH("LEFT")
    hint:SetJustifyV("TOP")
    hint:SetText(TEXT.hint)
    self.hintLabel = hint

    self.pageLabel = footerContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.pageLabel:SetPoint("TOPLEFT", footerContainer, "TOPLEFT", 0, 0)
    self.pageLabel:SetText(TEXT.noMacro)

    self.selectedLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.selectedLabel:SetPoint("TOPLEFT", 310, -146)
    self.selectedLabel:SetText(TEXT.newMacro)

    local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 310, -174)
    nameLabel:SetText(TEXT.name)

    local nameContainer, nameEditBox = self:CreateEditBox(frame, 190, 30, false)
    nameContainer:SetPoint("TOPLEFT", 310, -196)
    self.nameEditBox = nameEditBox
    self.nameEditContainer = nameContainer
    self.nameEditBox:SetMaxLetters(16)

    local iconLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconLabel:SetPoint("TOPLEFT", 514, -174)
    iconLabel:SetText(TEXT.icon)

    local iconContainer, iconEditBox = self:CreateEditBox(frame, 170, 30, false)
    iconContainer:SetPoint("TOPLEFT", 514, -196)
    self.iconEditBox = iconEditBox
    self.iconEditContainer = iconContainer
    self.iconEditBox:SetText(MACRO_FALLBACK_ICON)
    self.iconEditBox:SetScript("OnTextChanged", function()
        ADDON:RefreshIconPreview()
    end)

    self.iconPreview = iconContainer:CreateTexture(nil, "ARTWORK")
    self.iconPreview:SetSize(18, 18)
    self.iconPreview:SetPoint("LEFT", 8, 0)
    self.iconPreview:SetTexture(MACRO_FALLBACK_ICON)

    self.iconEditBox:ClearAllPoints()
    self.iconEditBox:SetPoint("TOPLEFT", 32, -6)
    self.iconEditBox:SetPoint("BOTTOMRIGHT", -6, 6)
    self.iconEditBox:SetScript("OnMouseDown", function(box)
        box:SetFocus()
        ADDON:ToggleIconPicker()
    end)

    local bodyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bodyLabel:SetPoint("TOPLEFT", 310, -240)
    bodyLabel:SetText(TEXT.body)

    local bodyContainer, bodyEditBox = self:CreateEditBox(frame, 374, 210, true)
    bodyContainer:SetPoint("TOPLEFT", 310, -262)
    self.bodyEditBox = bodyEditBox
    self.bodyEditContainer = bodyContainer
    self.bodyScroll = bodyContainer.scrollFrame
    self.bodyEditBox:SetMaxLetters(255)

    self.syntaxLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.syntaxLabel:SetPoint("TOPLEFT", bodyContainer, "BOTTOMLEFT", 2, -10)
    self.syntaxLabel:SetPoint("RIGHT", -16, 0)
    self.syntaxLabel:SetJustifyH("LEFT")
    self.syntaxLabel:SetText(TEXT.syntaxHint)

    self.remoteHintLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.remoteHintLabel:SetPoint("TOPLEFT", self.syntaxLabel, "BOTTOMLEFT", 0, -6)
    self.remoteHintLabel:SetPoint("RIGHT", -16, 0)
    self.remoteHintLabel:SetJustifyH("LEFT")
    self.remoteHintLabel:SetText(TEXT.importOnly)
    self.remoteHintLabel:Hide()

    local iconPicker = CreateFrame("Frame", addonName .. "IconPicker", frame, "BackdropTemplate")
    iconPicker:SetSize(236, 196)
    iconPicker:SetPoint("TOPLEFT", iconContainer, "BOTTOMLEFT", 0, -8)
    iconPicker:SetFrameStrata("DIALOG")
    iconPicker:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    iconPicker:SetBackdropColor(0.04, 0.04, 0.05, 0.98)
    iconPicker:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
    iconPicker:Hide()
    self.iconPickerFrame = iconPicker

    self.iconPickerButtons = {}
    for index = 1, ICONS_PER_PAGE do
        local button = CreateFrame("Button", nil, iconPicker, "BackdropTemplate")
        local col = (index - 1) % 6
        local row = math.floor((index - 1) / 6)
        button:SetSize(32, 32)
        button:SetPoint("TOPLEFT", 12 + (col * 36), -12 - (row * 36))
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        button:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
        button:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(20, 20)
        button.icon:SetPoint("CENTER")

        button.Highlight = button:CreateTexture(nil, "OVERLAY")
        button.Highlight:SetAllPoints()
        button.Highlight:SetColorTexture(0.15, 0.35, 0.6, 0.35)
        button.Highlight:Hide()

        button:SetScript("OnClick", function(iconButton)
            if iconButton.iconValue then
                ADDON:SelectIcon(iconButton.iconValue)
            end
        end)

        self.iconPickerButtons[index] = button
    end

    self.iconPickerPrev = self:CreateButton(iconPicker, "<", 28, "BOTTOMLEFT", iconPicker, "BOTTOMLEFT", 12, 10, function()
        ADDON.iconPickerPage = math.max(1, (ADDON.iconPickerPage or 1) - 1)
        ADDON:RefreshIconPicker()
    end)
    self.iconPickerNext = self:CreateButton(iconPicker, ">", 28, "LEFT", self.iconPickerPrev, "RIGHT", 4, 0, function()
        ADDON.iconPickerPage = (ADDON.iconPickerPage or 1) + 1
        ADDON:RefreshIconPicker()
    end)
    self.iconPickerAuto = self:CreateButton(iconPicker, "?", 28, "LEFT", self.iconPickerNext, "RIGHT", 8, 0, function()
        ADDON:SelectIcon(MACRO_FALLBACK_ICON)
    end)
    self.iconPickerPageLabel = iconPicker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.iconPickerPageLabel:SetPoint("LEFT", self.iconPickerAuto, "RIGHT", 12, 0)
    self.iconPickerPageLabel:SetText("1 / 1")

    local newButton = self:CreateButton(frame, TEXT.buttonNew, 90, "TOPRIGHT", footerContainer, "TOPRIGHT", 0, -2, function()
        ADDON:ClearEditor()
    end)
    self.newButton = newButton

    local saveButton = self:CreateButton(frame, TEXT.buttonSave, 110, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -274, 40, function()
        ADDON:SaveEditorToGame()
    end)
    self.saveButton = saveButton

    local duplicateButton = self:CreateButton(frame, TEXT.buttonDuplicate, 110, "LEFT", saveButton, "RIGHT", 8, 0, function()
        ADDON:DuplicateSelectedMacro()
    end)
    self.duplicateButton = duplicateButton

    local deleteButton = self:CreateButton(frame, TEXT.buttonDelete, 110, "LEFT", duplicateButton, "RIGHT", 8, 0, function()
        ADDON:DeleteSelectedMacroFromGame()
    end)
    self.deleteButton = deleteButton

    local importButton = self:CreateButton(frame, TEXT.buttonImport, 110, "TOPLEFT", self.remoteHintLabel, "BOTTOMLEFT", 0, -10, function()
        ADDON:ImportSelectedRemoteMacro()
    end)
    self.importButton = importButton

    self:RefreshSyntaxState()
    self:ApplyElvUISkin()
end

function ADDON:ToggleUI()
    self:CreateUI()

    if self.frame:IsShown() then
        self.frame:Hide()
        return
    end

    self:RefreshUI()
    self.frame:Show()
end

function ADDON:QueueMacroRefresh()
    if not self.playerReady then
        return
    end

    self.macroRefreshGeneration = (self.macroRefreshGeneration or 0) + 1
    local generation = self.macroRefreshGeneration
    C_Timer.After(0.15, function()
        if generation ~= ADDON.macroRefreshGeneration then
            return
        end

        local selectedEntry = not ADDON:IsViewingRemoteSource() and ADDON:GetSelectedEntry() or nil
        local selectedSlot = selectedEntry and selectedEntry.slot
        ADDON:SyncCurrentCharacterToAccount()

        if not ADDON:IsViewingRemoteSource() then
            ADDON.currentMacros = ADDON:EnumerateMacros(ADDON:GetScope())
            ADDON:SelectMacroBySlot(selectedSlot)
        end

        if ADDON.frame then
            ADDON:RefreshUI()
        end
    end)
end

function ADDON:HandleSlashCommand(message)
    local command = trim((message or ""):lower())

    if command == "global" or command == "general" or command == "generales" then
        self:SetScope("global")
        return
    end

    if command == "character" or command == "char" or command == "personnage" then
        self:SetScope("character")
        return
    end

    if command == "reset" then
        self:CreateUI()
        self:ResetWindowPosition()
        return
    end

    if command == "minimap" then
        self:EnsureDB()
        LafeeMacroManagerGlobalDB.minimap.hide = not LafeeMacroManagerGlobalDB.minimap.hide
        self:UpdateMinimapButtonPosition()
        self:Print(LafeeMacroManagerGlobalDB.minimap.hide and TEXT.minimapHidden or TEXT.minimapShown)
        return
    end

    if command == "help" or command == "?" then
        self:Print(TEXT.help)
        return
    end

    if command ~= "" then
        self:Print(TEXT.help)
        return
    end

    self:ToggleUI()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("UPDATE_MACROS")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        ADDON:EnsureDB()
        ADDON.scrollOffset = 0
        ADDON.selectedSourceKey = LafeeMacroManagerDB.characterKey
        return
    end

    if event == "UPDATE_MACROS" then
        ADDON:QueueMacroRefresh()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if ADDON.frame then
            ADDON:RefreshControlState()
        end
        return
    end

    if event == "PLAYER_LOGOUT" then
        if ADDON.playerReady then
            ADDON:SyncCurrentCharacterToAccount()
        end
        return
    end

    if event ~= "PLAYER_LOGIN" then
        return
    end

    ADDON:EnsureDB()
    ADDON:RefreshCharacterIdentity()
    ADDON.scrollOffset = 0
    ADDON.selectedSourceKey = LafeeMacroManagerDB.characterKey
    ADDON.playerReady = true
    ADDON:SyncCurrentCharacterToAccount()
    ADDON:GetCurrentMacros()
    ADDON:CreateMinimapButton()
    ADDON:RegisterSpellbookCallback()

    SLASH_LAFEEMACROMANAGER1 = "/lmm"
    SLASH_LAFEEMACROMANAGER2 = "/lafeemacro"
    SlashCmdList.LAFEEMACROMANAGER = function(message)
        ADDON:HandleSlashCommand(message)
    end
end)
