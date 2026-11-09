import LocalAuthentication

import SwiftUI
import UIKit

@main
struct TKFloatKeyApp: App {
    @StateObject private var vault = CredentialVault()
    @State private var locked = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundedAt: Date?

    var body: some Scene {
        WindowGroup {
            ZStack {
                if locked {
                    LockScreen { locked = false }
                        .transition(.opacity)
                } else {
                    MainScreen(vault: vault, onLock: { locked = true })
                        .overlay(FloatingPanel(vault: vault))
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: locked)
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .background:
                    // Only remember when we left; do not lock yet.
                    backgroundedAt = Date()
                case .active:
                    // Relock only after 10 minutes away, so switching to another
                    // app to paste a password does not force a Face ID prompt.
                    if let left = backgroundedAt,
                       Date().timeIntervalSince(left) > 600 {
                        locked = true
                    }
                    backgroundedAt = nil
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Lock gate (Face ID / Touch ID / passcode)

struct LockScreen: View {
    var onUnlock: () -> Void
    @State private var message = "点击解锁"
    @State private var busy = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 54, weight: .thin))
                .foregroundStyle(LinearGradient(colors: [.blue, .indigo],
                                                startPoint: .top, endPoint: .bottom))
            Text("TK 账号槽位")
                .font(.system(size: 21, weight: .bold, design: .rounded))
            Text("10 组账号密码 + 2FA，本地加密存储")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button(action: unlock) {
                HStack(spacing: 7) {
                    if busy { ProgressView().tint(.white) }
                    else { Image(systemName: "faceid") }
                    Text(busy ? "验证中…" : message)
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: 240)
                .padding(.vertical, 13)
                .background(Capsule().fill(LinearGradient(colors: [.blue, .indigo],
                                                          startPoint: .leading, endPoint: .trailing)))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(busy)
            Spacer()
            Text("数据仅保存在本机 Keychain，不上传任何服务器")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear(perform: unlock)
    }

    private func unlock() {
        guard !busy else { return }
        busy = true
        BiometricGate.authenticate(reason: "解锁你的账号槽位") { ok, err in
            busy = false
            if ok {
                onUnlock()
            } else {
                message = err ?? "点此重试"
            }
        }
    }
}

enum BiometricGate {
    static func authenticate(reason: String, completion: @escaping (Bool, String?) -> Void) {
        let ctx = LAContext()
        var error: NSError?
        // Prefer presence-of-the-owner (biometrics OR device passcode).
        let policy: LAPolicy = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics

        guard ctx.canEvaluatePolicy(policy, error: &error) else {
            completion(true, nil)   // no passcode/biometrics configured: local tool, fail open
            return
        }
        ctx.evaluatePolicy(policy, localizedReason: reason) { ok, err in
            DispatchQueue.main.async {
                completion(ok, ok ? nil : (err as NSError?)?.localizedDescription ?? "点此重试")
            }
        }
    }
}

// MARK: - Main screen behind the floating panel

struct MainScreen: View {
    @ObservedObject var vault: CredentialVault
    var onLock: () -> Void

    @State private var showBulk = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    card(title: "已用槽位", value: "\(vault.filledCount) / \(vault.count)", icon: "square.grid.3x3.fill")
                    card(title: "2FA 槽位", value: "\(vault.totpCount)",
                         icon: "lock.shield.fill")

                    Button {
                        showBulk = true
                    } label: {
                        Label("批量导入", systemImage: "square.and.arrow.down.on.square")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.15)))
                    }
                    .buttonStyle(.plain)

                    Text("点右下角蓝色悬浮球展开槽位。每行右侧两位小按钮：蓝色复制账号，橙色复制密码。点数字展开可见明文和 2FA 验证码。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(18)
                .padding(.bottom, 120)   // keep content clear of the floating ball
            }
            .navigationTitle("TK 悬浮面板")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { lockButton }
            }
            .sheet(isPresented: $showBulk) {
                BulkImportView(vault: vault)
            }

        }
    }

    private func card(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.13)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 17, weight: .bold, design: .rounded))
            }
            Spacer()
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var lockButton: some View {
        Button("锁定", action: onLock)
            .font(.system(size: 13, weight: .semibold))
    }
}









