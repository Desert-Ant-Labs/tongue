#if !os(WASI)
import FFIBuffer
import Tongue

// C ABI over the Tongue core, called by the Swift JNI entry points in
// `AndroidJNI.swift` and usable from any other host language. Foundation-free, so
// the Android build ships without the ~50 MB Foundation/ICU stack. Instance-based,
// mirroring the Swift SDK: one `Tongue` per handle.
//
//   tongue_create(metaUTF8, weights, weightsLen)  -> handle | NULL
//   tongue_detect(handle, textUTF8, topK)         -> buffer | NULL
//   tongue_destroy(handle)
//   tongue_buffer_free(ptr)
//
// Simpler than emo's surface because there is nothing to download and no
// tokenizer: the weights are 2 MB, so the AAR bundles them and hands the bytes
// straight in. No cache root, no model store, and nothing async — a detection is
// pure arithmetic, so unlike emo there is no `blockingValue` bridge either.
//
// Detections come back as a self-describing binary buffer rather than
// hand-rolled JSON, matching emo's convention (ffiEmit prefixes a big-endian u32
// payload length):
//
//   u32  reliability   0 confident, 1 likely, 2 tentative, 3 empty
//   u32  verdict       0 decisive, 1 narrowing, 2 ambiguous
//   u32  count
//   count x { u32 codeLen, codeLen bytes UTF-8 language code, f64 probability }

/// A retained box so the opaque handle keeps its `Tongue` alive.
private final class Handle {
    let tongue: Tongue
    init(_ tongue: Tongue) { self.tongue = tongue }
}

private func instance(_ handle: UnsafeMutableRawPointer?) -> Tongue? {
    guard let handle else { return nil }
    return Unmanaged<Handle>.fromOpaque(handle).takeUnretainedValue().tongue
}

private func reliabilityCode(_ value: Reliability) -> Int {
    switch value {
    case .confident: 0
    case .likely: 1
    case .tentative: 2
    case .empty: 3
    }
}

private func verdictCode(_ value: Verdict) -> Int {
    switch value {
    case .decisive: 0
    case .narrowing: 1
    case .ambiguous: 2
    }
}

/// Create a detector from the bundled metadata JSON and weight bytes.
/// Returns NULL if the metadata is malformed or the weights do not match it.
@_cdecl("tongue_create")
public func tongue_create(
    _ metadataJSON: UnsafePointer<CChar>?,
    _ weights: UnsafePointer<UInt8>?,
    _ weightsLength: Int32
) -> UnsafeMutableRawPointer? {
    guard let metadataJSON, let weights, weightsLength > 0 else { return nil }
    let bytes = [UInt8](UnsafeBufferPointer(start: weights, count: Int(weightsLength)))
    guard let tongue = try? Tongue(
        metadataJSON: String(cString: metadataJSON), weightBytes: bytes
    ) else { return nil }
    return Unmanaged.passRetained(Handle(tongue)).toOpaque()
}

/// Identify the language of `text`. See the buffer layout above.
@_cdecl("tongue_detect")
public func tongue_detect(
    _ handle: UnsafeMutableRawPointer?,
    _ text: UnsafePointer<CChar>?,
    _ topK: Int32
) -> UnsafeMutablePointer<CChar>? {
    guard let tongue = instance(handle), let text else { return nil }
    let detection = tongue.detect(String(cString: text), topK: Int(max(1, topK)))

    var writer = FFIWriter()
    writer.u32(reliabilityCode(detection.reliability))
    writer.u32(verdictCode(detection.route.verdict))
    writer.u32(detection.candidates.count)
    for candidate in detection.candidates {
        writer.string(candidate.language)
        writer.f64(candidate.probability)
    }
    return ffiEmit(writer.bytes)
}

@_cdecl("tongue_destroy")
public func tongue_destroy(_ handle: UnsafeMutableRawPointer?) {
    guard let handle else { return }
    Unmanaged<Handle>.fromOpaque(handle).release()
}

@_cdecl("tongue_buffer_free")
public func tongue_buffer_free(_ pointer: UnsafeMutablePointer<CChar>?) {
    ffiFree(pointer)
}
#endif
