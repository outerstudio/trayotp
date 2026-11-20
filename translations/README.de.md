<p align="center">
  <img src="../docs/app-icon.gif" width="128" alt="TrayOTP-Symbol">
</p>

<h1 align="center">TrayOTP</h1>

<p align="center">
  <a href="../README.md">English</a> · <b>Deutsch</b> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> ·
  <a href="README.it.md">Italiano</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> ·
  <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a>
</p>

<p align="center">
  <b>Deine Zwei-Faktor-Codes, einen Klick entfernt in der macOS-Menüleiste.</b><br>
  Import aus Google Authenticator, 2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator und mehr. Verschlüsselt, offline, Open Source.
</p>

<p align="center">
  <a href="https://github.com/outerstudio/trayotp/releases/latest"><img src="https://img.shields.io/github/v/release/outerstudio/trayotp?label=download" alt="Neueste Version"></a>
  <a href="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml"><img src="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14 oder neuer">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT-Lizenz"></a>
  <a href="https://buymeacoffee.com/garyyeap"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee"></a>
  <a href="https://ko-fi.com/garyyeap"><img src="https://img.shields.io/badge/Ko--fi-72a4f2?logo=kofi&logoColor=white" alt="Ko-fi"></a>
  <a href="https://liberapay.com/garyyeap"><img src="https://img.shields.io/badge/Liberapay-f6c915?logo=liberapay&logoColor=black" alt="Liberapay"></a>
  <a href="https://thanks.dev/u/gh/garyyeap"><img src="https://img.shields.io/badge/thanks.dev-000000?logo=thanksdotdev&logoColor=white" alt="thanks.dev"></a>
</p>

<p align="center">
  <a href="#install">Installation</a> ·
  <a href="#getting-started">Erste Schritte</a> ·
  <a href="#using-trayotp">TrayOTP verwenden</a> ·
  <a href="#security">Sicherheit</a> ·
  <a href="#troubleshooting">Fehlerbehebung</a>
</p>

<p align="center">
  <img src="../docs/screenshots/panel.png" width="340" alt="Das TrayOTP-Fenster unter seinem Menüleistensymbol: ein Suchfeld, Tokens mit Name, Code, Account und nächstem Code sowie die Tasten Hinzufügen, Sperren und Beenden">
  <img src="../docs/screenshots/deep-black.png" width="340" alt="Das Fenster mit dem Tiefschwarzen Design: ein rein schwarzer Hintergrund für OLED-Bildschirme">
</p>

> Diese Übersetzung kann hinter der [englischen README](../README.md) zurückliegen. Im Zweifel gilt die englische Fassung.

## Funktionen

