// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "tdo",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "TDOCore", targets: ["TDOCore"]),
    .library(name: "TDOTerminal", targets: ["TDOTerminal"]),
    .executable(name: "tdo", targets: ["tdo"]),
    .executable(name: "tdo-mac", targets: ["tdo-mac"]),  // ← NEW
  ],
  targets: [
    .target(name: "TDOCore", path: "Sources/TDOCore"),
    .target(name: "TDOTerminal", dependencies: ["TDOCore"], path: "Sources/TDOTerminal"),
    .executableTarget(name: "tdo", dependencies: ["TDOCore", "TDOTerminal"], path: "Sources/tdo"),
    .executableTarget(
      name: "tdo-mac",
      dependencies: ["TDOCore"],  // thin GUI uses core only
      path: "Sources/tdo-mac"
    ),
  ]
)
