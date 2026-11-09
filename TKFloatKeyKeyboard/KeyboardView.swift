import UIKit
import SwiftUI


// MARK: - Keyboard UI

/// Interaction contract (what the user asked for):
///   tap "1".."10"  → only SELECT that slot, nothing is typed
///   tap 「账号」    → load ONLY the username into the focused field
///   tap 「密码」    → load ONLY the password
///   tap the 2FA     → load ONLY the current 6-digit code
///   tap 「备注」    → load ONLY the label
struct KeyboardView: View {

    @ObservedObject var vault: SharedVault
    var onInsert: (String) -> Void
    var onDelete: () -> Void
    var onNextKeyboard: () -> Void
    var onDismiss: () -> Void

    @State private var selected: Int? = nil
    @State private var toast: String? = nil

    private var selectedSlot: Credential? {
        guard let id = selected else { return nil }
        return vault.slots.first { $0.id == id }
    }

    /// Ids to render. Falls back to 1…10 when nothing has synced, so the
    /// keyboard is never blank and never traps on an empty array.
    private var displayIDs: [Int] {
        let ids = vault.slots.map(\.id).sorted()
        return ids.isEmpty ? Array(1...10) : ids
    }

    var body: some View {
        VStack(spacing: 6) {
            slotRow
            if let slot = selectedSlot {
                actionStrip(slot)
            } else {
                hintStrip
            }
            bottomBar
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear { vault.reload() }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(.black.opacity(0.78)))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
                    .transition(.opacity)
            }
        }
    }

    // MARK: 1 2 3 … 10 — selection only

    private var slotRow: some View {
        HStack(spacing: 5) {
            ForEach(Array(displayIDs.prefix(20)), id: \.self) { id in
                let slot = vault.slots.first { $0.id == id } ?? .empty(id)
                Button {
                    // Only selects the slot. Typing happens on the buttons below.
                    selected = (selected == id) ? nil : id
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 1) {
                        Text("\(id)")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                        Group {
                            if slot.hasTOTP {
                                Image(systemName: "lock.fill").font(.system(size: 7, weight: .bold))
                            } else {
                                Image(systemName: "lock.open").font(.system(size: 7, weight: .bold))
                            }
                        }
                        .opacity(slot.isEmpty ? 0.25 : 0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(selected == id
                                  ? AnyShapeStyle(Color.accentColor)
                                  : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(slot.isEmpty ? Color.clear : Color.accentColor.opacity(0.35),
                                          lineWidth: 1)
                    )
                    .foregroundStyle(selected == id ? Color.white
                                                    : (slot.isEmpty ? Color.secondary : Color.primary))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Per-field load buttons

    private func actionStrip(_ slot: Credential) -> some View {
        HStack(spacing: 6) {
            loadButton(icon: "person.fill", title: "账号",
                       enabled: !slot.username.isEmpty,
                       tint: .blue) {
                load(slot.username, as: "账号")
            }
            loadButton(icon: "key.fill", title: "密码",
                       enabled: !slot.password.isEmpty,
                       tint: .orange) {
                load(slot.password, as: "密码")
            }
            if slot.hasTOTP {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let code = slot.currentTOTP()
                    loadButton(icon: "lock.shield.fill",
                               title: code?.value ?? "2FA",
                               enabled: code != nil,
                               tint: .green) {
                        if let c = code { load(c.value, as: "2FA") }
                    }
                }
            }
            if !slot.label.isEmpty {
                loadButton(icon: "tag.fill", title: slot.label,
                           enabled: true, tint: .purple) {
                    load(slot.label, as: "备注")
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: 38)
    }

    private var hintStrip: some View {
        Group {
            if vault.slots.allSatisfy({ $0.isEmpty }) {
                // Two very different causes, two very different fixes.
                if !vault.hasSynced {
                    Text("没数据：设置→通用→键盘→TK面板，打开「完全访问」；再到 App 点「同步到键盘」")
                        .foregroundStyle(.orange)
                } else {
                    Text("还没有账号：先打开 TK面板 App 录入 1–10 号槽位")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("先点 1–10 选中槽位，再点「账号」或「密码」只插入对应内容")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(RoundedRectangle(cornerRadius: 9)
            .fill(Color(uiColor: .secondarySystemGroupedBackground)))
    }

    private var bottomBar: some View {
        HStack(spacing: 6) {
            Button(action: onNextKeyboard) {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .frame(width: 46, height: 38)
                    .background(RoundedRectangle(cornerRadius: 9)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground)))
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "delete.left")
                    .font(.system(size: 16))
                    .frame(width: 52, height: 38)
                    .background(RoundedRectangle(cornerRadius: 9)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground)))
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 16))
                    .frame(width: 52, height: 38)
                    .background(RoundedRectangle(cornerRadius: 9)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground)))
            }
            .buttonStyle(.plain)
        }
    }

    private func loadButton(icon: String, title: String, enabled: Bool,
                            tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            guard enabled else { return }
            action()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(enabled ? 0.16 : 0.06))
            )
            .foregroundStyle(enabled ? tint : Color.secondary.opacity(0.5))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    /// Insert exactly one piece of data and flash a confirmation.
    private func load(_ value: String, as label: String) {
        guard !value.isEmpty else { return }
        onInsert(value)
        flash("已插入\(label)")
    }

    private func flash(_ text: String) {
        withAnimation(.easeOut(duration: 0.15)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeIn(duration: 0.2)) { toast = nil }
        }
    }
}









