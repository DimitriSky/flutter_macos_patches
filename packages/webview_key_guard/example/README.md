# WebView Key Lab

An isolated macOS comparison app for repeated WebView keyboard events. Running
the lab does not modify the host app or the default Flutter SDK. It lives under
`webview_key_guard/example/`; mode P consumes the package source in this checkout.
The app is named
`WebView Key Lab`, bundle ID `com.dmilab.webviewkeylab`.

## Current Lab

| Mode | Implementation | Boundary |
| --- | --- | --- |
| P | Current `webview_key_guard` package, default | Uses the package controller and command boundary; laboratory guards are off |
| 0 | Stock embedded WebView, observation only | No keyboard correction |
| A | Consume only Cmd+Enter key equivalents | Narrow workaround control |
| B | Route focused WebView keyboard events outside Flutter's async queue | Embedded native responder experiment |
| B1 | Route only `keyDown` outside Flutter's async queue | Isolates the effect of routing `keyUp` and `flagsChanged` |
| B2 | B1 routing plus same-object guard at focused Flutter `keyDown` | Keeps WebKit editing commands while bounding Flutter re-entry |
| B3 | B2 plus a synchronous native-command boundary | Does not reinterpret the current event in its source host while AppKit executes a command |
| C | Reject the same native event object on re-entry | Identity guard, not a time debounce |
| C2 | Apply object-identity guards at WKWebView equivalent, WKWebView `keyDown`, and focused Flutter `keyDown` | Tests the boundaries missed by C |
| D | WKWebView in a separate native window | No Flutter responder in the WebView hierarchy |
| E | JavaScript `preventDefault` for Command/Control | Page-level cancellation experiment |

## Shared Package: P

The source of truth is the parent
[webview_key_guard package](../README.md). This example uses a local dependency:

```yaml
webview_key_guard:
  path: ..
```

Change protection logic in the parent package, not in the lab's historical B3
files. Production consumers use the Git URL pinned to an immutable commit.

Use Flutter 3.47.5 on your PATH to retain this lab's existing toolchain.
From the package repository root:

```bash
cd example
flutter pub get
flutter run -d macos
```

