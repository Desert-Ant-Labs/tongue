// swift-tools-version: 6.1
import PackageDescription

// A runnable command-line example. Deliberately not an iOS app project: this can
// be executed with `swift run` on any machine, in CI included, where a .xcodeproj
// needs Xcode and a simulator. The API calls are identical in a SwiftUI view.
let package = Package(
    name: "TongueExample",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(name: "TongueExample", dependencies: [.product(name: "Tongue", package: "tongue-sdk")]),
    ]
)
