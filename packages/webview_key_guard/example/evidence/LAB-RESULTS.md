# WebView Key Lab: 2026-09-25

Updated: 2026-09-26.

## Scope

macOS, Flutter 3.47.5, Dart 3.13.4, webview_flutter 4.14.1,
webview_flutter_wkwebview 3.26.1. Input was sent through Computer Use to the
separate `com.dmilab.webviewkeylab` app. No app code was changed.
Most results below use automated input. B2 failed the physical control;
B3 passed both physical controls with the new command boundary active,
including the observation-disabled control and held Enter. Broad physical
coverage and native cancellation/sibling-control behavior remain open.

## Results

| Mode | Observed result | Evidence |
| --- | --- | --- |
| 0 | One Cmd+Enter produced 128 page keydowns; 127 duplicates. Emergency abort. | `lab-0-failure.json` |
| A | Cmd+Enter was single; Cmd+B produced 128 keydowns and 127 duplicates. Abort. | `lab-A-failure.json` |
| B | Final full matrix: 844 attempts, 858 page keydowns, 15 duplicates on Shift+Escape. No emergency abort. | `lab-B-matrix.json` |
| B1 | 844 attempts: 843 delivered at first; Ctrl+NumpadEnter delivered once on retry, zero DOM duplicates. Later Cmd+B triggered 256 native re-entries and abort; short replay did not reproduce it. | `b1-full-844-first-pass.json`, `b1-full-844-after-retry.json`, `b1-focus-return-cmdb-loop.json` |
| B2 | 844 attempts, 844 page keydowns, zero duplicates or aborts. Select All, Undo/Redo, and 20 Flutter-to-WebView Cmd+B transitions worked. | `b2-full-844.json`, `b2-editing-focus-initial.json`, `b2-focus-20-cycles.json` |
| B2 physical | Cmd+Enter, Cmd+B, Alt+Escape: one each. One Shift+Escape: 255 page keydowns, 254 duplicates, emergency abort. WebKit saw the same event 256 times; Flutter saw it once; guard suppressed zero. | `b2-physical-cmd-enter-2026-09-25.json`, `b2-physical-shift-escape-loop-2026-09-25.json` |
| B3 | 844 attempts, 844 page keydowns, zero duplicates or aborts. Copy/Cut/Paste, Select All, Undo/Redo, and 20 Flutter-to-WebView Cmd+B focus cycles passed. Command boundary skipped zero equivalents; this automatic run alone does not prove physical-loop correction. | `b3-full-844-2026-09-25.json`, `b3-editing-copy-cut-paste-2026-09-25.json`, `b3-focus-20-cycles-2026-09-25.json` |
| B3 physical | Three Shift+Escape, one Cmd+B, one Cmd+Enter: exactly five DOM events, zero duplicates. Command boundary fired three times inside cancelOperation, one per Shift+Escape. No emergency abort; Flutter max visits 1. | `b3-physical-shift-escape-2026-09-25.json` |
| B3 physical, no method exchanges | Six Shift+Escape, two Cmd+B, two Cmd+Enter, one each Escape/Alt+Escape/Alt+Shift+Escape. Held Enter: one initial event plus 17 normal repeats. Total 31 DOM events, zero duplicates; stopped on release. Boundary fired on six Shift+Escape and one Escape. | `b3-uninstrumented-physical-escape-hold-2026-09-26.json` |
| C | Full matrix plus 10 smoke inputs: 857 keydowns, 3 duplicates. | `lab-C-matrix.json` |
| C2 | 844 attempts, 844 page keydowns, zero duplicates; Cmd+A did not select and Cmd+Z did not undo in the HTML input. | `c2-full-844.json`, `c2-editing-failure.json` |
| D | Full matrix: 844 attempts, 844 page keydowns, zero duplicates. | `lab-D-matrix.json` |
| D physical | One Shift+Escape produced 2 page keydowns, 1 duplicate after 33 ms, no Flutter entries. The cancellation stack contains only native responders. WebKit observation still enabled. | `d-trace-physical-shift-escape-2026-09-25.json` |
| D physical, no method exchanges | One Shift+Escape produced 67 page keydowns, 66 duplicates. First duplicate after 14 ms, last after 45 ms. WebKit observation disabled; no Flutter keyDown entries. | `d-uninstrumented-physical-shift-escape-2026-09-25.json` |
| E | Command shortcuts were canceled, including Select All/Paste. Alt+Escape then produced 256 keydowns and 255 duplicates. Abort. | `lab-E-failure.json` |

