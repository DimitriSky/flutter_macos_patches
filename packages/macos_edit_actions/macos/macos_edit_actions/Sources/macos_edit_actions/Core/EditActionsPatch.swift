import Cocoa
import ObjectiveC

/// Adds `paste:`, `copy:`, `cut:` and `selectAll:` that work on the Flutter editing model to the
/// engine's text input view, and answers the menu validation for them.
///
/// Without it the Edit menu does nothing in Flutter fields, and a Cmd+V that arrives as a plain
/// key press without the Command device bit (dictation and automation tools) pastes into a
/// hidden NSTextView storage. Only the given classes are patched; NSTextView itself is never
/// changed. A command the class already implements itself (a newer engine) is left alone, and
/// every patched command falls back to the inherited implementation when the field state is
/// not what this patch expects.
public final class EditActionsPatch {
  public static let shared = EditActionsPatch()

  /// The engine class that receives the commands of the Edit menu while a Flutter field has focus.
  public static let flutterClassName = "FlutterTextInputPlugin"

  public var enabled = true
  public var pasteboard: NSPasteboard = .general
  public private(set) var patchedSelectors: [String] = []
  public private(set) var skippedSelectors: [String] = []
  public private(set) var missingClassNames: [String] = []
  public private(set) var handled = 0

  private typealias Action = @convention(c) (NSResponder, Selector, Any?) -> Void
  private typealias Validate = @convention(c) (NSResponder, Selector, Any?) -> Bool

  /// Patches the Flutter engine class. Safe to call more than once.
  public func installForFlutter() {
    precondition(Thread.isMainThread)
    guard let cls = NSClassFromString(Self.flutterClassName) as? NSResponder.Type else {
      // A newer engine may have renamed the class: nothing is patched, nothing breaks.
      if !missingClassNames.contains(Self.flutterClassName) { missingClassNames.append(Self.flutterClassName) }
      return
    }
    install(on: cls)
  }

  /// Patches one class. Exposed for native tests.
  public func install(on cls: NSResponder.Type) {
    precondition(Thread.isMainThread)
    let owned = ownMethodNames(of: cls)
    let commands: [(Selector, (NSResponder) -> Bool)] = [
      (#selector(NSText.paste(_:)), { EditCommands.paste(into: $0, from: self.pasteboard) }),
      (#selector(NSText.copy(_:)), { EditCommands.copy(from: $0, to: self.pasteboard) }),
      (#selector(NSText.cut(_:)), { EditCommands.cut(from: $0, to: self.pasteboard) }),
      (#selector(NSText.selectAll(_:)), { EditCommands.selectAll(in: $0) }),
    ]
    for (selector, run) in commands {
      let name = NSStringFromSelector(selector)
      let label = "\(NSStringFromClass(cls)).\(name)"
      if owned.contains(name) { skippedSelectors.append(label); continue }
      guard !patchedSelectors.contains(label), let method = class_getInstanceMethod(cls, selector) else { continue }
      let original = unsafeBitCast(method_getImplementation(method), to: Action.self)
      let block: @convention(block) (NSResponder, Any?) -> Void = { view, sender in
        if self.enabled && run(view) {
          self.handled += 1
        } else {
          original(view, selector, sender)
        }
      }
      class_addMethod(cls, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
      patchedSelectors.append(label)
    }
    patchValidation(on: cls, owned: owned)
  }

  /// Menu items are enabled by the model of the Flutter field, not by the hidden storage.
  private func patchValidation(on cls: NSResponder.Type, owned: Set<String>) {
    for selector in [NSSelectorFromString("validateUserInterfaceItem:"), NSSelectorFromString("validateMenuItem:")] {
      let name = NSStringFromSelector(selector)
      let label = "\(NSStringFromClass(cls)).\(name)"
      guard !owned.contains(name), !patchedSelectors.contains(label),
            let method = class_getInstanceMethod(cls, selector) else { continue }
      let original = unsafeBitCast(method_getImplementation(method), to: Validate.self)
      let block: @convention(block) (NSResponder, Any?) -> Bool = { view, item in
        if self.enabled,
           let action = (item as? NSValidatedUserInterfaceItem)?.action,
           let answer = EditCommands.isEnabled(action: action, view: view, pasteboard: self.pasteboard) {
          return answer
        }
        return original(view, selector, item)
      }
      class_addMethod(cls, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
      patchedSelectors.append(label)
    }
  }

  private func ownMethodNames(of cls: AnyClass) -> Set<String> {
    var count: UInt32 = 0
    guard let list = class_copyMethodList(cls, &count) else { return [] }
    defer { free(list) }
    return Set((0..<Int(count)).map { NSStringFromSelector(method_getName(list[$0])) })
  }

  public var status: [String: Any] {
    [
      "enabled": enabled, "patched": patchedSelectors, "skipped": skippedSelectors,
      "missing": missingClassNames, "handled": handled,
    ]
  }
}
