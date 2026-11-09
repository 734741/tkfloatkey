import SwiftUI
import UIKit

/// Bulk import: paste lines of `备注|账号|密码|2FA密钥` and fill all ten slots
/// in one shot. Order matters — line 1 goes to slot 1, line 2 to slot 2, …
///
/// Accepted formats (the leading number is optional):
///   1|主号|user1@x.com|pass1|JBSWY3DPEHPK3PXP
///   主号|user1@x.com|pass1|JBSWY3DPEHPK3PXP
///   主号|user1@x.com|pass1
struct BulkImportView: View {

    @ObservedObject var vault: CredentialVault
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var status: String? = nil
    @State private var statusIsError = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {

                Text("每行一组，用竖线 | 分隔四个字段：
备注 | 账号 | 密码 | 2FA密钥

2FA 那栏可以留空。前导编号可写可不写。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextEditor(text: $text)
                    .font(.system(size: 13, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 240)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    Button {
                        if let s = UIPasteboard.general.string { text = s }
                    } label: {
                        Label("从剪贴板粘贴", systemImage: "doc.on.clipboard")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.07)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        apply()
                    } label: {
                        Label("导入", systemImage: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }

                if let status {
                    Text(status)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(statusIsError ? Color.red : Color.green)
                }

                Spacer()
            }
            .padding(18)
            .navigationTitle("批量导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func apply() {
        let rawLines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !rawLines.isEmpty else {
            status = "没有内容"
            statusIsError = true
            return
        }

        var filled = 0
        for (index, line) in rawLines.enumerated() {
            // Slots are unbounded: every parsed line gets its own slot.
            var parts = line.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            // Drop a leading numeric index if present ("1|备注|账号|…")
            if let first = parts.first, Int(first) != nil, parts.count >= 3 {
                parts.removeFirst()
            }
            guard parts.count >= 2 else { continue }

            var cred = Credential.empty(index + 1)
            cred.label = parts.count > 0 ? parts[0] : ""
            cred.username = parts.count > 1 ? parts[1] : ""
            cred.password = parts.count > 2 ? parts[2] : ""

            if parts.count > 3, !parts[3].isEmpty {
                let secret = parts[3]
                if let parsed = TOTP.parse(secret) {
                    cred.totpSecret = parsed.secret
                    cred.totpDigits = parsed.digits
                    cred.totpPeriod = parsed.period
                    cred.totpAlgorithm = parsed.algorithm.rawValue
                } else {
                    cred.totpSecret = secret
                }
            }

            if !cred.isEmpty {
                if index < vault.count {
                    vault[index + 1] = cred
                } else {
                    vault.append(cred)
                }
                filled += 1
            }
        }

        vault.republishToChannel()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        status = "已导入 \(filled) 组，并已同步到键盘"
        statusIsError = false
    }
}

