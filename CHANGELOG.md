# Changelog

## 0.5.5 - 2026-08-04
- Added live blue highlighting for spell names recognized by the Retail spell API.
- Supports spell operands in `#showtooltip`, `/cast`, `/castsequence`, `/castrandom`, `/use` and related spell commands.
- Removed the body editor mouse-down focus hook that prevented native drag selection and `Ctrl+C` / `Ctrl+X` from working reliably.
- Kept the live syntax preview, explicit caret and spellbook Shift-click insertion.

## 0.5.4 - 2026-08-04
- Added an explicit solid caret driven by the native EditBox cursor position.
- Explicitly focuses the body EditBox on left mouse down.
- Restored live syntax colors through a non-interactive preview owned by the native EditBox.
- Kept native mouse selection highlighting and spell insertion on the single raw EditBox.

## 0.5.3 - 2026-08-04
- Fixed the editor-window crash caused by treating the `TitleBg` texture as a draggable frame.
- Added a dedicated invisible title-bar drag frame.
- Replaced all overlapping spellbook hooks with one `EventRegistry` callback for `SpellBookItemMixin.OnModifiedClick`.
- Removed recursive spellbook scans, tooltip fallbacks, timing-based duplicate suppression and obsolete spellbook APIs.
- Removed the unused syntax-coloring implementation and updated the interface wording to command validation.

## 0.5.2 - 2026-08-04
- Replaced the overlaid syntax-preview editor with one native multiline `EditBox` used directly as the scroll child.
- Restored the native visible caret and mouse drag selection.
- Kept command validation below the editor without drawing a second text layer over editable text.
- Kept the macro body selectable in combat and when viewing a read-only character source.
- Restricted window dragging to the title bar so it cannot intercept text selection.

## 0.5.1 - 2026-08-04
- Restored native mouse selection, caret rendering and selection replacement in the macro body editor.
- Fixed Retail spellbook insertion by resolving spell data from the clickable icon's parent `SpellBookItem` frame.
- Added a direct hook for `SpellBookItemMixin:OnModifiedIconClick` on Retail 12.x.
- Spell names can be inserted with either Shift + left-click or Shift + right-click.

## 0.5.0 - 2026-08-04
- Updated Retail interface support for 12.0.5, 12.0.7 and 12.1.0.
- Added optional ElvUI metadata and a CurseForge-ready README.
- The editor window now remembers its position, stays on screen and closes with Escape.
- Added `/lmm reset`, `/lmm minimap`, `/lmm help` and the `/lafeemacro` alias.
- Added debounced synchronization after external macro changes and before logout.
- Editing controls now reflect combat lockdown and macro dragging is blocked in combat.
- Added safer error handling for macro creation, editing, deletion, duplication and import.
- Selection now follows the macro slot returned by Blizzard, including duplicate names.
- Fixed duplicate spellbook insertions caused by overlapping hooks.
- Improved icon picker pagination and expanded recognized macro commands.
- Removed stale automatic-icon cache entries when a macro is deleted.

## 0.4.0 - 2026-04-12
- Nouvelle tentative de coloration en direct avec une couche de rendu syntaxique dans le meme cadre `Contenu`, synchronisee avec une vraie zone editable.
- Sauvegarde prealable creee dans `Lafee_macro_manager.lua.bak-2026-04-12-livecolor` et `Lafee_macro_manager.toc.bak-2026-04-12-livecolor`.

## 0.3.11 - 2026-04-12
- Suppression d'un relayout inutile du champ `Contenu` a chaque frappe, qui pouvait envoyer le curseur visuellement sur la derniere ligne.

## 0.3.10 - 2026-04-12
- Correction de la conversion entre position du curseur colore et position brute, en se basant sur le prefixe reel du texte avant le curseur.

## 0.3.9 - 2026-04-12
- Correction d'un saut de position pendant l'edition coloree en preservant le scroll vertical lors du rafraichissement du champ `Contenu`.

## 0.3.8 - 2026-04-12
- Ajout d'une coloration bleue legere pour les noms de sorts reconnus apres `/cast`, `/use` et `/castsequence`.

## 0.3.7 - 2026-04-12
- Nettoyage du texte recupere depuis le tooltip du grimoire pour ne conserver que le nom du sort, sans balises d'icone.
- Desactivation des logs de debug du grimoire par defaut.

## 0.3.6 - 2026-04-12
- Ajout d'un fallback de resolution du nom de sort via le tooltip du bouton survole dans le grimoire.

## 0.3.5 - 2026-04-12
- Elargissement de la resolution du sort depuis les boutons du grimoire avec `GetID()`, `slotIndex`, `C_SpellBook.GetSpellBookItemInfo` et `GetSpellBookItemInfo`.

