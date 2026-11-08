import UIKit
import SwiftUI

/// Custom keyboard: when any text field in any app is focused, this keyboard
/// shows slots 1–10 across the top. Tap a slot → its account / password / 2FA
/// get inserted straight into the field. No more copy-paste round trips.
///
/// Structure mirrors the official Xcode "Custom Keyboard Extension" template:
///   KeyboardViewController  → hosts the SwiftUI view and does the insertion
///   KeyboardView            → compact SwiftUI UI (slot row + detail strip)
final class KeyboardViewController: UIInputViewController {

    private var host: UIHostingController<KeyboardView>?
    private let vault = SharedVault()

    /// Height the keyboard asks the system for. Two rows of buttons + padding.
    private var preferredKeyboardHeight: CGFloat {
        let base: CGFloat = 118                 // slot row + action strip + margins
        return hasFullAccess ? base : base + 22 // extra hint row when no full access
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

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

        // Constraints, not manual frames — mixing both made the keyboard
        // collapse to zero height on some iOS versions.
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
        // Refresh on every appearance so newly saved slots show up immediately.
        vault.reload()
        updateHeight()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeight()
    }

    private func updateHeight() {
        let target = CGSize(width: 0, height: preferredKeyboardHeight)
        if preferredContentSize.height != target.height {
            preferredContentSize = target
        }
    }

    private func insert(_ text: String) {
        guard !text.isEmpty else { return }
        textDocumentProxy.insertText(text)
    }
}
