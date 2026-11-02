// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "MacosEditActionsCore",
  platforms: [.macOS(.v10_15)],
  products: [.library(name: "MacosEditActionsCore", targets: ["MacosEditActionsCore"])],
  targets: [
    .target(name: "MacosEditActionsCore", path: "macos/macos_edit_actions/Sources/macos_edit_actions/Core"),
    .testTarget(name: "MacosEditActionsCoreTests", dependencies: ["MacosEditActionsCore"], path: "macos/Tests"),
  ]
)
