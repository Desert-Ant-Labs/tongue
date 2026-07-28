# tongue — Kotlin SDK (JVM + Android)

On-device language identification for short text, across 84 languages.

```kotlin
val tongue = Tongue.bundled()
tongue.detect("kann ich das haben").language   // "de"
tongue.detect("안녕하세요").language             // "ko"
```

**No native code, no NDK, and nothing on the classpath but the Kotlin standard
library.** A detection is an int8 embedding
gather, a sum, one 59×32 matmul and a masked softmax — a few thousand
multiply-adds — so this is a direct Kotlin port rather than a JNI binding over the
Swift core. That is a deliberate departure from `emo-kotlin`: bridging would cost
~51 MB of static Swift runtime per ABI to serve 2 MB of weights. See
[ANDROID.md](../../ANDROID.md) for the measurements.

Works unchanged on the JVM and on Android, using only `java.text.Normalizer` and
`java.util.regex`.

## Install

```kotlin
dependencies { implementation("ai.desertant:tongue:0.1.1") }
```

## Saying "I don't know"

Short input is often genuinely undecidable, and the SDK says so rather than
guessing.

```kotlin
val detection = tongue.detect("la casa")
detection.isTooCloseToCall   // true — equally Italian and Spanish
detection.reliability        // TENTATIVE
detection.candidates         // [it 0.31, es 0.29, …]
```

Present both when `isTooCloseToCall` is set, and treat `TENTATIVE` as "unknown"
rather than as an answer.

## The cross-platform contract

The normalizer, hasher and router are a **frozen specification** shared with the
Python reference and the Swift and JavaScript SDKs. `GoldenVectorTest` replays the
same vector files all of them do, including whole-bag hasher equality:

```
./gradlew goldenVectors
```

Regenerate the Unicode tables rather than editing them:

```
python3 scripts/gen_kotlin_tables.py --reference ../tongue-training
```

## Model

Weights, benchmarks and limitations: [huggingface.co/desert-ant-labs/tongue](https://huggingface.co/desert-ant-labs/tongue).
Read the model card's failure modes before deploying.

## Licence

[Desert Ant Labs Source-Available Licence](https://license.desertant.com/1.0).
Free for most apps; a commercial licence is required at scale.
