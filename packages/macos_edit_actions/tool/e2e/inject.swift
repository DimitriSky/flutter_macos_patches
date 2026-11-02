import Cocoa
import Carbon

// A copy of VoiceCommand's TextInjector (TextInjector.swift): put the text on
// the pasteboard, wait pasteDelay, post Cmd down / V down / V up / Cmd up to
// cghidEventTap with no pause between them, restore the pasteboard after
// restoreDelay. The only addition is a guard: it pastes only while the frontmost
// application has the bundle id given in --require, so a probe can never type
// into some other window.
//
// usage: inject --require <bundleId> [--text <t>] [--paste-delay s] [--restore-delay s]
//               [--variant verbatim|flags|gaps]

var args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}
let required = option("--require")
let text = option("--text") ?? "probe-text-123"
let pasteDelay = Double(option("--paste-delay") ?? "0.05")!
let restoreDelay = Double(option("--restore-delay") ?? "0.20")!
let variant = option("--variant") ?? "verbatim"
let sourceName = option("--source") ?? "hid"
let tapName = option("--tap") ?? "hid"
let devFlag = args.contains("--devflag")
let cmdFlags: CGEventFlags = devFlag ? [.maskCommand, CGEventFlags(rawValue: 0x8)] : .maskCommand
let keyCode = CGKeyCode(UInt16(option("--key") ?? "9", radix: 16)!)

guard let required else { print("refusing: --require <bundleId> is mandatory"); exit(2) }
let front = NSWorkspace.shared.frontmostApplication
print("frontmost:", front?.bundleIdentifier ?? "nil", "pid", front?.processIdentifier ?? -1)
guard front?.bundleIdentifier == required else { print("refusing: frontmost is not \(required)"); exit(3) }

func simulatePaste() {
    let state: CGEventSourceStateID = sourceName == "session" ? .combinedSessionState : (sourceName == "private" ? .privateState : .hidSystemState)
    let source = CGEventSource(stateID: state)
    let kVK_ANSI_V: CGKeyCode = keyCode
    let kVK_Command: CGKeyCode = 0x37
    let loc: CGEventTapLocation = tapName == "session" ? .cgSessionEventTap : (tapName == "annotated" ? .cgAnnotatedSessionEventTap : .cghidEventTap)

    let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: true)
    cmdDown?.flags = cmdFlags
    let vDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_V, keyDown: true)
    vDown?.flags = cmdFlags
    let vUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_V, keyDown: false)
    vUp?.flags = cmdFlags
    let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: false)

    switch variant {
    case "gaps":   // same events, 10 ms apart
        for event in [cmdDown, vDown, vUp, cmdUp] { event?.post(tap: loc); usleep(10_000) }
    case "type":   // a plain letter, no modifiers: do key events reach the field at all?
        let kVK_ANSI_Q: CGKeyCode = keyCode
        CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_Q, keyDown: true)?.post(tap: loc)
        CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_Q, keyDown: false)?.post(tap: loc)
    case "hw", "hwgaps":   // what a real keyboard sends: the modifier as a flagsChanged event
        func modifier(down: Bool) -> CGEvent? {
            let e = CGEvent(source: source)
            e?.type = .flagsChanged
            e?.setIntegerValueField(.keyboardEventKeycode, value: Int64(kVK_Command))
            e?.flags = down ? cmdFlags : []
            return e
        }
        let gap: UInt32 = variant == "hwgaps" ? 10_000 : 0
        for event in [modifier(down: true), vDown, vUp, modifier(down: false)] { event?.post(tap: loc); if gap > 0 { usleep(gap) } }
    case "hwkey":   // a key-press event for the modifier turned into a flagsChanged event
        let down = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: true)
        down?.type = .flagsChanged; down?.flags = cmdFlags
        let up = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: false)
        up?.type = .flagsChanged; up?.flags = []
        for event in [down, vDown, vUp, up] { event?.post(tap: loc); usleep(8_000) }
    case "flags":  // the modifier as a flags-changed state, not a key press
        let down = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_V, keyDown: true)
        down?.flags = cmdFlags
        let up = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_V, keyDown: false)
        up?.flags = cmdFlags
        down?.post(tap: loc); up?.post(tap: loc)
    default:       // verbatim
        cmdDown?.post(tap: loc)
        vDown?.post(tap: loc)
        vUp?.post(tap: loc)
        cmdUp?.post(tap: loc)
    }
}

let pasteboard = NSPasteboard.general
let snapshot = (pasteboard.pasteboardItems ?? []).map { item -> NSPasteboardItem in
    let copy = NSPasteboardItem()
    for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
    return copy
}
pasteboard.clearContents()
pasteboard.setString(text, forType: .string)
let injectedChangeCount = pasteboard.changeCount

DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) {
    simulatePaste()
    DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
        let stillOurs = pasteboard.changeCount == injectedChangeCount || pasteboard.string(forType: .string) == text
        if stillOurs {
            pasteboard.clearContents()
            if !snapshot.isEmpty { pasteboard.writeObjects(snapshot) }
        }
        print("done; pasteboard restored:", stillOurs)
        exit(0)
    }
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
