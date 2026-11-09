import SwiftUI
import UIKit

/// The expandable list: 10 numbered rows. Tap "1" and its account/password/2FA
/// unfold right there.
struct SlotPanel: View {

    @ObservedObject var vault: CredentialVault
    var onClose: () -> Void
    var onMove: (CGSize) -> Void

    @State private var openSlot: Int? = nil
    @State private var revealed: Set<Int> = []
    @State private var editingSlot: Credential? = nil
    @State private var headerDrag: CGSize = .zero
    @State private var toast: String? = nil
    @State private var showBulkDelete = false
    @State private var deleteSelection: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().opacity(0.4)
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(vault.slots) { slot in
                        row(slot)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 9)
            }
            .frame(maxHeight: 400)

            // 固定在面板底部，不随列表滚动，也不遮挡内容
            Divider().opacity(0.4)
            Button {
                let id = vault.addSlot()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    openSlot = id
                }
            } label: {
                Label("新增槽位", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.3), radius: 22, y: 10)
        )
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.black.opacity(0.82)))
                    .foregroundStyle(.white)
                    .padding(.top, 6)
                    .transition(.opacity)
            }
        }
        .sheet(item: $editingSlot) { cred in
            EditorSheet(credential: cred) { saved in
                vault[saved.id] = saved
                revealed.insert(saved.id)
            }
        }
        .sheet(isPresented: $showBulkDelete) {
            BulkDeleteSheet(vault: vault, selection: $deleteSelection) {
                showBulkDelete = false
                openSlot = nil
                flash("已删除选中槽位")
            }
        }
    }

    // MARK: - Header (drag handle + close)

    private var panelHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.tint)
            Text("TK 账号槽位")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showBulkDelete = true
                }
            } label: {
                Image(systemName: "checklist")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { v in
                    onMove(CGSize(width: v.translation.width - headerDrag.width,
                                  height: v.translation.height - headerDrag.height))
                    headerDrag = v.translation
                }
                .onEnded { _ in headerDrag = .zero }
        )
    }

    // MARK: - One numbered row

    private func row(_ slot: Credential) -> some View {
        let isOpen = openSlot == slot.id
        return VStack(spacing: 0) {
            // Whole row taps to expand. The two quick-copy buttons on the right
            // stop the tap so you can load a credential in one touch instead of
            // expanding first.
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        openSlot = isOpen ? nil : slot.id
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 9) {
                        Text("\(slot.id)")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(slot.isEmpty
                                          ? AnyShapeStyle(Color.secondary.opacity(0.15))
                                          : AnyShapeStyle(LinearGradient(
                                                colors: [.blue, .indigo],
                                                startPoint: .top, endPoint: .bottom)))
                            )
                            .foregroundStyle(slot.isEmpty ? Color.secondary : .white)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(slot.label.isEmpty ? (slot.isEmpty ? "空槽位" : masked(slot.username)) : slot.label)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                            if !slot.isEmpty {
                                Text(masked(slot.username))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // One-tap loads, available without expanding the row.
                if !slot.isEmpty {
                    quickButton("person.fill", "账号", tint: .blue) {
                        copy(slot.username)
                    }
                    .disabled(slot.username.isEmpty)

                    quickButton("key.fill", "密码", tint: .orange) {
                        copy(slot.password)
                    }
                    .disabled(slot.password.isEmpty)
                }

                if let code = slot.currentTOTP() {
                    Button {
                        copy(code.value)
                    } label: {
                        Text(code.value)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .frame(height: 28)
                            .background(RoundedRectangle(cornerRadius: 7)
                                .fill(Color.green.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)

            if isOpen {
                detail(slot)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isOpen ? Color.primary.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isOpen ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.07),
                              lineWidth: 0.8)
        )
    }

    // MARK: - Expanded detail

    private func detail(_ slot: Credential) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if slot.isEmpty {
                Button {
                    editingSlot = slot
                } label: {
                    Label("添加账号密码", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.14)))
                }
                .buttonStyle(.plain)
            } else {
                fieldRow(title: "账号", value: slot.username,
                         revealed: revealed.contains(slot.id)) {
                    revealed.insert(slot.id)
                } hide: {
                    revealed.remove(slot.id)
                }

                fieldRow(title: "密码", value: slot.password,
                         revealed: revealed.contains(slot.id)) {
                    revealed.insert(slot.id)
                } hide: {
                    revealed.remove(slot.id)
                }

                if slot.hasTOTP {
                    totpRow(slot)
                }

                HStack(spacing: 8) {
                    Button {
                        copy(slot.username)
                    } label: {
                        smallButton("复制账号", "person.crop.circle")
                    }
                    .buttonStyle(.plain)
                    .disabled(slot.username.isEmpty)

                    Button {
                        copy(slot.password)
                    } label: {
                        smallButton("复制密码", "key.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(slot.password.isEmpty)

                    Button {
                        editingSlot = slot
                    } label: {
                        smallButton("编辑", "slider.horizontal.3")
                    }
                    .buttonStyle(.plain)

                    Button {
                        vault.delete(slot.id)
                        withAnimation { openSlot = nil }
                    } label: {
                        smallButton("删除", "trash.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 11)
        .padding(.top, 2)
    }

    private func fieldRow(title: String, value: String, revealed: Bool,
                          show: @escaping () -> Void,
                          hide: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)

            Text(revealed ? value : String(repeating: "•", count: min(max(value.count, 6), 14)))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 点一下就只复制这一项（此行对应账号或密码，不混在一起）
            Button {
                copy(value)
                if !revealed { show() }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11))
                    Text("复制")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.tint)
                .padding(.horizontal, 7)
                .frame(height: 26)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            }
            .buttonStyle(.plain)

            Button {
                revealed ? hide() : show()
            } label: {
                Image(systemName: revealed ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.05)))
    }

    private func totpRow(_ slot: Credential) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let code = slot.currentTOTP()
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "lock.shield.fill")
                    Text("2FA")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.green)

                Text(code?.value ?? "------")
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                    .textSelection(.enabled)

                if let c = code {
                    ZStack {
                        Circle()
                            .stroke(Color.green.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: CGFloat(c.remaining) / CGFloat(c.period))
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: c.remaining)
                        Text("\(c.remaining)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 26, height: 26)
                }

                Spacer()

                Button {
                    if let c = code { copy(c.value) }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 11))
                        Text("复制").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 7)
                    .frame(height: 24)
                    .background(Capsule().fill(Color.green.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.green.opacity(0.08)))
            .id("\(slot.id)-\(code?.value ?? "-")-\(Int(context.date.timeIntervalSince1970))")
        }
    }

    /// Compact one-tap copy chip shown on the collapsed row.
    private func quickButton(_ icon: String, _ title: String,
                             tint: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(tint.opacity(0.13)))
        }
        .buttonStyle(.plain)
    }

    private func smallButton(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(title).font(.system(size: 11, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.07)))
    }

        /// One tap = put exactly this value on the clipboard, nothing else.
    private func copy(_ value: String) {
        guard !value.isEmpty else { return }
        UIPasteboard.general.string = value
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeOut(duration: 0.12)) { toast = "已复制" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.easeIn(duration: 0.18)) { toast = nil }
        }
    }

    private func masked(_ s: String) -> String {
        guard s.count > 4 else { return String(repeating: "•", count: max(s.count, 3)) }
        return String(s.prefix(3)) + String(repeating: "•", count: min(s.count - 3, 8))
    }
}


