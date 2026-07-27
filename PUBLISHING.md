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

2. **Grant this repo the organisation publishing secrets.** `MAVEN_CENTRAL_USERNAME`,
   `MAVEN_CENTRAL_PASSWORD`, `SIGNING_IN_MEMORY_KEY`, `SIGNING_IN_MEMORY_KEY_PASSWORD`
   and `NPM_TOKEN` exist as Desert-Ant-Labs organisation secrets with *selected
   repositories* visibility, so `Desert-Ant-Labs/tongue` has to be added to that
   selection (Org Settings → Secrets and variables → Actions → each secret).

   `ai.desertant` is already an established, verified Maven namespace — `core`,
   `emo`, `redact`, `shapes` and the convention plugin all publish under it — and
   `@desert-ant-labs` already publishes five npm packages, so nothing needs
   registering with Sonatype or npm. Only the grant is missing.

3. **Tag the release.** Both registries then publish from CI; no key ever leaves
   GitHub:

       mise run set-version 0.1.0    # bumps both artifacts, already at 0.1.0
       git tag v0.1.0 && git push --tags

   `publish-android.yml` and `publish-npm.yml` each gate on the tag naming their
   artifact's version *and* on that package's files having changed since the previous
   tag, so a blanket version bump republishes nothing. This is core's release model,
   ported. The Swift SDK needs no step at all — SwiftPM resolves the tag directly.

   To publish by hand instead, put the same credentials in `mise.local.toml` and run
   `mise run publish-android` / `mise run publish-npm`. `signAllPublications()` is
   applied only when `signingInMemoryKey` is present, so ordinary builds and CI stay
   green without keys — the same guard the shared convention plugin uses.

4. **desert-ant-core**: a branch adding `String.nfc` is committed locally but not
   pushed. It is not required by anything shipping — the Swift package keeps NFC
   local in `Sources/Tongue/NFC.swift` — but it is the right long-term home, and
   `Sources/TongueAndroid` needs it if the Node native binding is ever built.

## Version

All three packages are at `0.1.0`, and the model they carry is the one published at
[huggingface.co/desert-ant-labs/tongue](https://huggingface.co/desert-ant-labs/tongue)
(head-v14 with the tau=0.75 prior correction folded in).
