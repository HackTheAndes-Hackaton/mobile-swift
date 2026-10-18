import Foundation
import AVFoundation
import UserNotifications
import TiskzCore

enum VoiceMode: String, CaseIterable, Identifiable {
    case assistant, analysis, phone
    var id: Self { self }
    var label: String { switch self { case .assistant: return "Conversar con marin"; case .analysis: return "Analizar micrófono"; case .phone: return "Ver llamada Vapi" } }
}
@MainActor final class CallSession: NSObject, ObservableObject {
    @Published var analysis = Analysis()
    @Published var active = false
    @Published var connected = false
    @Published var muted = false
    @Published var message = ""
    @Published var mode: VoiceMode = .assistant
    @Published var connectionMS: Int?
    @Published var deliveryMS: Int?
    @Published var evidenceBusy = false
    @Published var retryEvidence = false
    @Published var playing = false
    @Published var startedAt: Date?
    var onFinish: ((Analysis, Date, VoiceMode) -> Void)?
    private var api: Backend?
    private var room: VoiceRoom?
    private var boundSession: String?
    private var socket: URLSessionWebSocketTask?
    private var peer: VoicePeer?
    private var startTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var captureTask: Task<Void, Never>?
    private var generation = UUID()
    private var ready = false
    private var peerOpen = false
    private var assistantStarted = false
    private var serverCaptures: Set<String> = []
    private var evidenceConsent = false
    private var buffer = ExcerptBuffer()
    private var vad = VoiceActivity()
    private var relay = TranscriptRelay()
    private let resampler = PCMResampler()
    private var captureRequests: [String: Int] = [:]
    private var pendingEvidence: (id: String, wav: Data)?
    private var player: AVAudioPlayer?
    private var interruptions: [NSObjectProtocol] = []
    override init() {
        super.init()
        interruptions.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in if self?.mode != .phone { self?.stop(reason: "Audio interrumpido. Vuelve a conectar cuando termine la llamada.") } } })
        interruptions.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue || reason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue {
                Task { @MainActor in if self?.mode != .phone { self?.stop(reason: "Cambió la salida de audio. Vuelve a conectar.") } }
            }
        })
    }
    // NSObject is needed for lifecycle notification ownership, not for telephony privileges.
    func start(settings: Settings, mode: VoiceMode, consent: Bool, evidence: Bool) {
        guard !active, consent else { return }
        self.mode = mode; active = true; connected = false; muted = false; analysis = Analysis(); message = "Conectando…"
        evidenceConsent = evidence && mode != .phone; startedAt = Date(); connectionMS = nil; deliveryMS = nil
        ready = false; peerOpen = false; assistantStarted = false; serverCaptures = []; generation = UUID(); let run = generation
        buffer.clear(); vad = VoiceActivity(); relay = TranscriptRelay(); captureRequests = [:]; pendingEvidence = nil; retryEvidence = false
        let base = settings.base, code = settings.code
        startTask = Task { [weak self] in
            guard let self else { return }
            do {
                let api = try Backend(base: base); self.api = api
                if mode != .phone {
                    let permission = await withCheckedContinuation { c in AVAudioApplication.requestRecordPermission { c.resume(returning: $0) } }
                    try Task.checkCancellation()
                    guard permission else { throw ServiceError(message: "Permite el micrófono en Ajustes para iniciar.") }
                    let room = try await api.create(code: code, assistant: mode == .assistant, evidence: self.evidenceConsent)
                    guard self.generation == run, !Task.isCancelled else {
                        _ = try? await api.post("v1/sessions/\(room.id)/end", token:room.token, body:[:]); api.close(); throw CancellationError()
                    }
                    self.room = room; self.boundSession = room.id
                    try Task.checkCancellation()
                    self.open(api.endpoint.events(session: room.id, ticket: room.token), run: run)
                    while !self.ready { try await Task.sleep(for: .milliseconds(30)); try Task.checkCancellation() }
                    let peer = VoicePeer(); self.peer = peer
                    peer.onError = { [weak self] in guard self?.generation == run else { return }; self?.stop(reason: "Se perdió el audio WebRTC.") }
                    peer.onOpen = { [weak self] in
                        guard let self, self.generation == run else { return }; self.peerOpen = true
                        if mode != .assistant || self.assistantStarted { self.becameConnected(run:run) }
                        else { self.message = "Audio conectado · iniciando marin…" }
                    }
                    peer.onEvent = { [weak self] e in guard self?.generation == run else { return }; self?.provider(e) }
                    peer.onSamples = { [weak self] data, rate in guard self?.generation == run else { return }; self?.samples(data, rate:rate) }
                    try peer.prepare(); let offer = try await peer.offer()
                    let answer = try await api.post("v1/sessions/\(room.id)/offer", token: room.token, body: ["sdp":offer])
                    try Task.checkCancellation()
                    guard let sdp = answer["sdp"] as? String else { throw ProtocolError.invalidResponse }; try await peer.answer(sdp)
                } else {
                    let url = try await api.monitorURL(code: code); try Task.checkCancellation(); self.open(url, run: run)
                }
            } catch is CancellationError { }
            catch { if self.generation == run { self.stop(reason: (error as? ServiceError)?.message ?? "No se pudo conectar. Comprueba la red y el canal HTTPS.") } }
        }
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(45))
            guard !Task.isCancelled, let self, self.generation == run, self.active, !self.connected else { return }
            self.stop(reason: "La conexión tardó demasiado. Vuelve a intentar.")
        }
    }
    private func becameConnected(run: UUID) {
        guard active, generation == run else { return }; connected = true
        connectionMS = Int(Date().timeIntervalSince(startedAt ?? Date()) * 1000)
        message = mode == .phone ? "Alertas conectadas · esperando llamada" : "Voz conectada"
    }
    private func open(_ url: URL, run: UUID) {
        guard let api else { return }
        let socket = api.session.webSocketTask(with: url); self.socket = socket; socket.maximumMessageSize = 131_072; socket.resume()
        receiveTask = Task { [weak self] in
            do {
                while !Task.isCancelled {
                    let frame = try await socket.receive(); try Task.checkCancellation()
                    let data: Data; switch frame { case .string(let s): data = Data(s.utf8); case .data(let d): data = d; @unknown default: continue }
                    guard let e = Wire.object(data), let self, self.generation == run, self.active else { continue }; self.event(e)
                }
            } catch { if !Task.isCancelled, let self, self.generation == run { self.stop(reason: "Se perdió el canal de alertas. El micrófono se ha cerrado.") } }
        }
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20)); guard !Task.isCancelled else { return }
                do { try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in socket.sendPing { e in if let e { c.resume(throwing:e) } else { c.resume() } } } }
                catch { if let self, self.generation == run { self.stop(reason: "Se perdió el canal de alertas.") }; return }
            }
        }
    }
    private func send(_ event: [String: Any]) {
        guard active, let socket, let data = try? JSONSerialization.data(withJSONObject: event), let text = String(data: data, encoding: .utf8) else { return }
        let run = generation
        Task { [weak self] in do { try await socket.send(.string(text)) } catch { if let self, self.generation == run { self.stop(reason: "No se pudo enviar el evento al servidor.") } } }
    }
    private func event(_ e: [String: Any]) {
        let type = e["type"] as? String
        if type == "phone.ready", mode == .phone { ready = true; becameConnected(run: generation); return }
        if type == "phone.call", mode == .phone, let id = Wire.uuid(e["call_id"]) {
            if boundSession != id {
                if boundSession != nil, let start = startedAt { onFinish?(analysis, start, mode) }
                boundSession = id; analysis = Analysis(); startedAt = Date()
            }
            message = "Llamada Vapi en curso · solo observación"; return
        }
        guard let id = Wire.uuid(e["session_id"]), id == boundSession else { return }
        if type == "session.ready" { ready = true; send(["type":"session.start"]); return }
        if let timestamp = Wire.number(e["server_sent_at_ms"], range: 0...1e15) { deliveryMS = max(0, Int(Date().timeIntervalSince1970 * 1000 - timestamp)) }
        if mode == .assistant, let command = Wire.contextCommand(e) { peer?.send(command); return }
        if type == "audio.capture_requested" { capture(e); return }
        if type == "audio.capture_result" {
            guard let request = Wire.uuid(e["request_id"]), captureRequests[request] != nil else { return }
            if e["status"] as? String == "saved", let clip = Wire.clip(e["fragment_id"]) { analysis.clipID = clip; analysis.evidenceStatus = "Fragmento guardado · pendiente de revisión" }
            else if e["status"] as? String == "failed", analysis.clipID == nil { analysis.evidenceStatus = "No se pudo conservar el fragmento" }
        }
        if type == "call.hangup_requested" {
            guard mode != .phone, HangupRequest.parse(e, session:id, latestRevision:analysis.revision) != nil else { return }
            stop(reason: "El agente finalizó esta sesión de voz."); return
        }
        let previous = analysis.currentAssessment?.state; analysis.accept(e)
        if let current = analysis.currentAssessment?.state, current != previous, current == .alertar || current == .verificar { notify(current) }
        if ["alert.updated","comparison.alert"].contains(type ?? ""), let eventID = Wire.text(e["event_id"], max: 200) { send(["type":"event.received", "event_id":eventID, "session_id":id]) }
        if type == "call.ended" {
            if mode == .phone { if let start = startedAt { onFinish?(analysis, start, mode) }; boundSession = nil; startedAt = nil; message = "Alertas conectadas · esperando llamada" }
            else { stop(reason: "Sesión finalizada") }
        }
    }
    private func provider(_ e: [String: Any]) {
        let type = e["type"] as? String ?? ""
        if mode == .assistant {
            if ["session.input_transcript.delta","session.output_transcript.delta","session.delegation.created","session.closed"].contains(type) { send(["type":"live.event", "event":e]) }
            if type == "session.closed" { stop(reason: "marin finalizó la conversación") }
            if type == "session.started" { assistantStarted = true; if peerOpen { becameConnected(run:generation) }; message = "marin está escuchando" }
        } else if let update = relay.accept(e) { send(update) }
        if type == "error" || type == "conversation.item.input_audio_transcription.failed" { analysis.error = "Falló el servicio de voz. No significa ausencia de riesgo." }
    }
    private func samples(_ data: Data, rate: Double) {
        guard active, connected, !muted, !playing, !data.isEmpty else { return }
        let count = data.count / 2
        let rms = data.withUnsafeBytes { raw -> Double in
            let values = raw.bindMemory(to: Int16.self); var sum = 0.0
            for v in values { let x = Double(Int16(littleEndian:v)) / 32768; sum += x * x }; return sqrt(sum / Double(max(count, 1)))
        }
        if vad.accept(rms: rms, now: ProcessInfo.processInfo.systemUptime), mode == .analysis { peer?.send(["type":"input_audio_buffer.commit"]) }
        guard evidenceConsent else { return }
        if let pcm = resampler.convert(data, sampleRate:rate) { buffer.append(pcm) }
    }
    func toggleMute() { muted.toggle(); peer?.mute(muted); buffer.clear(); resampler.reset(); vad = VoiceActivity() }
    private func capture(_ e: [String: Any]) {
        guard evidenceConsent, let id = boundSession, let request = CaptureRequest.parse(e, session: id), captureRequests[request.id] == nil, serverCaptures.count < 3, request.revision >= max(analysis.revision, 1) else { return }
        captureRequests[request.id] = request.revision; serverCaptures.insert(request.id)
        send(["type":"audio.capture_received", "request_id":request.id, "session_id":id])
        guard !evidenceBusy else { send(["type":"audio.capture_failed", "request_id":request.id, "session_id":id, "reason":"busy"]); return }
        save(requestID: request.id)
    }
    func saveManual() {
        guard evidenceConsent, !evidenceBusy, captureRequests.count < 100 else { return }
        if let pending = pendingEvidence { save(requestID:pending.id, retry:pending.wav); return }
        let id = UUID().uuidString.lowercased(); captureRequests[id] = max(analysis.revision, 1); save(requestID:id)
    }
    private func save(requestID: String, retry: Data? = nil) {
        guard let api, let room, let wav = retry ?? buffer.wav() else {
            analysis.evidenceStatus = "Aún no hay un segundo de audio autorizado"
            if let id = boundSession { send(["type":"audio.capture_failed", "request_id":requestID, "session_id":id, "reason":"no_audio"]) }; return
        }
        evidenceBusy = true; analysis.evidenceStatus = "Guardando fragmento…"; pendingEvidence = (requestID, wav); retryEvidence = false; let run = generation
        captureTask = Task { [weak self] in
            do {
                let clip = try await api.save(wav, room: room, requestID: requestID)
                guard !Task.isCancelled, let self, self.generation == run else { return }
                self.analysis.clipID = clip; self.analysis.evidenceStatus = "Fragmento guardado · pendiente de revisión"; self.evidenceBusy = false; self.pendingEvidence = nil; self.retryEvidence = false
            } catch {
                guard !Task.isCancelled, let self, self.generation == run else { return }
                self.evidenceBusy = false
                if [400,401,403,404,410,413,422].contains((error as? ServiceError)?.status ?? 0) {
                    self.pendingEvidence = nil; self.retryEvidence = false; self.analysis.evidenceStatus = "No se pudo guardar. Comprueba la sesión y el servicio de evidencia."
                } else { self.retryEvidence = true; self.analysis.evidenceStatus = "No se confirmó el guardado. Reintenta con el mismo identificador." }
                self.send(["type":"audio.capture_failed", "request_id":requestID, "session_id":room.id, "reason":"capture_unavailable"])
            }
        }
    }
    func playExcerpt() {
        guard let api, let room, let clip = analysis.clipID, !playing else { return }; let run = generation
        Task { [weak self] in
            do {
                let data = try await api.load(room: room, clip: clip)
                guard let self, self.active, self.generation == run else { return }
                self.peer?.mute(true); self.buffer.clear(); self.playing = true
                self.player = try AVAudioPlayer(data: data); self.player?.play()
                try await Task.sleep(for: .seconds((self.player?.duration ?? 0) + 0.1))
                if self.generation == run { self.playing = false; self.player = nil; self.peer?.mute(self.muted) }
            } catch { if let self, self.generation == run { self.playing = false; self.peer?.mute(self.muted); self.message = "No se pudo reproducir el fragmento autorizado." } }
        }
    }
    private func notify(_ state: AssessmentState) {
        let content = UNMutableNotificationContent(); content.title = "Tiskz · \(state.label)"; content.body = "Hay una nueva orientación. Abre la conversación para revisarla."; content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content:content, trigger:nil))
    }
    func stop(reason: String = "Sesión finalizada") {
        guard active else { return }; active = false; connected = false; generation = UUID()
        startTask?.cancel(); receiveTask?.cancel(); heartbeat?.cancel(); watchdog?.cancel(); captureTask?.cancel()
        peer?.close(); peer = nil; socket?.cancel(with: .normalClosure, reason:nil); socket = nil
        player?.stop(); player = nil; playing = false; buffer.clear(); resampler.reset(); pendingEvidence = nil; retryEvidence = false; evidenceBusy = false
        if mode != .phone || boundSession != nil, let start = startedAt { onFinish?(analysis, start, mode) }
        startedAt = nil; message = reason; analysis.ended = true
        let oldAPI = api, oldRoom = room; room = nil; boundSession = nil; api = nil
        Task { if let api = oldAPI { if let room = oldRoom { _ = try? await api.post("v1/sessions/\(room.id)/end", token:room.token, body:[:]) }; api.close() } }
    }
}
