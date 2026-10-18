import Foundation

/// Silence-based commits preserve negations inside a phrase. Audio is never persisted here.
public struct VoiceActivity {
    private var began: TimeInterval?; private var lastSpeech: TimeInterval = 0
    public init() {}
    public mutating func accept(rms: Double, now: TimeInterval) -> Bool {
        if rms > 0.012 { if began == nil { began = now }; lastSpeech = now }
        if let start = began, now - start > 0.4, now - lastSpeech > 1.2 { began = nil; return true }; return false
    }
}
/// Input must already be mono signed PCM16 at 16 kHz. Bounded to ten seconds.
public struct ExcerptBuffer {
    private var pcm = Data()
    public init() {}
    public mutating func append(_ bytes: Data) {
        pcm.append(bytes.prefix(bytes.count - bytes.count % 2)); if pcm.count > 320_000 { pcm.removeFirst(pcm.count - 320_000) }
    }
    public mutating func clear() { pcm.resetBytes(in: 0..<pcm.count); pcm.removeAll(keepingCapacity: false) }
    public func wav() -> Data? {
        guard pcm.count >= 32_000 else { return nil }
        var data = Data("RIFF".utf8)
        func u32(_ n: UInt32) { var v = n.littleEndian; data.append(Data(bytes: &v, count: 4)) }
        func u16(_ n: UInt16) { var v = n.littleEndian; data.append(Data(bytes: &v, count: 2)) }
        u32(UInt32(pcm.count + 36)); data.append(Data("WAVEfmt ".utf8)); u32(16); u16(1); u16(1); u32(16_000); u32(32_000); u16(2); u16(16); data.append(Data("data".utf8)); u32(UInt32(pcm.count)); data.append(pcm); return data
    }
}
