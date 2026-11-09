import Foundation
import Security

/// One of the ten credential slots.
struct Credential: Identifiable, Codable, Equatable {
    var id: Int                 // 1...10 — this is the "1 2 3 4…" the user taps
    var label: String           // e.g. account name / note
    var username: String
    var password: String
    var totpSecret: String      // Base32 or full otpauth:// URI; empty = no 2FA
    var totpDigits: Int
    var totpPeriod: Int
    var totpAlgorithm: String   // SHA1 / SHA256 / SHA512

    static func empty(_ id: Int) -> Credential {
        Credential(id: id, label: "", username: "", password: "",
                   totpSecret: "", totpDigits: 6, totpPeriod: 30,
                   totpAlgorithm: "SHA1")
    }

    var isEmpty: Bool {
        username.isEmpty && password.isEmpty && totpSecret.isEmpty && label.isEmpty
    }

    var hasTOTP: Bool { !totpSecret.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Live 2FA code for this slot, nil when no secret configured.
    func currentTOTP(at date: Date = Date()) -> TOTP.Code? {
        let raw = totpSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if let parsed = TOTP.parse(raw) {
            return try? TOTP.now(secret: parsed.secret,
                                 digits: parsed.digits,
                                 period: parsed.period,
                                 algorithm: parsed.algorithm,
                                 date: date)
        }
        let algo = TOTP.Algorithm(rawValue: totpAlgorithm.uppercased()) ?? .sha1
        return try? TOTP.now(secret: raw, digits: totpDigits,
                             period: totpPeriod, algorithm: algo, date: date)
    }

    /// Lenient decode used by the keyboard, which may see partial JSON.
    static func fromJSON(_ dict: [String: Any]) -> Credential? {
        guard let id = dict["id"] as? Int else { return nil }
        return Credential(
            id: id,
            label: dict["label"] as? String ?? "",
            username: dict["username"] as? String ?? "",
            password: dict["password"] as? String ?? "",
            totpSecret: dict["totpSecret"] as? String ?? "",
            totpDigits: dict["totpDigits"] as? Int ?? 6,
            totpPeriod: dict["totpPeriod"] as? Int ?? 30,
            totpAlgorithm: dict["totpAlgorithm"] as? String ?? "SHA1"
        )
    }
}

// MARK: - Vault (Keychain + pasteboard channel, shared with the keyboard)

final class CredentialVault: ObservableObject {

    static let slotCount = 10
    static let keychainService = BuildConfig.keychainService
    static let keychainAccount = BuildConfig.keychainAccount

    @Published private(set) var slots: [Credential]

    init() {
        if let decoded = CredentialVault.loadAll(),
           decoded.count == CredentialVault.slotCount {
            slots = decoded.sorted { $0.id < $1.id }
        } else {
            slots = (1...CredentialVault.slotCount).map(Credential.empty)
        }
        // Make sure the keyboard can see whatever we have right now.
        republishToChannel()
    }

    subscript(id: Int) -> Credential {
        get { slots.first { $0.id == id } ?? .empty(id) }
        set {
            guard let idx = slots.firstIndex(where: { $0.id == id }) else { return }
            slots[idx] = newValue
            persist()
        }
    }

    var filledCount: Int { slots.filter { !$0.isEmpty }.count }
    var totpCount: Int { slots.filter { $0.hasTOTP }.count }

    func clear(_ id: Int) { self[id] = .empty(id) }

    func clearAll() {
        slots = (1...CredentialVault.slotCount).map(Credential.empty)
        persist()
    }

    // MARK: Persistence — Keychain (private) + pasteboard channel (keyboard)

    func persist() {
        guard let data = try? JSONEncoder().encode(slots) else { return }

        // 1) Private Keychain copy (device-only, not in backups).
        CredentialVault.saveKeychain(data)

        // 2) Push the same JSON onto the private pasteboard channel so the
        //    keyboard extension can read it. No App Group needed, so this works
        //    with a free Apple ID.
        CredentialVault.pushToChannel(data)
    }

    /// Writes the vault onto the dedicated (non-general) pasteboard.
    static func pushToChannel(_ data: Data) {
        let board = BuildConfig.channel
        board.items = [[
            BuildConfig.payloadVersionKey: 1,
            "json": data.base64EncodedString()
        ]]
    }

    /// Re-reads the Keychain copy, so a fresh install can re-publish to the channel.
    func republishToChannel() {
        guard let data = CredentialVault.loadKeychain() else { return }
        CredentialVault.pushToChannel(data)
    }

    private static func loadAll() -> [Credential]? {
        if let data = loadKeychain(),
           let decoded = try? JSONDecoder().decode([Credential].self, from: data) {
            return decoded
        }
        return nil
    }

    private static func loadKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func saveKeychain(_ data: Data) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(base as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add.merge(attrs) { _, new in new }
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

