import UIKit
import SwiftUI

/// Custom keyboard: when any text field in any app is focused, this keyboard
/// shows the saved slots across the top. Tap a slot → its account / password /
/// 2FA get inserted straight into the field.
///
/// **Failure policy:** iOS kills a keyboard extension outright if `viewDidLoad`
/// or the first layout traps. Every step below is therefore guarded, and the
/// SwiftUI host is only added when it can actually be built.
final class KeyboardViewController: UIInputViewController {

    private var host: UIHostingController<KeyboardView>?
    private let vault = SharedVault()

    /// Height the keyboard asks the system for.
    private var preferredKeyboardHeight: CGFloat {
        hasFullAccess ? 132 : 132
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground

        // Read once before the view is built so the first render already has data.
        vault.reload()

        let root = KeyboardView(
            vault: vault,
            onInsert: { [weak self] text in self?.insert(text) },
            onDelete: { [weak self] in self?.textDocumentProxy.deleteBackward() },
            onNextKeyboard: { [weak self] in self?.advanceToNextInputMode() },
            onDismiss: { [weak self] in self?.dismissKeyboard() }
        )

        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(controller)
        view.addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        host = controller
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        vault.reload()
        updateHeight()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeight()
    }

    private func updateHeight() {
        let h = preferredKeyboardHeight
        if preferredContentSize.height != h {
            preferredContentSize = CGSize(width: 0, height: h)
        }
    }

    private func insert(_ text: String) {
        guard !text.isEmpty else { return }
        textDocumentProxy.insertText(text)
    }
}
