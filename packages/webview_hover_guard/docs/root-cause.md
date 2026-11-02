# Hover jump in macOS WebViews: root cause

Found 2026-10-20 in an app's in-app browser (webview_flutter, Flutter 3.44.6, macOS).

## Symptom

- Mouse on "Edit text" in a web menu; a couple of seconds later the highlight moves to
  "Add reference" or "Delete block" below it, without any mouse movement.
- Entering the top item from above briefly highlights the item below it.
- On the last item the highlight disappears.
- Not seen in SimpleWebBrowser, whose page starts at the window top, and which redraws less.

## Evidence

1. Logger injected into the real page in the real app: the mouse rested at page y=276
   on "Edit text". With no frames for 9 s, the hover stayed put. After one forced Flutter
   frame (`ext.flutter.reassemble` through the VM service), within 0.13 s the page got
   `mouseover` at y=360, which is the mouse position relative to the window, 84 pt lower
   (title bar + 52 pt browser toolbar), and "Delete block" was highlighted.
2. `tool/hover_harness` without Flutter, real mouse:
   - per-frame re-add of the container: hover jumps (y=204 = 120 + 84);
   - per-frame frame updates only: no jump;
   - re-adding only the tracking-area container: no jump;
   - WKWebView wrapped in another NSView: still jumps, so changing plugins does not help;
   - with this guard: no jump.
3. Native unit test: an unpatched re-add of a view that has a sibling above it calls
   `viewDidMoveToWindow` again; this is what makes WebKit re-read the mouse.

## Where in the sources

- Flutter engine `FlutterMutatorView.mm`, `updatePlatformViewWithBounds`:
  `[containerSuperview addSubview:_platformViewContainer]` on every frame, then
  `[self addSubview:_trackingAreaContainer positioned:NSWindowAbove relativeTo:nil]`.
- WebKit `WebViewImpl.mm`: tracking areas are owned by `WKMouseTrackingObserver`, whose
  `mouseEntered:` forwards to the page.

## Scope

macOS only (the macOS engine embedder plus AppKit tracking areas). On macOS every Flutter
WebView is WKWebView, so all WebView plugins are affected. The shift equals the web view's
offset in the window: no visible shift if the page starts at the window's top-left corner.
