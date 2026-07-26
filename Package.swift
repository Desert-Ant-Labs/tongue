// swift-tools-version: 6.1
import PackageDescription
import Foundation

// Tongue: on-device language identification for short text.
//
//   desert-ant-core   reusable primitives (Regex, TextNormalization, JSON,
//                     ModelStore) with per-platform backends, so the pipeline
//                     stays pure Swift and cross-compiles to Android and wasm
//   Sources/Tongue    the pipeline: normalizer, FNV-1a hasher, UAX#24 script
//                     router, int8 head, plus the 2 MB weights as a resource
//
// No inference runtime. Unlike emo and toxic, which carry transformers and so
// depend on desert-ant-core's `Inference` for Core ML / LiteRT sessions, a
// detection here is an embedding gather, a sum, one 59x32 matmul and a masked
// softmax. Nothing to hand to an accelerator, so there is no Core ML or LiteRT
// artifact and no per-runtime resource split.
//
// The normalizer, hasher and router are a frozen specification shared with the
// Python reference and the other SDKs; Tests/TongueTests replays golden/ so a
// port cannot drift silently.
//
// Setting SWIFT_ANDROID_STATIC_BUILD drops JavaScriptKit from the dependency
// graph (matching emo and desert-ant-core), which an Android static-stdlib link
// requires and which also lets the package build on a 6.1 toolchain.
let noJavaScriptKit = ProcessInfo.processInfo.environment["SWIFT_ANDROID_STATIC_BUILD"] != nil

let package = Package(
    name: "Tongue",
    platforms: [
        .iOS(.v16), .macOS(.v13), .macCatalyst(.v16),
        .tvOS(.v16), .watchOS(.v9), .visionOS(.v1),
    ],
    products: [
        .library(name: "Tongue", targets: ["Tongue"]),
        // Android JNI library, built by `mise run android-natives`. Also builds on
        // a host triple, where only the C ABI compiles (AndroidJNI.swift is
        // `#if os(Android)`), which is what lets it be smoke-tested on macOS.
        .library(name: "TongueAndroid", type: .dynamic, targets: ["TongueAndroid"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Desert-Ant-Labs/desert-ant-core.git", from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "Tongue",
            dependencies: [
                // Cross-platform regex (host-bridged on Android, where Swift has
                // no ICU) and Unicode NFC. The pipeline uses no platform code.
                .product(name: "Regex", package: "desert-ant-core"),
                .product(name: "TextNormalization", package: "desert-ant-core"),
                .product(name: "JSON", package: "desert-ant-core"),
                .product(name: "PlatformSupport", package: "desert-ant-core"),
            ],
            resources: [
                .copy("Resources/tongue_int8.bin"),
                .copy("Resources/tongue_meta.json"),
            ]
        ),
        .target(
            name: "TongueAndroid",
            dependencies: [
                "Tongue",
                .product(name: "FFIBuffer", package: "desert-ant-core"),
                .product(name: "HostBridge", package: "desert-ant-core",
                         condition: .when(platforms: [.android])),
                .product(name: "PlatformSupport", package: "desert-ant-core"),
            ]
        ),
        .testTarget(
            name: "TongueTests",
            dependencies: ["Tongue"],
            resources: [
                .copy("Resources/normalize_vectors.json"),
                .copy("Resources/script_vectors.json"),
                .copy("Resources/hashing_vectors.json"),
            ]
        ),
    ]
)