- **Lebt in der Menüleiste.** Auf das Symbol klicken, auf einen Code klicken, er ist kopiert. Kein Dock-Symbol, kein Fenster, um das man sich kümmern muss.
- **Vorschau auf den nächsten Code.** Der kommende Code steht rechts in jeder Zeile, und eine durchscheinende Füllung hinter der Zeile zeigt die Restzeit des aktuellen.
- **Nur Tastatur oder nur Klicken, wie du willst.** Globales Tastenkürzel, tippen zum Suchen, ↩ zum Kopieren, ⌘↑/↓ zum Umsortieren, Esc zum Schließen.
  Siehe [Codes kopieren](#copying-codes) und [Gruppen](#groups).
- **Alle gängigen Token-Typen.** TOTP (SHA-1, SHA-256, SHA-512, 6–8 Ziffern, beliebiger Zeitraum), HOTP (zählerbasiert) und Steam Guard.
- **Tokens ohne Telefon hinzufügen.** Einen `otpauth://`-Link, ein Base32-Geheimnis oder ein Bild mit QR-Code einsetzen.
- **Frei rein und raus.** Import aus Google Authenticator, 2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator,
  Stratum, andOTP, FreeOTP+, Raivo OTP und CSV-Dateien von Passwortmanagern. Export nach 2FAS, Aegis, Ente Auth, Bitwarden und Google Authenticator.
- **Gruppen.** Zuklappbare Abschnitte, Sortieren und Verschieben per Drag & Drop; bleiben in 2FAS-, Aegis- und Ente-Exporten erhalten.
- **Dienst-Symbole.** Jedes [Aegis-Symbolpaket](#service-icons) verwenden, Symbole von Hand wählen, eigene Bilder nutzen oder das Favicon einer Website laden.
- **Standardmäßig gesperrt.** Touch ID (oder dein Mac-Passwort), bevor Codes angezeigt werden, optional zusätzlich ein Master-Passwort.
- **Sicher.** Tokens werden mit AES-256-GCM verschlüsselt, der Schlüssel liegt in deinem Anmeldeschlüsselbund. Siehe [Sicherheit](#security).
- **Privat.** Alles bleibt auf deinem Mac. Kein Account, keine Synchronisierung, keine Analyse.
- **In deiner Sprache.** English, Deutsch, Español, Français, Italiano, 日本語, 한국어, Português (Brasil), 简体中文 und
  繁體中文. Folgt der Sprache deines Mac, oder wähle eine unter **⋯ → Sprache**.
- **Klein und nativ.** Swift und SwiftUI, wenige MB. Benötigt macOS 14 Sonoma oder neuer; läuft auf Apple Silicon und Intel.

<a id="install"></a>
## Installation

### Download

1. Lade `TrayOTP-vX.Y.Z.zip` aus der [neuesten Version](https://github.com/outerstudio/trayotp/releases/latest).
2. Entpacke sie und bewege **TrayOTP.app** in den Ordner **Programme**.
3. Öffne die App. Beim ersten Mal meldet macOS, dass die App nicht überprüft werden kann (siehe unten).

**Warum die Warnung?** TrayOTP ist Open Source und nicht mit einem kostenpflichtigen Apple-Developer-Zertifikat signiert,
daher kann macOS nicht prüfen, wer sie erstellt hat. So öffnest du sie trotzdem:

- Folge der [Anleitung von Apple zum Öffnen einer App von einem unbekannten Entwickler](https://support.apple.com/de-de/guide/mac-help/mh40616/26/mac/26) und wähle auf der Seite deine macOS-Version.

Das ist nur einmal pro Version nötig. Wenn du einem heruntergeladenen Build nicht vertrauen möchtest,
[baue sie selbst](#build-from-source) in etwa einer Minute.

**Download prüfen (optional):** Jede Version enthält eine `.sha256`-Datei. Im Terminal:

```sh
shasum -a 256 -c TrayOTP-vX.Y.Z.zip.sha256
```

<a id="build-from-source"></a>
### Aus dem Quellcode bauen

Du brauchst nur Apples **Command Line Tools**:

```sh
xcode-select --install                                 # überspringen, wenn bereits installiert
git clone https://github.com/outerstudio/trayotp.git
cd trayotp
make release                                           # baut build/TrayOTP.app
cp -R build/TrayOTP.app /Applications/
```

Selbst gebaute Apps öffnen sich ohne Warnung.

<a id="getting-started"></a>
## Erste Schritte

1. Klicke auf das TrayOTP-Symbol in der Menüleiste (ein Schloss in einem Kreis) und entsperre mit Touch ID.
2. Füge deine Tokens hinzu:
   - **Aus einer anderen App:** Klicke auf **Hinzufügen → Aus Datei importieren …**, oder für Google Authenticator auf
     **Hinzufügen → QR-Code mit Kamera scannen …** (siehe [Import und Export](#import-and-export)).
   - **Einzeln:** Klicke auf **Hinzufügen** und setze den Einrichtungslink oder das Geheimnis ein (siehe [Token hinzufügen](#adding-a-token)).
3. Klicke auf einen Code, um ihn zu kopieren.

<a id="using-trayotp"></a>
## TrayOTP verwenden

<a id="copying-codes"></a>
### Codes kopieren

- **Von überall öffnen:** Lege unter **⋯ → Globales Tastenkürzel festlegen …** eine Tastenkombination fest und drücke sie in jeder App.
  **Esc** schließt das Fenster und bringt dich zurück zur vorherigen App.
- **Klicke auf einen Code**, um ihn zu kopieren. Eine Meldung bestätigt es. Klicke auf den kommenden Code rechts in der Zeile (oder Rechtsklick → **Nächsten Code kopieren**), um stattdessen ihn zu kopieren.
- **Tastatur:** Das Suchfeld ist beim Öffnen aktiv. Tippe zum Filtern, **↑/↓** zum Auswählen, **Eingabe** (↩) zum Kopieren und **→** für den nächsten Code.
  **↑** in der obersten Zeile führt zurück ins Suchfeld.
- Bei zählerbasierten (HOTP) Tokens: Rechtsklick → **Nächster Code**, um den Zähler weiterzuschalten.
- **Token bearbeiten:** Rechtsklick → **Bearbeiten …**, um Dienstname und Account zu ändern. Der Code bleibt gleich.
- **Den Code eines Tokens immer ausblenden:** Rechtsklick → **Code immer ausblenden**. Er bleibt auch bei **Codes ausblenden** auf **Nie** verborgen, bis du ihn anklickst.
- **Nach dem Kopieren schließen** im ⋯-Menü schließt das Fenster nach jedem Kopieren, sodass du sofort einsetzen kannst.
- Kopierte Codes sind vor Zwischenablage-Managern verborgen und werden nach 30 Sekunden aus der Zwischenablage gelöscht.

<a id="adding-a-token"></a>
### Token hinzufügen

Klicke unten im Fenster auf **Hinzufügen** und setze eines davon ein:

| Du hast | So geht's |
|---|---|
| Einen `otpauth://…`-Einrichtungslink | Einsetzen. Name, Account und Einstellungen werden aus dem Link übernommen. |
| Einen geheimen Schlüssel wie `JBSW Y3DP EHPK 3PXP` | Einsetzen und einen Namen eingeben (z. B. „GitHub“). Leerzeichen und Kleinbuchstaben sind kein Problem. |
| Einen QR-Code auf dem Bildschirm | Bildschirmfoto in die Zwischenablage (**⌃⇧⌘4**) oder Rechtsklick auf das Bild → **Bild kopieren**. Dann **Hinzufügen** öffnen (wird automatisch ausgefüllt) oder **Link, Geheimnis oder QR-Bild einsetzen** klicken. |
| Einen QR-Code auf einem anderen Gerät oder auf Papier | Klicke auf **QR-Code mit Kamera scannen …** und halte ihn vor die Kamera des Mac. |

Eine Live-Vorschau zeigt den Code vor dem Sichern, damit du ihn mit der Website vergleichen kannst.

> **Tipp: Füge ein neues Token gleichzeitig deinem Telefon hinzu.** Wenn eine Website ihren 2FA-QR-Code zeigt, scanne ihn
> mit deiner Telefon-App (Google Authenticator, 2FAS, Aegis …) *und* übernimm ein Bildschirmfoto in TrayOTP (**⌃⇧⌘4**, dann **Hinzufügen**).
> Es ist dasselbe Geheimnis, beide zeigen also dieselben Codes, und du hast ein Backup, falls du Telefon oder Mac verlierst.
> Mach das, bevor du den Bestätigungscode auf der Website eingibst: Die meisten Websites zeigen den QR-Code nie wieder.
> Kein QR-Code? Kopiere den Einrichtungsschlüssel (oft unter „Scannen nicht möglich?“) und gib ihn in beiden Apps ein.

<a id="groups"></a>
### Gruppen

- **Gruppe erstellen:** **⋯ → Neue Gruppe …** oder Rechtsklick auf ein Token → **In Gruppe bewegen → Neue Gruppe …**.
- **Token verschieben:** Rechtsklick → **In Gruppe bewegen** oder auf eine Gruppenüberschrift ziehen.
- **Umsortieren:** Ziehe ein Token auf ein anderes: die obere Hälfte der Zeile setzt es darüber, die untere darunter.
  Oder wähle es aus und drücke **⌘↑/⌘↓**; über das Ende einer Gruppe hinaus wandert es in die nächste. Ziehe eine Gruppenüberschrift auf eine andere, um Gruppen umzusortieren.
- **Zuklappen:** Klicke auf eine Gruppenüberschrift (auch „Ohne Gruppe“). Die Suche findet Tokens auch in zugeklappten Gruppen.
  Bewegst du die Auswahl mit ↑/↓ in eine zugeklappte Gruppe, öffnet sie sich, bis du sie verlässt; nur ein Klick auf die
  Überschrift speichert den Zustand.
- **Gruppe umbenennen, verschieben oder löschen:** Rechtsklick auf die Überschrift. Beim Löschen bleiben die Tokens erhalten; sie wandern nach „Ohne Gruppe“.

<a id="service-icons"></a>
### Dienst-Symbole

TrayOTP liefert keine Markenlogos mit. Stattdessen liest es Symbolpakete im
[Aegis-Symbolpaketformat](https://github.com/beemdevelopment/Aegis/blob/master/docs/iconpacks.md):

1. Lade `aegis-icons.zip` von den [aegis-icons-Releases](https://github.com/aegis-icons/aegis-icons/releases)
   (oder ein anderes Aegis-kompatibles Paket).
2. **⋯ → Symbolpaket → Aegis-Symbolpaket installieren …** und die ZIP-Datei wählen.

Tokens erhalten automatisch ein Symbol anhand von Aussteller oder Name („Google Workspace“ → Google).
Für alles andere Rechtsklick auf ein Token:

| Menüeintrag | Funktion |
|---|---|
| **Symbol bearbeiten …** | Das aktuelle Symbol anpassen (nur wenn das Token eines hat, keine Initialen) |
| **Symbol aus Paket wählen …** | Das installierte Paket durchsuchen und ein Symbol von Hand wählen |
| **Symbol aus Datei festlegen …** | Eine Bilddatei verwenden (PNG, JPEG, SVG, HEIC, PDF …) |
| **Symbol einsetzen** | Ein kopiertes Bild verwenden |
| **Symbol von Website laden …** | Das Favicon der Website laden (du bestätigst zuerst die Domain) |
| **Symbol entfernen** | Zurück zum automatischen Symbol oder zu farbigen Initialen |

Um viele auf einmal festzulegen, ordnet **⋯ → Symbolpaket → Symbole aus Ordner importieren …** Bilddateinamen den Token-Namen zu
(`github.png` → GitHub). Ein selbst gewähltes Symbol hat immer Vorrang vor der automatischen Zuordnung des Pakets.

> **Datenschutzhinweis:** **Symbol von Website laden …** lädt das Favicon über den Symboldienst von DuckDuckGo, daher
> sieht DuckDuckGo diese Domain. Das passiert nur, wenn du es auswählst, nie automatisch.

<a id="import-and-export"></a>
### Import und Export

**Import:** **Hinzufügen → Aus Datei importieren …**, dann die Datei wählen. TrayOTP erkennt die App und fragt nach dem Backup-Passwort,
falls die Datei verschlüsselt ist. Was nicht importiert werden kann, wird danach aufgelistet.

**Export:** **⋯ → Backup & Export ▸ → In andere App exportieren ▸**, dann die App wählen. TrayOTP fragt zuerst nach Touch ID.

| App | Import | Export | Gruppen |
|---|---|---|---|
| **2FAS** (`.2fas`) | Unverschlüsselt oder verschlüsselt | Unverschlüsselt oder verschlüsselt | ✓ |
| **Aegis** (`.json`) | Unverschlüsselt oder verschlüsselt | Unverschlüsselt oder verschlüsselt | ✓ (und Symbole) |
| **Ente Auth** (`.txt`) | Klartext | Klartext | ✓ (als Tags) |
| **Google Authenticator** | QR-Codes von „Konten übertragen“ | QR-Codes (30 s, 6 oder 8 Ziffern) | — |
| **Bitwarden** und **Bitwarden Authenticator** (`.json`, `.csv`) | Unverschlüsselt | Unverschlüsseltes JSON (kein HOTP) | ✓ (Ordner) |
| **Proton Authenticator** (`.json`) | Unverschlüsselt oder verschlüsselt | — | — |
| **Stratum** / Authenticator Pro | Unverschlüsselt oder verschlüsselt | — | ✓ (Kategorien) |
| **andOTP** (`.json`, `.json.aes`) | Unverschlüsselt oder verschlüsselt | — | ✓ (erster Tag) |
| **FreeOTP+** (`.json`) | ✓ | — | — |
| **Raivo OTP** (`.zip`, ungetestet, [bitte melden](https://github.com/outerstudio/trayotp/issues)) | Passwortgeschützte ZIP | — | — |
| **Apple Passwörter** (`.csv`) | Bestätigungscodes (Spalte `OTPAuth`) | — | — |
| **Andere Passwortmanager** (`.csv`, ungetestet, [bitte melden](https://github.com/outerstudio/trayotp/issues)): 1Password, KeePassXC … | Eine Spalte namens `OTPAuth`, `TOTP` oder `login_totp` | — | ✓ (Ordner/Gruppe) |
| Jede Textdatei mit `otpauth://`-Links | ✓ | ✓ | — |

**Google Authenticator:** Öffne auf dem Telefon **⋮ → Konten übertragen → Konten exportieren**. Google blockiert
Bildschirmfotos dieses Bildschirms, klicke daher in TrayOTP auf **Hinzufügen → QR-Code mit Kamera scannen …** und halte das Telefon
etwa 20–30 cm vor die Kamera des Mac, mit hoher Helligkeit. Alle Konten im Code werden auf einmal importiert. Zeigt Google
mehrere QR-Codes, scanne jeden davon. Dichte Codes sind für eine Webcam schwerer zu lesen: Wenn einer nicht erkannt wird,
exportiere weniger Konten auf einmal.

Keine eingebaute Kamera (Mac mini, Mac Studio, Mac Pro)? Eine USB-Webcam funktioniert, ebenso ein iPhone oder iPad (nicht das
Gerät mit Google Authenticator) als Webcam (Integrationskamera). Oder fotografiere den Übertragungsbildschirm mit einem
anderen Telefon, bring das Foto auf deinen Mac (AirDrop, iCloud-Fotos, E-Mail …) und importiere es mit
**Hinzufügen → Aus Datei importieren …**: PNG, JPEG und HEIC funktionieren.

**Nach Google Authenticator:** **⋯ → Backup & Export → In andere App exportieren → Google Authenticator (QR-Codes) …** zeigt die Konten als QR-Codes,
10 pro Code. Öffne in Google Authenticator **⋮ → Konten übertragen → Konten importieren** und scanne jeden davon. Google
akzeptiert nur 30-Sekunden-Codes mit 6 oder 8 Ziffern, andere Tokens (und Steam) werden daher ausgelassen, und du erfährst welche.
Das Fenster ist vor Bildschirmfotos und Bildschirmfreigabe verborgen und schließt sich, wenn TrayOTP sperrt.

**Duplikate:** Ein Token wird übersprungen, wenn du bereits eines mit demselben Geheimnis und Account hast; dieselbe Datei
zweimal zu importieren (oder überlappende Google-QR-Codes) fügt also nichts Neues hinzu. Ein Token mit demselben Namen und
Account wie ein vorhandenes, aber anderem Geheimnis wird behalten, mit dem Zeitpunkt des Hinzufügens hinter dem Namen
(z. B. `GitHub 2026-11-17 23:40`), und nach dem Import aufgelistet. Meist hat die Website ein neues Geheimnis ausgestellt;
lösche das alte Token, sobald das neue funktioniert. Dasselbe gilt, wenn du ein Token einzeln hinzufügst.

**Ungetestet** heißt: TrayOTP liest das Format wie dokumentiert, wurde aber noch nicht mit einer aus dieser App exportierten
Datei ausprobiert. Wenn ein Import fehlschlägt oder die Codes nicht stimmen,
[eröffne bitte ein Issue](https://github.com/outerstudio/trayotp/issues) mit Name und Version der App (hänge nie die Datei an:
sie enthält deine Geheimnisse).

> **Bevor du Tokens in deiner alten App löschst,** prüfe, ob einige importierte Codes mit den dort angezeigten übereinstimmen.

Nicht unterstützt: verschlüsselte Ente-Auth-Exporte (exportiere stattdessen als Klartext aus Ente), verschlüsselte
Bitwarden-Exporte, Backups des ursprünglichen FreeOTP, Authy und Microsoft Authenticator (sie können nicht exportieren)
sowie Yandex- und mOTP-Tokens.

> **Unverschlüsselte Exporte enthalten alle deine Geheimnisse im Klartext.** Lösche die Datei nach dem Import.
> Für ein Backup, das du aufbewahrst, nimm **Aegis (verschlüsselt)**: Sein Passwortschutz (scrypt) ist viel schwerer zu
> knacken als der von 2FAS.

### Sperre und Einstellungen

Alles im **⋯**-Menü:

| Einstellung | Funktion |
|---|---|
| **Entsperrt bleiben ▸** | Wie lange TrayOTP nach der letzten Verwendung entsperrt bleibt: jedes Mal sperren, 1 Minute bis 1 Stunde, **Bis der Mac schläft oder sperrt**, **Bis ich sperre** oder eine eigene Anzahl Minuten. Es sperrt, wenn der Mac schläft oder der Bildschirm gesperrt wird, außer bei **Bis ich sperre**: Dann bleibt es entsperrt, bis du auf „Sperren“ klickst. |
| **Master-Passwort festlegen …** | Das Passwort, das du vor dem Exportieren oder Löschen von Tokens eingibst (siehe [Sicherheit](#security)). Sobald es festgelegt ist, bietet das Menü Ändern, Entfernen, **Mit Passwort statt Touch ID entsperren** und **Passwort vergessen …**, um alle Tokens zu löschen und neu anzufangen. |
| **Passworterinnerung ▸** | Alle 7, 30 oder 90 Tage (oder eine eigene Anzahl) erneut nach dem Passwort fragen, damit du es nicht vergisst. Standardmäßig 30 Tage. |
| **Globales Tastenkürzel festlegen …** | Das Fenster aus jeder App mit einer Tastenkombination deiner Wahl öffnen (braucht ⌘, ⌃ oder ⌥). |
| **Menüleistensymbol anzeigen** | Ausschalten, um das Symbol auszublenden. Das globale Tastenkürzel (oder erneutes Öffnen von TrayOTP im Finder oder Launchpad) zeigt das Fenster dann oben auf dem Bildschirm. |
| **Nach dem Kopieren schließen** | Das Fenster schließen, sobald ein Code kopiert ist, damit du ihn sofort einsetzen kannst. |
| **Zwischenablage nach 30 Sekunden leeren** | Kopierte Codes nach 30 Sekunden aus der Zwischenablage löschen (nur wenn dort noch derselbe Code liegt). Standardmäßig an. |
| **Codes ausblenden ▸** | Codes als Punkte maskieren, bis du etwas tust: **Nie** (Standard), **Bis zum Darüberfahren** (Mauszeiger oder Tastaturauswahl zeigt eine Zeile) oder per Klick: **Klick zeigt 5 Sekunden** oder **Klick zeigt 10 Sekunden** (ein Klick auf eine Zeile kopiert den Code und zeigt ihn so lange). Auch beim Kopieren eines verborgenen Codes wird er sichtbar. |
| **Fenster vor Bildschirmfreigabe verbergen** | Hält das Fenster aus Bildschirmfreigaben, Screenshots und Aufnahmen heraus (auch aus deinen eigenen Screenshots). |
| **Backup & Export ▸** | Verschlüsseltes Backup mit einem Klick (Aegis-Format, **Aus Datei importieren…** stellt es wieder her) in einen einmal gewählten Ordner, plus eine Erinnerung, wenn das letzte Backup älter als 7, 30 (Standard) oder 90 Tage ist. **Aus Backup wiederherstellen…** öffnet dieselbe Dateiauswahl wie **Hinzufügen → Aus Datei importieren …**. |
| **Design ▸** | **Wie System** (Standard) folgt dem hellen oder dunklen Erscheinungsbild deines Mac. Mit **Hell** oder **Dunkel** legst du es fest, mit **Tiefschwarz** bekommst du einen rein schwarzen Fensterhintergrund statt des durchscheinenden Materials, für OLED-Bildschirme. Es gilt auch für die Fenster und Dialoge von TrayOTP. |
| **Beim Anmelden starten** | TrayOTP beim Anmelden starten. |
| **Nach Updates suchen …** | Öffnet ein Fenster mit der aktuellen Version, **Jetzt prüfen**, **Automatisch suchen** (einmal täglich, standardmäßig an) und dem **Update-Kanal**: **Stabil**, **Beta** oder **Alpha**. Eine neuere Version zeigt außerdem eine Schaltfläche **Auf … aktualisieren …** unter Hinzufügen / Sperren / Beenden. |
| **Sprache ▸** | **Systemsprache** folgt der Sprache deines Mac (Englisch, wenn TrayOTP nicht in sie übersetzt ist), oder wähle eine der Übersetzungen. TrayOTP startet zum Wechseln neu. |

Klicke unten im Fenster auf **Sperren**, um sofort zu sperren.

<p align="center">
  <img src="../docs/screenshots/lock-screen.png" width="340" alt="Das gesperrte Fenster: „TrayOTP ist gesperrt“, die Touch-ID-Abfrage und die Tasten „Passwort verwenden …“ und „Beenden“">
</p>

<a id="security"></a>
## Sicherheit

### So werden deine Geheimnisse gespeichert

- Tokens werden verschlüsselt (**AES-256-GCM**) auf deinem Mac gespeichert, in einer Datei, die nur dein Benutzeraccount lesen kann.
- Der Schlüssel ist ein zufälliger 256-Bit-Schlüssel in deinem **Anmeldeschlüsselbund**, nie neben der Datei.
- Der Tresor wird erst nach Touch ID oder dem Mac-Passwort entschlüsselt, und die
  entschlüsselten Tokens werden beim erneuten Sperren aus dem Speicher entfernt.
- **Exportieren**, **ein Token löschen** und **das Master-Passwort ändern** fragen immer erneut nach deinem Passwort, auch wenn
  TrayOTP entsperrt ist. Siehe [Master-Passwort](#master-password).
- Nichts verlässt deinen Mac, außer einer Domain, die du mit **Symbol von Website laden …** nachschlägst.
- Die Kamera wird nur verwendet, solange das Fenster **QR-Code scannen** offen ist. Bilder werden im Speicher gelesen und nie gesichert.
  macOS fragt beim ersten Mal nach dem Kamerazugriff und eventuell erneut nach einem Update (TrayOTP ist ad hoc signiert).

<a id="master-password"></a>
### Master-Passwort

Touch ID ließe jemanden deinen Finger benutzen, während du schläfst, daher fragt TrayOTP nach einem Passwort, das du tippst.
Nachdem du dein erstes Token hinzugefügt oder importiert hast, bittet TrayOTP dich, ein **Master-Passwort** festzulegen. Es steht vor:

- dem Exportieren deiner Tokens (das Passwort verschlüsselt standardmäßig auch die Backup-Datei; für jeden Export kannst du ein anderes wählen),
- dem Löschen eines Tokens (nachdem du es einmal getippt hast, fragen weitere Löschungen innerhalb von 2 Minuten nicht erneut),
- dem Anzeigen eines einzelnen Tokens als QR-Code (Rechtsklick → **Exportieren…**, um es in einer anderen Authenticator-App hinzuzufügen;
  nachdem du das Passwort einmal getippt hast, fragen weitere QR-Codes innerhalb von 3 Minuten nicht erneut),
- dem Ändern oder Entfernen des Passworts.

Standardmäßig ersetzt es Touch ID zum Öffnen von TrayOTP nicht. Schalte **⋯ → Master-Passwort → Mit Passwort statt Touch ID
entsperren** ein, und der Tresorschlüssel im Schlüsselbund wird selbst mit einem aus demselben Passwort abgeleiteten Schlüssel
verschlüsselt (scrypt mit N=2¹⁷, r=8, p=1: etwa 0,5 s und 128 MB pro Versuch). Wer in deinen Schlüsselbund gelangt, muss trotzdem
das Passwort erraten. Ein-, Ausschalten oder Ändern des Passworts wechselt zu einem neuen Tresorschlüssel, sodass alte Kopien des
Schlüsselbunds (etwa in einem Time-Machine-Backup) den Tresor danach nicht mehr öffnen können.

**Wenn du es vergisst, kann es nicht wiederhergestellt werden.** Ohne die Entsperr-Option führt der einzige Weg zurück über
**⋯ → Master-Passwort → Passwort vergessen …**, was alle deine Tokens löscht. Mit ihr können deine Tokens gar nicht
wiederhergestellt werden. Stelle sicher, dass du dich bei jedem Account auf anderem Weg anmelden kannst (mit seinen Backup-Codes
oder einem verschlüsselten Export), bevor du dich allein auf TrayOTP verlässt. Die **Passworterinnerung** fragt alle paar Tage
nach dem Passwort, damit es dir geläufig bleibt.

Du kannst es überspringen, indem du *Ich verstehe das Risiko* tippst. Dann fragen Exporte und Löschungen nur nach Touch ID oder
dem Mac-Passwort, und jeder an deinem entsperrten Mac kann alle deine Tokens exportieren. Es hinterlässt auch eine Lücke: Wer
TrayOTP zuerst öffnet, kann das Passwort festlegen. Schalte es später mit **⋯ → Master-Passwort festlegen …** ein.

<a id="limitations"></a>
### Einschränkungen

- TrayOTP ist nicht mit einem Apple-Developer-Zertifikat signiert, daher erlaubt macOS nicht, den Tresorschlüssel im
  Schlüsselbund an Touch ID zu binden. Touch ID wird von der App erzwungen, und wenn eine andere App den Schlüssel anfordert,
  erscheint eine macOS-Abfrage **„möchte deinen Schlüsselbund verwenden“**. Du solltest diese Abfrage nur direkt nach einem
  Update von TrayOTP sehen, wenn du die App öffnest. **Erscheint sie zu einem anderen Zeitpunkt oder nennt sie eine andere App
  als TrayOTP, klicke auf „Ablehnen“:** Etwas anderes versucht, den Schlüssel zu lesen, der deine Tokens schützt.
- Deine Geheimnisse sind nur so sicher wie dein Mac. Aktiviere **FileVault**, **verschlüssele deine Time-Machine-Backups** und
  verwende ein starkes Anmeldepasswort. Würden sowohl die Tresordatei als auch dein Anmeldeschlüsselbund gestohlen, steht das
  Anmeldepasswort im Weg (plus das Master-Passwort, falls festgelegt).
- Builds verwenden die Hardened Runtime, die verhindert, dass andere Prozesse Code in TrayOTP einschleusen oder einen
  Debugger anhängen.

Ein Sicherheitsproblem gefunden? Melde es bitte vertraulich über den
[Security-Tab](https://github.com/outerstudio/trayotp/security) des Repositorys statt in einem öffentlichen Issue.

<a id="troubleshooting"></a>
## Fehlerbehebung

- **„TrayOTP möchte deinen Schlüsselbund verwenden“ nach einem Update**
  - macOS fragt nach jedem Update erneut, weil jede Version separat signiert ist. Gib das Passwort deines Anmeldeschlüsselbunds
    ein (normalerweise dein Mac-Passwort) und wähle **Immer erlauben**. Erscheint die Abfrage zu einem anderen Zeitpunkt, siehe
    [Einschränkungen](#limitations).
- **Launchpad zeigt ein leeres Symbol**
  - Launchpad listet nur Apps in `/Applications`. Ist das Symbol nach dem Verschieben noch leer, führe `killall Dock` aus.
- **Ein QR-Code wird nicht erkannt**
  - Schneide das Bildschirmfoto enger um den Code zu. Für Google Authenticator nutze **QR-Code mit Kamera scannen …**
    (siehe [Import und Export](#import-and-export)).
- **„Falsches Backup-Passwort“**
  - Verwende das Passwort, das beim Export des Backups aus der anderen App (oder TrayOTP) festgelegt wurde, nicht dein Mac-Passwort.

## Nutzung auf eigene Gefahr

TrayOTP ist kostenlose Open-Source-Software, bereitgestellt wie besehen, ohne jegliche Gewährleistung (siehe [Lizenz](../LICENSE)).
Die Autoren haften nicht für verlorenen Zugang zu deinen Accounts, verlorene oder offengelegte Geheimnisse oder sonstige Schäden.

Verlorene 2FA-Codes können dich aus deinen Accounts aussperren, lass TrayOTP also nicht deine einzige Kopie sein:

- Sichere die **Wiederherstellungscodes** jeder Website, wenn du 2FA einrichtest.
- Halte das Token auch in einer zweiten App, etwa auf deinem Telefon (siehe Tipp unter [Token hinzufügen](#adding-a-token)).
- Exportiere ab und zu ein verschlüsseltes Backup (**⋯ → Backup & Export → Jetzt sichern**) und bewahre es sicher auf.
- Prüfe nach dem Import einige Codes, bevor du etwas aus deiner alten App löschst.

## Unterstützung

TrayOTP ist kostenlos. Wenn es dir Zeit spart, kannst du mir [einen Kaffee spendieren](https://buymeacoffee.com/garyyeap)
(auch im ⋯-Menü) oder über [Ko-fi](https://ko-fi.com/garyyeap), [Liberapay](https://liberapay.com/garyyeap) oder
[thanks.dev](https://thanks.dev/u/gh/garyyeap) unterstützen.

## Entwicklung

Bauen, Tests, Projektaufbau, Übersetzungen und Formatdetails stehen in der
[englischen README](../README.md#development), ebenso die [Danksagungen](../README.md#credits).

## Lizenz

[MIT](../LICENSE) © 2026 outerstudio.com
