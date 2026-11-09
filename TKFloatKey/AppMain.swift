import LocalAuthentication

import SwiftUI
import UIKit

@main
struct TKFloatKeyApp: App {
    @StateObject private var vault = CredentialVault()
    @State private var locked = true
    @Environment(\.scenePhase) private var scenePhase

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
                // Re-arm the gate whenever the app leaves the foreground so the
                // credentials are not sitting in plain sight in the app switcher.
                if phase == .background { locked = true }
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

    @State private var syncToast: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    card(title: "已用槽位", value: "\(vault.filledCount) / 10", icon: "square.grid.3x3.fill")
                    card(title: "2FA 槽位", value: "\(vault.totpCount)",
                         icon: "lock.shield.fill")

                    Button {
                        vault.republishToChannel()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation { syncToast = "已同步 \(vault.filledCount) 个槽位到键盘" }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation { syncToast = nil }
                        }
                    } label: {
                        Label("同步到键盘", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.15)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onLock()
                    } label: {
                        Label("锁定面板", systemImage: "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.07)))
                    }
                    .buttonStyle(.plain)

                    Text("右下角的悬浮球点一下即可展开 1–10 号槽位；长按拖动可换位置，松手自动贴边。点某个数字就展开对应的账号、密码与实时 2FA。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    Text("改完账号后记得点一次「同步到键盘」，键盘才能读到最新内容。")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
                .padding(18)
                .padding(.bottom, 120)   // keep content clear of the floating ball
            }
            .navigationTitle("TK 悬浮面板")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { lockButton }
            }
            .overlay(alignment: .top) {
                if let syncToast {
                    Text(syncToast)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.8)))
                        .foregroundStyle(.white)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
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






