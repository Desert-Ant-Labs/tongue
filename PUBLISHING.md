# Publishing checklist

Everything below is built, tested and committed. The remaining steps create public
artifacts with permanent names, so they are deliberately left for a maintainer to
run rather than automated here.

## Verified locally

| | command | result |
|---|---|---|
| Apple | `mise run test-swift` | 7/7, no dependencies, default toolchain |
| Android + JVM | `mise run test-kotlin` | `./gradlew build` green, golden vectors in `check` |
| Browser + Node | `mise run test-js` | 5/5, packed tarball installs and detects |
| Examples | `mise run examples` | all three print identical probabilities |
| CI | `.github/workflows/ci.yml` | four jobs; resolves deps from released tags |

Consumer smoke tests both passed: `publishToMavenLocal` → `ai.desertant:tongue:0.1.0`
(1.6 MB jar) used from a separate Kotlin program, and `npm pack` → tarball installed
into a fresh project and used as `@desert-ant-labs/tongue`.

## Remaining steps

1. ~~**Create the repository.**~~ Done: [Desert-Ant-Labs/tongue](https://github.com/Desert-Ant-Labs/tongue)
   is the monorepo (Swift at root, plus `packages/` and `Examples/`), matching `emo`.
   SwiftPM installs straight from it, so that alone ships the Apple SDK.

   No separate `tongue-kotlin`/`tongue-js` distribution repos: `emo-kotlin` and
   `emo-js` still exist but are deprecated stubs reading "This package has moved to
   the unified Emo repository", and JitPack carries no builds for the monorepo. The
   org publishes to Maven Central and npm from the monorepo, so we do the same.

2. **Maven Central.** `ai.desertant` is an established, verified namespace — `core`,
   `emo`, `redact`, `shapes` and the convention plugin are all published under it —
   so nothing needs registering. What is needed is the release credentials, which
   live with whoever runs the releases:

       ORG_GRADLE_PROJECT_mavenCentralUsername=...   # Central Portal token
       ORG_GRADLE_PROJECT_mavenCentralPassword=...
       ORG_GRADLE_PROJECT_signingInMemoryKey=...     # ASCII-armoured GPG secret key
       ORG_GRADLE_PROJECT_signingInMemoryKeyPassword=...

       cd packages/tongue-kotlin && ./gradlew publishToMavenCentral

   `signAllPublications()` is applied only when `signingInMemoryKey` is present, so
   local builds and CI stay green without keys — same guard the shared plugin uses.

3. **npm.** `@desert-ant-labs` already publishes `emo`, `shapes`, `redact`, `clear`
   and `desert-ant-web`, so this needs only an org token:

       cd packages/tongue-js && npm publish --access public

4. **desert-ant-core**: a branch adding `String.nfc` is committed locally but not
   pushed. It is not required by anything shipping — the Swift package keeps NFC
   local in `Sources/Tongue/NFC.swift` — but it is the right long-term home, and
   `Sources/TongueAndroid` needs it if the Node native binding is ever built.

## Version

All three packages are at `0.1.0`, and the model they carry is the one published at
[huggingface.co/desert-ant-labs/tongue](https://huggingface.co/desert-ant-labs/tongue)
(head-v14 with the tau=0.75 prior correction folded in).
