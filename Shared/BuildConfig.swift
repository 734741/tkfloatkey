import Foundation

/// Shared build/runtime configuration — compiled into BOTH the app and the
/// keyboard extension (same file, added to both targets) so the two sides can
/// never disagree about the App Group or file names.
enum BuildConfig {

    /// App Group identifier — must match the entitlements files verbatim.
    static let appGroup = "group.com.local.tkfloatkey"

    /// Keychain service for the app's private copy of the vault.
    static let keychainService = "com.local.tkfloatkey.vault"
    static let keychainAccount = "slots.v1"

    /// File name shared between the app and the keyboard.
    static let sharedFileName = "slots.v1.json"

    /// True when the App Group container really resolved on this device.
    ///
    /// Unsigned CI builds that Sideloadly re-signs do NOT get the App Groups
    /// entitlement, so this comes back `false` — the UI uses that to explain why
    /// the keyboard shows no data instead of silently showing empty slots.
    static var hasAppGroup: Bool {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup) != nil
    }

    /// Directory used for the shared JSON payload.
    ///
    /// Signed builds get the App Group container, which both processes can read.
    /// Otherwise it degrades to Documents so the app itself still works.
    static var sharedDirectory: URL? {
        if let group = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return group
        }
        return FileManager.default.urls(for: .documentDirectory,
                                        in: .userDomainMask).first
    }
}
