import AppKit
import ApplicationServices
// usage: axmenu <pid> <menu item title> : press the first AXMenuItem with that exact title; also print whether it is enabled
let pid = pid_t(CommandLine.arguments[1])!
let wanted = CommandLine.arguments[2]
func attr(_ e: AXUIElement, _ n: String) -> AnyObject? { var v: CFTypeRef?; return AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success ? v : nil }
func find(_ e: AXUIElement, _ d: Int) -> AXUIElement? {
    if d > 8 { return nil }
    if (attr(e, kAXRoleAttribute) as? String) == "AXMenuItem", (attr(e, kAXTitleAttribute) as? String) == wanted { return e }
    for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { if let f = find(c, d + 1) { return f } }
    return nil
}
guard let item = find(AXUIElementCreateApplication(pid), 0) else { print("menu item not found"); exit(1) }
print("enabled:", attr(item, kAXEnabledAttribute) ?? "?")
print("press:", AXUIElementPerformAction(item, kAXPressAction as CFString).rawValue)
