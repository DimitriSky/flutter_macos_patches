import Cocoa
import XCTest
@testable import MacosEditActionsCore

/// A stand-in for the engine's text input view: an NSTextView that keeps the field text in a
/// model of its own, reports it like `editingState` and changes it only through the entry points
/// the real one uses for typing (`insertText:replacementRange:` and `doCommandBySelector:`).
class FakeField: NSTextView {
  var text = ""
  var selection = NSRange(location: 0, length: 0)
  var inserted: [(String, NSRange)] = []
  var commands: [String] = []
  var inherited: [String] = []   // what the inherited NSTextView commands were asked to do

  @objc func editingState() -> NSDictionary {
    ["text": text, "selectionBase": selection.location, "selectionExtent": selection.location + selection.length]
  }

  override func insertText(_ insertString: Any, replacementRange: NSRange) {
    let string = insertString as? String ?? ""
    inserted.append((string, replacementRange))
    let range = replacementRange.location == NSNotFound ? selection : replacementRange
    text = (text as NSString).replacingCharacters(in: range, with: string)
    selection = NSRange(location: range.location + (string as NSString).length, length: 0)
  }

  override func doCommand(by selector: Selector) {
    commands.append(NSStringFromSelector(selector))
    let length = (text as NSString).length
    switch NSStringFromSelector(selector) {
    case "moveToBeginningOfDocument:": selection = NSRange(location: 0, length: 0)
    case "moveToEndOfDocumentAndModifySelection:": selection = NSRange(location: selection.location, length: length - selection.location)
    default: break
    }
  }

  override func paste(_ sender: Any?) { inherited.append("paste") }
  override func copy(_ sender: Any?) { inherited.append("copy") }
  override func cut(_ sender: Any?) { inherited.append("cut") }
  override func selectAll(_ sender: Any?) { inherited.append("selectAll") }
}

final class EditActionsPatchTests: XCTestCase {
  // Each test patches its own class: a patch stays on its class for the process lifetime.
  final class A: FakeField {}
  final class B: FakeField {}
  final class C: FakeField {}
  final class D: FakeField {}
  final class E: FakeField {}
  final class F: FakeField {}
  final class G: FakeField {}
  final class H: FakeField {
    var own = 0
    override func paste(_ sender: Any?) { own += 1 }
  }

  private let pasteboard = NSPasteboard(name: NSPasteboard.Name("macos_edit_actions.tests"))

  private func patch() -> EditActionsPatch {
    let patch = EditActionsPatch()
    patch.pasteboard = pasteboard
    return patch
  }

  private func field<T: FakeField>(_ type: T.Type, _ text: String, _ selection: NSRange) -> T {
    let field = T()
    field.text = text
    field.selection = selection
    return field
  }

  func testPasteGoesIntoTheEditingModelNotTheHiddenStorage() {
    let patch = patch(); patch.install(on: A.self)
    pasteboard.clearContents(); pasteboard.setString("B", forType: .string)
    let field = field(A.self, "AC", NSRange(location: 1, length: 0))
    field.paste(nil)
    XCTAssertEqual(field.text, "ABC")
    XCTAssertEqual(field.inserted.count, 1)
    XCTAssertEqual(field.inserted[0].1.location, NSNotFound, "replaces the selection, like typing")
    XCTAssertEqual(field.string, "", "the hidden NSTextView storage is not touched")
    XCTAssertTrue(field.inherited.isEmpty)
    XCTAssertEqual(patch.handled, 1)
  }

  func testPasteReplacesTheSelection() {
    let patch = patch(); patch.install(on: B.self)
    pasteboard.clearContents(); pasteboard.setString("X", forType: .string)
    let field = field(B.self, "abcd", NSRange(location: 1, length: 2))
    field.paste(nil)
    XCTAssertEqual(field.text, "aXd")
  }

  func testCopyTakesTheFieldSelectionInUTF16() {
    let patch = patch(); patch.install(on: C.self)
    pasteboard.clearContents()
    let field = field(C.self, "a😀b", NSRange(location: 1, length: 2))
    field.copy(nil)
    XCTAssertEqual(pasteboard.string(forType: .string), "😀")
    XCTAssertEqual(field.text, "a😀b")
    XCTAssertTrue(field.inherited.isEmpty)
  }

  func testCutCopiesAndRemovesTheSelection() {
    let patch = patch(); patch.install(on: D.self)
    pasteboard.clearContents()
    let field = field(D.self, "hello world", NSRange(location: 0, length: 6))
    field.cut(nil)
    XCTAssertEqual(pasteboard.string(forType: .string), "hello ")
    XCTAssertEqual(field.text, "world")
    XCTAssertEqual(field.inserted.last?.0, "")
  }

