import Foundation
import Security

struct Keychain {
    static func read(_ account: String) -> String {
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:"com.tiskz.ios", kSecAttrAccount as String:account, kSecReturnData as String:true, kSecMatchLimit as String:kSecMatchLimitOne]
        var result: CFTypeRef?; guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return "" }; return String(data: data, encoding: .utf8) ?? ""
    }
    static func write(_ value: String, account: String) throws {
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:"com.tiskz.ios", kSecAttrAccount as String:account]
        if value.isEmpty { SecItemDelete(query as CFDictionary); return }
        let attrs: [String:Any] = [kSecValueData as String:Data(value.utf8), kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let result = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if result == errSecItemNotFound { var item = query; attrs.forEach { item[$0] = $1 }; guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw ServiceError(message: "No se pudo guardar la credencial en el llavero.") } }
        else if result != errSecSuccess { throw ServiceError(message: "No se pudo actualizar el llavero.") }
    }
}
@MainActor final class Settings: ObservableObject {
    @Published var base = UserDefaults.standard.string(forKey: "channel") ?? "https://api.maritime.sh/a/ebf0eb81-42c0-4437-a044-1af84af1b755"
    @Published var code = Keychain.read("voice-code")
    @Published var panel = UserDefaults.standard.string(forKey: "panel") ?? "https://web-repo-xi.vercel.app/api/v1"
    @Published var panelKey = Keychain.read("panel-key")
    @Published var org = UserDefaults.standard.string(forKey: "org") ?? "org_vecinal"
    @Published var keepHistory = UserDefaults.standard.bool(forKey: "keep-history")
    @Published var shareHistory = UserDefaults.standard.bool(forKey: "share-history")
    func save() throws {
        _ = try TiskzCore.Endpoint(base); _ = try TiskzCore.Endpoint(panel)
        code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        panelKey = panelKey.trimmingCharacters(in: .whitespacesAndNewlines)
        try Keychain.write(code, account:"voice-code")
        try Keychain.write(panelKey, account:"panel-key")
        let d = UserDefaults.standard; d.set(base, forKey:"channel"); d.set(panel, forKey:"panel"); d.set(org, forKey:"org"); d.set(keepHistory, forKey:"keep-history"); d.set(shareHistory, forKey:"share-history")
    }
}
import TiskzCore
