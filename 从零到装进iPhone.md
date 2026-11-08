# 从零到装进 iPhone（Windows 全流程）

> 你没有 Mac，所以用 **GitHub Actions 云端 macOS 编译 → 下载 IPA → Sideloadly 签名安装**。
> 全程不需要 Mac，只需要一个 GitHub 账号 + 你的 Apple ID。

---

## 第 0 步：现状（我已经在这台机器上做完的）

| 项目 | 状态 |
|---|---|
| App 工程（主 App + 键盘扩展） | ✅ 已写好 |
| iPhone 连接检测 | ✅ 已连上 |
| 设备识别 | ✅ iPhone X（iPhone10,3）/ iOS **16.7.15** / 20H380 / arm64 |
| 越狱 / TrollStore | ❌ 都没有 → 必须走 Apple ID 签名 |
| Sideloadly | ✅ 已装：`C:\Users\Administrator\AppData\Local\Sideloadly\sideloadly.exe` |
| Apple 移动设备服务 | ✅ 运行中（端口 27015） |
| 设备配对 | ✅ 已完成（UDID `04786c2e23c38b4435044e03fc090ee47d830613`） |
| TOTP 算法 | ✅ RFC 6238 / RFC 4226 官方向量全通过 |

**唯一还差的一步：把源码编译成 .ipa。** Windows 没有苹果工具链，所以交给 GitHub 的云 Mac。

---

## 第 1 步：把工程推到 GitHub（约 3 分钟）

### 1.1 注册/登录 GitHub
没有账号就去 https://github.com/signup 注册，免费。

### 1.2 新建仓库
1. 右上角 `+` → **New repository**
2. Repository name 填 `tkfloatkey`
3. 选 **Private**（推荐，别公开）
4. **不要**勾选 "Add a README file"
5. 点 **Create repository**

### 1.3 推送代码

在本机 PowerShell 里，把下面的 `你的用户名` 换成你的 GitHub 用户名：

```powershell
cd E:\222\TKFloatKey

git init
git add .
git commit -m "TKFloatKey: 10-slot floating panel + keyboard extension"
git branch -M main
git remote add origin https://github.com/你的用户名/tkfloatkey.git
git push -u origin main
```

推送时会弹窗要你登录 GitHub（浏览器授权即可）。

---

## 第 2 步：云端自动编译（约 5 分钟）

推送成功后：

1. 打开 `https://github.com/你的用户名/tkfloatkey`
2. 点上方 **Actions** 标签
3. 左边看到 **Build TKFloatKey IPA**，点进去
4. 如果是黄色提示 "Workflows aren't being run on this fork"，点 **I understand my workflows, go ahead and enable them**
5. 点右侧 **Run workflow** → **Run workflow**
6. 等 3–5 分钟，出现绿色 ✅

### 下载产物

在跑完的那次运行页面，最下方 **Artifacts**：
- **TKFloatKey-ipa** ← 点这个下载
- 得到 `TKFloatKey-ipa.zip`，解压出 `TKFloatKey.ipa`

> 如果失败：页面上会显示红色 ❌，点 **build-log** 那个 artifact 下载日志发我，我按报错改代码。

---

## 第 3 步：用 Sideloadly 装进手机（约 5 分钟）

### 3.1 打开 Sideloadly

```
C:\Users\Administrator\AppData\Local\Sideloadly\sideloadly.exe
```

### 3.2 填三个东西

| 字段 | 填什么 |
|---|---|
| **IPA** | 选刚下载解压出来的 `TKFloatKey.ipa` |
| **Apple ID** | 你的 Apple ID 邮箱 |
| **Password** | 你的密码（**只能用 App 专用密码，见下**） |

### 3.3 关于密码（重要）

如果你的 Apple ID 开了双重验证（绝大多数都开了），**直接填账号密码会失败**。必须用 App 专用密码：

