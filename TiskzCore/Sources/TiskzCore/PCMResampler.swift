#if canImport(AVFAudio)
import Foundation
@preconcurrency import AVFAudio

/// Confine an instance to one serial executor. No audio device or disk is opened.
public final class PCMResampler {
    private var converter: AVAudioConverter?
    private var rate: Double = 0
    public init() {}
    public func reset() { converter = nil; rate = 0 }
    public func convert(_ data: Data, sampleRate: Double) -> Data? {
        guard (8_000...192_000).contains(sampleRate), !data.isEmpty, data.count % 2 == 0, data.count <= 65_536,
              let input = AVAudioFormat(commonFormat:.pcmFormatInt16, sampleRate:sampleRate, channels:1, interleaved:true),
              let output = AVAudioFormat(commonFormat:.pcmFormatInt16, sampleRate:16_000, channels:1, interleaved:true) else { return nil }
        if converter == nil || rate != sampleRate { converter = AVAudioConverter(from:input, to:output); rate = sampleRate }
        let count = data.count / 2
        guard let converter, let pcm = AVAudioPCMBuffer(pcmFormat:input, frameCapacity:AVAudioFrameCount(count)),
              let converted = AVAudioPCMBuffer(pcmFormat:output, frameCapacity:AVAudioFrameCount(Double(count) * 16000 / sampleRate + 64)) else { return nil }
        pcm.frameLength = AVAudioFrameCount(count)
        _ = data.withUnsafeBytes { bytes in memcpy(pcm.mutableAudioBufferList.pointee.mBuffers.mData!, bytes.baseAddress!, data.count) }
        let frame = InputFrame(pcm)
        var error: NSError?
        converter.convert(to:converted, error:&error) { _, status in frame.take(status) }
        guard error == nil, converted.frameLength > 0, let samples = converted.int16ChannelData?[0] else { return nil }
        return Data(bytes:samples, count:Int(converted.frameLength) * 2)
    }
}
/// Immutable sample storage; the only mutable field is protected by the lock.
private final class InputFrame: @unchecked Sendable {
    private let pcm: AVAudioPCMBuffer
    private let lock = NSLock()
    private var supplied = false
    init(_ pcm: AVAudioPCMBuffer) { self.pcm = pcm }
    func take(_ status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        lock.lock(); defer { lock.unlock() }
        if supplied { status.pointee = .noDataNow; return nil }
        supplied = true; status.pointee = .haveData; return pcm
    }
}
#endif
