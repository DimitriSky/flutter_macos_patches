#!/bin/bash
# End-to-end check of macos_edit_actions against the real Flutter engine, no human needed.
# Needs: Accessibility permission for the terminal, Flutter on PATH, a free screen (the example takes focus).
# Usage: tool/e2e/run.sh            # builds the example, runs every check, exits non-zero on failure
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$HERE/../.."
BIN="${TMPDIR:-/tmp}/macos_edit_actions_e2e"
B=com.dmilab.macosEditActionsExample
CT="$HOME/Library/Containers/$B/Data/tmp"
APP="$PKG/example/build/macos/Build/Products/Debug/macos_edit_actions_example.app"
FAILED=0

mkdir -p "$BIN"
for t in inject axmenu axitems activate; do swiftc -O "$HERE/$t.swift" -o "$BIN/$t" 2>/dev/null || { echo "cannot build $t"; exit 2; }; done
(cd "$PKG/example" && flutter build macos --debug >/dev/null) || { echo "cannot build example"; exit 2; }

pid() { pgrep -f "macos_edit_actions_example.app/Contents/MacOS" | head -1; }
field() { cat "$CT/field1.txt" 2>/dev/null; }
check() { # name, expected substring of field1.txt
  if field | grep -q -F "$2"; then echo "PASS $1"; else echo "FAIL $1: expected $2, got $(field)"; FAILED=1; fi
}
launch() { # fix.txt content ("off" or "")
  pkill -f "macos_edit_actions_example.app/Contents/MacOS"; sleep 2
  mkdir -p "$CT"; rm -f "$CT/field1.txt" "$CT/field2.txt" "$CT/status.json" "$CT/fix.txt"
  [ "$1" = off ] && echo off > "$CT/fix.txt"
  open -n "$APP"; sleep 8; "$BIN/activate" "$(pid)" >/dev/null; sleep 1
}
paste_synthetic() { "$BIN/inject" --require "$B" --text "$1" >/dev/null; sleep 2; }  # like dictation tools
paste_keyboard()  { "$BIN/inject" --require "$B" --text "$1" --devflag >/dev/null; sleep 2; }  # like a real keyboard
menu() { "$BIN/axmenu" "$(pid)" "$1" >/dev/null; sleep 1; }

echo "== plugin off: the bug is visible"
launch off
paste_synthetic "baseline"; check "off: synthetic Cmd+V does nothing" '"text":""'
menu Paste;                 check "off: Edit > Paste does nothing" '"text":""'

echo "== plugin on"
launch on
paste_synthetic "hello world"; check "synthetic Cmd+V pastes once" '"text":"hello world"'
menu "Select All";             check "Edit > Select All" '"base":0,"extent":11'
[ "$("$BIN/axitems" "$(pid)")" = "Undo=off Redo=off Cut=on Copy=on Paste=on Select All=on" ] \
  && echo "PASS items enabled with selection" || { echo "FAIL item states: $("$BIN/axitems" "$(pid)")"; FAILED=1; }
menu Copy; [ "$(pbpaste)" = "hello world" ] && echo "PASS Edit > Copy" || { echo "FAIL Edit > Copy: $(pbpaste)"; FAILED=1; }
menu Cut;  check "Edit > Cut empties the field" '"text":""'
[ "$(pbpaste)" = "hello world" ] && echo "PASS Edit > Cut fills clipboard" || { echo "FAIL Edit > Cut clipboard"; FAILED=1; }
[ "$("$BIN/axitems" "$(pid)")" = "Undo=off Redo=off Cut=off Copy=off Paste=on Select All=off" ] \
  && echo "PASS items disabled with empty field" || { echo "FAIL item states: $("$BIN/axitems" "$(pid)")"; FAILED=1; }
menu Paste; check "Edit > Paste" '"text":"hello world"'
menu "Select All"; paste_keyboard "ABC"; check "real-keyboard Cmd+V pastes once (no double)" '"text":"ABC","base":3'
"$BIN/inject" --require "$B" --text x --key 0 --devflag >/dev/null; sleep 1
check "real-keyboard Cmd+A" '"base":0,"extent":3'

pkill -f "macos_edit_actions_example.app/Contents/MacOS"
[ $FAILED = 0 ] && echo "ALL PASS" || echo "SOME FAILED"
exit $FAILED
