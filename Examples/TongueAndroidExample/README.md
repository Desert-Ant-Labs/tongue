# TongueAndroidExample

A tiny Android app for trying Tongue with the Maven Central package
`ai.desertant:tongue`.

## Run

Connect a device or start an emulator, then:

```bash
./gradlew :app:installDebug
```

Type in any language and watch the answer update as you type. Everything runs on
the main thread — no coroutines, no debounce, nothing downloaded — because a
detection is arithmetic over 2 MB of weights that ship inside the artifact.

Until `ai.desertant:tongue:0.1.0` is on Maven Central, publish it locally first:

```bash
cd ../.. && mise run publish-android   # with no credentials this lands in ~/.m2
```

`settings.gradle.kts` lists `mavenLocal()`, so the app resolves it from there.