See the [package README](https://github.com/DimitriSky/flutter_webview_key_guard/blob/main/README.md)
for its tests, Settings toggle, and removal instructions. The host app
application and backend need not run for the lab to resolve the package.

After changing native Swift, rebuild/relaunch the lab. A previously built
consumer app does not change just because the source repository changed.
To update a production consumer, publish the package commit, pin its new SHA,
run `flutter pub get`, and commit the consumer's lockfile. Keep `path: ..` in
this example so its tests exercise the source in the same checkout.

All commands below run from `example/`. Existing evidence is historical;
it does not certify a newly built checkout. Machine-specific paths in the
documents and evidence have been anonymized. Old lab commit IDs are historical
references; that repository's Git history is not imported into this package.

P enables the package and leaves all lab strategy flags off. Selecting any
historical mode disables the package; B3 and P never apply two command guards
together. The native snapshot exposes `implementation` and `packageEnabled`.
Flutter/WebKit entry counters and the emergency abort still belong to the
harness; `suppressed` counts lab interventions, not private package guards.
The 256-visit emergency abort remains a failed run, never a passing fix.

The package controller permits a diagnostic subclass which records entries
before calling `super.keyDown`. The actual routing and command boundary remain
in the package. The historical B3 whole-host boundary is unchanged; it is not
the package's narrower source-WebView boundary. Existing B3 evidence does not
prove P passed; P uses its own run IDs and results.

## Isolated package regression

Using this example's existing Flutter 3.47.5 SDK, from `example/`:

```sh
flutter pub get
KEY_LAB_WEBKIT_OBSERVATION=off KEY_LAB_TRACE_STACKS=off \
  flutter test --no-pub integration_test/package_isolation_test.dart -d macos
python3 scripts/qualify_package.py
flutter build macos --debug --no-pub
```

The Python runner applies the same environment flags and saves count-only
evidence. If the SDK is not on PATH, set `KEY_GUARD_FLUTTER_BIN` to its `flutter`
executable. It keeps raw runner output in an OS temporary log, outside the repo.
The final build restores the normal lab entry point after the native test.

The fixture uses the actual package window/controller/plugin and an owned inline
HTML page. `reviewFocus`/`reviewKey` on the lab's method channel focus only its
own views and enqueue NSEvents only into its AppKit queue; there is no OS-wide
key injection. WebKit method exchanges and historical B3 protection are off.
It checks three WebKit editing targets, Shift+Escape/Cmd+B/Cmd+Enter, legitimate
repeat events and keyUp, Select All/Undo/Redo, On/Off, Flutter typing, and return
to WebView. It does not use the clipboard or consumer app/backend data.

The [2026-10-08 result](evidence/package-isolation-review-20261008.json) is a
fresh synthetic native test, not physical keyboard qualification. Existing
physical evidence remains historical. Full package review:
[review loops](../docs/review-loops-2026-10-08.md).

## Historical Laboratory Results

The earlier findings below describe the laboratory implementations, not a
completed full-matrix or physical-keyboard qualification of P.

B2 completed the 844-case safe automated matrix and preserved Select All,
Undo, and Redo, but failed the physical-keyboard test: one Shift+Escape
produced 254 DOM duplicates and an emergency abort. Its Flutter-entry guard
did not fire; the same native event looped in WebKit. B1 also had a native
re-entry abort after a long run, while C2 broke Select All and Undo. No
embedded-view fix had been selected at that stage. Those observations predate P.

The physical D control also produced a Shift+Escape duplicate: two DOM
events from one press, zero Flutter entries, and a native cancellation
stack with only WKWebView/NSWindow responders. A fresh D control with WebKit
method exchanges disabled also failed: 67 Shift+Escape DOM events, 66
duplicates. Neither the Flutter responder path nor the diagnostic method
exchanges are required for that reproduction. Flutter is still loaded
elsewhere in the lab process, so this is not yet a standalone AppKit executable.

B3 remains the historical experimental implementation. It uses public AppKit
overrides in a separate `WebCommandBoundary.swift` owner: `NSWindow.doCommand`
opens a per-window scope; a host view returns unhandled for a key-equivalent
traversal of the same event during that scope. There is no delay, key-code
allowlist, or JavaScript cancellation. The same event outside that command,
a different event, and an unrelated host continue normally. The host boundary
currently surrounds the Flutter content; nested native controls in that host
need regression coverage before considering production integration.

B3 completed the 844-attempt automatic matrix: 844 DOM keydowns, zero
duplicates, no abort. The eight non-Shift equals cases were still emitted
as Shift+Equal, so this covers 836 distinct expected chords. Select All,
Copy/Cut/Paste, Undo/Redo, and 20 Flutter-to-WebView Cmd+B focus cycles
also passed. The first physical B3 run delivered exactly three Shift+Escape,
one Cmd+B, and one Cmd+Enter, with zero duplicates. The command boundary
actually fired once per Shift+Escape (`skippedEquivalents: 3`). A fresh
physical control without WebKit method exchanges also passed: six Shift+Escape,
two Cmd+B, two Cmd+Enter, and one each Escape/Alt+Escape/Alt+Shift+Escape.
Holding Enter for 1.913 seconds produced one initial event plus 17 ordinary
repeats, stopping on keyUp. Total: 31 DOM events, zero duplicates; the command
boundary fired seven times. Native cancellation targets and the remaining
physical combinations still need coverage before production integration.
Four new native tests passed for scope lifetime, nested commands, fresh/repeat events,
and unrelated subtrees/windows (12 native tests at that stage). B2 remains
available as a control; the current default is P. Rich-text formatting did not visibly change under Cmd+B/I/U
in either B3 or plain native D; this is not counted as a formatting pass.

The sidebar switches methods at runtime. Refresh starts a **new** run and a
new WebView. Reopening the D window keeps the existing run. The toolbar can
hide the comparison controls. Results are retained between app launches.
The page records keyboard events only; it never calls models or the host app.
The native snapshot includes a bounded event-stage trace without typed text.

The follow-up trace also keeps event beginnings, monotonic callback-arrival
times, and sampled Escape call stacks. `KEY_LAB_TRACE_STACKS=off` disables
stack capture. Starting a fresh process with
`KEY_LAB_WEBKIT_OBSERVATION=off` skips the WKWebView method exchanges while
retaining B2's Flutter routing/guard. In that control, WebKit counters are
not measured and the WebKit emergency breaker is absent. A/C/C2 depend on
the method exchanges; use this control only for P, B1/B2/B3 or D. These switches
are diagnostic controls, not a new fix. B3 also works independently of the
WKWebView observation exchanges. The physical failure was recaptured:
188 DOM duplicates, with sampled stacks showing WebKit command execution
through NSWindow's cancellation handler back into `performKeyEquivalent`,
before Flutter `keyDown`. See Part 2 for evidence and remaining controls.

The common emergency breaker aborts a run after 256 native visits by one
event. An aborted run is a failure, not a passing fix, and requires a clean
process restart before switching methods. Baseline 0 is therefore observed
and bounded, not byte-for-byte identical to the historical minimal app.

```bash
flutter run -d macos
```

The diagnostic HTTP server is owned by the lab, bound only to `127.0.0.1`
on a free port. Its URL appears in the status bar and as `KEY_LAB_URL` in
stdout. `/state` contains the current run; `/matrix` contains all 1,184 cases.
No separate FLUX server is needed for the current lab.

Capture evidence without storing clipboard or input text:

```bash
ruby scripts/capture_run.rb http://127.0.0.1:PORT B lab-B-manual
```

See [results and the physical-keyboard checklist](evidence/LAB-RESULTS.md)
and [the B/C follow-up](MACOS-WEBVIEW-KEY-REPEAT-RESEARCH.md#17-исследование-bc-продолжение-2026-09-25).
[Part 2](MACOS-WEBVIEW-KEY-REPEAT-RESEARCH-PART-2.md) explains B1/B2, the
physical Shift+Escape failure, and the next investigation.
The original no-fix source was recorded in old lab commit `5a6d4fb`.

### Code Ownership

- `lib/lab`: lifecycle, results, matrix, local diagnostic server, UI.
- `macos/Runner/Lab`: independent native strategies, event identity ledger,
  responder routing, native window, and a shared method-channel contract.
- `assets`: one diagnostic page shared by all eleven modes.
- `webview_key_guard` path dependency: the parent package in the same checkout.
- `RunnerTests`: native policy and event-identity tests, without OS key injection.

Reuse audit: the needed WebView host reuses stock `WebViewWidget`; A keeps
the existing Cmd+Enter algorithm as a control. Native routing and telemetry
have new owners because the minimal project had no equivalent components.
This test harness is deliberately not extracted into the app's production code.
`main.dart` shrank from 53 to 25 lines; native bootstrap stays small. Each
new source owner is under 250 lines, below the 350-line target.

Package-integration reuse audit: needed - test the actual shipped algorithm;
candidates found - the shared package, existing variant selector and telemetry;
decision - reuse the package and extend the harness with P; why - preserve
historical controls without maintaining a second current implementation.
The path-link helper remains as a historical tool; the example's normal
dependency already points to the parent package at `..`.

### Package Integration Verification, 2026-09-26

- 7 Dart tests, 4 Node tests, and 9 native Core tests in the shared package passed.
- Flutter analysis and macOS Debug build passed on the existing Flutter 3.47.5 SDK.
- At the time of this run, both consumers' resolved package configs pointed to
  the same package inside the host app. The package has since moved to its own repository;
  this historical run is not a new test of the relocated build.
- Live P -> B3 -> 0 -> P switching confirmed `packageEnabled` true/false/false/true
  and `implementation` package/lab/lab/package. Historical results remain separate.
- Run `1790373936650638`: 37 DOM keydowns, zero duplicates, repeats, or prevented
  events; no abort. Shift+Escape, Cmd+B and Cmd+Enter were tested in textarea,
  input and contenteditable. Other Escape/Enter modifier combinations and normal
  typing/Undo were included. Flutter text input and Select All worked; Flutter
  Cmd+B/Cmd+Enter did not add page events. Returning to WebView worked.
- Laboratory `suppressed`, `routed`, and command-boundary counters stayed zero
  in P. This verifies that the historical B3 guard was not doing the work.
- [Sanitized P snapshot](evidence/lab-P-package-smoke-20260926.json) was captured
  with the existing script; typed values are replaced with lengths.
- Hosted RunnerTests compiled but did not execute: the XCTest launch stalled
  before app code, with a sample in dyld's library-loading `open`. The interrupted
  test command exited 73 while finalizing its result bundle. This is not a pass;
  the root cause of that launch issue is not established. Normal app launch worked.

This was a synthetic smoke test with WebKit observation enabled, not the 844-case
matrix, a physical-keyboard test, or a no-observation control. Those P controls
were pending at the time; later validation is recorded below. The earlier B3
physical results must not be attributed to P.

### Standalone Package Extraction, 2026-09-26

At the time of this extraction check, the package had its own local Git
repository beside the lab. Both consumers resolved its Dart package and
native plugin to that one directory. No keyboard logic changed during the
move. The current installation instructions above supersede that local setup.

All 7 lab Dart tests and 4 Node tests passed again, as did 9 Core XCTest and
3 Dart tests in the package and 8 app setting tests. Package/lab analysis
and both macOS Debug builds passed. Builds used separate
`build/key-guard-extraction` outputs; the existing SDK versions were retained.
Apps were not launched, and hosted RunnerTests, physical input, and the
full P matrix were not rerun. Earlier live evidence remains historical.

### Current Git-Pinned P Validation, 2026-09-26

Later validation of the actual Git dependency supersedes the pending status
above. [The detailed results](evidence/LAB-RESULTS.md#current-git-package-p-verification-2026-09-26)
cover physical-keyboard runs, the 844-case safe matrix, editing and focus,
and automatic and physical controls with WebKit observation disabled. All five runs had zero
page duplicates and no emergency abort. The full matrix needed one retry;
Computer Use could not distinguish eight non-Shift `equal` chords. In the
observation-disabled physical control, Shift+Escape, Cmd+B and Cmd+Enter each
arrived exactly once; three additional events were normal modifier presses.

A separate crash during the first editing attempt occurred while the lab trace
read `NSEvent.isARepeat`. Both diagnostic event readers now limit that read to
keyDown events; the first rebuilt app passed the editing replay. Its new native
regression test compiled, but Xcode's hosted test launch stalled before
execution; this test is not counted as passed. The app's Settings widget
tests passed, and an isolated Debug app retained the off preference across
a process restart before it was restored to on.

## Historical Minimal Baseline

The original commit was a minimal macOS Flutter application created to isolate the repeated
`Cmd+Enter` event observed in the app. It contains one stock `WebViewWidget` and
does not contain app code, `performKeyEquivalent` overrides, JavaScript event
cancellation, debounce logic, or the `WebViewCommandKeyRouter` workaround.

## Original baseline environment

- Flutter `3.44.6`, stable, revision `ee80f08bbf`
- Dart `3.12.2`
- `webview_flutter 4.14.1`
- `webview_flutter_wkwebview 3.26.0`
- macOS diagnostic URL: `http://127.0.0.1:8001/keys`

The WebView package versions match the app lockfile used during the original
investigation.

## Reproduce Historical Baseline

The commands in this section describe the original minimal source, not the
current comparison lab. The current launch instructions are above.

Start the safe diagnostic server. It only records browser events and does not
run FLUX, models, or Codex:

```bash
cd investigation-project
.venv/bin/python -m uvicorn backend.diagnose_requests:app \
  --host 127.0.0.1 --port 8001 --no-access-log
```

Run the clean Flutter application:

```bash
cd example/
flutter run -d macos
```

Click the textarea once and press `Cmd+Enter` once. Inspect the page counter or
`http://127.0.0.1:8001/diagnostic/state`.

## Result from 2026-09-25

One synthetic `Cmd+Enter`, delivered through the same Computer Use path used in
the app reproduction, produced:

- 8,899 `keydown` events;
- 8,899 `keypress` events;
- `meta=true`, `repeat=false`, `isTrusted=true` for every recorded key event;
- the same browser timestamp, `57655`, for the first and last event.

The application was terminated to stop the loop. The raw diagnostic log is:

```text
investigation-project/.cache/investigation/reproduction/20260925-101306.jsonl
```

This reproduces the app incident signature without app code. It proves
that the defect exists in the stock Flutter macOS WebView stack used by the app.
It does not by itself distinguish whether the responsible layer is the Flutter
engine, `webview_flutter_wkwebview`, or their interaction with AppKit/WKWebView.

## Flutter upgrade comparison, 2026-09-25

Flutter `3.47.5` was installed separately for this historical check.
Its framework revision is `6a19cca564`,
engine revision `af7e796e16`, Dart `3.13.4`. The official ARM64 archive's
SHA-256 was verified before extraction:

```text
d4dd908b5f8f65515831b6d68ae33307a813f2b68947dded7a1994ee5ea7cead
```

The ordinary `flutter` command still uses the existing Flutter `3.44.6` SDK.
The new SDK occupies approximately 3.9 GiB, excluding the downloaded archive.

Each row below represents one synthetic `super+Return` through Computer Use,
with the textarea focused. All builds are debug macOS builds of this project
without the app fix. `webview_flutter` stayed at `4.14.1` throughout.

| Flutter | WKWebView plugin | Saved keydown | Saved keypress | Result |
| --- | --- | ---: | ---: | --- |
| 3.44.6 | 3.26.0 | 8,899 | 8,899 | Loop reproduced (original baseline) |
| 3.47.5 | 3.26.0 | 11,470 | 11,470 | Loop reproduced |
| 3.47.5 | 3.26.1 | 7,473 | 7,473 | Loop reproduced |

The two new runs were stopped by terminating the test app after approximately
11 seconds of recorded keyboard activity. Counts reflect the events received
by the diagnostic server before termination, not a natural stopping point or
a throughput benchmark. No model or generation request was triggered.

Every saved keydown in each new run has `repeat=false`, `meta=true`,
`trusted=true`, `prevented=false`, and a single unchanging timestamp per run:

- Plugin `3.26.0`: run `ef069d79-dd48-4277-b87b-9d9eff61c602`, timestamp `22777`.
- Plugin `3.26.1`: run `3c0102da-ae9f-4f29-9355-bc170bd01bc8`, timestamp `34837`.

Evidence snapshots include counters and the first/last observed events:

- [Flutter 3.47.5 with plugin 3.26.0](evidence/flutter-3.47.5-wkwebview-3.26.0-state.json)
- [Flutter 3.47.5 with plugin 3.26.1](evidence/flutter-3.47.5-wkwebview-3.26.1-state.json)

The complete raw event log for both new runs is at:

```text
investigation-project/.cache/investigation/reproduction/20260925-102156.jsonl
```

Neither the Flutter stable upgrade nor the plugin patch upgrade resolves this
synthetic-input reproduction. Physical keyboard input on the new SDK has not
been tested; these results do not substitute for that separate test.

### Current project state

The project now pins `webview_flutter_wkwebview 3.26.1` after the second stage.
To repeat the first stage, pin `3.26.0` using the same external SDK and rebuild.
Flutter automatically updated `matcher`, `meta`, `test_api`, and `vector_math`,
added analyzer exclusions and raised the macOS deployment target from 10.15 to
12.0. These changes are part of the SDK migration, not keyboard handling fixes.

Application source checksums stayed identical across all stages:

```text
lib/main.dart
55a5976f785c6a2edb9f7b3bf0019807249c5b28d93387c2de478a6773d93762
macos/Runner/MainFlutterWindow.swift
65c9613c11bcedfa51416b16c975d8ba6ff12b405fc19d60db8755d92e86d9fe
```
