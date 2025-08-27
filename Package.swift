// swift-tools-version: 5.9
import PackageDescription

var package = Package(
    name: "tdo",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "TDOCore", targets: ["TDOCore"]),
        .library(name: "TDOTerminal", targets: ["TDOTerminal"]),
        .executable(name: "tdo", targets: ["tdo"])
    ],
    targets: [
        .target(name: "TDOCore", path: "Sources/TDOCore"),
        .target(name: "TDOTerminal", dependencies: ["TDOCore"], path: "Sources/TDOTerminal"),
        .executableTarget(name: "tdo", dependencies: ["TDOCore", "TDOTerminal"], path: "Sources/tdo")
    ]
)

#if os(macOS)
package.products.append(
    .executable(name: "tdo-mac", targets: ["tdo-mac"])
)
package.targets.append(
    .executableTarget(
        name: "tdo-mac",
        dependencies: ["TDOCore"],
        path: "Sources/tdo-mac"
    )
)
#endif