1. 浏览器打开 https://appleid.apple.com
2. 登录 → **登录与安全** → **App 专用密码**
3. 点 **+** 生成，名字填 `sideloadly`
4. 得到形如 `abcd-efgh-ijkl-mnop` 的一串 —— **这个才是 Sideloadly 要的密码**

> 这串密码只用于签名，勾上 "Save to Keychain" 可以下次免输。
> 我全程不接触你的账号密码，你自己在 Sideloadly 窗口里输入。

### 3.4 点 Start

确认左上角设备栏识别到你的 iPhone（显示 iPhone / iOS 16.7.15）。然后点 **Start**。

过程中手机上可能弹出 **"要信任此电脑吗"** → 点信任。

### 3.5 手机上信任开发者

装完后 App 图标是灰的、点不开，这是正常的：

**设置 → 通用 → VPN与设备管理 → 开发者 App → 点你的 Apple ID → 信任**

如果系统提示需要联网验证，让它联网一次。

---

## 第 4 步：开启键盘（关键，别跳过）

键盘默认关闭，不开的话"不用切 App 直接填"这个功能用不了。

1. **设置 → 通用 → 键盘 → 键盘 → 添加新键盘**
2. 在第三方键盘列表里找到 **TK面板** → 点进去
3. 打开 **完全访问**（Allow Full Access）→ 弹窗点 **允许**

> 不开完全访问：键盘读不到 App Group 里的数据，会显示空槽位。这是 iOS 沙箱，不是 bug。

---

## 第 5 步：开始用

### 先录入账号

1. 打开 **TK面板** App → Face ID 解锁
2. 点右下角蓝色悬浮球 → 展开 1–10
3. 点「1」号空槽位 → **添加账号密码**
4. 填：备注 / 账号 / 密码
5. 有 2FA 就把密钥粘进「2FA」那栏（支持 Base32 或 `otpauth://` 整条链接）
6. 保存

重复填到 10 号。

### 登录时怎么用（不用切 App）

在 TikTok 登录页点账号输入框：

1. 键盘弹出 → 点地球键切到 **TK面板**
2. 点 `1` → 该槽位高亮（**只是选中，不输入任何东西**）
3. 点「**账号**」→ 只有账号进了输入框
4. 点到密码框 → 键盘上点「**密码**」→ 只有密码进了输入框
5. 需要 2FA → 点绿色六位数字 → 只有验证码进了输入框

每次点击有轻震动 + 顶部提示「已插入账号 / 已插入密码」。

### 悬浮面板怎么用（切回 App 时）

- 点 `1`–`10` → **只展开**该槽位
- 账号行点「**加载**」→ 只把账号放剪贴板
- 密码行点「**加载**」→ 只把密码放剪贴板（同时把掩码变明文）
- 2FA 行点「**加载**」→ 只把验证码放剪贴板
- 长按悬浮球可拖到任意角落，松手贴边，位置会记住

---

## 常见问题

**Q：7 天后 App 打不开了？**
免费 Apple ID 签名 7 天过期。重新走第 3 步装一次即可。**数据不会丢**（存在 Keychain 里）。
想免维护可以额外装 AltStore 做自动续签。

**Q：键盘显示"没有数据"？**
按第 4 步开「完全访问」。

**Q：以后改了代码怎么重新出包？**
`git add . && git commit -m "update" && git push` → GitHub Actions 自动重新编译 → 重新下载安装。

**Q：想换自己的 Bundle ID？**
在 `TKFloatKey.xcodeproj/project.pbxproj` 里把
`com.local.tkfloatkey` 和 `com.local.tkfloatkey.keyboard` 改成你自己的。
`Shared/BuildConfig.swift` 里的 App Group 也要同步改。

**Q：安全吗？**
- 数据只在本机 Keychain，不联网、不上传、无任何网络请求
- App 退到后台自动回锁（Face ID）
- 2FA 密钥本地计算，不经过任何服务器
- Keychain 用 `WhenUnlockedThisDeviceOnly`，不进备份、不跨设备
