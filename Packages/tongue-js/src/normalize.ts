// The pinned input normalizer, ported from src/tongue_training/normalize.py.
//
// That module is a frozen specification, not an implementation detail: this file
// must reproduce its output exactly, or the model sees different features here
// than it was trained on. The contract is docs/normalizer.md plus
// golden/normalize_vectors.json, replayed by test/golden.test.ts.
//
// Porting hazards this file is deliberate about:
//
//   NFC, not NFKC. Canonical composition only. NFKC also folds compatibility
//     characters ("ﬁ" -> "fi", "½" -> "1⁄2"), changing the character sequence and
//     therefore every n-gram derived from it.
//   Code-point truncation. Python slices by code point, so the 512 cap counts
//     code points. `String.prototype.slice` counts UTF-16 units and would cut
//     astral characters in half.
//   Unicode property escapes. `\p{...}` needs the `u` flag; the general-category
//     filter mirrors Python's `unicodedata.category`.

export const MAX_CHARACTERS = 512;

// Order is part of the contract; see `normalize`.
const URL_RE = /(?:https?:\/\/|www\.)\S+/giu;
const EMAIL_RE = /\S+@\S+\.\S+/gu;
const MENTION_RE = /[@#][\p{L}\p{N}_]+/gu;
const DIGIT_RE = /\p{Nd}+/gu;
// Emoji, symbol modifiers and invisible formatting characters: no language
// signal, but they do perturb the n-gram bag. So, Sk, Cf, Co, Cn.
const DISCARD_RE = /[\p{So}\p{Sk}\p{Cf}\p{Co}\p{Cn}]/gu;
const WHITESPACE_RE = /\s+/gu;

/**
 * Apply the frozen normalization pipeline.
 *
 * 1. Unicode NFC
 * 2. remove URLs, then emails, then @mentions and #hashtags
 * 3. remove digit runs
 * 4. remove symbol and format characters
 * 5. invariant lowercase
 * 6. collapse whitespace runs to one space and trim the ends
 * 7. truncate to MAX_CHARACTERS code points
 */
export function normalize(text: string): string {
  let result = text.normalize("NFC");
  result = result.replace(URL_RE, " ").replace(EMAIL_RE, " ").replace(MENTION_RE, " ");
  result = result.replace(DIGIT_RE, " ").replace(DISCARD_RE, "");
  result = result.toLowerCase();
  result = result.replace(WHITESPACE_RE, " ").trim();
  // Spread iterates by code point, so this truncates the way Python does.
  const codePoints = [...result];
  return codePoints.length > MAX_CHARACTERS
    ? codePoints.slice(0, MAX_CHARACTERS).join("")
    : result;
}

/** Whitespace tokens of already-normalized text. */
export function tokens(text: string): string[] {
  return text ? text.split(" ") : [];
}
