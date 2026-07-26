package ai.desertant.tongue

import java.text.Normalizer as JavaNormalizer

/**
 * The pinned input normalizer, ported from src/tongue_training/normalize.py.
 *
 * That module is a frozen specification, not an implementation detail: this file
 * must reproduce its output exactly, or the model sees different features here
 * than it was trained on. The contract is docs/normalizer.md plus
 * golden/normalize_vectors.json, replayed by GoldenVectorTest.
 *
 * Porting hazards this file is deliberate about:
 *
 *  - **NFC, not NFKC.** Canonical composition only. NFKC also folds compatibility
 *    characters (U+FB01 to "fi", U+00BD to "1/2"), changing the character
 *    sequence and therefore every n-gram derived from it.
 *  - **Code-point truncation.** Python slices by code point, so the 512 cap counts
 *    code points, not UTF-16 `char`s. A string of astral characters would
 *    otherwise truncate at half the length.
 *  - **Invariant lowercase.** `lowercase()` with no locale is Unicode-default;
 *    `lowercase(Locale.getDefault())` would diverge under a Turkish locale.
 *  - **Category filter.** `Character.getType` matches Python's
 *    `unicodedata.category` for the five classes dropped here.
 */
public object Normalizer {
    public const val MAX_CHARACTERS: Int = 512

    // Order is part of the contract; see [normalize].
    private val URL = Regex("""(?:https?://|www\.)\S+""", RegexOption.IGNORE_CASE)
    private val EMAIL = Regex("""\S+@\S+\.\S+""")
    private val MENTION = Regex("""[@#]\w+""")
    private val DIGITS = Regex("""\d+""")
    private val WHITESPACE = Regex("""\s+""")

    // Emoji, symbol modifiers and invisible formatting characters: no language
    // signal, but they do perturb the n-gram bag. Java's int constants for
    // Unicode general categories So, Sk, Cf, Co, Cn.
    private val DISCARDED = setOf(
        Character.OTHER_SYMBOL.toInt(),
        Character.MODIFIER_SYMBOL.toInt(),
        Character.FORMAT.toInt(),
        Character.PRIVATE_USE.toInt(),
        Character.UNASSIGNED.toInt(),
    )

    /**
     * Apply the frozen normalization pipeline.
     *
     * 1. Unicode NFC
     * 2. remove URLs, then emails, then @mentions and #hashtags
     * 3. remove digit runs
     * 4. remove symbol and format characters
     * 5. invariant lowercase
     * 6. collapse whitespace runs to one space and trim the ends
     * 7. truncate to [MAX_CHARACTERS] code points
     */
    public fun normalize(text: String): String {
        var result = JavaNormalizer.normalize(text, JavaNormalizer.Form.NFC)
        result = URL.replace(result, " ")
        result = EMAIL.replace(result, " ")
        result = MENTION.replace(result, " ")
        result = DIGITS.replace(result, " ")
        result = dropDiscardedCategories(result)
        result = result.lowercase()
        result = WHITESPACE.replace(result, " ").trim()
        return truncateToCodePoints(result, MAX_CHARACTERS)
    }

    private fun dropDiscardedCategories(text: String): String {
        val out = StringBuilder(text.length)
        var index = 0
        while (index < text.length) {
            val codePoint = text.codePointAt(index)
            if (Character.getType(codePoint) !in DISCARDED) out.appendCodePoint(codePoint)
            index += Character.charCount(codePoint)
        }
        return out.toString()
    }

    /** Truncate by code point, matching Python's string slice. */
    private fun truncateToCodePoints(text: String, limit: Int): String {
        if (text.codePointCount(0, text.length) <= limit) return text
        return text.substring(0, text.offsetByCodePoints(0, limit))
    }

    /** Whitespace tokens of already-normalized text. */
    public fun tokens(text: String): List<String> =
        if (text.isEmpty()) emptyList() else text.split(" ")
}
