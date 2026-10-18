import Foundation
import TiskzCore

final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
struct ServiceError: LocalizedError {
    let message: String
    var status: Int? = nil
    var errorDescription: String? { message }
}
struct VoiceRoom { let id: String; let token: String }
final class Backend {
    let endpoint: Endpoint
    private let delegate = NoRedirect()
    lazy var session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 30; c.timeoutIntervalForResource = 45
        c.urlCache = nil; c.httpCookieStorage = nil
        return URLSession(configuration: c, delegate: delegate, delegateQueue: nil)
    }()
    init(base: String) throws { endpoint = try Endpoint(base) }
    func post(_ path: String, token: String, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: endpoint.url(path)); request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "X-Voice-Token"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try Self.check(response)
        guard let json = Wire.object(data) else { throw ServiceError(message: "Respuesta del canal inválida.") }; return json
    }
    static func check(_ response: URLResponse) throws {
        guard let r = response as? HTTPURLResponse else { throw ServiceError(message: "Respuesta inválida.") }
        guard (200...299).contains(r.statusCode) else {
            let messages = [401:"Código incorrecto o sesión vencida.", 403:"Acceso no autorizado.", 409:"Ya hay una sesión de control activa.", 429:"Demasiadas sesiones. Cierra una e inténtalo de nuevo."]
            throw ServiceError(message: messages[r.statusCode] ?? "El servicio devolvió HTTP \(r.statusCode).", status:r.statusCode)
        }
    }
    func create(code: String, assistant: Bool, evidence: Bool) async throws -> VoiceRoom {
        guard (12...512).contains(code.count) else { throw ServiceError(message: "Configura el código privado del equipo.") }
        var body: [String: Any] = ["consentimiento_analisis": true]
        if assistant { body["mode"] = "assistant"; body["consentimiento_voz_ia"] = true }
        if evidence { body["consentimiento_conservacion"] = true; body["audio_capture_protocol"] = 1 }
        let e = try await post("v1/sessions", token: code, body: body)
        guard let id = Wire.uuid(e["session_id"]), let token = e["producer_token"] as? String, (12...256).contains(token.count) else { throw ProtocolError.invalidResponse }
        return VoiceRoom(id: id, token: token)
    }
    func monitorURL(code: String) async throws -> URL {
        let json = try await post("v1/phone/monitor", token: code, body: ["consentimiento_analisis":true, "consentimiento_corte_automatico":false])
        guard let ticket = json["ticket"] as? String, (12...256).contains(ticket.count) else { throw ProtocolError.invalidResponse }; return endpoint.events(ticket: ticket)
    }
    func save(_ wav: Data, room: VoiceRoom, requestID: String) async throws -> String {
        let e = try await post("v1/sessions/\(room.id)/evidence", token: room.token, body: ["request_id":requestID, "audio_base64":wav.base64EncodedString()])
        guard let d = e["data"] as? [String: Any], let id = Wire.clip(d["id"]) else { throw ProtocolError.invalidResponse }; return id
    }
    func load(room: VoiceRoom, clip: String) async throws -> Data {
        guard Wire.clip(clip) != nil else { throw ProtocolError.invalidResponse }
        var req = URLRequest(url: endpoint.url("v1/sessions/\(room.id)/evidence/\(clip)")); req.setValue(room.token, forHTTPHeaderField: "X-Voice-Token")
        let (data, response) = try await session.data(for: req); try Self.check(response)
        guard (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("audio/wav") == true, (32_044...480_044).contains(data.count), data.prefix(4) == Data("RIFF".utf8) else { throw ProtocolError.invalidResponse }; return data
    }
    func close() { session.invalidateAndCancel() }
}
