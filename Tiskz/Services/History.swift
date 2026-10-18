import Foundation
import TiskzCore

struct CallRecord: Identifiable, Codable {
    let id: UUID
    let start: Date
    let end: Date
    let mode: String
    let analysis: Analysis
    var uploaded = false
}
@MainActor final class History: ObservableObject {
    @Published private(set) var records: [CallRecord] = []
    @Published var message = ""
    private var file: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("calls.json")
    }
    init(enabled: Bool) {
        if enabled, let data = try? Data(contentsOf: file), data.count <= 8_000_000 { records = (try? JSONDecoder().decode([CallRecord].self, from:data)) ?? [] }
    }
    func append(_ a: Analysis, start: Date, mode: VoiceMode, enabled: Bool) {
        guard enabled else { return }
        records.insert(CallRecord(id:UUID(), start:start, end:Date(), mode:mode.label, analysis:a), at:0)
        records = Array(records.prefix(100)); persist()
    }
    private func persist() {
        do {
            let dir = file.deletingLastPathComponent(); try FileManager.default.createDirectory(at:dir, withIntermediateDirectories:true)
            var data = try JSONEncoder().encode(records)
            while data.count > 8_000_000 && records.count > 1 { records.removeLast(); data = try JSONEncoder().encode(records) }
            try data.write(to:file, options:[.atomic, .completeFileProtection])
            var url = file; var values = URLResourceValues(); values.isExcludedFromBackup = true; try url.setResourceValues(values)
        } catch { message = "No se pudo guardar el historial local." }
    }
    func clear() { records = []; try? FileManager.default.removeItem(at:file); message = "Historial eliminado de este iPhone." }
    func upload(_ record: CallRecord, settings: Settings) async {
        guard settings.shareHistory, !settings.panelKey.isEmpty, !settings.org.isEmpty else { message = "Autoriza el envío y configura la API del panel en Ajustes."; return }
        do {
            let api = try Backend(base:settings.panel); defer { api.close() }
            var request = URLRequest(url:api.endpoint.url("calls/\(record.id.uuidString.lowercased())")); request.httpMethod = "PUT"
            request.setValue("Bearer \(settings.panelKey)", forHTTPHeaderField:"Authorization"); request.setValue(settings.org, forHTTPHeaderField:"X-Tiskz-Org"); request.setValue("application/json", forHTTPHeaderField:"Content-Type")
            let a = record.analysis
            let verdict: String = a.currentAssessment?.state == .alertar ? "suspicious" : "none"
            let iso = ISO8601DateFormatter()
            let payload: [String: Any] = ["caller_number_raw":NSNull(), "caller_e164":NSNull(), "caller_name":NSNull(), "direction":record.mode == VoiceMode.phone.label ? "incoming" : "outgoing", "call_status":"ended", "started_at":iso.string(from:record.start), "answered_at":iso.string(from:record.start), "ended_at":iso.string(from:record.end), "talk_duration_s":max(0,Int(record.end.timeIntervalSince(record.start))), "simulated":false, "blocked":false, "screened":true, "verdict":verdict, "risk_score":Int((a.probability ?? 0) * 100), "risk_reasons":a.reasons, "scam_type":NSNull(), "impersonating":NSNull(), "summary":a.summary.isEmpty ? NSNull() : a.summary as Any, "transcript":a.captions.map { ["id":$0.id, "speaker":$0.speaker, "text":$0.text, "flagged":$0.flagged] as [String:Any] }]
            request.httpBody = try JSONSerialization.data(withJSONObject:payload)
            let (_, response) = try await api.session.data(for:request); try Backend.check(response)
            if let i = records.firstIndex(where: { $0.id == record.id }) { records[i].uploaded = true; persist() }; message = "Sesión enviada al panel de la organización."
        } catch { message = (error as? ServiceError)?.message ?? "No se pudo enviar. Puedes reintentar sin duplicar la sesión." }
    }
}
