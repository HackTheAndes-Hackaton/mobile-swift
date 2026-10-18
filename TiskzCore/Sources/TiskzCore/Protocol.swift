import Foundation
import CoreFoundation

public enum ProtocolError: Error { case invalidURL, invalidResponse }
public struct Endpoint {
    public let base: URL
    public init(_ value: String) throws {
        guard let c = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)), c.scheme == "https", let host = c.host, !host.isEmpty, c.user == nil, c.password == nil, c.query == nil, c.fragment == nil, let url = c.url else { throw ProtocolError.invalidURL }
        base = url
    }
    public func url(_ path: String) -> URL { base.appendingPathComponent(path) }
    public func events(session: String? = nil, ticket: String) -> URL {
        var c = URLComponents(url: url("ws/calls"), resolvingAgainstBaseURL: false)!
        c.scheme = "wss"
        c.queryItems = [URLQueryItem(name: session == nil ? "channel" : "session", value: session ?? "phone"), URLQueryItem(name: "ticket", value: ticket)]
        return c.url!
    }
}
public enum Wire {
    public static func object(_ data: Data) -> [String: Any]? {
        guard data.count <= 131_072 else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
    public static func bool(_ value: Any?) -> Bool? {
        guard let n = value as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { return nil }; return n.boolValue
    }
    public static func number(_ value: Any?, range: ClosedRange<Double>) -> Double? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite, range.contains(n.doubleValue) else { return nil }; return n.doubleValue
    }
    public static func integer(_ value: Any?, range: ClosedRange<Int> = 0...Int(Int32.max)) -> Int? {
        guard let d = number(value, range: Double(range.lowerBound)...Double(range.upperBound)), d.rounded() == d else { return nil }; return Int(d)
    }
    public static func text(_ value: Any?, max: Int) -> String? {
        guard let s = value as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, s.count <= max else { return nil }; return s
    }
    public static func uuid(_ value: Any?) -> String? { guard let s = value as? String, UUID(uuidString: s) != nil else { return nil }; return s.lowercased() }
    public static func clip(_ value: Any?) -> String? { guard let s = value as? String, s.range(of: "^clip_[a-f0-9]{48}$", options: .regularExpression) != nil else { return nil }; return s }
    public static func contextCommand(_ e: [String: Any]) -> [String: Any]? {
        guard e["type"] as? String == "live.command", let c = e["command"] as? [String: Any], c["type"] as? String == "session.thinking.append", let content = c["content"] as? String, content.count <= 1800 else { return nil }
        if let id = c["delegation_id"], !(id is NSNull), text(id, max: 150) == nil { return nil }
        var result: [String: Any] = ["type": "session.thinking.append", "content": content]
        if let id = c["delegation_id"] as? String { result["delegation_id"] = id }
        if let id = c["event_id"] as? String { result["event_id"] = String(id.prefix(150)) }
        return result
    }
}

public struct CaptureRequest: Equatable {
    public let id: String
    public let revision: Int
    public static func parse(_ e: [String: Any], session: String, now: Date = Date()) -> Self? {
        guard e["type"] as? String == "audio.capture_requested", Wire.uuid(e["session_id"]) == session.lowercased(), let id = Wire.uuid(e["request_id"]), let rev = Wire.integer(e["revision"], range: 1...Int(Int32.max)), Wire.integer(e["window_ms"]) == 10_000, let expiry = e["expires_at"] as? String else { return nil }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: expiry) ?? ISO8601DateFormatter().date(from: expiry), date > now, date.timeIntervalSince(now) <= 60 else { return nil }
        return Self(id: id, revision: rev)
    }
}

public struct HangupRequest {
    public let id: String
    public static func parse(_ e: [String: Any], session: String, latestRevision: Int) -> Self? {
        guard e["type"] as? String == "call.hangup_requested", Wire.uuid(e["session_id"]) == session.lowercased(), let id = Wire.uuid(e["request_id"]), let revision = Wire.integer(e["revision"]), let reason = e["reason"] as? String, ["risk_detected", "agent_ended"].contains(reason), revision >= max(latestRevision, reason == "risk_detected" ? 1 : 0) else { return nil }
        return Self(id: id)
    }
}
