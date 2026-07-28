// swift-tools-version: 6.1
import PackageDescription

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
// Built on desert-ant-core, the shared primitives every Desert Ant model SDK uses.
// That sets a Swift 6.2 floor, because core depends on JavaScriptKit for its wasm
// backend — the same floor emo and toxic already carry. It costs consumers a
// current Xcode and costs the model nothing: accuracy, size and latency are
// identical either way.
//
// Setting SWIFT_ANDROID_STATIC_BUILD drops JavaScriptKit from the graph, which the
// Android static-stdlib link needs (its swift-syntax macros conflict with
// -resource-dir) and which also lets the package build on an older toolchain. The
// gating lives in desert-ant-core's own manifest, and SwiftPM evaluates every
// manifest in one process environment, so exporting the variable is all it takes
// here — no conditional of our own. Matches emo.

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
        .package(url: "https://github.com/Desert-Ant-Labs/desert-ant-core.git", from: "0.4.2"),
    ],
    targets: [
        .target(
            name: "Tongue",
            dependencies: [
                // Cross-platform regex: host-delegated on Android, where Swift has
                // no ICU. The pipeline itself stays free of platform code.
                .product(name: "Regex", package: "desert-ant-core"),
                .product(name: "PlatformSupport", package: "desert-ant-core"),
                // The usage turnstile. emo, redact and shapes get this for free
                // because Inference depends on it and wraps every session; this
                // model has no inference runtime, so it is wired directly. See
                // docs/USAGE.md.
                .product(name: "Usage", package: "desert-ant-core"),
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
                .copy("Resources/detection_vectors.json"),
                .copy("Resources/normalize_vectors.json"),
                .copy("Resources/script_vectors.json"),
                .copy("Resources/hashing_vectors.json"),
            ]
        ),
    ]
)
