# macOS Edit Actions

Makes the standard macOS edit commands — Paste, Copy, Cut, Select All — work in Flutter
text fields on macOS: from the **Edit menu**, and from tools that **inject a Cmd+V**
(dictation apps, text expanders, clipboard managers).

## The problem

In a Flutter macOS app the Edit menu has Paste, Copy, Cut and Select All, but clicking them
does nothing in a text field, and a Cmd+V sent by another program is lost. Real keyboard
shortcuts work, so it looks random.

## The cause

Two separate engine gaps (details and evidence: [docs/root-cause.md](docs/root-cause.md)):

1. The engine's text input view does not implement `paste:`, `copy:`, `cut:`, `selectAll:`.
   The menu sends them to the first responder, which falls back to a hidden `NSTextView`
   storage that Flutter never reads.
2. A Cmd+V posted by another program lacks the device-dependent Command bit that the engine
   uses to track modifiers, so Flutter sees a plain "V" and types nothing.

## The fix

At plugin registration the engine class `FlutterTextInputPlugin` (and only it) gets
`paste:`, `copy:`, `cut:`, `selectAll:` acting on the Flutter editing model, and its menu
validation enables or disables the items by that model (Copy and Cut need a selection,
Paste needs text on the pasteboard). The Edit menu and the Cmd+V of other programs then use
the same path, and a real keyboard Cmd+V still pastes exactly once.

If the engine already defines a command itself (a future Flutter), it is left alone.
If the class is renamed, nothing is patched and nothing breaks; `status()` reports it as `missing`.
Undo and Redo are not covered.

## Use

Add the dependency; there is nothing to call.

```yaml
dependencies:
  macos_edit_actions:
    git:
      url: https://github.com/DimitriSky/flutter_macos_patches.git
      path: packages/macos_edit_actions
      ref: <commit>
```

The app needs a standard Edit menu (the default Flutter macOS template has one).

Diagnostics and an A/B switch:

```dart
await const MacosEditActions().status();          // enabled, patched, skipped, missing, handled
await const MacosEditActions().setEnabled(false); // show the bug again
```

## Checks

- `swift test` — native unit tests of the commands (AppKit, no Flutter).
- `flutter test` — Dart API.
- `tool/e2e/run.sh` — real engine, no human: builds `example/`, then injects Cmd+V like a
  dictation tool and presses Edit menu items through Accessibility. FAIL with the plugin off,
  PASS with it on, including enabled/disabled item states and no double paste on a
  keyboard-like Cmd+V. Needs Accessibility permission for the terminal and takes the focus
  for about a minute.

Remove this package once Flutter fixes
[flutter/flutter#184571](https://github.com/flutter/flutter/issues/184571)
(see also PR [#190539](https://github.com/flutter/flutter/pull/190539)).
