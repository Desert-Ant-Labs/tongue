# tongue — on-device language identification for Swift, Kotlin and JavaScript

**tongue identifies the language of short text — a word, a phrase, a sentence —
entirely on the device, with no network call and no inference runtime.** It
returns an ISO language code, ranked alternatives with probabilities, and an
explicit "not sure" signal. One 2 MB model, three SDKs, identical answers on all
of them.

```swift
let tongue = try Tongue()
tongue.detect("kann ich das haben").language   // "de"
```

| | |
|---|---|
| **Languages** | 84 codes: 59 decoded by the model, 25 more settled by script alone |
| **Model size** | 2,104,940 bytes (int8), shipped inside the package |
| **Latency** | ~17 µs per detection (Node 23, Apple M-series, 20,000 iterations) |
| **Added to an Android APK** | ~2.5 MB total, **0** native libraries |
| **Added to a web bundle** | ~11 kB gzip of JavaScript; the model is fetched separately |
| **Dependencies** | none on npm; kotlin-stdlib on Maven; desert-ant-core on SwiftPM |
| **Network** | never for detection — see [Usage reporting](#usage-reporting) |
| **Licence** | [source-available](https://license.desertant.com/1.0), free below a threshold |

Platforms: iOS 16+ · macOS 13+ · tvOS 16+ · watchOS 9+ · visionOS 1+ · Android 24+ ·
JVM 17+ · browsers · Node 18+ · Deno · Bun.

*Last updated: 28 July 2026 · version 0.1.1*

---

## Install and use

Each block below is complete and standalone. Copy one.

### Swift (iOS, macOS, tvOS, watchOS, visionOS)

```swift
// Package.swift
.package(url: "https://github.com/Desert-Ant-Labs/tongue.git", from: "0.1.1")
```

```swift
import Tongue

let tongue = try Tongue()                      // loads the bundled 2 MB model
let detection = tongue.detect("kann ich das haben")

detection.language          // "de"
detection.reliability       // .confident
detection.candidates        // [Prediction(language: "de", probability: 0.999…), …]
detection.isTooCloseToCall  // false
```

**Requires Swift 6.2 tooling** (Xcode 26 or newer, or a swiftly toolchain).
`desert-ant-core` depends on JavaScriptKit, whose manifest declares
swift-tools 6.2, so an older Xcode resolves the package and then fails to build
it. This is the single most common setup failure.

### Kotlin (Android and JVM)

```kotlin
// build.gradle.kts
implementation("ai.desertant:tongue:0.1.1")
```

```kotlin
import ai.desertant.tongue.Tongue

// Android: pass the Context. On a bare JVM call Tongue.bundled().
val tongue = Tongue.bundled(context)
val detection = tongue.detect("kann ich das haben")

detection.language          // "de"
detection.reliability       // Reliability.CONFIDENT
detection.candidates        // [Prediction("de", 0.999…), …]
detection.isTooCloseToCall  // false
```

No native library, no NDK, no ABI splits — it is a plain jar that runs unchanged
on Android and on the JVM. On Android, pass the `Context`: without one there is
nowhere durable to store the usage device id.

### JavaScript and TypeScript (browser, Node, Deno, Bun)

```bash
npm install @desert-ant-labs/tongue
```

```ts
import { Tongue } from "@desert-ant-labs/tongue";

const tongue = await Tongue.load();            // Node: reads the bundled model
const detection = tongue.detect("kann ich das haben");

detection.language          // "de"
detection.reliability       // "confident"
detection.candidates        // [{ language: "de", probability: 0.999… }, …]
detection.isTooCloseToCall  // false
```

**In a browser you must serve the model yourself and pass `from`.** A bundler does
not serve files out of `node_modules`, so `Tongue.load()` with no argument
resolves against the page URL and, on a single-page app, fetches `index.html`.

Copy both files into your static directory as a build step:

```bash
cp node_modules/@desert-ant-labs/tongue/dist/tongue_int8.bin \
   node_modules/@desert-ant-labs/tongue/dist/tongue_meta.json \
   public/models/tongue/
```

```ts
const tongue = await Tongue.load({ from: "/models/tongue" });
```

That is verified end to end in a Vite build running in headless Chromium.

Both files are exported subpaths, so a copy script can locate them without
assuming a `node_modules` layout — which is what makes this work under pnpm and
Yarn PnP:

```js
// copy-model.mjs
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const bin = require.resolve("@desert-ant-labs/tongue/model/tongue_int8.bin");
const meta = require.resolve("@desert-ant-labs/tongue/model/tongue_meta.json");
```

A word of warning about the `?url` form: `load` takes one base directory, so both
files have to sit under it, and Vite inlines assets below `assetsInlineLimit`
(4 kB by default) as `data:` URIs. `tongue_meta.json` is 2.4 kB, so it gets
inlined while the 2 MB `.bin` does not, and any base path derived from the two
disagrees. Either set `assetsInlineLimit: 0` or use the copy step above.

---

## What `detect` returns

`detect(text, topK = 3)` returns a `Detection`:

| Field | Type | Meaning |
|---|---|---|
| `language` | `String?` | Top candidate's ISO code, or null on empty input |
| `candidates` | `[Prediction]` | Ranked, each with `language` and `probability` |
| `reliability` | enum | `confident` · `likely` · `tentative` · `empty` |
| `isTooCloseToCall` | `Bool` | Top two are within 0.12 of each other |
| `normalized` | `String` | The text after normalization, as the model saw it |
| `route.verdict` | enum | `decisive` (script alone settled it) · `narrowing` · `ambiguous` |

`route.verdict` is an enum on `route`, not on `Detection` itself.

---

## Handling "I don't know"

**Short text is often genuinely undecidable, and tongue says so instead of
guessing.** Reliability is keyed off evidence — input length and how far the top
candidate leads the runner-up — not raw softmax confidence, which is badly
overconfident on two words.

```swift
let detection = tongue.detect("la casa")
detection.isTooCloseToCall   // true — equally Italian and Spanish
detection.reliability        // .tentative
detection.candidates         // [it 0.305, es 0.295, ca 0.271]
```

Recommended handling:

1. If `isTooCloseToCall`, present both candidates rather than crowning one.
2. Treat `tentative` as "unknown", not as an answer.
3. Ask for more text where the product allows it — reliability improves sharply
   past about 18 characters.

---

## Known failure modes

Read these before shipping. They are properties of the model, not bugs:

- **One or two words is often genuinely ambiguous.** `"la casa"` is equally
  Italian and Spanish; no model resolves that from the text alone.
- **Malay and Indonesian are not reliably separable** at this size. They share
  most of their vocabulary.
- **Mongolian works only in the traditional script**, not Cyrillic Mongolian.
- **Brand names, product codes and version strings are not language.**
  `"Samsung Galaxy"` has no correct answer.
- **Code-switched text** returns the dominant language, not a list.

Full benchmarks and per-language accuracy:
[huggingface.co/desert-ant-labs/tongue](https://huggingface.co/desert-ant-labs/tongue).

---

## FAQ

**Does any text leave the device?**
No. Detection is pure arithmetic on bundled weights and never touches the
network. A separate licence-metering event reports a generated UUID and a count —
never text, results, or anything about the user. See
[Usage reporting](#usage-reporting).

**How do I turn off telemetry?**
Set `DAL_USAGE_DISABLED=1` (or `globalThis.__dalUsageDisabled = "1"` in a
browser). No client is constructed at all.

**Does it need a network connection?**
No. The model ships inside the package on every platform.

**Why is my Swift build failing to resolve the package?**
You are on Swift 6.1 or older. The package needs 6.2 tooling — Xcode 26+.

**Why does `Tongue.load()` fail in my React app?**
In a browser it needs `{ from: "/path/where/you/serve/the/model" }`. See the
JavaScript section above.

**Does it work with Next.js, webpack, Create React App?**
Yes, from 0.1.1. The browser build contains no Node built-ins.

**How big is it really?**
The model is 2,104,940 bytes on every platform. An Android APK grows ~2.5 MB
with zero native libraries; a web bundle grows ~11 kB gzip of JavaScript plus the
separately-fetched model.

**Do the three SDKs give identical answers?**
Yes, to nine decimal places. All three replay the same golden vectors as the
Python reference, and the vectors pin the normalizer, hasher, router and the
model's output probabilities.

**Which languages are supported?**
84 codes. 59 are decoded by the model; 25 more are settled by script alone
(Hangul → `ko`, Thai → `th`, Cherokee → `chr`, and so on) with no model involved.

---

## How it works

Two stages, and the first often finishes the job.

A **script router** with zero parameters reads the Unicode scripts present. Text
in a script only one language uses — Hangul, Greek, Thai, Cherokee — is decided
outright. Shared scripts (Latin, Cyrillic, Arabic, Devanagari) narrow the
candidate set instead.

The **head** then decodes among the remaining candidates: FNV-1a-hashed character
n-grams of orders 1–5, boundary-marked so `ão$` and `^gli` stay distinct from
word-internal sequences, summed through an int8 embedding table into a linear
layer with a per-script masked softmax. A detection is a few thousand
multiply-adds — no tokenizer, no inference runtime, nothing to hand an
accelerator.

Hashing instead of a vocabulary is why there is no tokenizer file to ship or
version-match.

## The cross-platform contract

The normalizer, hasher, router and head output are a **frozen specification**
shared with the Python reference. Vectors are generated in the reference repo and
copied into each port, so all three replay the same files — including whole-bag
equality on the hasher and probability equality on the head.

This matters because regex character classes are engine-defined: `\w`, `\d` and
`\s` mean different things in ICU, `java.util.regex` and JavaScript, and Unicode
data moves with the host runtime. Every such class is written out explicitly, and
the discard table is pinned to Unicode 13.0.0 — the version the model was trained
against — so the same input yields the same features on every device.

Regenerate rather than hand-editing:

```bash
mise run gen-tables
```

## Examples

`Examples/` has one runnable project per platform: a SwiftUI iOS app, an Android
app, a browser page, and two console programs that print identical probabilities
for the same inputs.

```bash
mise run examples      # the two console examples
mise run example-web   # browser demo on localhost:8710
mise run test          # every suite, all three ports
```

## Usage reporting

Detection is entirely on device. Separately, the SDK reports usage so the licence
can be metered: **a generated UUID, the app's bundle id or package name, and a
count of detections.** No text, no results, nothing about the user or the machine.

A device is counted at most once a day, though that is not one request a day —
after the daily event opens, further detections ride small delta events on a
3-second debounce, and a browser uses a 30-minute window. Extra events cannot
over-bill: the server counts distinct devices per month.

Switch it off with `DAL_USAGE_DISABLED=1`. Full wire format and rationale:
[docs/USAGE.md](docs/USAGE.md).

## Licence

[Desert Ant Labs Source-Available Licence 1.0](https://license.desertant.com/1.0).
Free for most applications; a commercial licence is required at scale.
Licensing: <licensing@desertant.com>.
