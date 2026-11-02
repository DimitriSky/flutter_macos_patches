# WebView Hover Guard

Keeps web page hover under the mouse in Flutter macOS apps with an embedded WebView
(WKWebView: `webview_flutter`, `flutter_inappwebview` or any other plugin).

## The problem

With the mouse resting on a menu item of a web page, the highlight jumps to an item
below it, or disappears from the last item, a moment later. It happens whenever
Flutter draws a frame, so in an app with any animation or timer it looks random.

## The cause

On every frame the Flutter macOS engine (`FlutterMutatorView.applyFlutterLayer`)
calls `addSubview:` for the platform view container even though it is already in place.
The tracking-area container lies above it, so AppKit really reorders the views and
re-evaluates tracking areas. WebKit then gets the mouse position relative to the
window instead of the WKWebView: hover moves down by the web view's distance from
the window top (and sideways by its distance from the left edge).
Details and evidence: [docs/root-cause.md](docs/root-cause.md).

## The fix

At plugin registration, `addSubview:` of the engine classes `FlutterMutatorView` and
`FlutterPathClipView` (and only them) skips a view that is already their subview.
A real move to another superview, e.g. when a clip path appears, still goes through.
If a future engine renames these classes, nothing is patched and nothing breaks;
`status()` reports them as `missing`.

## Use

Add the dependency; there is nothing to call.

```yaml
dependencies:
  webview_hover_guard:
    git:
      url: https://github.com/DimitriSky/flutter_macos_patches.git
      path: packages/webview_hover_guard
      ref: <commit>
```

Diagnostics and an A/B switch:

```dart
await const WebViewHoverGuard().status();          // enabled, patched, missing, skipped
await const WebViewHoverGuard().setEnabled(false); // show the bug again
```

## Checks

- `swift test` — native unit tests of the guard (AppKit views in a real window).
- `tool/hover_harness` — real-mouse reproduction without Flutter: FAIL unguarded,
  PASS guarded, for both a bare and a wrapped WKWebView.
- `tool/web_probe` — logger for real pages in a real app, plus a mouse driver.
- `flutter test` — Dart API.

Remove this package once the Flutter engine stops re-adding attached platform views.
