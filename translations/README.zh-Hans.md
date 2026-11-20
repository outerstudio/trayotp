<p align="center">
  <img src="../docs/app-icon.gif" width="128" alt="TrayOTP 图标">
</p>

<h1 align="center">TrayOTP</h1>

<p align="center">
  <a href="../README.md">English</a> · <a href="README.de.md">Deutsch</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> ·
  <a href="README.it.md">Italiano</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> ·
  <a href="README.pt-BR.md">Português (Brasil)</a> · <b>简体中文</b> · <a href="README.zh-Hant.md">繁體中文</a>
</p>

<p align="center">
  <b>你的双重认证验证码，在 macOS 菜单栏中一键可得。</b><br>
  可从 Google 身份验证器、2FAS、Aegis、Ente Auth、Bitwarden、Proton Authenticator 等导入。加密、离线、开源。
</p>

<p align="center">
  <a href="https://github.com/outerstudio/trayotp/releases/latest"><img src="https://img.shields.io/github/v/release/outerstudio/trayotp?label=download" alt="最新版本"></a>
  <a href="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml"><img src="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14 或更高版本">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT 许可证"></a>
  <a href="https://buymeacoffee.com/garyyeap"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee"></a>
  <a href="https://ko-fi.com/garyyeap"><img src="https://img.shields.io/badge/Ko--fi-72a4f2?logo=kofi&logoColor=white" alt="Ko-fi"></a>
  <a href="https://liberapay.com/garyyeap"><img src="https://img.shields.io/badge/Liberapay-f6c915?logo=liberapay&logoColor=black" alt="Liberapay"></a>
  <a href="https://thanks.dev/u/gh/garyyeap"><img src="https://img.shields.io/badge/thanks.dev-000000?logo=thanksdotdev&logoColor=white" alt="thanks.dev"></a>
</p>

<p align="center">
  <a href="#install">安装</a> ·
  <a href="#getting-started">快速上手</a> ·
  <a href="#using-trayotp">使用 TrayOTP</a> ·
  <a href="#security">安全性</a> ·
  <a href="#troubleshooting">故障排除</a>
</p>

<p align="center">
  <img src="../docs/screenshots/panel.png" width="340" alt="菜单栏图标下方的 TrayOTP 面板：搜索栏、显示名称、验证码、账户和下一个验证码的令牌，以及添加、锁定和退出按钮">
  <img src="../docs/screenshots/deep-black.png" width="340" alt="使用深黑主题的面板：为 OLED 屏幕准备的纯黑背景">
</p>

> 本译文可能落后于[英文 README](../README.md)。如有出入，以英文版为准。

## 功能

