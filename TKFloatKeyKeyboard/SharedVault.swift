import Foundation
import UIKit

/// Reads the 10 slots from the dedicated pasteboard channel written by the
/// main app. No App Group required, so a free Apple ID build works.
final class SharedVault: ObservableObject {

    static let channelName = BuildConfig.channelName

    @Published private(set) var slots: [Credential] = []
    @Published private(set) var hasSynced = false

    init() {
        reload()
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.reload() }
    }

    /// Pull the latest payload off the channel.
    func reload() {
        guard let decoded = SharedVault.readChannel() else {
            hasSynced = false
            return
        }
        hasSynced = true
        let sorted = decoded.sorted { $0.id < $1.id }
        if sorted != slots { slots = sorted }
    }

    private static func readChannel() -> [Credential]? {
        let board = BuildConfig.channel
        // `UIPasteboard.items` is a non-optional [[String: Any]]; an empty
        // array means nothing has been published yet.
        guard let item = board.items.first else { return nil }
        guard let encoded = item["json"] as? String,
              let data = Data(base64Encoded: encoded),
              let decoded = try? JSONDecoder().decode([Credential].self, from: data)
        else { return nil }
        return decoded
    }
}
