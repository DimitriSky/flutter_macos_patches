import Cocoa

/// The standard edit commands of the Edit menu, done on the editing model of a Flutter field.
///
/// The engine's text input view (`FlutterTextInputPlugin`, an NSTextView) keeps the text of the
/// focused Flutter field in its own model and sends changes to the framework through
/// `insertText:replacementRange:` and `doCommandBySelector:`. The inherited NSTextView commands
/// work on a hidden NSTextView storage instead, so their result never reaches the field.
/// These functions use the view's own entry points, the way typing does.
enum EditCommands {
  /// The text and the selection of the field (UTF-16 offsets), as the engine reports them.
  struct FieldState {
    let text: String
    let selection: NSRange
  }

  static let editingStateSelector = NSSelectorFromString("editingState")

  /// `nil` when the view does not report an editing state the way the engine does.
  static func state(of view: NSResponder) -> FieldState? {
    guard view.responds(to: editingStateSelector),
          let dictionary = view.perform(editingStateSelector)?.takeUnretainedValue() as? [String: Any],
          let text = dictionary["text"] as? String,
          let base = (dictionary["selectionBase"] as? NSNumber)?.intValue,
          let extent = (dictionary["selectionExtent"] as? NSNumber)?.intValue
    else { return nil }
    let length = (text as NSString).length
    let start = max(0, min(base, extent, length))
    let end = max(0, min(max(base, extent), length))
    return FieldState(text: text, selection: NSRange(location: start, length: end - start))
  }

  static func selectedText(_ state: FieldState) -> String {
    (state.text as NSString).substring(with: state.selection)
  }

  /// Puts the pasteboard text in place of the selection. False when there is nothing to paste.
  static func paste(into view: NSResponder, from pasteboard: NSPasteboard) -> Bool {
    guard let client = view as? NSTextInputClient,
          let string = pasteboard.string(forType: .string), !string.isEmpty
    else { return false }
    // A range that is not found means "the selection": the same call typing makes.
    client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
    return true
  }

  /// Copies the selection. False when nothing is selected or the state is unknown.
  static func copy(from view: NSResponder, to pasteboard: NSPasteboard) -> Bool {
    guard let state = state(of: view), state.selection.length > 0 else { return false }
    pasteboard.clearContents()
    pasteboard.setString(selectedText(state), forType: .string)
    return true
  }

  /// Copies the selection and removes it from the field.
  static func cut(from view: NSResponder, to pasteboard: NSPasteboard) -> Bool {
    guard let client = view as? NSTextInputClient,
          let state = state(of: view), copy(from: view, to: pasteboard)
    else { return false }
    client.insertText("", replacementRange: state.selection)
    return true
  }

  /// Selects the whole text with two movement commands the framework already understands.
  static func selectAll(in view: NSResponder) -> Bool {
    guard let state = state(of: view), !state.text.isEmpty else { return false }
    view.doCommand(by: NSSelectorFromString("moveToBeginningOfDocument:"))
    view.doCommand(by: NSSelectorFromString("moveToEndOfDocumentAndModifySelection:"))
    return true
  }

  /// Whether a menu item of this action should be enabled; `nil` for other actions or an unknown state.
  static func isEnabled(action: Selector, view: NSResponder, pasteboard: NSPasteboard) -> Bool? {
    switch action {
    case #selector(NSText.paste(_:)):
      return state(of: view) == nil ? nil : (pasteboard.string(forType: .string)?.isEmpty == false)
    case #selector(NSText.copy(_:)), #selector(NSText.cut(_:)):
      return state(of: view).map { $0.selection.length > 0 }
    case #selector(NSText.selectAll(_:)):
      return state(of: view).map { !$0.text.isEmpty }
    default:
      return nil
    }
  }
}