C's duplicate chords were Alt+Escape, Shift+Escape, and Alt+Shift+Escape.
B's first exploratory run, with only keyDown rerouting, had zero duplicates.
The final B implementation also reroutes keyUp/flagsChanged and showed the
Shift+Escape failure. This is not enough to determine whether the difference
is caused by that change or intermittent native responder behavior. Do not
describe B as a verified universal fix or silently discard the failing run.

The final B matrix initially did not observe Ctrl+Shift+B. An individual
retry after refocusing did deliver it once. See `lab-B-editing-focus.json`.
The full matrix was not completed for 0, A, or E after their known failures;
all untested cases remain untested, not passing.

D was the earlier automated candidate, but the current task requires an
embedded WebView. D also failed the physical one-press/one-event criterion,
including a fresh process without WebKit method exchanges. B2 is no longer
a viable candidate as-is: the physical
Shift+Escape loop stayed in WebKit and never retriggered its Flutter guard.
The separate B1 loop did show repeated Flutter entry by the same NSEvent;
B2's unit test rejects that route, but no live B2 run exercised the guard.
Neither an engine patch nor app integration is included.

## Coverage And Limits

- Matrix: 74 keys x all 16 combinations of Cmd/Ctrl/Alt/Shift = 1,184 cases.
- Automatic subset: 844 attempts in each full B/B1/B2/B3/C/C2/D run, refocusing Prompt
  before each input. This includes letters, digits, Enter/keypad Enter,
  navigation, deletion, punctuation, and modifier combinations.
- 340 system/function/window cases are deliberately reserved for supervised
  testing; automatic runs must not quit apps, change display settings, or
  trigger system actions without accounting for those effects.
- Eight non-Shift `equal` cases were emitted by Computer Use as Shift+Equal.
  Thus a clean 844-attempt run confirms 836 distinct expected chords, not 844.
  Physical `=` still needs all eight non-Shift modifier sets.
- No synthetic `isARepeat` input was used in live tests. Physical held Enter
  passed in B3 without WebKit method exchanges: first repeat after 501 ms,
  then roughly 83-84 ms intervals, keyUp after 1.913 seconds, no later keydowns.
  Other held keys, modifier release order, layouts, and IME remain open.
- JS duplicates use timestamp/code/modifiers/repeat as a diagnostic signature.
  Native object identity is recorded separately. Native key-equivalent
  re-entry alone is not a failure; AppKit can legitimately visit that path
  several times while the page receives only one event.
- Elapsed time is wall-clock run duration including pauses, not a benchmark.

Verified editing: Select All, Paste, Undo and Redo in B and D; Undo was checked
against the actual restored text, not just key counters. Typing after moving
focus WebView -> Flutter input -> WebView also worked in B. E blocked Paste.
Select All and Undo/Redo were also checked against actual input values in B1
and B2. C2 delivered the keydowns but failed Select All and Undo.
B3 Copy/Cut/Paste was also checked against actual text. Rich-text formatting
did not visibly change for Cmd+B/I/U in either B3 or plain D; it is not a pass.
Cmd+W did not close D; the lab's menu has no Close shortcut,
so this is not counted as a keyboard correction success or regression.

## Deterministic Checks

- `flutter analyze`: clean.
- `flutter test`: 5 tests passed (matrix coverage, reserved commands, variants,
  stale-report rejection, aborted-run status).
- Native XCTest: 12 tests passed, including all 128 native key codes x 16
  modifier sets x 10 strategies, bounded trace capture, and B3 command-scope
  lifetime/identity tests. These test policy decisions, not the physical OS route.
- Native identity tests preserve new rapid presses and new repeat events;
  emergency tests refuse to start another mode after a loop.
- Debug macOS app built successfully with the explicit external SDK.
- Result persistence was verified by closing and reopening the app after
  aborted runs: the 0 and A results were retained.

