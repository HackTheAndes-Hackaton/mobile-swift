import Foundation

public struct Caption: Identifiable, Codable, Equatable {
    public let id: String
    public var speaker: String
    public var text: String
    public var final: Bool
    public var sequence: Int
    public var flagged: Bool
    public var label: String { speaker == "agent" ? "marin" : speaker == "user" ? "Tú" : "Quien llama" }
}
public enum AssessmentState: String, Codable, CaseIterable {
    case observar, verificar, alertar, inconcluso
    public var label: String { switch self { case .observar: return "Observar"; case .verificar: return "Verificar"; case .alertar: return "Alerta"; case .inconcluso: return "Inconcluso" } }
}
public struct Assessment: Codable, Equatable {
    public var state: AssessmentState
    public var guidance: String
    public var quotes: [String]
    public var revision: Int
}
public struct Analysis: Codable, Equatable {
    public var captions: [Caption] = []
    public var comparison: [Caption] = []
    public var alert: Bool? = nil
    public var probability: Double? = nil
    public var revision = -1
    public var understandingRevision = -1
    public var summary = ""
    public var reasons: [String] = []
    public var assessment: Assessment? = nil
    public var status = "Esperando audio"
    public var comparisonStatus = "Sin comparación"
    public var comparisonProbability: Double? = nil
    public var comparisonRevision = -1
    public var evidenceStatus = "Sin fragmentos guardados"
    public var clipID: String? = nil
    public var readyToAnswer = false
    public var ended = false
    public var error: String? = nil
    public init() {}
    public var currentAssessment: Assessment? {
        guard let a = assessment, a.revision >= max(revision, understandingRevision) else { return nil }; return a
    }
    /// Only this reducer interprets data. Plain-text advice never becomes a device command.
    public mutating func accept(_ e: [String: Any]) {
        switch e["type"] as? String {
        case "transcript.update":
            guard let c = Self.caption(e, comparison: false) else { return }
            let old = captions.first(where: { $0.id == c.id })
            guard old?.final != true else { return }
            Self.upsert(c, into: &captions, limit: 200)
            if c.speaker != "agent" { readyToAnswer = false }
        case "alert.updated":
            guard let a = Wire.bool(e["alerta"]), let p = Wire.number(e["probability"], range: 0...1), let r = Wire.integer(e["revision"]), r >= revision else { return }
            alert = a; probability = p; revision = r; readyToAnswer = false
        case "risk.update":
            guard let p = Wire.number(e["risk_percent"], range: 0...100), let r = Wire.integer(e["revision"]), r >= revision else { return }
            probability = p / 100; revision = r
            if let a = Wire.bool(e["alerta"]) { alert = a }
            reasons = Array((e["reasons"] as? [String] ?? []).prefix(30)).map { String($0.prefix(500)) }
        case "understanding.update":
            guard let r = Wire.integer(e["revision"]), r >= understandingRevision, let a = e["analysis"] as? [String: Any], a["rol"] as? String == "comprension", let s = Wire.text(a["resumen"], max: 4000) else { return }
            summary = s; understandingRevision = r
        case "assessment.update":
            guard let r = Wire.integer(e["revision"]), r >= max(revision, understandingRevision, assessment?.revision ?? -1), let a = e["assessment"] as? [String: Any], a["version"] as? String == "orientacion_v1", let raw = a["estado"] as? String, let state = AssessmentState(rawValue: raw), let guidance = Wire.text(a["orientacion"], max: 2000) else { return }
            let entries = a["evidencia_textual"] as? [[String: Any]] ?? []
            guard entries.count <= 8 else { return }
            let quotes = entries.compactMap { Wire.text($0["cita"], max: 600) }; guard quotes.count == entries.count else { return }
            assessment = Assessment(state: state, guidance: guidance, quotes: quotes, revision: r)
        case "agent.status":
            let labels = ["connecting": "Conectando", "screening": "Escuchando", "analyzing": "Analizando", "safe": "Análisis disponible", "suspicious": "Revisar señales", "scam": "Señales de riesgo"]
            if let s = e["status"] as? String, let label = labels[s] { status = label }
        case "call.ready_to_answer":
            guard let r = Wire.integer(e["revision"]), r >= max(revision, understandingRevision) else { return }
            readyToAnswer = alert == false && currentAssessment?.state == .observar
        case "call.ended": ended = true; status = "Sesión finalizada"
        case "comparison.status":
            guard Wire.bool(e["comparison_only"]) == true else { return }; comparisonStatus = String((e["status"] as? String ?? "").prefix(100))
        case "transcript.comparison":
            guard Wire.bool(e["comparison_only"]) == true, let c = Self.caption(e, comparison: true), comparison.first(where: { $0.id == c.id })?.final != true else { return }; Self.upsert(c, into: &comparison, limit: 12)
        case "comparison.alert":
            guard Wire.bool(e["comparison_only"]) == true, Wire.bool(e["alerta"]) != nil, let p = Wire.number(e["probability"], range: 0...1), let r = Wire.integer(e["revision"], range: 1...Int(Int32.max)), r >= comparisonRevision else { return }
            comparisonProbability = p; comparisonRevision = r
        case "error": error = "El análisis informó un error. No significa ausencia de riesgo."
        default: break
        }
    }
    private static func caption(_ e: [String: Any], comparison: Bool) -> Caption? {
        guard let id = Wire.text(e["id"], max: 200), let text = Wire.text(e["text"], max: 4000), let sequence = Wire.integer(e["sequence"], range: 0...(comparison ? 99 : Int(Int32.max))), let final = Wire.bool(e["final"]) else { return nil }
        if comparison && id.range(of: "^scribe-[0-9]{1,3}$", options: .regularExpression) == nil { return nil }
        let s = (e["speaker"] as? String ?? "caller").lowercased()
        return Caption(id: id, speaker: ["agent", "assistant", "bot", "ai", "marin"].contains(s) ? "agent" : s == "user" ? "user" : "caller", text: text, final: final, sequence: sequence, flagged: Wire.bool(e["flagged"]) ?? false)
    }
    private static func upsert(_ c: Caption, into list: inout [Caption], limit: Int) {
        if let i = list.firstIndex(where: { $0.id == c.id }) { list[i] = c } else { list.append(c) }
        list.sort { $0.sequence < $1.sequence }; if list.count > limit { list.removeFirst(list.count - limit) }
    }
}

/// Provider captions and the Scribe comparison have independent identities and scores.
public struct TranscriptRelay {
    private var sequences: [String: Int] = [:]
    private var text: [String: String] = [:]
    private var finals: Set<String> = []
    public init() {}
    public mutating func accept(_ e: [String: Any]) -> [String: Any]? {
        guard let type = e["type"] as? String, let id = Wire.text(e["item_id"], max: 200) else { return nil }
        guard !finals.contains(id) else { return nil }
        if sequences[id] == nil { guard sequences.count < 100 else { return nil }; sequences[id] = sequences.count }
        if type == "input_audio_buffer.committed" { return nil }
        let final = type == "conversation.item.input_audio_transcription.completed"
        guard final || type == "conversation.item.input_audio_transcription.delta" else { return nil }
        let value = final ? e["transcript"] as? String : (text[id] ?? "") + (e["delta"] as? String ?? "")
        guard let value, Wire.text(value, max: 4000) != nil else { return nil }
        text[id] = value; if final { finals.insert(id); text.removeValue(forKey: id) }
        return ["type": "transcript.update", "id": id, "speaker": "user", "text": value, "final": final, "sequence": sequences[id]!]
    }
}
