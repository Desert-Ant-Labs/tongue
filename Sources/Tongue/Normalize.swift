import Regex

// The pinned input normalizer, ported from the Python reference in
// src/tongue_training/normalize.py. That module is a frozen specification, not
// an implementation detail: this file must reproduce its output exactly, or the
// model sees different features here than it was trained on. The contract is
// docs/normalizer.md plus golden/normalize_vectors.json, replayed by
// TongueTests — change one and you change all of them, in the same commit.
//
// Regex comes from desert-ant-core, the shared primitive every model SDK uses: on
// Android it routes through the host's java.util.regex, so the pipeline holds no
// platform code. NFC is still local (see NFC.swift) only because core's `nfc` is
// unreleased; that file documents how to delete itself once it ships.
//
// Porting hazards this file is deliberate about:
//
//   NFC, not NFKC.  Canonical composition only. NFKC also folds compatibility
//     characters (U+FB01 -> "fi", U+00BD -> "1/2"), which changes the character
//     sequence and therefore every n-gram derived from it.
//   Scalar truncation.  Python slices by code point, so the 512 cap counts
//     Unicode scalars — not grapheme clusters and not UTF-16 units.
//   Invariant lowercase.  `String.lowercased()` is Unicode-default, never
//     locale-aware: Turkish dotted/dotless I would otherwise diverge by locale.
//   General category.  `Unicode.Scalar.Properties.generalCategory` is stdlib,
//     so the symbol/format filter needs no platform support.
//
// Deliberately NOT done: diacritic stripping (ñ, ø, ő, ț are among the strongest
// language signals there are), stemming, or stopword removal.

public enum Normalizer {
    public static let maxCharacters = 512

    // Order is part of the contract; see `normalize(_:)`.
    //
    // `nonisolated(unsafe)` because `Pattern` is not `Sendable`: its wasm engine
    // wraps a `JSObject`, which genuinely is not, so the type cannot conform
    // unconditionally. Sharing these is safe regardless — each is immutable after
    // construction, the Foundation engine wraps an `NSRegularExpression`
    // (documented thread-safe), the Android engine holds a String and a Bool, and
    // wasm is single-threaded. Compiling them once matters: rebuilding five per
    // call would dominate a detection that costs tens of microseconds.
    private nonisolated(unsafe) static let url = pattern(#"(?:https?://|www\.)\S+"#, ignoringCase: true)
    private nonisolated(unsafe) static let email = pattern(#"\S+@\S+\.\S+"#)
    private nonisolated(unsafe) static let mention = pattern(#"[@#]\w+"#)
    private nonisolated(unsafe) static let digits = pattern(#"\d+"#)
    private nonisolated(unsafe) static let whitespace = pattern(#"\s+"#)

    // Emoji, symbol modifiers and invisible formatting characters: they carry no
    // language signal but do perturb the n-gram bag.
    private static let discardedCategories: Set<Unicode.GeneralCategory> = [
        .otherSymbol, .modifierSymbol, .format, .privateUse, .unassigned,
    ]

    private static func pattern(_ source: String, ignoringCase: Bool = false) -> Pattern {
        // Force-try: these are literals in this file, so a bad pattern is a
        // programming error the first test run catches, not a runtime path.
        let compiled = try! Pattern(source)
        return ignoringCase ? compiled.ignoresCase() : compiled
    }

    /// Replace every match with a single space.
    ///
    /// `Regex` reports match ranges rather than offering substitution, so this
    /// walks the matches in reverse and splices — reverse order keeps the earlier
    /// indices valid as the string is mutated.
    private static func replacingMatches(_ pattern: Pattern, in text: String) -> String {
        let matches = pattern.matches(in: text)
        guard !matches.isEmpty else { return text }
        var result = text
        for match in matches.reversed() { result.replaceSubrange(match.range, with: " ") }
        return result
    }

    /// Apply the frozen normalization pipeline.
    ///
    /// 1. Unicode NFC
    /// 2. remove URLs, then emails, then @mentions and #hashtags
    /// 3. remove digit runs
    /// 4. remove symbol and format characters
    /// 5. invariant lowercase
    /// 6. collapse whitespace runs to one space and trim the ends
    /// 7. truncate to `maxCharacters` Unicode scalars
    public static func normalize(_ text: String) -> String {
        var result = text.nfc
        result = replacingMatches(url, in: result)
        result = replacingMatches(email, in: result)
        result = replacingMatches(mention, in: result)
        result = replacingMatches(digits, in: result)
        result = String(String.UnicodeScalarView(
            result.unicodeScalars.filter { !discardedCategories.contains($0.properties.generalCategory) }
        ))
        result = result.lowercased()
        result = trimmed(replacingMatches(whitespace, in: result))
        guard result.unicodeScalars.count > maxCharacters else { return result }
        return String(String.UnicodeScalarView(result.unicodeScalars.prefix(maxCharacters)))
    }

    /// Hand-rolled so this file needs no Foundation: `Character.isWhitespace` is
    /// stdlib, and the only whitespace left by step 6 is the single spaces it
    /// collapsed to.
    private static func trimmed(_ text: String) -> String {
        var slice = Substring(text)
        while let first = slice.first, first.isWhitespace { slice.removeFirst() }
        while let last = slice.last, last.isWhitespace { slice.removeLast() }
        return String(slice)
    }

    /// Whitespace tokens of already-normalized text.
    public static func tokens(_ text: String) -> [String] {
        text.isEmpty ? [] : text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    }
}
