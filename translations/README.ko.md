<p align="center">
  <img src="../docs/app-icon.gif" width="128" alt="TrayOTP 아이콘">
</p>

<h1 align="center">TrayOTP</h1>

<p align="center">
  <a href="../README.md">English</a> · <a href="README.de.md">Deutsch</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> ·
  <a href="README.it.md">Italiano</a> · <a href="README.ja.md">日本語</a> · <b>한국어</b> ·
  <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a>
</p>

<p align="center">
  <b>2단계 인증 코드를 macOS 메뉴 막대에서 클릭 한 번으로.</b><br>
  Google OTP, 2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator 등에서 가져올 수 있습니다. 암호화, 오프라인, 오픈 소스.
</p>

<p align="center">
  <a href="https://github.com/outerstudio/trayotp/releases/latest"><img src="https://img.shields.io/github/v/release/outerstudio/trayotp?label=download" alt="최신 릴리스"></a>
  <a href="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml"><img src="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14 이상">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT 라이선스"></a>
  <a href="https://buymeacoffee.com/garyyeap"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee"></a>
  <a href="https://ko-fi.com/garyyeap"><img src="https://img.shields.io/badge/Ko--fi-72a4f2?logo=kofi&logoColor=white" alt="Ko-fi"></a>
  <a href="https://liberapay.com/garyyeap"><img src="https://img.shields.io/badge/Liberapay-f6c915?logo=liberapay&logoColor=black" alt="Liberapay"></a>
  <a href="https://thanks.dev/u/gh/garyyeap"><img src="https://img.shields.io/badge/thanks.dev-000000?logo=thanksdotdev&logoColor=white" alt="thanks.dev"></a>
</p>

<p align="center">
  <a href="#install">설치</a> ·
  <a href="#getting-started">시작하기</a> ·
  <a href="#using-trayotp">TrayOTP 사용하기</a> ·
  <a href="#security">보안</a> ·
  <a href="#troubleshooting">문제 해결</a>
</p>

<p align="center">
  <img src="../docs/screenshots/panel.png" width="340" alt="메뉴 막대 아이콘 아래의 TrayOTP 패널: 검색 필드, 이름·코드·계정·다음 코드가 표시된 토큰, 추가·잠금·종료 버튼">
  <img src="../docs/screenshots/deep-black.png" width="340" alt="딥 블랙 테마의 패널: OLED 화면을 위한 완전한 검은색 배경">
</p>

> 이 번역은 [영어 README](../README.md)보다 오래되었을 수 있습니다. 내용이 다르면 영어 버전이 우선합니다.

## 기능

