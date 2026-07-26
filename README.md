# tongue — SDKs for Apple, Android and the web

On-device language identification for short text, across 83 languages. Names the
language of a word, a phrase or a sentence in tens of microseconds, entirely on
device.

| platform | package | status |
|---|---|---|
| iOS · macOS · tvOS · watchOS · visionOS | this repo (SwiftPM) | golden vectors passing |
| Android · JVM | [`packages/tongue-kotlin`](packages/tongue-kotlin) | golden vectors passing |
| Browser · Node | [`packages/tongue-js`](packages/tongue-js) | golden vectors passing |

Every platform is a direct port held to the same frozen specification, and all
three replay the same golden vectors as the Python reference. Run everything with
`mise run test`.

```swift
import Tongue

let tongue = try Tongue()
tongue.detect("kann ich das haben").language   // "de"
tongue.detect("안녕하세요").language             // "ko"
```

No ML runtime, no dependencies, no tokenizer. A detection is an int8 embedding
gather, a sum, one 59×32 matmul and a masked softmax — a few thousand
multiply-adds. The 2 MB weights ship inside the package.

## Install

```swift
.package(url: "https://github.com/Desert-Ant-Labs/tongue.git", from: "0.1.0")
```

Requires iOS 16 / macOS 13 / tvOS 16 / watchOS 9 / visionOS 1.

## Saying "I don't know"

Short input is often genuinely undecidable, and the SDK says so rather than
guessing. Reliability is keyed off evidence — input length and how far the top
candidate leads the runner-up — not raw softmax confidence, which is badly
overconfident on two words.

```swift
let detection = tongue.detect("la casa")
detection.isTooCloseToCall     // true — equally Italian and Spanish
detection.reliability          // .tentative
detection.candidates           // [it 0.31, es 0.29, ...]
```

Present both when `isTooCloseToCall` is set. Treat `.tentative` as "unknown"
rather than as an answer, and ask for more text where the product allows it.

## What the API gives you

| | |
|---|---|
| `detect(_:topK:)` | `Detection` — ranked candidates, reliability, and which stage answered |
| `Detection.language` | top candidate, or `nil` on empty input |
| `Detection.candidates` | `[Prediction]` with probabilities |
| `Detection.reliability` | `.confident` · `.likely` · `.tentative` · `.empty` |
| `Detection.isTooCloseToCall` | top two within 0.12 |
| `Detection.route` | `.decisive` (script alone settled it) · `.narrowing` · `.ambiguous` |
| `Tongue(weightsURL:metadataURL:)` | load from disk instead of the bundle |

## How it works

Two stages, and the first one often finishes the job.

A **script router** with zero parameters reads the Unicode scripts present. Text
in a script only one language uses — Hangul, Greek, Thai — is decided outright,
no model involved. Shared scripts (Cyrillic, Arabic, Devanagari, Bengali) are
narrowed to their candidate languages first.

The **head** then decodes among the remaining candidates: FNV-1a-hashed character
n-grams of orders 1–5, boundary-marked so `ão$` and `^gli` stay distinct from
word-internal sequences, summed through an int8 embedding table into a linear
layer with a per-script masked softmax.

Hashing instead of a vocabulary is why there is no tokenizer file to ship or
version-match, and why every platform produces identical bucket indices by
construction.

## The cross-platform contract

The normalizer, hasher and router are a **frozen specification** shared with the
Python reference implementation and the other SDKs. `Tests/TongueTests` replays
`golden/normalize_vectors.json`, `hashing_vectors.json` and `script_vectors.json`
so a port cannot drift silently — including whole-bag equality on the hasher,
which catches boundary marking and n-gram coverage that per-string hashes miss.

Regenerate the Unicode tables rather than editing them:

```
python3 scripts/gen_swift_tables.py --reference ../tongue-training
```

## Tests

```
swift test
```

XCTest needs the full Xcode toolchain; if `xcode-select -p` points at
CommandLineTools, run:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Model

Weights, benchmarks and limitations: [huggingface.co/desert-ant-labs/tongue](https://huggingface.co/desert-ant-labs/tongue).
Live demo: [desert-ant-labs-tongue-demo.static.hf.space](https://desert-ant-labs-tongue-demo.static.hf.space/).

Read the model card's failure modes before deploying. In short: one or two words
is often genuinely ambiguous; Malay and Indonesian are not reliably separable at
this size; Mongolian works only in the traditional script; and brand names and
version strings are not language at all.

## Licence

[Desert Ant Labs Source-Available Licence](https://license.desertant.com/1.0).
Free for most apps; a commercial licence is required at scale.
Licensing: <licensing@desertant.com>.