  func testSelectAllUsesTwoMovementCommandsAndSelectsEverything() {
    let patch = patch(); patch.install(on: E.self)
    let field = field(E.self, "some text", NSRange(location: 4, length: 0))
    field.selectAll(nil)
    XCTAssertEqual(field.commands, ["moveToBeginningOfDocument:", "moveToEndOfDocumentAndModifySelection:"])
    XCTAssertEqual(field.selection, NSRange(location: 0, length: 9))
  }

  func testNothingToDoFallsBackToTheInheritedCommand() {
    let patch = patch(); patch.install(on: F.self)
    pasteboard.clearContents()
    let field = field(F.self, "", NSRange(location: 0, length: 0))
    field.paste(nil)      // nothing on the pasteboard
    field.copy(nil)       // nothing selected
    field.cut(nil)
    field.selectAll(nil)  // empty field
    XCTAssertEqual(field.inherited, ["paste", "copy", "cut", "selectAll"])
    XCTAssertEqual(patch.handled, 0)
  }

  func testDisabledPatchLeavesTheInheritedBehavior() {
    let patch = patch(); patch.install(on: G.self)
    pasteboard.clearContents(); pasteboard.setString("B", forType: .string)
    patch.enabled = false
    let field = field(G.self, "AC", NSRange(location: 1, length: 0))
    field.paste(nil)
    XCTAssertEqual(field.inherited, ["paste"])
    XCTAssertEqual(field.text, "AC")
    patch.enabled = true
    field.paste(nil)
    XCTAssertEqual(field.text, "ABC")
  }

  func testACommandTheClassImplementsItselfIsLeftAlone() {
    let patch = patch(); patch.install(on: H.self)
    pasteboard.clearContents(); pasteboard.setString("B", forType: .string)
    let field = field(H.self, "AC", NSRange(location: 1, length: 0))
    field.paste(nil)
    XCTAssertEqual(field.own, 1)
    XCTAssertEqual(field.text, "AC")
    XCTAssertTrue(patch.skippedSelectors.contains { $0.hasSuffix(".paste:") })
    XCTAssertFalse(patch.patchedSelectors.contains { $0.hasSuffix(".paste:") })
    XCTAssertTrue(patch.patchedSelectors.contains { $0.hasSuffix(".copy:") })
  }

  func testMenuItemsAreEnabledByTheFieldModel() {
    final class V: FakeField {}
    let patch = patch(); patch.install(on: V.self)
    pasteboard.clearContents(); pasteboard.setString("B", forType: .string)
    let none = field(V.self, "text", NSRange(location: 1, length: 0))
    let some = field(V.self, "text", NSRange(location: 0, length: 2))
    func enabled(_ field: V, _ action: Selector) -> Bool {
      field.validateUserInterfaceItem(NSMenuItem(title: "x", action: action, keyEquivalent: ""))
    }
    XCTAssertFalse(enabled(none, #selector(NSText.copy(_:))))
    XCTAssertFalse(enabled(none, #selector(NSText.cut(_:))))
    XCTAssertTrue(enabled(some, #selector(NSText.copy(_:))))
    XCTAssertTrue(enabled(some, #selector(NSText.cut(_:))))
    XCTAssertTrue(enabled(none, #selector(NSText.paste(_:))))
    XCTAssertTrue(enabled(none, #selector(NSText.selectAll(_:))))
    pasteboard.clearContents()
    XCTAssertFalse(enabled(none, #selector(NSText.paste(_:))))
    let empty = field(V.self, "", NSRange(location: 0, length: 0))
    XCTAssertFalse(enabled(empty, #selector(NSText.selectAll(_:))))
  }

  func testMissingEngineClassIsReportedAndNothingBreaks() {
    let patch = patch()
    patch.installForFlutter()   // there is no FlutterTextInputPlugin in a test process
    XCTAssertEqual(patch.missingClassNames, ["FlutterTextInputPlugin"])
    XCTAssertTrue(patch.patchedSelectors.isEmpty)
    patch.installForFlutter()
    XCTAssertEqual(patch.missingClassNames.count, 1)
    XCTAssertEqual(patch.status["enabled"] as? Bool, true)
  }

  func testInstallingTwiceDoesNotWrapTwice() {
    final class W: FakeField {}
    let patch = patch(); patch.install(on: W.self); patch.install(on: W.self)
    pasteboard.clearContents(); pasteboard.setString("B", forType: .string)
    let field = field(W.self, "AC", NSRange(location: 1, length: 0))
    field.paste(nil)
    XCTAssertEqual(field.text, "ABC")
    XCTAssertEqual(field.inserted.count, 1)
  }
}