- **메뉴 막대에 상주.** 아이콘을 클릭하고 코드를 클릭하면 복사됩니다. Dock 아이콘도, 관리할 윈도우도 없습니다.
- **다음 코드 미리 보기.** 각 행 오른쪽에 다음 코드가 표시되고, 행 뒤의 반투명 채우기가 현재 코드의 남은 시간을 보여줍니다.
- **키보드만, 또는 클릭만. 원하는 대로.** 전역 단축키, 입력해서 검색, ↩로 복사, ⌘↑/↓로 순서 변경, Esc로 닫기.
  [코드 복사하기](#copying-codes)와 [그룹](#groups)을 참조하십시오.
- **일반적인 토큰 유형 모두 지원.** TOTP(SHA-1, SHA-256, SHA-512, 6–8자리, 모든 주기), HOTP(카운터 기반), Steam Guard.
- **휴대폰 없이 토큰 추가.** `otpauth://` 링크, Base32 비밀 키 또는 QR 코드가 담긴 이미지를 붙여넣기만 하면 됩니다.
- **자유롭게 옮기기.** Google OTP, 2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator,
  Stratum, andOTP, FreeOTP+, Raivo OTP, 암호 관리자 CSV에서 가져오기. 2FAS, Aegis, Ente Auth, Bitwarden, Google OTP로 내보내기.
- **그룹.** 접을 수 있는 섹션, 드래그 앤 드롭으로 정렬 및 이동. 2FAS, Aegis, Ente 내보내기에서도 유지됩니다.
- **서비스 아이콘.** 모든 [Aegis 아이콘 팩](#service-icons)을 사용하거나, 직접 아이콘을 고르거나, 자신의 이미지를 쓰거나, 사이트의 파비콘을 가져올 수 있습니다.
- **기본적으로 잠김.** 코드를 보여주기 전에 Touch ID(또는 Mac 암호)를 요구하며, 선택적으로 마스터 암호를 추가할 수 있습니다.
- **안전.** 토큰은 AES-256-GCM으로 암호화되며 키는 로그인 키체인에 보관됩니다. [보안](#security)을 참조하십시오.
- **비공개.** 모든 것이 Mac에 머뭅니다. 계정, 동기화, 분석 없음.
- **사용자의 언어로.** English, Deutsch, Español, Français, Italiano, 日本語, 한국어, Português (Brasil), 简体中文,
  繁體中文. Mac의 언어를 따르거나 **⋯ → 언어**에서 선택할 수 있습니다.
- **작고 네이티브.** Swift와 SwiftUI, 몇 MB. macOS 14 Sonoma 이상이 필요하며 Apple 실리콘과 Intel에서 실행됩니다.

<a id="install"></a>
## 설치

### 다운로드

1. [최신 릴리스](https://github.com/outerstudio/trayotp/releases/latest)에서 `TrayOTP-vX.Y.Z.zip`을 다운로드합니다.
2. 압축을 풀고 **TrayOTP.app**을 **응용 프로그램** 폴더로 옮깁니다.
3. 엽니다. 처음에는 macOS가 앱을 확인할 수 없다고 알립니다(아래 참조).

**경고가 나타나는 이유:** TrayOTP는 오픈 소스이며 유료 Apple Developer 인증서로 서명되지 않았기 때문에
macOS가 제작자를 확인할 수 없습니다. 그래도 열려면:

- Apple의 [확인되지 않은 개발자의 Mac 앱 열기](https://support.apple.com/ko-kr/guide/mac-help/mh40616/26/mac/26) 안내를 따르고, 페이지에서 사용 중인 macOS 버전을 선택하세요.

버전마다 한 번만 하면 됩니다. 다운로드한 빌드를 신뢰하고 싶지 않다면
약 1분 만에 [직접 빌드](#build-from-source)할 수 있습니다.

**다운로드 확인(선택 사항):** 각 릴리스에는 `.sha256` 파일이 포함되어 있습니다. 터미널에서:

```sh
shasum -a 256 -c TrayOTP-vX.Y.Z.zip.sha256
```

<a id="build-from-source"></a>
### 소스에서 빌드하기

Apple의 **Command Line Tools**만 있으면 됩니다:

```sh
xcode-select --install                                 # 이미 설치되어 있으면 건너뛰기
git clone https://github.com/outerstudio/trayotp.git
cd trayotp
make release                                           # build/TrayOTP.app 빌드
cp -R build/TrayOTP.app /Applications/
```

직접 빌드한 앱은 경고 없이 열립니다.

<a id="getting-started"></a>
## 시작하기

1. 메뉴 막대의 TrayOTP 아이콘(원 안의 자물쇠)을 클릭하고 Touch ID로 잠금을 해제합니다.
2. 토큰을 추가합니다:
   - **다른 앱에서:** **추가 → 파일에서 가져오기…**를 클릭합니다. Google OTP는
     **추가 → 카메라로 QR 코드 스캔…**을 사용합니다([가져오기 및 내보내기](#import-and-export) 참조).
   - **하나씩:** **추가**를 클릭하고 설정 링크나 비밀 키를 붙여넣습니다([토큰 추가하기](#adding-a-token) 참조).
3. 아무 코드나 클릭하면 복사됩니다.

<a id="using-trayotp"></a>
## TrayOTP 사용하기

<a id="copying-codes"></a>
### 코드 복사하기

- **어디서나 열기:** **⋯ → 전역 단축키 설정…**에서 키 조합을 설정한 다음 아무 앱에서나 누르십시오.
  **Esc**를 누르면 패널이 닫히고 이전에 사용하던 앱으로 돌아갑니다.
- **코드를 클릭**하면 복사되며 메시지로 확인됩니다. 행 오른쪽의 다음 코드를 클릭(또는 오른쪽 클릭 → **다음 코드 복사**)하면 그 코드를 복사합니다.
- **키보드:** 패널을 열면 검색 필드가 선택되어 있습니다. 입력해서 필터링하고, **↑/↓**로 선택, **Return**(↩)으로 복사, **→**로 다음 코드를 복사합니다.
  맨 위 행에서 **↑**를 누르면 검색 필드로 돌아갑니다.
- 카운터 기반(HOTP) 토큰은 오른쪽 클릭 → **다음 코드**로 카운터를 증가시킵니다.
- **토큰 편집:** 오른쪽 클릭 → **편집…**에서 서비스 이름과 계정을 변경합니다. 코드는 그대로 유지됩니다.
- **토큰 코드를 항상 숨기기:** 우클릭 → **항상 코드 숨기기**. **코드 숨기기**이(가) **안 함**이어도 클릭하기 전까지 가려진 채로 있습니다.
- ⋯ 메뉴의 **복사 후 닫기**를 켜면 복사할 때마다 패널이 닫혀 바로 붙여넣을 수 있습니다.
- 복사한 코드는 클립보드 관리자에게 숨겨지며 30초 후 클립보드에서 지워집니다.

<a id="adding-a-token"></a>
### 토큰 추가하기

패널 하단의 **추가**를 클릭한 다음, 다음 중 하나를 붙여넣습니다:

| 가진 것 | 할 일 |
|---|---|
| `otpauth://…` 설정 링크 | 붙여넣습니다. 이름, 계정, 설정이 링크에서 채워집니다. |
| `JBSW Y3DP EHPK 3PXP` 같은 비밀 키 | 붙여넣고 이름(예: ‘GitHub’)을 입력합니다. 공백이나 소문자도 괜찮습니다. |
| 화면의 QR 코드 | 클립보드로 스크린샷(**⌃⇧⌘4**)을 찍거나, 이미지를 오른쪽 클릭 → **이미지 복사**. 그런 다음 **추가**를 열거나(자동으로 채워짐) **링크, 비밀 키 또는 QR 이미지 붙여넣기**를 클릭합니다. |
| 다른 기기나 종이에 있는 QR 코드 | **카메라로 QR 코드 스캔…**을 클릭하고 Mac 카메라에 비춥니다. |

저장하기 전에 실시간 미리 보기로 코드가 표시되므로 웹 사이트와 비교할 수 있습니다.

> **팁: 새 토큰을 휴대폰에도 동시에 추가하십시오.** 웹 사이트에 2FA 설정 QR 코드가 표시되면
> 휴대폰 앱(Google OTP, 2FAS, Aegis…)으로 스캔하고 *동시에* 스크린샷으로 TrayOTP에 추가합니다(**⌃⇧⌘4**, 그다음 **추가**).
> 같은 비밀 키이므로 두 곳에 같은 코드가 표시되고, 휴대폰이나 Mac을 잃어버려도 백업이 남습니다.
> 웹 사이트에 확인 코드를 입력하기 전에 하십시오. 대부분의 사이트는 QR 코드를 다시 보여주지 않습니다.
> QR 코드가 없나요? 설정 키(‘스캔할 수 없나요?’ 아래에 있는 경우가 많음)를 복사하여 두 앱에 모두 입력하십시오.

<a id="groups"></a>
### 그룹

- **그룹 생성:** **⋯ → 새로운 그룹…**, 또는 토큰을 오른쪽 클릭 → **그룹으로 이동 → 새로운 그룹…**.
- **토큰 이동:** 오른쪽 클릭 → **그룹으로 이동**, 또는 그룹 머리말로 드래그합니다.
- **순서 변경:** 토큰을 다른 토큰 위로 드래그합니다. 행의 위쪽 절반에 놓으면 위로, 아래쪽 절반에 놓으면 아래로 들어갑니다.
  또는 선택하고 **⌘↑/⌘↓**를 누릅니다. 그룹의 끝을 넘어가면 다음 그룹으로 이동합니다. 그룹 머리말을 다른 머리말로 드래그하면 그룹 순서가 바뀝니다.
- **접기:** 그룹 머리말(‘그룹 없음’ 포함)을 클릭합니다. 검색은 접힌 그룹의 토큰도 항상 찾습니다.
  ↑/↓로 접힌 그룹에 선택을 옮기면 벗어날 때까지 열립니다. 열림/닫힘 상태는 머리말을 클릭할 때만 저장됩니다.
- **그룹 이름 변경, 이동 또는 삭제:** 머리말을 오른쪽 클릭합니다. 그룹을 삭제해도 토큰은 유지되며 ‘그룹 없음’으로 이동합니다.

<a id="service-icons"></a>
### 서비스 아이콘

TrayOTP에는 브랜드 로고가 포함되어 있지 않습니다. 대신
[Aegis 아이콘 팩 형식](https://github.com/beemdevelopment/Aegis/blob/master/docs/iconpacks.md)의 아이콘 팩을 읽습니다:

1. [aegis-icons 릴리스](https://github.com/aegis-icons/aegis-icons/releases)에서 `aegis-icons.zip`을 다운로드합니다
   (또는 다른 Aegis 호환 팩).
2. **⋯ → 아이콘 팩 → Aegis 아이콘 팩 설치…**에서 ZIP을 선택합니다.

토큰은 발급자나 이름으로 자동으로 아이콘을 받습니다(‘Google Workspace’ → Google).
그 외에는 토큰을 오른쪽 클릭:

| 메뉴 항목 | 기능 |
|---|---|
| **아이콘 편집…** | 현재 아이콘 조정(이니셜이 아닌 아이콘이 있을 때만) |
| **팩에서 아이콘 선택…** | 설치된 팩을 검색하여 직접 아이콘 선택 |
| **파일에서 아이콘 설정…** | 이미지 파일 사용(PNG, JPEG, SVG, HEIC, PDF…) |
| **아이콘 붙여넣기** | 복사한 이미지 사용 |
| **웹 사이트에서 아이콘 가져오기…** | 사이트의 파비콘 다운로드(먼저 도메인을 확인) |
| **아이콘 제거** | 자동 아이콘 또는 색상 이니셜로 되돌리기 |

여러 개를 한 번에 설정하려면 **⋯ → 아이콘 팩 → 폴더에서 아이콘 가져오기…**가 이미지 파일 이름을 토큰 이름과 일치시킵니다
(`github.png` → GitHub). 직접 선택한 아이콘은 항상 팩의 자동 일치보다 우선합니다.

> **개인정보 참고:** **웹 사이트에서 아이콘 가져오기…**는 DuckDuckGo의 아이콘 서비스를 통해 파비콘을 다운로드하므로
> DuckDuckGo가 해당 도메인을 알게 됩니다. 직접 선택할 때만 실행되며 자동으로 실행되지 않습니다.

<a id="import-and-export"></a>
### 가져오기 및 내보내기

**가져오기:** **추가 → 파일에서 가져오기…**에서 파일을 선택합니다. TrayOTP가 앱을 감지하고, 파일이 암호화되어 있으면
백업 암호를 요청합니다. 가져올 수 없는 항목은 마지막에 목록으로 표시됩니다.

**내보내기:** **⋯ → 백업 및 내보내기 ▸ → 다른 앱으로 내보내기 ▸**에서 앱을 선택합니다. TrayOTP가 먼저 Touch ID를 요청합니다.

| 앱 | 가져오기 | 내보내기 | 그룹 |
|---|---|---|---|
| **2FAS**(`.2fas`) | 일반 또는 암호화 | 일반 또는 암호화 | ✓ |
| **Aegis**(`.json`) | 일반 또는 암호화 | 일반 또는 암호화 | ✓(아이콘 포함) |
| **Ente Auth**(`.txt`) | 일반 텍스트 | 일반 텍스트 | ✓(태그로) |
| **Google OTP** | ‘계정 이전’ QR 코드 | QR 코드(30초, 6자리 또는 8자리) | — |
| **Bitwarden** 및 **Bitwarden Authenticator**(`.json`, `.csv`) | 암호화 안 함 | 암호화 안 된 JSON(HOTP 제외) | ✓(폴더) |
| **Proton Authenticator**(`.json`) | 일반 또는 암호화 | — | — |
| **Stratum** / Authenticator Pro | 일반 또는 암호화 | — | ✓(카테고리) |
| **andOTP**(`.json`, `.json.aes`) | 일반 또는 암호화 | — | ✓(첫 번째 태그) |
| **FreeOTP+**(`.json`) | ✓ | — | — |
| **Raivo OTP**(`.zip`, 미검증, [알려 주십시오](https://github.com/outerstudio/trayotp/issues)) | 암호로 보호된 ZIP | — | — |
| **Apple 암호**(`.csv`) | 인증 코드(`OTPAuth` 열) | — | — |
| **기타 암호 관리자**(`.csv`, 미검증, [알려 주십시오](https://github.com/outerstudio/trayotp/issues)): 1Password, KeePassXC… | 이름이 `OTPAuth`, `TOTP` 또는 `login_totp`인 열 | — | ✓(폴더/그룹) |
| `otpauth://` 링크가 담긴 모든 텍스트 파일 | ✓ | ✓ | — |

**Google OTP:** 휴대폰에서 **⋮ → 계정 이전 → 계정 내보내기**를 엽니다. Google은 이 화면의 스크린샷을 막기 때문에
TrayOTP에서 **추가 → 카메라로 QR 코드 스캔…**을 클릭하고, 밝기를 높인 휴대폰을 Mac 카메라에서 약 20–30cm 떨어진 곳에
비춥니다. 코드에 담긴 모든 계정을 한 번에 가져옵니다. Google에서 QR 코드를 여러 개 보여주면 각각 스캔하십시오.
밀도가 높은 코드는 웹캠이 읽기 어려우므로, 인식되지 않으면 한 번에 내보내는 계정 수를 줄이십시오.

내장 카메라가 없나요(Mac mini, Mac Studio, Mac Pro)? USB 웹캠도 되고, Google OTP가 설치되지 않은 iPhone이나 iPad를
웹캠으로 사용할 수도 있습니다(연속성 카메라). 또는 다른 휴대폰으로 이전 화면을 촬영하고 사진을 Mac으로 옮긴 다음
(AirDrop, iCloud 사진, 이메일…) **추가 → 파일에서 가져오기…**로 가져오십시오. PNG, JPEG, HEIC 모두 지원됩니다.

**Google OTP로:** **⋯ → 백업 및 내보내기 → 다른 앱으로 내보내기 → Google OTP(QR 코드)…**가 계정을 QR 코드로 표시합니다(코드당 10개).
Google OTP에서 **⋮ → 계정 이전 → 계정 가져오기**를 열고 각각 스캔하십시오. Google은 6자리 또는 8자리의 30초 코드만
지원하므로 다른 토큰(및 Steam)은 제외되며 어떤 토큰이 제외되었는지 알려줍니다.
이 윈도우는 스크린샷과 화면 공유에서 숨겨지며 TrayOTP가 잠기면 닫힙니다.

**중복:** 같은 비밀 키와 계정의 토큰이 이미 있으면 건너뛰므로, 같은 파일을 두 번 가져와도(또는 겹치는 Google QR 코드도)
새로 추가되는 것이 없습니다. 기존 토큰과 이름 및 계정이 같지만 비밀 키가 다른 토큰은 유지되며, 이름 뒤에 추가된 시간이
붙고(예: `GitHub 2026-11-17 23:40`) 가져오기 후 목록으로 표시됩니다. 보통 사이트에서 새 비밀 키를 발급했다는 뜻이므로,
새 토큰이 작동하면 이전 토큰을 삭제하십시오. 토큰을 하나씩 추가할 때도 마찬가지입니다.

**미검증**은 TrayOTP가 문서에 따라 형식을 읽지만, 해당 앱에서 내보낸 파일로는 아직 시험해 보지 않았다는 뜻입니다.
가져오기에 실패하거나 코드가 일치하지 않으면 앱 이름과 버전을 적어
[이슈를 등록](https://github.com/outerstudio/trayotp/issues)해 주십시오(파일은 절대 첨부하지 마십시오. 비밀 키가 들어 있습니다).

> **이전 앱에서 토큰을 삭제하기 전에** 가져온 코드 몇 개가 그 앱에 표시된 코드와 일치하는지 확인하십시오.

지원되지 않음: 암호화된 Ente Auth 내보내기(Ente에서 일반 텍스트로 내보내십시오), 암호화된 Bitwarden 내보내기,
원래 FreeOTP의 백업, Authy와 Microsoft Authenticator(내보내기 불가), Yandex 및 mOTP 토큰.

> **암호화되지 않은 내보내기에는 모든 비밀 키가 일반 텍스트로 들어 있습니다.** 가져온 후에는 파일을 삭제하십시오.
> 보관할 백업에는 **Aegis(암호화)**를 사용하십시오. 그 암호 보호(scrypt)는 2FAS보다 훨씬 깨기 어렵습니다.

### 잠금 및 설정

모두 **⋯** 메뉴에 있습니다:

| 설정 | 기능 |
|---|---|
| **잠금 해제 유지 ▸** | 마지막 사용 후 TrayOTP가 잠금 해제 상태를 유지하는 시간: 매번 잠금, 1분에서 1시간, **Mac이 잠자기 또는 잠금 상태가 될 때까지**, **직접 잠글 때까지**, 또는 사용자화 분. Mac이 잠자기 상태가 되거나 화면이 잠기면 잠기지만, **직접 잠글 때까지**는 잠금을 클릭할 때까지 잠금 해제 상태로 유지됩니다. |
| **마스터 암호 설정…** | 토큰을 내보내거나 삭제하기 전에 입력하는 암호입니다([보안](#security) 참조). 설정하면 메뉴에 변경, 제거, **Touch ID 대신 암호로 잠금 해제**, 그리고 모든 토큰을 지우고 다시 시작하는 **암호 분실…**이 표시됩니다. |
| **암호 알림 ▸** | 잊지 않도록 7일, 30일, 90일마다(또는 직접 지정한 일수마다) 암호를 다시 요청합니다. 기본값은 30일입니다. |
| **전역 단축키 설정…** | 원하는 키 조합으로 아무 앱에서나 패널을 엽니다(⌘, ⌃ 또는 ⌥ 필요). |
| **메뉴 막대 아이콘 보기** | 끄면 아이콘이 숨겨집니다. 그러면 전역 단축키(또는 Finder나 Launchpad에서 TrayOTP를 다시 열기)로 화면 상단에 패널이 표시됩니다. |
| **복사 후 닫기** | 코드가 복사되면 바로 패널을 닫아 즉시 붙여넣을 수 있게 합니다. |
| **30초 후 클립보드 지우기** | 복사한 코드를 30초 후 클립보드에서 지웁니다(여전히 그 코드가 들어 있을 때만). 기본값은 켜짐입니다. |
| **코드 숨기기 ▸** | 조작하기 전까지 코드를 점으로 가립니다: **안 함**(기본값), **가리킬 때까지**(포인터나 키보드 선택이 해당 행을 보여 줌), **클릭할 때까지**(행을 클릭하면 코드를 복사하고 10초 동안 보여 줌). 가려진 코드를 복사해도 표시됩니다. |
| **화면 공유에서 패널 숨기기** | 패널이 화면 공유, 스크린샷, 녹화에 나타나지 않게 합니다(내 스크린샷에도 나타나지 않습니다). |
| **백업 및 내보내기 ▸** | 한 번 선택한 폴더에 클릭 한 번으로 암호화 백업을 저장합니다(Aegis 형식이며 **파일에서 가져오기…**로 복원). 마지막 백업이 7일, 30일(기본값), 90일 지나면 알려 줍니다. **백업에서 복원…**은 **추가 → 파일에서 가져오기…**와 같은 파일 선택 창을 엽니다. |
| **딥 블랙 테마** | 반투명 재질 대신 완전한 검은색 패널 배경을 사용합니다. OLED 화면용입니다. |
| **로그인 시 실행** | 로그인할 때 TrayOTP를 시작합니다. |
| **업데이트 확인…** | 현재 버전, **지금 확인**, **자동으로 확인**(하루에 한 번, 기본값은 켜짐), **업데이트 채널**(**안정 버전**, **베타**, **알파**)이 있는 창을 엽니다. 새 릴리스가 있으면 추가 / 잠금 / 종료 아래에 **…(으)로 업데이트…** 버튼도 나타납니다. |
| **언어 ▸** | **시스템 언어**는 Mac의 언어를 따릅니다(TrayOTP가 해당 언어로 번역되지 않았으면 영어). 또는 번역 중 하나를 선택합니다. 전환하면 TrayOTP가 재시동됩니다. |

패널 하단의 **잠금**을 클릭하면 즉시 잠깁니다.

<p align="center">
  <img src="../docs/screenshots/lock-screen.png" width="340" alt="잠긴 패널: ‘TrayOTP가 잠겨 있음’, Touch ID 요청, 암호 사용… 및 종료 버튼">
</p>

<a id="security"></a>
## 보안

### 비밀 키가 저장되는 방식

- 토큰은 Mac에 암호화(**AES-256-GCM**)되어 저장되며, 해당 파일은 사용자 계정만 읽을 수 있습니다.
- 암호화 키는 임의의 256비트 키로, 파일 옆이 아닌 **로그인 키체인**에 보관됩니다.
- **내보내기**, **토큰 삭제**, **마스터 암호 변경**은 TrayOTP가 잠금 해제된 상태에서도 항상 암호를 다시 요청합니다. [마스터 암호](#master-password)를 참조하십시오.
- **내보내기**와 **토큰 삭제**는 TrayOTP가 잠금 해제된 상태에서도 항상 Touch ID를 다시 요청합니다.
- **웹 사이트에서 아이콘 가져오기…**로 직접 조회하는 도메인을 제외하면 어떤 것도 Mac 밖으로 나가지 않습니다.
- 카메라는 **QR 코드 스캔** 윈도우가 열려 있는 동안에만 사용됩니다. 프레임은 메모리에서 읽히며 저장되지 않습니다.
  macOS는 처음에 카메라 접근을 묻고, 업데이트 후 다시 물을 수 있습니다(TrayOTP는 애드혹 서명됨).

<a id="master-password"></a>
### 마스터 암호

Touch ID는 잠든 사이에 누군가 내 손가락을 사용할 수 있으므로, TrayOTP는 직접 입력하는 암호를 요청합니다.
첫 토큰을 추가하거나 가져오면 TrayOTP가 **마스터 암호**를 설정하라고 안내합니다. 이 암호는 다음 작업 앞에서 요구됩니다:

- 토큰 내보내기(이 암호는 기본적으로 백업 파일도 암호화합니다. 내보낼 때마다 다른 암호를 고를 수도 있습니다),
- 토큰 삭제(한 번 입력하면 2분 안의 추가 삭제에는 다시 묻지 않습니다),
- 토큰 하나를 QR 코드로 표시(오른쪽 클릭 → **내보내기…**, 다른 인증 앱에 추가할 때.
  암호를 한 번 입력하면 3분 안의 추가 QR 코드에는 다시 묻지 않습니다),
- 암호 변경 또는 제거.

기본적으로 TrayOTP를 여는 Touch ID를 대체하지는 않습니다. **⋯ → 마스터 암호 → Touch ID 대신 암호로 잠금 해제**를 켜면
키체인의 보관함 키 자체가 같은 암호에서 파생된 키로 암호화됩니다(scrypt, N=2¹⁷, r=8, p=1: 시도당 약 0.5초와 128MB).
키체인에 침입하더라도 암호를 추측해야 합니다. 켜기, 끄기 또는 암호 변경 시 새 보관함 키로 전환되므로,
이전 키체인 사본(예: Time Machine 백업)으로는 더 이상 보관함을 열 수 없습니다.

**잊어버리면 복구할 수 없습니다.** 잠금 해제 옵션이 없으면 다시 들어갈 유일한 방법은
**⋯ → 마스터 암호 → 암호 분실…**이며, 모든 토큰이 삭제됩니다. 옵션이 켜져 있으면 토큰을 전혀 복구할 수 없습니다.
TrayOTP에만 의존하기 전에 각 계정에 다른 방법(백업 코드나 암호화된 내보내기)으로 로그인할 수 있는지 확인하십시오.
**암호 알림**은 암호를 잊지 않도록 일정 일수마다 암호를 요청합니다.

*위험을 이해합니다*를 입력해 건너뛸 수 있습니다. 그러면 내보내기와 삭제는 Touch ID 또는 Mac 암호만 요청하며,
잠금 해제된 Mac 앞에 있는 사람은 누구나 모든 토큰을 내보낼 수 있습니다. 또한 빈틈이 생깁니다. 건너뛴 경우
TrayOTP를 가장 먼저 연 사람이 암호를 설정할 수 있습니다. 나중에 **⋯ → 마스터 암호 설정…**으로 켤 수 있습니다.

<a id="limitations"></a>
### 제한 사항

- TrayOTP는 Apple Developer 인증서로 서명되지 않았기 때문에 macOS가 키체인 안에서 보관함 키를 Touch ID에 묶는 것을
  허용하지 않습니다. Touch ID는 앱이 강제하며, 다른 앱이 키를 요청하면 macOS의 **‘키체인을 사용하려고 합니다’** 알림이
  나타납니다. 이 알림은 TrayOTP를 업데이트한 직후 앱을 열 때만 보여야 합니다. **다른 때에 나타나거나 TrayOTP가 아닌
  다른 앱 이름이 표시되면 ‘거부’를 클릭하십시오:** 다른 무언가가 토큰을 보호하는 키를 읽으려 하고 있습니다.
- 비밀 키는 Mac만큼만 안전합니다. **FileVault**를 켜고, **Time Machine 백업을 암호화**하고, 강력한 로그인 암호를 사용하십시오.
  보관함 파일과 로그인 키체인이 모두 도난당한 경우 이를 막아 주는 것은 로그인 암호(설정했다면 마스터 암호도)입니다.
- 빌드는 강화된 런타임을 사용하여 다른 프로세스가 TrayOTP에 코드를 주입하거나 디버거를 연결하지 못하게 합니다.

보안 문제를 발견했나요? 공개 이슈가 아니라 저장소의 [Security 탭](https://github.com/outerstudio/trayotp/security)을 통해
비공개로 알려 주십시오.

<a id="troubleshooting"></a>
## 문제 해결

- **업데이트 후 ‘TrayOTP가 키체인을 사용하려고 합니다’**
  - 각 릴리스가 별도로 서명되기 때문에 macOS는 업데이트할 때마다 다시 묻습니다. 로그인 키체인 암호(보통 Mac 암호)를 입력하고
    **항상 허용**을 선택하십시오. 다른 때에 나타나면 [제한 사항](#limitations)을 참조하십시오.
- **Launchpad에 빈 아이콘이 표시됨**
  - Launchpad는 `/Applications`에 있는 앱만 보여줍니다. 앱을 그곳으로 옮긴 후에도 아이콘이 비어 있으면 `killall Dock`을 실행하십시오.
- **QR 코드가 인식되지 않음**
  - 스크린샷을 코드에 더 가깝게 자르십시오. Google OTP는 **추가 → 카메라로 QR 코드 스캔…**을 사용하십시오
    ([가져오기 및 내보내기](#import-and-export) 참조).
- **‘백업 암호가 틀립니다’**
  - Mac 암호가 아니라 다른 앱(또는 TrayOTP)에서 백업을 내보낼 때 설정한 암호를 사용하십시오.

## 사용에 따른 책임

TrayOTP는 무료 오픈 소스 소프트웨어로, 어떠한 보증도 없이 있는 그대로 제공됩니다([라이선스](../LICENSE) 참조).
제작자는 계정 접근 상실, 비밀 키의 분실이나 유출, 기타 어떠한 손해에 대해서도 책임지지 않습니다.

2FA 코드를 잃으면 계정에 접근하지 못할 수 있으므로, TrayOTP를 유일한 사본으로 두지 마십시오:

- 2FA를 설정할 때 각 사이트의 **복구 코드**를 저장하십시오.
- 휴대폰 등 두 번째 앱에도 토큰을 보관하십시오([토큰 추가하기](#adding-a-token)의 팁 참조).
- 가끔 암호화된 백업을 내보내고(**⋯ → 백업 및 내보내기 → 지금 백업**) 안전한 곳에 보관하십시오.
- 가져온 후에는 이전 앱에서 무언가를 삭제하기 전에 코드 몇 개를 확인하십시오.

## 후원

TrayOTP는 무료입니다. 시간을 절약해 줬다면 [커피 한 잔 사 주세요](https://buymeacoffee.com/garyyeap)
(⋯ 메뉴에도 있습니다). [Ko-fi](https://ko-fi.com/garyyeap), [Liberapay](https://liberapay.com/garyyeap), [thanks.dev](https://thanks.dev/u/gh/garyyeap)로 후원하실 수도 있습니다.

## 개발

빌드, 테스트, 프로젝트 구조, 번역, 형식 세부 사항은 [영어 README](../README.md#development)에 있으며,
[크레딧](../README.md#credits)도 그곳에 있습니다.

## 라이선스

[MIT](../LICENSE) © 2026 outerstudio.com