## 0.3.4 - 2026-04-12
- Ajout temporaire de logs de debug pour le hook du grimoire afin d'identifier quel chemin d'evenement est reellement appele sur le client.

## 0.3.3 - 2026-04-12
- Renforcement de l'insertion depuis le grimoire en hookant aussi les vrais boutons descendants de `PlayerSpellsFrame` et `SpellBookFrame`.

## 0.3.2 - 2026-04-12
- Correction d'un bug qui reinjectait le texte colore comme texte brut a la perte de focus, ce qui ajoutait des `|` visibles.
- L'insertion depuis le grimoire dans le corps de macro passe maintenant par le texte brut interne plutot que par le texte colore affiche.

## 0.3.1 - 2026-04-12
- Tentative de coloration syntaxique en temps reel dans le meme champ `Contenu`.
- Le texte brut est conserve separement pour eviter de sauvegarder les codes couleur dans la macro.

## 0.3.0 - 2026-04-12
- Retour de la coloration syntaxique dans le meme champ `Contenu`, sans ajouter de cadre ni de couche de texte supplementaire.
- Le texte est affiche colore hors focus, puis repasse en brut quand le champ reprend le focus pour rester editable.

## 0.2.9 - 2026-04-12
- La zone `Contenu` suit maintenant le modele BugSack: `UIPanelScrollFrameTemplate` + `EditBox` enfant simple.
- Suppression des reglages additionnels qui s'ecartaient du comportement natif Blizzard sur cette zone.

## 0.2.8 - 2026-04-12
- Remplacement de la zone multi-ligne par un `EditBox` direct avec backdrop, sans `ScrollFrame` ni template d'input.
- Police, justification et position initiale du curseur definies explicitement pour se rapprocher d'un comportement natif stable.

## 0.2.7 - 2026-04-12
- Passage de la zone de corps de macro sur `InputScrollFrameTemplate` quand il est disponible, avec fallback sur l'ancienne construction si le template n'existe pas.
- Cette version vise a restaurer le comportement natif Blizzard du curseur, de la selection et de la saisie multi-ligne.

## 0.2.6 - 2026-04-12
- Suppression des handlers `OnMouseDown` qui cassaient le comportement natif du curseur et de la selection dans les zones de texte.
- Le grimoire accepte maintenant `Maj + clic` sans imposer strictement le clic droit, pour se rapprocher du comportement Blizzard.

## 0.2.5 - 2026-04-12
- Retour a une seule vraie zone de texte native pour le corps des macros, sans preview superposee ni cadre separe.
- Suppression des couches de texte additionnelles qui perturbaient la police, le curseur et la selection.
- Conservation des correctifs de gestion d'icone automatique et du hook de grimoire.

## 0.2.4 - 2026-04-12
- Remplacement de la coloration superposee par un panneau d'apercu syntaxique separe, pour conserver une vraie zone d'edition native.
- Correction de la police, de la selection et du comportement du curseur dans le corps de macro.
- Renforcement du hook du grimoire en captant aussi les clics standards des boutons de sorts pour l'insertion via `Maj + clic droit`.

## 0.2.3 - 2026-04-12
- Correction du chevauchement entre la previsualisation coloree et le vrai texte editable dans la zone de macro.
- La previsualisation est maintenant cachee pendant l'edition et reaffichee uniquement hors focus.
- Le curseur et le texte editable ne sont plus affiches en double.

## 0.2.2 - 2026-04-12
- Retour de la coloration syntaxique dans la zone de corps de macro quand le champ n'est pas en cours d'edition.
- Ajout d'un curseur visible pendant l'edition du texte.
- Correction de l'affichage pour que le texte normal reste visible pendant l'edition et la selection.

## 0.2.1 - 2026-04-12
- Correction de la gestion de l'icone automatique `?` pour qu'un alias comme `INV_question_mark` soit normalise vers l'icone de point d'interrogation.
- Conservation du mode d'icone automatique pour les macros enregistrees via l'addon, afin d'eviter qu'une re-sauvegarde fige l'icone sur un sort.
- Preservation de l'icone dynamique lors de la duplication et de l'import de macros.

## 0.2.0 - 2026-04-12
- Sauvegarde locale des fichiers avant modification.
- Incrementation de la version de l'addon de `0.1.0` vers `0.2.0`.
- Remplacement de la zone de corps de macro par une vraie zone de texte multi-ligne, avec selection et copie possibles.
- Conservation du controle de syntaxe des commandes de macro sous la zone d'edition.
- Ajout de l'insertion du nom d'un sort via `Maj + clic droit` dans le grimoire quand l'editeur est ouvert.
