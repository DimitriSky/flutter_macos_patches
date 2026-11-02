# Flutter macOS patches

Fixes for places where the Flutter macOS embedder and AppKit do not work together:
web pages (WKWebView) embedded in Flutter apps today, and the text input of Flutter fields.
Each fix is a separate Flutter plugin in `packages/`; an app adds only the ones it needs.

> This repository was named `flutter_webview_macos_patches` until 2026-11-02. GitHub redirects
> the old address, so existing `git:` dependencies and pinned commits keep working.

| Package | Problem it fixes |
|---|---|
| `webview_key_guard` | A key press on a web page reaches the page more than once (macOS + Flutter redispatch of unhandled keys). |
| `webview_modal_guard` | Mouse input passes through Flutter dialogs and menus to the web page under them. |
| `webview_hover_guard` | Page hover jumps to another element or disappears when Flutter draws a frame. |

## Use in an app

```yaml
dependencies:
  webview_key_guard:
    git:
      url: https://github.com/DimitriSky/flutter_macos_patches.git
      path: packages/webview_key_guard
      ref: <commit>
```

Pin `ref` to a commit; all packages of one app should use the same commit.

## Origin

The first two packages were copied without changes from their original repositories,
which stay as historical backups:

| Package | Original repository | Commit |
|---|---|---|
| `webview_key_guard` | https://github.com/DimitriSky/flutter_webview_key_guard | `76f4b676a56e4cb95cab4d55b73769b26c64c39b` |
| `webview_modal_guard` | https://github.com/DimitriSky/webview_modal_guard | `2f45b89a0ec8454a8c1ea1b6a79d2bd2b439fd3e` |