- **常驻菜单栏。** 点按图标，再点按验证码，即已拷贝。没有程序坞图标，也没有需要管理的窗口。
- **预览下一个验证码。** 每行右侧显示即将生效的验证码，行背后的半透明填充显示当前验证码的剩余时间。
- **纯键盘或纯鼠标，随你选择。** 全局快捷键，输入即搜索，↩ 拷贝，⌘↑/↓ 调整顺序，Esc 关闭。
  请参阅[拷贝验证码](#copying-codes)和[分组](#groups)。
- **支持所有常见令牌类型。** TOTP（SHA-1、SHA-256、SHA-512，6–8 位，任意周期）、HOTP（基于计数器）和 Steam Guard。
- **无需手机即可添加令牌。** 粘贴 `otpauth://` 链接、Base32 密钥或包含二维码的图像即可。
- **自由迁入迁出。** 可从 Google 身份验证器、2FAS、Aegis、Ente Auth、Bitwarden、Proton Authenticator、
  Stratum、andOTP、FreeOTP+、Raivo OTP 和密码管理器 CSV 导入；可导出到 2FAS、Aegis、Ente Auth、Bitwarden 和 Google 身份验证器。
- **分组。** 可折叠的分区，拖放即可排序和移动令牌，在 2FAS、Aegis 和 Ente 导出中保留。
- **服务图标。** 可使用任意 [Aegis 图标包](#service-icons)、手动挑选图标、使用自己的图像，或获取网站的网站图标。
- **默认锁定。** 显示验证码前需要触控 ID（或 Mac 密码），还可额外设置主密码。
- **安全。** 令牌以 AES-256-GCM 加密，密钥保存在你的登录钥匙串中。请参阅[安全性](#security)。
- **私密。** 所有数据都留在你的 Mac 上。无需账户，不同步，不做分析。
- **使用你的语言。** English、Deutsch、Español、Français、Italiano、日本語、한국어、Português (Brasil)、简体中文和
  繁體中文。跟随 Mac 的语言，或在 **⋯ → 语言**中选择。
- **小巧原生。** 使用 Swift 和 SwiftUI 构建，仅几 MB。需要 macOS 14 Sonoma 或更高版本；支持 Apple 芯片和 Intel。

<a id="install"></a>
## 安装

### 下载

1. 从[最新版本](https://github.com/outerstudio/trayotp/releases/latest)下载 `TrayOTP-vX.Y.Z.zip`。
2. 解压后将 **TrayOTP.app** 移到“**应用程序**”文件夹。
3. 打开它。首次打开时，macOS 会提示无法验证该 App（见下文）。

**为什么会有警告？** TrayOTP 是开源软件，没有使用付费的 Apple Developer 证书签名，因此
macOS 无法确认开发者。要照常打开：

- 请按照 Apple 的[打开来自身份不明开发者的 Mac App](https://support.apple.com/zh-cn/guide/mac-help/mh40616/26/mac/26)指南操作，并在页面上选择你的 macOS 版本。

每个版本只需操作一次。如果你不想信任下载的版本，
可以在大约一分钟内[自行构建](#build-from-source)。

**校验下载（可选）：** 每个版本都附带 `.sha256` 文件。在“终端”中运行：

```sh
shasum -a 256 -c TrayOTP-vX.Y.Z.zip.sha256
```

<a id="build-from-source"></a>
### 从源代码构建

只需要 Apple 的 **Command Line Tools**：

```sh
xcode-select --install                                 # 已安装则跳过
git clone https://github.com/outerstudio/trayotp.git
cd trayotp
make release                                           # 构建 build/TrayOTP.app
cp -R build/TrayOTP.app /Applications/
```

自行构建的 App 打开时不会有任何警告。

<a id="getting-started"></a>
## 快速上手

1. 点按菜单栏中的 TrayOTP 图标（圆圈里的锁），使用触控 ID 解锁。
2. 添加令牌：
   - **从其他 App：** 点按**添加 → 从文件导入…**；如果是 Google 身份验证器，点按
     **添加 → 用摄像头扫描二维码…**（请参阅[导入和导出](#import-and-export)）。
   - **逐个添加：** 点按**添加**，粘贴设置链接或密钥（请参阅[添加令牌](#adding-a-token)）。
3. 点按任意验证码即可拷贝。

<a id="using-trayotp"></a>
## 使用 TrayOTP

<a id="copying-codes"></a>
### 拷贝验证码

- **随处打开：** 在 **⋯ → 设置全局快捷键…** 中设置组合键，然后在任意 App 中按下。
  **Esc** 关闭面板并返回之前使用的 App。
- **点按验证码**即可拷贝，会有提示确认。点按行右侧的下一个验证码（或右键点按 →“**拷贝下一个验证码**”）则拷贝下一个验证码。
- **键盘：** 面板打开时搜索栏处于激活状态。输入以筛选，**↑/↓** 选择，**Return**（↩）拷贝，**→** 拷贝下一个验证码。
  在第一行按 **↑** 会回到搜索栏。
- 对于基于计数器（HOTP）的令牌，右键点按 →“**下一个验证码**”以推进计数器。
- **编辑令牌：** 右键点按 →“**编辑…**”可更改服务名称和账户。验证码保持不变。
- 打开 ⋯ 菜单中的“**拷贝后关闭**”后，每次拷贝都会关闭面板，方便立即粘贴。
- 拷贝的验证码会对剪贴板管理器隐藏，并在 30 秒后从剪贴板清除。

<a id="adding-a-token"></a>
### 添加令牌

点按面板底部的**添加**，然后粘贴以下任一内容：

| 你有 | 操作 |
|---|---|
| `otpauth://…` 设置链接 | 直接粘贴。名称、账户和设置会从链接中填入。 |
| 类似 `JBSW Y3DP EHPK 3PXP` 的密钥 | 粘贴并输入名称（例如“GitHub”）。空格和小写字母都没问题。 |
| 屏幕上的二维码 | 截图到剪贴板（**⌃⇧⌘4**），或右键点按图像 →“**拷贝图像**”。然后打开**添加**（会自动填入），或点按**粘贴链接、密钥或二维码图像**。 |
| 其他设备或纸上的二维码 | 点按**用摄像头扫描二维码…**，将其对准 Mac 的摄像头。 |

保存前会实时预览验证码，方便你与网站核对。

> **提示：同时把新令牌添加到手机上。** 当网站显示双重认证设置二维码时，
> 用手机 App（Google 身份验证器、2FAS、Aegis…）扫描，*同时*截图添加到 TrayOTP（**⌃⇧⌘4**，然后**添加**）。
> 这是同一个密钥，两边显示的验证码相同；即使丢失手机或 Mac，你也还有备份。
> 请在网站上输入确认码之前完成：大多数网站不会再次显示该二维码。
> 没有二维码？拷贝设置密钥（通常位于“无法扫描？”下方），在两个 App 中分别输入。

<a id="groups"></a>
### 分组

- **创建分组：** **⋯ → 新建分组…**，或右键点按令牌 →“**移到分组 → 新建分组…**”。
- **移动令牌：** 右键点按 →“**移到分组**”，或将其拖到分组标题上。
- **调整顺序：** 把令牌拖到另一个令牌上：放在该行上半部分会排在其上方，下半部分则在其下方。
  也可以选中后按 **⌘↑/⌘↓**；越过分组末尾时会移入下一个分组。将分组标题拖到另一个标题上可调整分组顺序。
- **折叠：** 点按分组标题（“未分组”也可以）。搜索始终能找到折叠分组中的令牌。
  用 ↑/↓ 将选择移入折叠的分组时，它会展开直到你移出；只有点按标题才会保存展开或折叠状态。
- **重命名、移动或删除分组：** 右键点按其标题。删除分组会保留其中的令牌，它们会移到“未分组”。

<a id="service-icons"></a>
### 服务图标

TrayOTP 不附带品牌标志，而是读取
[Aegis 图标包格式](https://github.com/beemdevelopment/Aegis/blob/master/docs/iconpacks.md)的图标包：

1. 从 [aegis-icons 发布页面](https://github.com/aegis-icons/aegis-icons/releases)下载 `aegis-icons.zip`
   （或任何兼容 Aegis 的图标包）。
2. **⋯ → 安装 Aegis 图标包…**，然后选择 ZIP 文件。

令牌会根据发行方或名称自动匹配图标（“Google Workspace”→ Google）。
其他情况下，右键点按令牌：

| 菜单项 | 作用 |
|---|---|
| **编辑图标…** | 调整当前图标（仅当令牌有图标而非首字母时） |
| **从图标包选择图标…** | 搜索已安装的图标包并手动挑选图标 |
| **从文件设置图标…** | 使用图像文件（PNG、JPEG、SVG、HEIC、PDF…） |
| **粘贴图标** | 使用你拷贝的图像 |
| **从网站获取图标…** | 下载网站的网站图标（先确认域名） |
| **移除图标** | 恢复为自动图标或彩色首字母 |

要一次设置多个，**⋯ → 从文件夹导入图标…** 会将图像文件名与令牌名称匹配
（`github.png` → GitHub）。你自己选择的图标总是优先于图标包的自动匹配。

> **隐私说明：** **从网站获取图标…** 通过 DuckDuckGo 的图标服务下载网站图标，因此
> DuckDuckGo 会看到该域名。只有在你主动选择时才会发生，绝不会自动进行。

<a id="import-and-export"></a>
### 导入和导出

**导入：** **添加 → 从文件导入…**，然后选择文件。TrayOTP 会识别 App，文件已加密时会要求输入备份密码。
无法导入的内容会在最后列出。

**导出：** **⋯ → 备份与导出 ▸ → 导出到其他 App ▸**，然后选择 App。TrayOTP 会先要求触控 ID。

| App | 导入 | 导出 | 分组 |
|---|---|---|---|
| **2FAS**（`.2fas`） | 未加密或加密 | 未加密或加密 | ✓ |
| **Aegis**（`.json`） | 未加密或加密 | 未加密或加密 | ✓（含图标） |
| **Ente Auth**（`.txt`） | 纯文本 | 纯文本 | ✓（作为标签） |
| **Google 身份验证器** | “转移账号”二维码 | 二维码（30 秒，6 或 8 位） | — |
| **Bitwarden** 和 **Bitwarden Authenticator**（`.json`、`.csv`） | 未加密 | 未加密 JSON（不含 HOTP） | ✓（文件夹） |
| **Proton Authenticator**（`.json`） | 未加密或加密 | — | — |
| **Stratum** / Authenticator Pro | 未加密或加密 | — | ✓（类别） |
| **andOTP**（`.json`、`.json.aes`） | 未加密或加密 | — | ✓（第一个标签） |
| **FreeOTP+**（`.json`） | ✓ | — | — |
| **Raivo OTP**（`.zip`，未经测试，[请反馈](https://github.com/outerstudio/trayotp/issues)） | 受密码保护的 ZIP | — | — |
| **Apple 密码**（`.csv`） | 验证码（`OTPAuth` 列） | — | — |
| **其他密码管理器**（`.csv`，未经测试，[请反馈](https://github.com/outerstudio/trayotp/issues)）：1Password、KeePassXC… | 名为 `OTPAuth`、`TOTP` 或 `login_totp` 的列 | — | ✓（文件夹/分组） |
| 任何包含 `otpauth://` 链接的文本文件 | ✓ | ✓ | — |

**Google 身份验证器：** 在手机上打开 **⋮ → 转移账号 → 导出账号**。Google 禁止对此界面截图，
因此请在 TrayOTP 中点按**添加 → 用摄像头扫描二维码…**，将调高亮度的手机对准 Mac 的摄像头，距离约 20–30 厘米。
二维码中的所有账户会一次性导入。如果 Google 显示了多个二维码，请逐个扫描。密集的二维码较难被摄像头识别：
如果无法识别，请减少每次导出的账户数量。

没有内置摄像头（Mac mini、Mac Studio、Mac Pro）？可以使用 USB 摄像头，也可以把未安装 Google 身份验证器的
iPhone 或 iPad 用作摄像头（连续互通相机）。或者用另一部手机拍下转移界面，把照片传到 Mac（隔空投送、iCloud 照片、邮件…），
再通过**添加 → 从文件导入…** 导入：支持 PNG、JPEG 和 HEIC。

**导出到 Google 身份验证器：** **⋯ → 备份与导出 → 导出到其他 App → Google 身份验证器（二维码）…** 会以二维码形式显示账户，
每个二维码 10 个。在 Google 身份验证器中打开 **⋮ → 转移账号 → 导入账号**，逐个扫描。Google 只接受 6 位或 8 位的
30 秒验证码，因此其他令牌（以及 Steam）会被略过，并告诉你是哪些。
该窗口不会出现在截图和屏幕共享中，并会在 TrayOTP 锁定时关闭。

**重复项：** 如果已存在密钥和账户都相同的令牌，就会跳过，因此重复导入同一文件（或相互重叠的 Google 二维码）
不会新增任何内容。名称和账户与现有令牌相同但密钥不同的令牌会保留，名称后附加添加时间（例如 `GitHub 2026-11-17 23:40`），
并在导入后列出。这通常意味着网站签发了新密钥；确认新令牌可用后，请删除旧令牌。逐个添加令牌时也是如此。

**未经测试**表示 TrayOTP 按照文档读取该格式，但尚未用该 App 实际导出的文件测试过。
如果导入失败或验证码不一致，请[提交 issue](https://github.com/outerstudio/trayotp/issues) 并注明 App 名称和版本
（切勿附上文件：其中包含你的密钥）。

> **在旧 App 中删除令牌之前，** 请确认几个导入的验证码与旧 App 显示的一致。

不支持：加密的 Ente Auth 导出（请改为从 Ente 导出纯文本）、加密的 Bitwarden 导出、原版 FreeOTP 的备份、
Authy 和 Microsoft Authenticator（它们无法导出），以及 Yandex 和 mOTP 令牌。

> **未加密的导出文件以纯文本形式包含你的所有密钥。** 导入后请删除该文件。
> 如需长期保存备份，请使用 **Aegis（加密）**：它的密码保护（scrypt）比 2FAS 更难破解。

### 锁定和设置

全部位于 **⋯** 菜单中：

| 设置 | 作用 |
|---|---|
| **要求解锁** | 显示验证码前要求触控 ID 或 Mac 密码（默认开启）。 |
| **保持解锁 ▸** | 上次使用后 TrayOTP 保持解锁的时长：每次都锁定、1 分钟到 1 小时、**直到 Mac 睡眠或锁定**，或自定分钟数。Mac 睡眠或屏幕锁定时总会锁定。 |
| **设置主密码…** | 导出或删除令牌之前需要输入的密码（请参阅[安全性](#security)）。设置后，菜单会提供更改、移除、**用密码代替 Touch ID 解锁**，以及用于抹除所有令牌并重新开始的**忘记密码…**。 |
| **密码提醒 ▸** | 每 7、30 或 90 天（或自定义天数）再次询问密码，以免你忘记。默认 30 天。 |
| **设置全局快捷键…** | 用你选择的组合键从任意 App 打开面板（需包含 ⌘、⌃ 或 ⌥）。 |
| **显示菜单栏图标** | 关闭后隐藏图标。之后通过全局快捷键（或在访达、启动台中再次打开 TrayOTP）在屏幕顶部显示面板。 |
| **拷贝后关闭** | 拷贝验证码后立即关闭面板，方便马上粘贴。 |
| **30 秒后清除剪贴板** | 30 秒后从剪贴板清除已拷贝的验证码（仅当剪贴板中仍是该验证码时）。默认开启。 |
| **备份与导出 ▸** | 一键将加密备份（Aegis 格式，可用“从文件导入…”恢复）保存到您选定的文件夹；上次备份超过 7、30（默认）或 90 天时会提醒您。 “**从备份恢复…**”会打开与 **添加 → 从文件导入…** 相同的文件选择窗口。 |
| **深黑主题** | 面板背景使用纯黑，而非半透明材质，适合 OLED 屏幕。 |
| **登录时启动** | 登录时启动 TrayOTP。 |
| **语言 ▸** | “**系统语言**”跟随 Mac 的语言（若 TrayOTP 没有该语言的翻译则使用英文），也可以选择其中一种翻译。切换时 TrayOTP 会重新启动。 |

点按面板底部的**锁定**可立即锁定。

<p align="center">
  <img src="../docs/screenshots/lock-screen.png" width="340" alt="锁定的面板：“TrayOTP 已锁定”、触控 ID 提示，以及“使用密码…”和“退出”按钮">
</p>

<a id="security"></a>
## 安全性

### 密钥的存储方式

- 令牌以加密形式（**AES-256-GCM**）存储在你的 Mac 上，该文件只有你的用户账户可以读取。
- 加密密钥是随机的 256 位密钥，保存在你的**登录钥匙串**中，从不与文件放在一起。
- 开启**要求解锁**后，只有在触控 ID 或 Mac 密码验证后才会解密保险库，再次锁定时已解密的令牌会从内存中清除。
- **导出**、**删除令牌**和**更改主密码**总会再次要求输入密码，即使 TrayOTP 已解锁。请参阅[主密码](#master-password)。
- 除了你通过**从网站获取图标…** 主动查询的域名外，没有任何数据离开你的 Mac。
- 摄像头仅在**扫描二维码**窗口打开时使用。画面只在内存中读取，从不保存。
  macOS 首次会请求摄像头权限，更新后可能再次请求（TrayOTP 使用临时签名）。

<a id="master-password"></a>
### 主密码

触控 ID 可能让别人在你睡着时用你的手指解锁，所以 TrayOTP 会要求你输入一个密码。
添加或导入第一个令牌后，TrayOTP 会请你设置**主密码**。它会拦在以下操作之前：

- 导出令牌（该密码默认也用于加密备份文件；每次导出你也可以另选一个密码），
- 删除令牌（输入一次后，2 分钟内再次删除不会再询问），
- 将单个令牌显示为二维码（右键 → **导出…**，用于添加到另一个验证器应用；
  输入一次密码后，3 分钟内再显示二维码不会再询问），
- 更改或移除密码。

默认情况下，它不会取代触控 ID 来打开 TrayOTP。开启 **⋯ → 主密码 → 用密码代替 Touch ID 解锁** 后，钥匙串中的保险库密钥本身
会用从同一密码派生的密钥加密（scrypt，N=2¹⁷，r=8，p=1：每次尝试约 0.5 秒、128 MB）。即使有人进入你的钥匙串，仍须猜出密码。
开启、关闭或更改密码都会切换到新的保险库密钥，因此旧的钥匙串副本（例如时间机器备份中的副本）此后无法打开保险库。

**如果忘记，将无法恢复。** 未开启解锁选项时，唯一的出路是 **⋯ → 主密码 → 忘记密码…**，这会抹除你所有的令牌。开启后，令牌完全
无法恢复。在只依赖 TrayOTP 之前，请确保你能用其他方式（备份码或加密导出）登录每个账户。**密码提醒**会每隔一段天数询问密码，
让你不会忘记。

你可以输入*我了解风险*来跳过。这样导出和删除只会要求触控 ID 或 Mac 密码，任何坐在已解锁 Mac 前的人都能导出你所有的令牌。
这也留下一个缺口：如果你跳过了，最先打开 TrayOTP 的人可以设置密码。之后可以用 **⋯ → 设置主密码…** 开启。

<a id="limitations"></a>
### 限制

- TrayOTP 没有使用 Apple Developer 证书签名，因此 macOS 不允许它在钥匙串中将保险库密钥与触控 ID 绑定。
  触控 ID 由 App 强制执行；如果其他 App 请求该密钥，macOS 会弹出 **“想要使用你的钥匙串”** 提示。
  你只应在更新 TrayOTP 后首次打开时看到这个提示。**如果在其他时候出现，或提示中的 App 不是 TrayOTP，请点按“拒绝”：**
  有别的程序正试图读取保护你令牌的密钥。
- 你的密钥只和你的 Mac 一样安全。请开启 **FileVault**、**加密时间机器备份**，并使用强登录密码。
  如果保险库文件和登录钥匙串同时被盗，挡在中间的就是登录密码（以及你设置的主密码）。
- 构建版本使用强化运行时，可阻止其他进程向 TrayOTP 注入代码或附加调试器。

发现安全问题？请通过仓库的 [Security 标签页](https://github.com/outerstudio/trayotp/security)私下报告，不要提交公开 issue。

<a id="troubleshooting"></a>
## 故障排除

- **更新后出现“TrayOTP 想要使用你的钥匙串”**
  - 每个版本都是单独签名的，所以每次更新后 macOS 都会再次询问。输入登录钥匙串密码（通常就是 Mac 密码），然后选择**始终允许**。
    如果在其他时候出现，请参阅[限制](#limitations)。
- **启动台显示空白图标**
  - 启动台只列出 `/Applications` 中的 App。如果移到那里后图标仍为空白，请运行 `killall Dock`。
- **无法识别二维码**
  - 把截图裁得更贴近二维码。对于 Google 身份验证器，请使用**添加 → 用摄像头扫描二维码…**（请参阅[导入和导出](#import-and-export)）。
- **“备份密码错误”**
  - 请使用从其他 App（或 TrayOTP）导出备份时设置的密码，而不是 Mac 密码。

## 风险自负

TrayOTP 是免费的开源软件，按“原样”提供，不附带任何形式的担保（请参阅[许可证](../LICENSE)）。
对于账户无法访问、密钥丢失或泄露，或任何其他损失，作者概不负责。

丢失双重认证验证码可能会让你无法登录账户，所以不要让 TrayOTP 成为唯一的副本：

- 设置双重认证时，保存每个网站的**恢复代码**。
- 在第二个 App（例如手机上的 App）中也保留该令牌（请参阅[添加令牌](#adding-a-token)中的提示）。
- 时常导出加密备份（**⋯ → 备份与导出 → 立即备份**）并妥善保存。
- 导入后，在旧 App 中删除任何内容之前，先核对几个验证码。

## 支持

TrayOTP 是免费的。如果它为你节省了时间，欢迎[请我喝杯咖啡](https://buymeacoffee.com/garyyeap)
（也可在 ⋯ 菜单中找到），或通过 [Ko-fi](https://ko-fi.com/garyyeap)、[Liberapay](https://liberapay.com/garyyeap) 或 [thanks.dev](https://thanks.dev/u/gh/garyyeap) 赞助。

## 开发

构建、测试、项目结构、翻译和格式细节请参阅[英文 README](../README.md#development)，
[致谢](../README.md#credits)也在那里。

## 许可证

[MIT](../LICENSE) © 2026 outerstudio.com
