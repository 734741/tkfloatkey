import SwiftUI
import UIKit

/// Bulk import: paste lines of `账号----密码----2FA密钥----备注` and fill slots in one shot.
/// Order matters — line 1 goes to slot 1, line 2 to slot 2, …
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

    private let helpText = """
    格式（用 ---- 隔开）：
    账号----密码----2FA密钥----备注

    第 3、4 段可以留空。备注留空时列表会直接显示账号本身。

    例：
    abc@outlook.com----pass123----JBSWY3DPEHPK3PXP----主号
    abc@outlook.com----pass123
    """

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {

                Text(helpText)
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
                        if let pasted = UIPasteboard.general.string {
                            text = pasted
                        }
                    } label: {
                        Label("从剪贴板粘贴", systemImage: "doc.on.clipboard")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(Color.primary.opacity(0.07)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        apply()
                    } label: {
                        Label("导入", systemImage: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.18)))
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

    // MARK: - Parsing helpers

    /// Splits one line into fields.
    ///
    /// Primary separator is `----` (four dashes). Empties are preserved so a
    /// missing 2FA column does not shift the password into its place.
    /// `|` is also accepted as a fallback for hand-typed rows.
    static func split(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.contains("----") {
            return trimmed
                .components(separatedBy: "----")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        if trimmed.contains("|") {
            return trimmed
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return [trimmed]
    }

    /// A readable caption when the line had no explicit label.
    static func shortLabel(for username: String, index: Int) -> String {
        if let at = username.firstIndex(of: "@") {
            let head = String(username[username.startIndex..<at])
            return head.isEmpty ? "账号\(index + 1)" : head
        }
        return username.isEmpty ? "账号\(index + 1)" : String(username.prefix(12))
    }

    private func apply() {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let rawLines = normalized
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
            var parts = BulkImportView.split(line)

            // Drop a leading numeric index if present ("1|备注|账号|…")
            if let first = parts.first, Int(first) != nil, parts.count >= 2 {
                parts.removeFirst()
            }
            guard !parts.isEmpty else { continue }

            var cred = Credential.empty(index + 1)

            // Strict positional order, exactly three fields:
            //   parts[0] = 账号 (邮箱)
            //   parts[1] = 密码
            //   parts[2] = 2FA 密钥
            // A fourth optional field is the note.
            cred.username = parts.count > 0 ? parts[0] : ""
            cred.password = parts.count > 1 ? parts[1] : ""

            if parts.count > 2, !parts[2].isEmpty {
                let secret = parts[2]
                if let parsed = TOTP.parse(secret) {
                    cred.totpSecret = parsed.secret
                    cred.totpDigits = parsed.digits
                    cred.totpPeriod = parsed.period
                    cred.totpAlgorithm = parsed.algorithm.rawValue
                } else {
                    cred.totpSecret = secret
                }
            }
            if parts.count > 3 { cred.label = parts[3] }

            // Leave the label empty when none was supplied: the row already
            // shows the account, and the user can type a note later.

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






