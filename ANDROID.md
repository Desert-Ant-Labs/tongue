# Android: the Swift-via-JNI path works, but is the wrong trade for this model

The cross-compile is proven end to end. `mise run android-natives`-style build:

    swiftly run swift build -c release --product TongueAndroid \
      --swift-sdk aarch64-unknown-linux-android24 \
      -Xswiftc -static-stdlib -Xswiftc -resource-dir -Xswiftc <bundle>/swift_static

produces a genuine Android ELF exporting the four C ABI symbols
(`tongue_create`, `tongue_detect`, `tongue_destroy`, `tongue_buffer_free`), with
no dependency on `libLiteRt.so` — this model needs no inference runtime, so the
LiteRT vendoring in the shared catalog's `android-natives` task does not apply.

Built and verified for both `aarch64` and `x86_64`.

## The problem: 51 MB per ABI, for a 2 MB model

| | aarch64 | x86_64 |
|---|---|---|
| linked | 65.8 MB | 65.2 MB |
| `--strip-unneeded` | **51.5 MB** | **52.6 MB** |
| `-Osize --gc-sections --icf=all` | 51.4 MB | — |

That is the statically linked Swift runtime, and it does not compress away: the
size flags recovered 0.1 MB, because Swift's reflection metadata stays reachable.
An AAR with both ABIs would be ~100 MB to serve 2 MB of weights.

emo and toxic pay the same 50 MB, and for them it amortises — their pipelines are
a tokenizer plus a transformer plus Core ML / LiteRT sessions, so writing that
once in Swift and bridging it is clearly right.

## Recommendation for tongue: port to Kotlin instead

This pipeline is arithmetic. The whole thing is ~400 lines: normalizer, FNV-1a
hasher, a UAX#24 range table, an int8 gather, a 59x32 matmul, a masked softmax.
Kotlin has `java.text.Normalizer` and `java.util.regex` natively, so a direct
port needs no JNI, no native library and no cross-compile toolchain, and would
ship about 2 MB total rather than 100 MB.

The safety argument that normally favours bridging — "one implementation, one set
of semantics" — is already covered here by `golden/`: three vector files that any
port must reproduce byte for byte, which is how the Swift and JavaScript ports are
held honest. A Kotlin port would replay the same files.

Keep `Sources/TongueAndroid` regardless: the C ABI is also what a future Node
native binding would use (alongside `packages/tongue-js`, via koffi), where the
size cost is paid once on a server rather than in every app bundle.

## Measured outcome

The prediction above held. `Examples/TongueAndroidExample` is a real app whose only
dependency is `ai.desertant:tongue`, and its debug APK is:

| | |
|---|---|
| APK total | **2.52 MB** |
| `tongue_int8.bin` inside it | 2,104,940 bytes |
| `classes*.dex` | 2.42 MB |
| `lib/` entries | **0** |

Zero `lib/` entries is the claim made concrete: there is no native library in the
APK, so no per-ABI multiplication and no ABI splits to publish. The 2 MB of weights
account for essentially the whole download, against ~100 MB for the two-ABI JNI
route this document rejected.
