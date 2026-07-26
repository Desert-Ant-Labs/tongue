import XCTest
@testable import Tongue

// The golden vectors are the cross-platform contract. The Python reference, this
// SDK, and the JavaScript port all replay the same files; if any of them drifts,
// the model sees different features on that platform and the implementations
// disagree silently. These tests exist so that drift fails loudly instead.
//
// Regenerate with `python scripts/gen_golden.py` in the training repo, in the
// same commit as any change to the normalizer, hasher or router spec.

final class GoldenVectorTests: XCTestCase {
    private func vectors(_ name: String) throws -> [String: Any] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw XCTSkip("\(name).json missing from the test bundle")
        }
        guard let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            XCTFail("\(name).json is not a JSON object")
            return [:]
        }
        return root
    }

    func testNormalizerMatchesReference() throws {
        let root = try vectors("normalize_vectors")
        let cases = root["cases"] as? [[String: Any]] ?? []
        XCTAssertFalse(cases.isEmpty, "no normalizer cases loaded")
        for entry in cases {
            let input = entry["input"] as? String ?? ""
            let expected = entry["output"] as? String ?? ""
            XCTAssertEqual(
                Normalizer.normalize(input), expected,
                "normalize(\(input.debugDescription)) diverged from the reference"
            )
        }
        // The cap is counted in Unicode scalars, matching Python's code-point
        // slice — not grapheme clusters and not UTF-16 units.
        if let cap = root["max_chars"] as? Int {
            XCTAssertEqual(Normalizer.maxCharacters, cap)
            let long = String(repeating: "é", count: cap + 50)
            XCTAssertEqual(Normalizer.normalize(long).unicodeScalars.count, cap)
        }
    }

    func testHasherMatchesReference() throws {
        let root = try vectors("hashing_vectors")
        XCTAssertEqual(Hashing.offsetBasis, UInt32(root["offset_basis"] as? Int ?? 0))
        XCTAssertEqual(Hashing.prime, UInt32(root["prime"] as? Int ?? 0))

        for entry in root["fnv1a"] as? [[String: Any]] ?? [] {
            let input = entry["input"] as? String ?? ""
            let expected = UInt32(entry["hash"] as? Int ?? 0)
            XCTAssertEqual(
                Hashing.fnv1a(input), expected,
                "fnv1a(\(input.debugDescription)) diverged from the reference"
            )
        }

        // Whole-bag equality: catches boundary marking, n-gram order coverage and
        // the modulo, which per-string hashes alone would not.
        let buckets = root["num_buckets"] as? Int ?? 262_144
        let orders = root["ngram_orders"] as? [Int] ?? Hashing.ngramOrders
        for entry in root["bags"] as? [[String: Any]] ?? [] {
            let normalized = entry["normalized"] as? String ?? ""
            let expected = (entry["bag"] as? [String: Int] ?? [:])
                .reduce(into: [Int: Int]()) { $0[Int($1.key) ?? -1] = $1.value }
            let actual = Hashing.buckets(normalized, numBuckets: buckets, orders: orders)
            XCTAssertEqual(actual, expected, "bag for \(normalized.debugDescription) diverged")
        }
    }

    func testRouterMatchesReference() throws {
        let cases = try vectors("script_vectors")["cases"] as? [[String: Any]] ?? []
        XCTAssertFalse(cases.isEmpty, "no router cases loaded")
        for entry in cases {
            let input = entry["input"] as? String ?? ""
            let normalized = Normalizer.normalize(input)
            XCTAssertEqual(normalized, entry["normalized"] as? String ?? normalized,
                           "normalization diverged before routing \(input.debugDescription)")

            let route = Router.route(normalized)
            XCTAssertEqual(route.verdict.rawValue, entry["verdict"] as? String ?? "",
                           "verdict diverged for \(input.debugDescription)")
            XCTAssertEqual(route.candidates, entry["candidates"] as? [String] ?? [],
                           "candidates diverged for \(input.debugDescription)")
            if let expectedScript = entry["script"] as? String {
                XCTAssertEqual(route.script?.rawValue, expectedScript,
                               "script diverged for \(input.debugDescription)")
            } else {
                XCTAssertNil(route.script, "expected no script for \(input.debugDescription)")
            }
        }
    }
}

final class DetectionTests: XCTestCase {
    private func makeTongue() throws -> Tongue {
        do { return try Tongue() }
        catch { throw XCTSkip("bundled model unavailable: \(error)") }
    }

    func testDetectsAcrossScripts() throws {
        let tongue = try makeTongue()
        let expectations: [(String, String)] = [
            ("je voudrais un café au lait", "fr"),
            ("kann ich das haben", "de"),
            ("muchas gracias por la ayuda", "es"),
            ("привет как твои дела", "ru"),
            ("안녕하세요 만나서 반갑습니다", "ko"),
            ("こんにちは、お元気ですか", "ja"),
            ("مرحبا كيف حالك اليوم", "ar"),
            ("the garage sale is on saturday morning", "en"),
        ]
        for (text, expected) in expectations {
            XCTAssertEqual(tongue.detect(text).language, expected,
                           "detect(\(text.debugDescription))")
        }
    }

    func testReportsTooCloseToCallRatherThanGuessing() throws {
        let tongue = try makeTongue()
        // "la casa" is equally Italian and Spanish; presenting one would be a lie.
        let detection = tongue.detect("la casa")
        XCTAssertTrue(detection.isTooCloseToCall)
        XCTAssertEqual(detection.reliability, .tentative)
    }

    func testShortInputIsNotReportedConfident() throws {
        let tongue = try makeTongue()
        // Reads as Welsh to any character model. The point is that it says so.
        XCTAssertEqual(tongue.detect("hi i am").reliability, .tentative)
    }

    func testEmptyInput() throws {
        let tongue = try makeTongue()
        let detection = tongue.detect("   ")
        XCTAssertEqual(detection.reliability, .empty)
        XCTAssertNil(detection.language)
    }
}
