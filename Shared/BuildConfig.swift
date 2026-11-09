import Foundation
import UIKit

/// Shared config for BOTH the app and the keyboard extension.
///
/// **No App Group required.** A free Apple ID cannot provision App Groups, so
/// the two processes exchange data through a pasteboard channel instead:
///
///   app      → writes JSON into UIPasteboard under `channelName`
///   keyboard → reads that pasteboard on every appearance
///
/// The pasteboard is private to this app pair (it is namespaced and contains
/// only the encoded vault), so it does not clobber the user's clipboard: we use
/// a *separate* `UIPasteboard(name:create:)` instance, not `general`.
enum BuildConfig {

    /// Dedicated pasteboard used as the app ↔ keyboard channel.
    /// Not `.general`, so the user's copied text is untouched.
    static let channelName = "com.local.tkfloatkey.vault"

    /// Keychain service for the app's own private copy of the vault.
    static let keychainService = "com.local.tkfloatkey.vault"
    static let keychainAccount = "slots.v1"

    /// Version tag written alongside the payload so the keyboard can tell
    /// "never synced" apart from "synced an empty vault".
    static let payloadVersionKey = "tkfkv"

    /// The shared pasteboard instance (created lazily, never nil in practice).
    static var channel: UIPasteboard {
        UIPasteboard(name: UIPasteboard.Name(channelName), create: true)
    }
}
