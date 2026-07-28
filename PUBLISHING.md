# Publishing checklist

Everything below is built, tested and committed. The remaining steps create public
artifacts with permanent names, so they are deliberately left for a maintainer to
run rather than automated here.

## Verified locally

| | command | result |
|---|---|---|
| Apple | `mise run test-swift` | 7/7 (resolves desert-ant-core, JavaScriptKit, swift-syntax) |
| Android + JVM | `mise run test-kotlin` | `./gradlew build` green, golden vectors in `check` |
| Browser + Node | `mise run test-js` | 9/9, packed tarball installs and detects |
| Console examples | `mise run examples` | both print identical probabilities |
| iOS app | `xcodebuild -scheme TongueExample` | BUILD SUCCEEDED, `TongueExample.app` produced |
| Android app | `./gradlew clean :app:assembleDebug` | 2.54 MB APK, model inside, **0** `lib/` entries |
| Android device | `:app:installDebug` on API 36 | app runs; "kann ich das haben" → German, confident |
| Android vectors | golden vectors via `app_process` on API 36 | 43 normalize + 19 detection cases, all pass |
| CI | `.github/workflows/ci.yml` | four jobs; the table check now runs unconditionally |

Consumer smoke tests both passed: `publishToMavenLocal` → `ai.desertant:tongue`
(1.7 MB jar) used from a separate Kotlin program, and `npm pack` → tarball installed
into a fresh project and used as `@desert-ant-labs/tongue`.

Cross-port parity is checked outside the shipped suites too: 53 diverse inputs give
identical language, reliability, tie flag and 9-decimal probabilities on all three
ports, and ten Swift launches over that corpus produce one hash.

The Android runtime is now covered directly. Android's `java.text` and
`java.util.regex` are ICU-backed and its Unicode data moves with the platform, so
"passes on the JVM" was never the same claim as "passes on a phone" — and the
pinned discard table exists precisely because that difference was real. The same
jar was dexed and run on an API 36 emulator through `app_process`, replaying the
same vector files: 43 normalize cases and 19 detection cases, all passing. emo
covers this with a Firebase Test Lab instrumented test, which needs the AGP
`androidTest` setup this package deliberately does not have.

Still unverified: no usage event has ever been delivered end to end to the ingest
endpoint. Every run here sets `DAL_USAGE_DISABLED=1`, because emitting one would
put this machine into real billing data. The state machine is pinned by vectors
and the wire bytes are asserted byte for byte in two ports; the round trip is not.

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
