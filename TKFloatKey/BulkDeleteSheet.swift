import SwiftUI
import UIKit

/// Multi-select deletion. Tick the slots you want gone, then confirm once.
struct BulkDeleteSheet: View {

    @ObservedObject var vault: CredentialVault
    @Binding var selection: Set<Int>
    var onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmAll = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if vault.slots.isEmpty {
                    Text("没有槽位")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(vault.slots) { slot in
                            Button {
                                toggle(slot.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selection.contains(slot.id)
                                          ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 19))
                                        .foregroundStyle(selection.contains(slot.id)
                                                         ? Color.red : Color.secondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(slot.label.isEmpty ? "槽位 \(slot.id)" : slot.label)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        Text(slot.username.isEmpty ? "空" : slot.username)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text("\(slot.id)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }

                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Button {
                            if selection.count == vault.slots.count {
                                selection.removeAll()
                            } else {
                                selection = Set(vault.slots.map(\.id))
                            }
                        } label: {
                            Text(selection.count == vault.slots.count ? "取消全选" : "全选")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(0.07)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            deleteSelected()
                        } label: {
                            Text(selection.isEmpty ? "删除选中" : "删除选中 (\(selection.count))")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.red.opacity(selection.isEmpty ? 0.08 : 0.18)))
                                .foregroundStyle(selection.isEmpty ? Color.secondary : Color.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(selection.isEmpty)
                    }
                }
                .padding(12)
            }
            .navigationTitle("批量删除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ id: Int) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteSelected() {
        guard !selection.isEmpty else { return }
        let toDelete = selection
        selection.removeAll()
        vault.deleteMultiple(toDelete)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
        onFinish()
    }
}