The first XCTest launch and later external-drive file operations temporarily stalled in
`open`/dyld. No permission or security protection was disabled. A subsequent
XCTest run completed successfully. This was not counted as a key-loop result.
The final hosted reruns stalled again before executing tests and were stopped;
the four passing native tests refer to the preceding completed run. Final
window-reopening/default-mode changes were verified in the normally launched
app, not certified by a second successful hosted XCTest run.

Final-build smoke evidence: `lab-D-final-smoke.json` has 60 inputs and zero
duplicates; `lab-C-final-smoke.json` reproduces the same three Escape duplicate
cases; `lab-E-final-smoke.json` reproduces the Alt+Escape abort. Reopening D
kept the same run ID and 60-event counter. All six result rows survived restart.

## Current Git Package P Verification (2026-09-26)

These runs use the Git-pinned `webview_key_guard` commit
`b557b9f918734ff0ccd9b409d36f39fa8cdf0a94`, not the lab's B3 code.
The package was enabled in every run. The saved JSON files include the run ID,
native PID, implementation, WebKit-observation flag, and page counters.

| Run | Result | Evidence |
| --- | --- | --- |
| Physical keyboard | Three Shift+Escape, one each Cmd+B, Cmd+Enter, Alt+Escape, Alt+Enter, Cmd+Alt+Enter, Alt+Shift+Escape and plain B; held Enter yielded one initial event plus 21 legitimate repeats. 32 page keydowns, zero duplicates, no abort. WebKit observation was on. | `lab-P-physical-2026-09-26.json` |
| Safe automatic matrix | 74 keys x 16 modifier sets; 340 cases reserved for supervised testing. Of 844 safe cases, one Cmd+Shift+Backslash did not arrive on the first attempt but arrived on retry: 845 input attempts, 844 page keydowns, zero duplicates or aborts. Eight non-Shift `equal` cases were emitted as Shift+Equal by Computer Use, leaving 836 distinct expected chords observed. | `lab-P-full-matrix-2026-09-26.json` |
| Editing and focus | Prompt Select All, typing, Undo/Redo; Input Select All, Copy/Cut/Paste; Rich text Select All, typing, Undo/Redo, Cmd+B, Tab/Shift+Tab, Escape and Cmd+Enter. Expected text restored after Undo/Paste; 17 page keydowns, zero duplicates or aborts. This does not prove visible rich-text formatting for Cmd+B. | `lab-P-edit-focus-2026-09-26.json` |
| No WebKit method exchanges | Fresh process with `KEY_LAB_WEBKIT_OBSERVATION=off`; three cycles of Cmd+B, Cmd+Enter and four Escape variants, then editing in all three fields and focus movement. 30 page keydowns, zero duplicates or aborts; native state confirms observation off and package on. Input was automated, not physical. | `lab-P-no-observation-2026-09-26.json` |
| Physical keyboard, no WebKit method exchanges | User pressed Shift+Escape, Cmd+B and Cmd+Enter once each. Each arrived once; six page keydowns include three normal modifier-key events (Shift once, Cmd twice). Zero duplicates, repeats, prevented events or aborts. Flutter received three keydowns with maximum visits 1 and zero duplicate objects. | `lab-P-no-observation-physical-2026-09-26.json` |

The last physical control used run `1790419235351953`, PID 94262, with
`packageEnabled=true` and `webKitObservationEnabled=false`. Counters remained
unchanged on a second read and when the evidence was saved. This process
contains the NativeKeyTrace correction; the later defensive EventLedger
change was compiled separately and is not covered by this live run.

During the first editing attempt, the lab process aborted in
`NativeKeyTrace.record` at `NSEvent.isARepeat`; the stack includes AppKit's
spell-correction panel. The tracer accepted `flagsChanged` but read
`isARepeat` without checking the event type. It now reads repeat only for
`keyDown`; the same rule now protects `EventLedger`, and a regression XCTest
for `flagsChanged` was added. The crash report
does not identify the event type conclusively, so the precise trigger remains
an inference. The rebuilt app completed the editing and no-observation runs
without a crash. This was a lab diagnostic fault, not evidence of a package
key-routing failure.

