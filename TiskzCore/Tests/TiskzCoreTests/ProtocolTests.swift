import XCTest
@testable import TiskzCore
final class ProtocolTests: XCTestCase {
    func testHTTPSAndProxyPrefix() throws {
        for s in ["http://example.com", "https://a:b@example.com", "https://example.com?key=x", "https://example.com/#x"] { XCTAssertThrowsError(try Endpoint(s)) }
        let endpoint = try Endpoint("https://example.com/a/id")
        XCTAssertEqual(endpoint.url("v1/sessions").path, "/a/id/v1/sessions")
        XCTAssertEqual(endpoint.events(session: "room", ticket: "x&y").query, "session=room&ticket=x%26y")
    }
    func testStrictTypes() {
        XCTAssertNil(Wire.bool(1)); XCTAssertNil(Wire.number(true, range: 0...1)); XCTAssertNil(Wire.integer(1.2)); XCTAssertNil(Wire.number(Double.nan, range: 0...1))
        XCTAssertEqual(Wire.bool(true), true)
    }
    func testInitialUnknownAndStaleRevisions() {
        var a = Analysis(); XCTAssertNil(a.alert)
        a.accept(["type":"alert.updated", "alerta": true, "probability":0.9, "revision":3])
        a.accept(["type":"alert.updated", "alerta": false, "probability":0.1, "revision":2])
        a.accept(["type":"alert.updated", "alerta": 0, "probability":0.1, "revision":4])
        XCTAssertEqual(a.alert, true); XCTAssertEqual(a.revision, 3)
        a.accept(["type":"error"]); XCTAssertEqual(a.alert, true); XCTAssertNotNil(a.error)
    }
    func testAssessmentExpiresWhenNewAnalysisArrives() {
        var a = Analysis()
        a.accept(["type":"assessment.update", "revision":1, "assessment":["version":"orientacion_v1", "estado":"verificar", "orientacion":"Verifica por otra vía"]])
        XCTAssertEqual(a.currentAssessment?.state, .verificar)
        a.accept(["type":"alert.updated", "revision":2, "alerta":false, "probability":0.1])
        XCTAssertNil(a.currentAssessment)
    }
    func testScribeCannotChangePrimaryDecision() {
        var a = Analysis()
        a.accept(["type":"comparison.alert", "comparison_only":true, "alerta":true, "probability":0.99, "revision":1])
        XCTAssertNil(a.alert); XCTAssertEqual(a.comparisonProbability, 0.99)
    }
    func testFinalCaptionImmutableAndOrdered() {
        var a = Analysis()
        a.accept(["type":"transcript.update", "id":"b", "speaker":"assistant", "sequence":2, "text":"Hola", "final":true])
        a.accept(["type":"transcript.update", "id":"a", "sequence":1, "text":"No necesito pagos", "final":true])
        a.accept(["type":"transcript.update", "id":"a", "sequence":1, "text":"Necesito pagos", "final":false])
        XCTAssertEqual(a.captions.map(\.id), ["a", "b"]); XCTAssertEqual(a.captions.first?.text, "No necesito pagos"); XCTAssertEqual(a.captions.last?.speaker, "agent")
    }
    func testCaptureRequiresBoundSessionAndFreshExpiry() {
        let session = UUID().uuidString.lowercased(); let now = Date()
        var e: [String:Any] = ["type":"audio.capture_requested", "session_id":session, "request_id":UUID().uuidString, "revision":1, "window_ms":10000, "expires_at":ISO8601DateFormatter().string(from: now.addingTimeInterval(30))]
        XCTAssertNotNil(CaptureRequest.parse(e, session: session, now: now))
        XCTAssertNil(CaptureRequest.parse(e, session: UUID().uuidString, now: now))
        e["expires_at"] = ISO8601DateFormatter().string(from: now.addingTimeInterval(-1)); XCTAssertNil(CaptureRequest.parse(e, session: session, now: now))
    }
    func testContextAllowlist() {
        XCTAssertNil(Wire.contextCommand(["type":"live.command", "command":["type":"call.hangup", "content":"x"]]))
        XCTAssertNotNil(Wire.contextCommand(["type":"live.command", "command":["type":"session.thinking.append", "content":"Revisa el contexto"]]))
    }
    func testTranscriptRelayFinal() {
        var r = TranscriptRelay()
        _ = r.accept(["type":"input_audio_buffer.committed", "item_id":"1"])
        let e = r.accept(["type":"conversation.item.input_audio_transcription.completed", "item_id":"1", "transcript":"No necesito claves"])
        XCTAssertEqual(e?["text"] as? String, "No necesito claves"); XCTAssertNil(r.accept(["type":"conversation.item.input_audio_transcription.delta", "item_id":"1", "delta":"alterado"]))
    }
    func testBufferBoundedAndSilenceCommit() {
        var b = ExcerptBuffer(); XCTAssertNil(b.wav()); b.append(Data(repeating: 0, count: 640_000)); XCTAssertEqual(b.wav()?.count, 320_044); b.clear(); XCTAssertNil(b.wav())
        var v = VoiceActivity(); XCTAssertFalse(v.accept(rms: 0.1, now: 0)); XCTAssertFalse(v.accept(rms: 0, now: 0.8)); XCTAssertTrue(v.accept(rms: 0, now: 1.3)); XCTAssertFalse(v.accept(rms: 0, now: 3))
    }
    func testHangupRequiresBoundSessionReasonAndCurrentRevision() {
        let session = UUID().uuidString.lowercased()
        var e: [String:Any] = ["type":"call.hangup_requested", "session_id":session, "request_id":UUID().uuidString, "revision":3, "reason":"risk_detected"]
        XCTAssertNotNil(HangupRequest.parse(e, session:session, latestRevision:3))
        XCTAssertNil(HangupRequest.parse(e, session:UUID().uuidString, latestRevision:3))
        XCTAssertNil(HangupRequest.parse(e, session:session, latestRevision:4))
        e["reason"] = "probability_high"; XCTAssertNil(HangupRequest.parse(e, session:session, latestRevision:3))
    }
    func testReadyCannotSurviveNewCallerTurnOrStaleReview() {
        var a = Analysis()
        a.accept(["type":"alert.updated", "alerta":false, "probability":0.1, "revision":2])
        a.accept(["type":"assessment.update", "revision":2, "assessment":["version":"orientacion_v1", "estado":"observar", "orientacion":"Puedes escuchar"]])
        a.accept(["type":"call.ready_to_answer", "revision":1]); XCTAssertFalse(a.readyToAnswer)
        a.accept(["type":"call.ready_to_answer", "revision":2]); XCTAssertTrue(a.readyToAnswer)
        a.accept(["type":"transcript.update", "id":"new", "text":"Ahora envía dinero", "sequence":3, "final":false]); XCTAssertFalse(a.readyToAnswer)
    }

    func testRealPCMResamplingKeepsMono16kFormat() {
        let resampler = PCMResampler()
        var result = Data()
        for _ in 0..<100 {
            let samples: [Int16] = (0..<960).map { Int16(sin(Double($0) * 2 * .pi * 440 / 48000) * 8000) }
            let data = samples.withUnsafeBytes { Data($0) }
            if let output = resampler.convert(data, sampleRate:48000) { result.append(output) }
        }
        XCTAssertTrue((60_000...65_000).contains(result.count))
        XCTAssertTrue(result.contains(where: { $0 != 0 }))
        var buffer = ExcerptBuffer(); buffer.append(result)
        XCTAssertEqual(String(data:buffer.wav()!.prefix(4), encoding:.ascii), "RIFF")
        XCTAssertNil(resampler.convert(Data([0]), sampleRate:48000))
        XCTAssertNil(resampler.convert(Data([0,0]), sampleRate:0))
    }

}
