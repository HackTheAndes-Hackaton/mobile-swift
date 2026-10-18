import Foundation
import AVFoundation
import WebRTC
import TiskzCore

@MainActor final class VoicePeer: NSObject {
    private var factory: RTCPeerConnectionFactory?
    private var peer: RTCPeerConnection?
    private var channel: RTCDataChannel?
    private var track: RTCAudioTrack?
    private var device: TiskzAudioDevice?
    private var open = false
    var onEvent: (([String: Any]) -> Void)?
    var onOpen: (() -> Void)?
    var onError: (() -> Void)?
    var onSamples: ((Data, Double) -> Void)?
    func prepare() throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audio.setPreferredSampleRate(48_000); try audio.setPreferredIOBufferDuration(0.02); try audio.setActive(true)
        RTCInitializeSSL()
        let device = TiskzAudioDevice(); self.device = device
        device.onSamples = { [weak self] data, rate in Task { @MainActor [weak self] in guard self?.open == true else { return }; self?.onSamples?(data, rate) } }
        let f = RTCPeerConnectionFactory(encoderFactory: nil, decoderFactory: nil, audioDevice: device); factory = f
        let config = RTCConfiguration(); config.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let peer = f.peerConnection(with: config, constraints: constraints, delegate: self) else { throw ServiceError(message: "No se pudo crear WebRTC.") }; self.peer = peer
        let source = f.audioSource(with: constraints); let track = f.audioTrack(with: source, trackId: "tiskz-microphone")
        track.isEnabled = false; self.track = track; peer.add(track, streamIds: ["tiskz-voice"])
        channel = peer.dataChannel(forLabel: "oai-events", configuration: RTCDataChannelConfiguration()); channel?.delegate = self
    }
    func offer() async throws -> String {
        guard let peer else { throw ProtocolError.invalidResponse }
        let offer: RTCSessionDescription = try await withCheckedThrowingContinuation { c in peer.offer(for: RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio":"true"], optionalConstraints: nil)) { s, e in if let s { c.resume(returning: s) } else { c.resume(throwing: e ?? ProtocolError.invalidResponse) } } }
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in peer.setLocalDescription(offer) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
        let deadline = Date().addingTimeInterval(4)
        while peer.iceGatheringState != .complete && Date() < deadline { try await Task.sleep(for: .milliseconds(40)) }
        return peer.localDescription?.sdp ?? offer.sdp
    }
    func answer(_ sdp: String) async throws {
        guard let peer, sdp.hasPrefix("v=") else { throw ProtocolError.invalidResponse }
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in peer.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: sdp)) { e in if let e { c.resume(throwing:e) } else { c.resume() } } }
    }
    func send(_ event: [String: Any]) {
        guard let channel, channel.readyState == .open, let data = try? JSONSerialization.data(withJSONObject: event) else { return }
        if !channel.sendData(RTCDataBuffer(data: data, isBinary: false)) { onError?() }
    }
    func mute(_ value: Bool) { track?.isEnabled = !value && open }
    func close() {
        open = false; track?.isEnabled = false; channel?.delegate = nil; channel?.close(); peer?.delegate = nil; peer?.close()
        channel = nil; peer = nil; track = nil; factory = nil; device?.onSamples = nil; device = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
extension VoicePeer: RTCPeerConnectionDelegate, RTCDataChannelDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        if newState == .failed { Task { @MainActor in self.onError?() } }
        if newState == .disconnected { Task { @MainActor [weak self] in try? await Task.sleep(for: .seconds(5)); if self?.peer?.iceConnectionState == .disconnected { self?.onError?() } } }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    nonisolated func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let state = dataChannel.readyState
        Task { @MainActor in
            if state == .open { self.open = true; self.track?.isEnabled = true; self.onOpen?() }
            else if state == .closed && self.open { self.onError?() }
        }
    }
    nonisolated func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        guard !buffer.isBinary, buffer.data.count <= 20_000, let e = Wire.object(buffer.data) else { return }
        Task { @MainActor in if self.open { self.onEvent?(e) } }
    }
}
