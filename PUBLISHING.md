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

1. **Create the repositories.** `tongue` is the monorepo (Swift at root, plus
   `packages/` and `Examples/`), matching `emo`. SwiftPM installs straight from it,
   so that alone ships the Apple SDK.

       gh repo create Desert-Ant-Labs/tongue --public --source=. --push

2. **Distribution repos**, if following emo exactly: `emo-kotlin` and `emo-js`
   exist as separate public repos because JitPack needs Gradle files at a repository
   root and npm wants a clean one. Extract `packages/tongue-kotlin` and
   `packages/tongue-js` the same way, or publish from the monorepo and skip them.

3. **Tag and publish.** Maven Central and npm both need credentials this repo does
   not carry:

       cd packages/tongue-kotlin && ./gradlew publish      # needs signing + Sonatype
       cd packages/tongue-js && npm publish --access public # needs an npm token

4. **desert-ant-core**: a branch adding `String.nfc` is committed locally but not
   pushed. It is not required by anything shipping — the Swift package keeps NFC
   local in `Sources/Tongue/NFC.swift` — but it is the right long-term home, and
   `Sources/TongueAndroid` needs it if the Node native binding is ever built.

## Version

All three packages are at `0.1.0`, and the model they carry is the one published at
[huggingface.co/desert-ant-labs/tongue](https://huggingface.co/desert-ant-labs/tongue)
(head-v14 with the tau=0.75 prior correction folded in).
