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
// No dependencies, deliberately. Reaching for desert-ant-core's host-delegated
// Regex and NFC would only pay off on Android, and Android is served by the direct
// Kotlin port in packages/tongue-kotlin — while core's JavaScriptKit dependency
// imposes a Swift 6.2 toolchain floor on every consumer. Sources/TongueAndroid
// (the C ABI for a future Node native binding) stays in the tree but out of this
// manifest for the same reason; see ANDROID.md to re-enable it.
let package = Package(
    name: "Tongue",
    platforms: [
        .iOS(.v16), .macOS(.v13), .macCatalyst(.v16),
        .tvOS(.v16), .watchOS(.v9), .visionOS(.v1),
    ],
    products: [
        .library(name: "Tongue", targets: ["Tongue"]),
    ],
    targets: [
        .target(
            name: "Tongue",
            resources: [
                .copy("Resources/tongue_int8.bin"),
                .copy("Resources/tongue_meta.json"),
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
