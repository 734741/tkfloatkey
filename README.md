# TKFloatKey · iPhone 悬浮账号面板

10 槽位的账号密码 + TOTP 2FA 悬浮面板。数据只存本机 Keychain，不联网。

---

## 一、功能对照

| 你的需求 | 实现 |
|---|---|
| 苹果手机悬浮窗 | 可拖动的悬浮球（`FloatingPanel.swift`），点一下展开，拖动换位置、松手自动贴边、位置记忆 |
| 导入登录用的账号密码 | 10 个固定槽位，每槽可存 备注 / 账号 / 密码 / 2FA 密钥（`CredentialVault.swift`） |
| 同时存 10 个，1、2、3… 排下去 | 槽位 id 固定 1–10，`ForEach` 按序渲染，空槽显示"空槽位" |
| 点 1 就能展开看到账号密码 | 点数字行 → 就地展开，账号/密码各带 👁 显示隐藏 + 一键复制 |
| 加 2FA 验证 | 内置 RFC 6238 TOTP（SHA1/256/512，6–8 位，30/60 秒），实时倒计时圆环 + 复制 |

**额外加的：**
- Face ID / 触控 ID / 密码解锁门禁，App 退到后台自动回锁
- Keychain 存储（`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`），不从备份恢复、不跨设备
- 编辑页粘 `otpauth://` 链接自动解析 algorithm/digits/period
- 复制时轻震动反馈

---

## 二、目录结构

```
TKFloatKey/
├── TKFloatKey.xcodeproj/          Xcode 工程（可直接打开）
├── TKFloatKey/
│   ├── AppMain.swift              App 入口 + 解锁门禁 + 主界面
│   ├── FloatingPanel.swift        悬浮球 + 拖拽 + 展开/收起 + 贴边吸附
│   ├── SlotPanel.swift            1–10 编号列表 + 展开详情 + 2FA 行 + 编辑页
│   ├── CredentialVault.swift      槽位模型 + Keychain 持久化
│   ├── TOTP.swift                 RFC 6238 TOTP（Base32 + HMAC 全手写）
│   ├── Info.plist
│   └── Assets.xcassets/
├── build_ipa.sh                   macOS 一键编译打包 IPA
└── verify_totp.py                 TOTP 算法对照 RFC 测试向量（已全通过）
```

---

## 三、在真机上跑起来

### 方案 A：Xcode 直接装（最快，7 天有效期）

1. Mac 上双击 `TKFloatKey.xcodeproj`
2. 选中 target → **Signing & Capabilities** → Team 选你的 Apple ID
   - 免费账号：Bundle Identifier 改成唯一值，如 `com.你的名字.tkfloatkey`
3. iPhone 用数据线连 Mac，Xcode 顶部选中你的设备，`⌘R`
4. iPhone 上：设置 → 通用 → VPN与设备管理 → 信任你的开发者证书

免费证书 7 天后过期，重连重跑一次即可。付费开发者账号（¥688/年）是 1 年。

### 方案 B：打包 IPA（自签 / 侧载）

```bash
cd TKFloatKey
bash build_ipa.sh 你的TEAMID          # 出未签名 ipa
bash build_ipa.sh 你的TEAMID --sign   # 用本机描述文件签名
```

产物 `TKFloatKey.ipa` 用 AltStore / Sideloadly / TrollStore 装进手机。

> TrollStore 用户（A12 及以下、iOS 14–16.x 或 17.0）：装完是**永久签名**，最省事。

---

## 四、用法

1. 首次打开 → Face ID 解锁
2. 点右下角蓝色悬浮球 → 展开 10 个槽位
3. 点「空槽位」→ 填备注 / 账号 / 密码 → 有 2FA 就贴密钥 → 保存
4. 之后点任意数字 → 就地展开该账号的账号、密码、实时 2FA 验证码
5. 悬浮球长按拖动换角落，松手自动贴边，位置自动记住

**2FA 密钥从哪来：**
- 已经绑了验证器的：在验证器里「导出 / 显示密钥」，拿到 Base32 字符串（如 `JBSWY3DPEHPK3PXP`）
- 新绑的：绑定时选「手动输入」而不是扫码，页面上会直接给密钥
- 有二维码的：扫码后复制 `otpauth://totp/...?secret=...` 整条链接，直接粘进去

---

## 五、TOTP 算法已验证

`verify_totp.py` 是 Swift 实现的逐行 Python 镜像（同样的常量、同样的位运算），跑对照：

```
== RFC 6238 vectors (8 digits, period 30) ==
T=59           SHA1 94287082/94287082  SHA256 46119246/46119246  SHA512 90693936/90693936  OK
T=1111111109   SHA1 07081804/07081804  SHA256 68084774/68084774  SHA512 25091201/25091201  OK
T=1111111111   SHA1 14050471/14050471  SHA256 67062674/67062674  SHA512 99943326/99943326  OK
T=1234567890   SHA1 89005924/89005924  SHA256 91819424/91819424  SHA512 93441116/93441116  OK
T=2000000000   SHA1 69279037/69279037  SHA256 90698825/90698825  SHA512 38618901/38618901  OK
T=20000000000  SHA1 65353130/65353130  SHA256 77737706/77737706  SHA512 47863826/47863826  OK

== RFC 4226 Appendix D (HOTP, SHA1, 6 digits) ==
10/10 OK

== leftover-seconds countdown (period 30) ==
4/4 OK

RESULT: ALL PASS
```

自己复跑：`python verify_totp.py`

---

## 六、关于"跨 App 悬浮"这件事

iOS 没有给第三方 App 系统级 overlay 权限，所以"在 TikTok 界面上叠一个密码窗"这条路在未越狱设备上不存在。现实里能选的是：

| 做法 | 能不能显示密码 | 代价 |
|---|---|---|
| 本工程：自己 App 内悬浮球 | ✅ 可以 | 需要切回本 App 点开 |
| 灵动岛 / 实时活动（iOS 16.1+） | ❌ 只能显示短文本，不能放密码 | 系统限制内容长度与类型 |
| 键盘扩展（Custom Keyboard） | ✅ 可以 | 需在设置里开启"完全访问"，且键盘区域小 |
| 越狱 + 插件（如 FloatingBall 类） | ✅ 可以 | 需越狱，风险高 |

如果你要的是**在任何 App 的输入框里直接点一下填账号密码**，比悬浮球更好用的是**自定义键盘扩展** —— 输入框弹起时键盘上方直接列出 1–10 号槽位，点一下就把账号/密码注入当前输入框。要的话我把键盘扩展（`KeyboardExtension` target + `UIInputViewController` + 共享 App Group 读 Keychain）也加上去，本工程的 `CredentialVault` 和 `TOTP` 可以直接复用。
