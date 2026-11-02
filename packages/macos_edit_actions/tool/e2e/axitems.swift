import AppKit
import ApplicationServices
// usage: axitems <pid> : print the items of the Edit menu with their enabled state
let pid = pid_t(CommandLine.arguments[1])!
func attr(_ e: AXUIElement, _ n: String) -> AnyObject? { var v: CFTypeRef?; return AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success ? v : nil }
func find(_ e: AXUIElement, _ d: Int, _ title: String) -> AXUIElement? {
    if d > 6 { return nil }
    if (attr(e, kAXRoleAttribute) as? String) == "AXMenuBarItem", (attr(e, kAXTitleAttribute) as? String) == title { return e }
    for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { if let f = find(c, d + 1, title) { return f } }
    return nil
}
func items(_ e: AXUIElement, _ d: Int) -> [(String, Bool)] {
    var out: [(String, Bool)] = []
    if (attr(e, kAXRoleAttribute) as? String) == "AXMenuItem", let t = attr(e, kAXTitleAttribute) as? String, !t.isEmpty {
        out.append((t, (attr(e, kAXEnabledAttribute) as? Bool) ?? false))
    }
    if d < 4 { for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { out += items(c, d + 1) } }
    return out
}
guard let edit = find(AXUIElementCreateApplication(pid), 0, "Edit") else { print("no Edit menu"); exit(1) }
let wanted = ["Undo", "Redo", "Cut", "Copy", "Paste", "Select All"]
print(items(edit, 0).filter { wanted.contains($0.0) }.map { "\($0.0)=\($0.1 ? "on" : "off")" }.joined(separator: " "))