Seven lab Dart tests, nine package native Core tests, three package Dart tests,
and eight app Settings widget tests passed. The lab Debug app and test
target built successfully. Hosted `RunnerTests` did not run:
both the full and targeted Xcode launches stalled before test execution and
were interrupted. Do not count the newly added native regression as passed.
The automatic matrix excludes 340 potentially system-affecting cases.
Physical input without WebKit observation is now verified for the three
previously problematic shortcuts above; it is not a full physical matrix.

### Further Testing Decision

The evidence supports keeping the current package enabled for normal use.
Another full automatic matrix is not needed unless the package or its
Flutter/WebView dependencies change, or a new failure appears. The next useful
short check is physical input inside the app's actual browser, including a
focus change back to a Flutter field: the live check in the app so far covered
the Settings switch and persistence, while keyboard delivery was tested here.
Eight non-Shift equal chords, other keyboard layouts/IME, modifier release
order, and native cancellation behavior remain targeted follow-up coverage.
Run reserved system shortcuts only when relevant to a concrete user workflow.
The hosted XCTest launch problem still needs repair so the new diagnostic
regression can execute; its compilation alone is not a passing test.

## Relocation Check (2026-10-08)

The app now lives in `webview_key_guard/example/` and uses `path: ..`.
Machine-specific paths in historical documents and evidence were anonymized;
their counters and qualification limits were preserved. Old lab Git history
was not imported. The capture script also removes machine-specific bundle
paths from newly saved reports.

On Flutter 3.47.5, package and example analysis passed, as did 3 package Dart
tests, 7 example Dart tests, 9 standalone package AppKit tests, and 4 example
Node tests. The relocated macOS Debug app built and launched in P mode with
the parent package enabled. Automated native-app input sent Cmd+Enter,
Shift+Escape, and Cmd+B into Prompt: three page keydowns, zero duplicates,
repeats or emergency aborts. See
`relocation-package-smoke-2026-10-08.json`.

This short check is not a new physical-keyboard qualification or full-matrix
run. Hosted RunnerTests were not rerun; their earlier launch limitation remains.

## Physical Keyboard Checklist

The historical B2 physical run `1790358984228405` aborted and was restarted.
The last historical B3 run `1790365705443304`, PID 63526, observation disabled,
was clean; its physical results above are already captured. The newer P
physical run is recorded in the section above. Do not repeat
covered inputs merely because the comprehensive checklist below lists them.
After any future abort, restart the whole process before switching modes.
The main window contains
the mode radios; D opens a second window titled `WebView Key Lab - D Native`. Closing that
second window returns to the controls. Refresh in the main window starts a
fresh run; the D button reopens the same native page without resetting it.

1. Click **Prompt**, the large white text field inside the web page, not
   `Flutter input` in the left sidebar.
2. Press and completely release, with about two seconds between inputs:
   Cmd+Enter, Cmd+B, Alt+Enter, Shift+Enter, Cmd+Alt+Enter, Cmd+Alt+A,
   Cmd+Shift+Enter, Ctrl+Enter, Cmd+Ctrl+Enter, and Cmd+Ctrl+Alt+Shift+B.
3. Test Escape, Alt+Escape, Shift+Escape and Alt+Shift+Escape individually.
   Check whether the counter keeps increasing after releasing the key.
4. Hold an ordinary letter for two seconds and release. Repeat with Enter,
   Cmd+B and Backspace. Legitimate repeat events should stop on release.
5. In Input, verify select-all, copy, cut, paste, undo and redo. In Rich text,
   select text and check Cmd+B/Cmd+I/Cmd+U visually. Repeat after switching
   focus to Flutter input and back, including releasing modifiers after
   the focus change.
6. Use the matrix dialog to cover the remaining modifier sets and keys.
   `Получено` means observed, not fully validated. The eight `=` cases and
   340 reserved cases are not certified by the automatic run. Test system
   commands separately, accounting for window/app activation and OS effects.
7. For 0/A/E and possibly B1, expect the known failures. After an emergency abort, close the
   entire lab and reopen it; do not compare another mode in the same process.

After the physical run, record the mode and the last chord pressed. The
current `/state` and the capture script preserve the evidence. No model
requests can be sent from the diagnostic page.
