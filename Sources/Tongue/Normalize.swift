import Foundation

// The pinned input normalizer, ported from the Python reference in
// src/tongue_training/normalize.py. That module is a frozen specification, not
// an implementation detail: this file must reproduce its output exactly, or the
// model sees different features here than it was trained on. The contract is
// docs/normalizer.md plus golden/normalize_vectors.json, replayed by
// TongueTests — change one and you change all of them, in the same commit.
//
// Foundation-only, and therefore dependency-free. This package targets Apple
// platforms; Android is served by the direct Kotlin port in
// packages/tongue-kotlin and the web by packages/tongue-js, so there is nothing
// to gain from desert-ant-core's host-delegated Regex here — and pulling it in
// costs consumers a Swift 6.2 toolchain floor, since core depends on
// JavaScriptKit. See ANDROID.md.
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
    // Compiled once: rebuilding five expressions per call would dominate a
    // detection that otherwise costs tens of microseconds. `NSRegularExpression`
    // is documented immutable and thread-safe, so sharing them is safe.
    private static let url = pattern(#"(?:https?://|www\.)\S+"#, ignoringCase: true)
    private static let email = pattern(#"\S+@\S+\.\S+"#)
    private static let mention = pattern(#"[@#]\w+"#)
    private static let digits = pattern(#"\d+"#)
    private static let whitespace = pattern(#"\s+"#)

    // Emoji, symbol modifiers and invisible formatting characters: they carry no
    // language signal but do perturb the n-gram bag.
    private static let discardedCategories: Set<Unicode.GeneralCategory> = [
        .otherSymbol, .modifierSymbol, .format, .privateUse, .unassigned,
    ]

    private static func pattern(_ source: String, ignoringCase: Bool = false) -> NSRegularExpression {
        // Force-try: these are literals in this file, so a bad pattern is a
        // programming error the first test run catches, not a runtime path.
        try! NSRegularExpression(pattern: source, options: ignoringCase ? [.caseInsensitive] : [])
    }

    /// Replace every match with a single space.
    private static func replacingMatches(_ expression: NSRegularExpression, in text: String) -> String {
        expression.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " "
        )
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

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
    }

    /// Whitespace tokens of already-normalized text.
    public static func tokens(_ text: String) -> [String] {
        text.isEmpty ? [] : text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    }
}
