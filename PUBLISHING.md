# Publishing checklist

Everything below is built, tested and committed. The remaining steps create public
artifacts with permanent names, so they are deliberately left for a maintainer to
run rather than automated here.

## Verified locally

| | command | result |
|---|---|---|
| Apple | `mise run test-swift` | 7/7, no dependencies |
| Android + JVM | `mise run test-kotlin` | `./gradlew build` green, golden vectors in `check` |
| Browser + Node | `mise run test-js` | 5/5, packed tarball installs and detects |
| Console examples | `mise run examples` | both print identical probabilities |
| iOS app | `xcodebuild -scheme TongueExample` | BUILD SUCCEEDED, `TongueExample.app` produced |
| Android app | `./gradlew :app:assembleDebug` | 2.52 MB APK, model inside, **0** `lib/` entries |
| CI | `.github/workflows/ci.yml` | four jobs; resolves deps from released tags |

Consumer smoke tests both passed: `publishToMavenLocal` → `ai.desertant:tongue:0.1.0`
(1.6 MB jar) used from a separate Kotlin program, and `npm pack` → tarball installed
into a fresh project and used as `@desert-ant-labs/tongue`.

Not verified: the Android app on a real device or emulator. It builds and packages,
and the Kotlin port's golden vectors pass on the JVM, but Android's `java.text`
and `java.util.regex` are ICU-backed and could in principle differ. `./gradlew
:app:installDebug` against the `Medium_Phone_API_36.0` AVD is the one-command check.
emo covers this with an instrumented test on Firebase Test Lab, which needs the AGP
`androidTest` setup this package deliberately does not have.

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
   GitHub. Substitute the version you are releasing:

       mise run set-version X.Y.Z
       git commit -am "release X.Y.Z"      # REQUIRED — see below
       git push origin main
       git tag vX.Y.Z && git push origin vX.Y.Z

   **The commit is not optional.** `set-version` edits tracked files and leaves them
   in the working tree. Tag without committing and the tag points at a commit still
   carrying the *previous* versions, so every gate reads the old number, decides this
   tag is not its artifact's release, and skips — while `release.yml` still posts a
   GitHub Release advertising coordinates that never shipped. A green Release page
   and an untouched registry is the worst possible failure here, because nothing
   looks wrong. Pushing the branch before the tag matters for the same reason: the
   tag has to be reachable from what CI checks out.

   `publish-android.yml` and `publish-npm.yml` each gate on the tag naming their
   artifact's version *and* on that package's files having changed since the previous
   tag, so a blanket version bump republishes nothing. `release.yml` creates the
   GitHub Release and names whichever packages that tag shipped. The Swift SDK needs
   no publish step at all — SwiftPM resolves the tag directly.

   emo gets all three from desert-ant-core's reusable `model-sdk-release.yml`. That
   workflow does not fit here: its Android job cross-compiles Swift JNI natives and
   builds an AAR, and its npm job needs per-platform native cores plus a WebAssembly
   build staged into `packages/<model>-node/native/`. This SDK has none of those (see
   ANDROID.md), so the equivalent is assembled locally instead — same trigger, same
   gating rule, same secrets.

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