// MARK: - Editor

struct EditorSheet: View {
    @State var credential: Credential
    var onSave: (Credential) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var totpInput = ""
    @State private var preview: String = ""
    @State private var error: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("槽位 \(credential.id)") {
                    TextField("备注（例如 账号1 / 主号）", text: $credential.label)
                }
                Section("账号密码") {
                    TextField("用户名 / 邮箱 / 手机号", text: $credential.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.oneTimeCode)
                        .keyboardType(.asciiCapable)
                    SecureField("密码", text: $credential.password)
                        .textContentType(.oneTimeCode)
                }
                Section {
                    TextField("Base32 密钥 或 otpauth:// 链接", text: $totpInput, axis: .vertical)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 13, design: .monospaced))
                        .onChange(of: totpInput) { _ in
                        refreshPreview()
                    }

                    HStack {
                        Text("当前验证码")
                        Spacer()
                        Text(preview.isEmpty ? "—" : preview)
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    if let error {
                        Text(error).font(.system(size: 11)).foregroundStyle(.red)
                    }
                } header: {
                    Text("2FA（可留空）")
                } footer: {
                    Text("粘贴 Authenticator 导出的 Base32 密钥，或整条 otpauth:// 链接。验证码全部在本地计算，不联网。")
                        .font(.system(size: 11))
                }
                Section {
                    Button(role: .destructive) {
                        credential.username = ""
                        credential.password = ""
                        credential.totpSecret = ""
                        credential.label = ""
                        onSave(credential)
                        dismiss()
                    } label: { Text("清空此槽位") }
                }
            }
            .navigationTitle("编辑槽位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        credential.totpSecret = TOTP.parse(totpInput)?.secret ?? totpInput
                        if let p = TOTP.parse(totpInput) {
                            credential.totpDigits = p.digits
                            credential.totpPeriod = p.period
                            credential.totpAlgorithm = p.algorithm.rawValue
                        }
                        onSave(credential)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                totpInput = credential.totpSecret
                refreshPreview()
            }
        }
    }

    private func refreshPreview() {
        error = nil
        let trimmed = totpInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { preview = ""; return }
        do {
            let parsed = TOTP.parse(trimmed)
            guard let p = parsed else { preview = ""; error = "无法解析该密钥"; return }
            let code = try TOTP.now(secret: p.secret, digits: p.digits,
                                    period: p.period, algorithm: p.algorithm)
            preview = code.value
        } catch {
            preview = ""
            self.error = error.localizedDescription
        }
    }
}















