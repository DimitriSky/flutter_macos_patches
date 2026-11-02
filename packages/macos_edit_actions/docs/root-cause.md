# Edit menu and injected Cmd+V in Flutter macOS: root cause

Found 2026-11-02 in TalkTo (Flutter 3.44–3.47, macOS) while checking dictation with
VoiceCommand, which pastes by injecting Cmd+V.

## Symptom

- Edit > Paste / Copy / Cut / Select All do nothing in a Flutter text field.
- A Cmd+V posted by another program (`CGEvent` through `cghidEventTap`) pastes nothing;
  the same Cmd+V on a real keyboard works.
- The same injection pastes fine into a native `NSTextView`, so the injector is not at fault.

## Evidence

1. Engine, `FlutterTextInputPlugin` (subclass of `NSTextView`): 52 own methods, among them
   `insertText:replacementRange:`, `doCommandBySelector:`, `editingState`. It does not define
   `paste:`, `copy:`, `cut:`, `selectAll:`. The inherited `NSTextView` versions act on the
   hidden storage, which Flutter never reads back.
2. Framework, `default_text_editing_shortcuts.dart`: `intentForMacOSSelector` has no
   paste, copy, cut or select-all entries, so forwarding the selector would not help either.
3. Modifiers: the engine tracks Command through device-dependent bits
   (`kModifierFlagMetaLeft = 0x8`, right `0x10`, from `KeyCodeMap_Internal.h`), not through
   the generic `NSEventModifierFlagCommand` (`0x100000`). Synthetic events carry only the
   generic bit, so Flutter sees "V" with `meta == false`.
4. Experiment on the example app with the same injector: flags `[.maskCommand]` — Cmd+A and
   Cmd+V ignored; flags `[.maskCommand, 0x8]` — Cmd+A selects all, Cmd+V pastes once.
5. Edit menu: the item sends the `paste:` action to the first responder and goes through gap 1.
6. Upstream: [flutter/flutter#184571](https://github.com/flutter/flutter/issues/184571)
   (open, P2); draft [PR #190539](https://github.com/flutter/flutter/pull/190539) makes
   `paste:`, `copy:`, `cut:`, `selectAll:` act on the editing model. FluidVoice reports the
   same with dictation (#1191).

## Why this fix

Handling the commands on `FlutterTextInputPlugin` fixes both the menu and injected Cmd+V
without touching how Flutter handles keys. Checked on the real engine that a keyboard-like
Cmd+V (with the device bit) still pastes exactly once, so the two paths do not add up.

- paste → `insertText(pasteboardString, replacementRange: {NSNotFound, 0})`, which the engine
  already turns into a text-editing update.
- copy / cut → selection read from `editingState` (`text`, `selectionBase`, `selectionExtent`);
  cut also inserts an empty string over the selection.
- selectAll → `moveToBeginningOfDocument:` then `moveToEndOfDocumentAndModifySelection:`
  through `doCommand(by:)`, which the framework maps to editing intents.
- `validateUserInterfaceItem:` / `validateMenuItem:` mirror the model state.

## Verification

`tool/e2e/run.sh` (real engine): plugin off — injected Cmd+V and Edit > Paste leave the
field empty; plugin on — injected Cmd+V pastes once, Select All selects 0..11, Copy fills
the pasteboard, Cut empties the field, items are enabled only when applicable, a
keyboard-like Cmd+V replaces the selection once, Cmd+A with the device bit selects all.

## Not covered

Undo and Redo (Flutter keeps its own history; the engine exposes no command for it).
