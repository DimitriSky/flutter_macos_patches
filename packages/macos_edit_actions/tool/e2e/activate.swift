import AppKit
let pid = pid_t(CommandLine.arguments[1])!
let ok = NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateIgnoringOtherApps]) ?? false
print("activate:", ok)
