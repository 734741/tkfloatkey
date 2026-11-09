import Foundation
import UIKit

/// Reads slots published by the main app over a private pasteboard channel.
///
/// Written defensively: a keyboard extension that throws during init or
/// `viewDidLoad` is silently killed by iOS and the user just sees the system
/// keyboard come back. So every step here is guarded and never traps.
final class SharedVault: ObservableObject {

    @Published private(set) var slots: [Credential] = []
    @Published private(set) var hasSynced = false

    init() {
        // No observers, no notifications — the controller reloads explicitly
        // each time the keyboard appears. Keeps init side-effect free.
    }

    /// Pull the latest payload off the channel. Safe to call repeatedly.
    func reload() {
        guard let decoded = SharedVault.readChannel() else {
            if hasSynced { hasSynced = false }
            return
        }
        if !hasSynced { hasSynced = true }
        let sorted = decoded.sorted { $0.id < $1.id }
        if sorted != slots { slots = sorted }
    }

    private static func readChannel() -> [Credential]? {
        // Wrapped in autoreleasepool + guards: pasteboard access can return an
        // empty array or throw under low memory, and a trap here would kill the
        // extension on launch.
        return autoreleasepool { () -> [Credential]? in
            let board = BuildConfig.channel
            let items = board.items
            guard let first = items.first else { return nil }
            guard let encoded = first["json"] as? String else { return nil }
            guard let data = Data(base64Encoded: encoded) else { return nil }
            return try? JSONDecoder().decode([Credential].self, from: data)
        }
    }
}
