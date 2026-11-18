<p align="center">
  <img src="../docs/app-icon.gif" width="128" alt="Icona di TrayOTP">
</p>

<h1 align="center">TrayOTP</h1>

<p align="center">
  <a href="../README.md">English</a> · <a href="README.de.md">Deutsch</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> ·
  <b>Italiano</b> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> ·
  <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a>
</p>

<p align="center">
  <b>I tuoi codici a due fattori, a un clic nella barra dei menu di macOS.</b><br>
  Importa da Google Authenticator, 2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator e altri. Crittografato, offline, open source.
</p>

<p align="center">
  <a href="https://github.com/outerstudio/trayotp/releases/latest"><img src="https://img.shields.io/github/v/release/outerstudio/trayotp?label=download" alt="Ultima versione"></a>
  <a href="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml"><img src="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14 o successivo">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="Licenza MIT"></a>
  <a href="https://buymeacoffee.com/garyyeap"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee"></a>
  <a href="https://ko-fi.com/garyyeap"><img src="https://img.shields.io/badge/Ko--fi-72a4f2?logo=kofi&logoColor=white" alt="Ko-fi"></a>
  <a href="https://liberapay.com/garyyeap"><img src="https://img.shields.io/badge/Liberapay-f6c915?logo=liberapay&logoColor=black" alt="Liberapay"></a>
  <a href="https://thanks.dev/u/gh/garyyeap"><img src="https://img.shields.io/badge/thanks.dev-000000?logo=thanksdotdev&logoColor=white" alt="thanks.dev"></a>
</p>

<p align="center">
  <a href="#install">Installazione</a> ·
  <a href="#getting-started">Primi passi</a> ·
  <a href="#using-trayotp">Usare TrayOTP</a> ·
  <a href="#security">Sicurezza</a> ·
  <a href="#troubleshooting">Risoluzione dei problemi</a>
</p>

<p align="center">
  <img src="../docs/screenshots/panel.png" width="340" alt="Il pannello di TrayOTP sotto la sua icona nella barra dei menu: un campo di ricerca, token con nome, codice, account e codice successivo e i pulsanti Aggiungi, Blocca ed Esci">
</p>

> Questa traduzione potrebbe essere meno aggiornata del [README in inglese](../README.md). In caso di dubbio vale la versione inglese.

## Funzionalità

- **Vive nella barra dei menu.** Fai clic sull’icona, fai clic su un codice ed è copiato. Nessuna icona nel Dock, nessuna finestra da gestire.
- **Anteprima del codice successivo.** Il prossimo codice compare a destra di ogni riga, e un riempimento traslucido dietro la riga mostra il tempo rimasto per quello attuale.
- **Solo tastiera o solo clic, decidi tu.** Abbreviazione globale, digita per cercare, ↩ per copiare, ⌘↑/↓ per riordinare, Esc per chiudere.
  Vedi [Copiare i codici](#copying-codes) e [Gruppi](#groups).
- **Tutti i tipi di token comuni.** TOTP (SHA-1, SHA-256, SHA-512, 6–8 cifre, qualsiasi periodo), HOTP (basato su contatore) e Steam Guard.
- **Aggiungi token senza telefono.** Incolla un link `otpauth://`, un segreto Base32 o un’immagine con un codice QR.
- **Entra ed esci liberamente.** Importa da Google Authenticator, 2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator,
  Stratum, andOTP, FreeOTP+, Raivo OTP e CSV di gestori di password. Esporta in 2FAS, Aegis, Ente Auth, Bitwarden e Google Authenticator.
- **Gruppi.** Sezioni comprimibili, trascina e rilascia per ordinare e spostare i token; mantenuti nelle esportazioni 2FAS, Aegis ed Ente.
- **Icone dei servizi.** Usa qualsiasi [pacchetto di icone Aegis](#service-icons), scegli le icone a mano, usa immagini tue o scarica la favicon di un sito.
- **Bloccato per impostazione predefinita.** Touch ID (o la password del Mac) prima di mostrare i codici, con una password principale opzionale in più.
- **Sicuro.** I token sono crittografati con AES-256-GCM e la chiave è conservata nel portachiavi di login. Vedi [Sicurezza](#security).
- **Privato.** Tutto resta sul tuo Mac. Nessun account, nessuna sincronizzazione, nessuna analisi.
- **Nella tua lingua.** English, Deutsch, Español, Français, Italiano, 日本語, 한국어, Português (Brasil), 简体中文 e
  繁體中文. Segue la lingua del Mac, oppure scegline una in **⋯ → Lingua**.
- **Leggero e nativo.** Swift e SwiftUI, pochi MB. Richiede macOS 14 Sonoma o successivo; funziona su Apple silicon e Intel.

<a id="install"></a>
## Installazione

### Download

1. Scarica `TrayOTP-vX.Y.Z.zip` dall’[ultima versione](https://github.com/outerstudio/trayotp/releases/latest).
2. Decomprimilo e sposta **TrayOTP.app** nella cartella **Applicazioni**.
3. Aprila. La prima volta, macOS dirà che non può verificare l’app (vedi sotto).

**Perché l’avviso?** TrayOTP è open source e non è firmato con un certificato Apple Developer a pagamento, quindi
macOS non può verificare chi l’ha creato. Per aprirlo comunque:

- **macOS 15 Sequoia e successivi:** apri l’app una volta, chiudi l’avviso, poi vai in
  **Impostazioni di Sistema → Privacy e sicurezza**, scorri in basso e fai clic su **Apri comunque** accanto a TrayOTP.
- **macOS 14 Sonoma:** clic destro su **TrayOTP.app** → **Apri** → **Apri**.

Basta farlo una volta per versione. Se preferisci non fidarti di una build scaricata,
[compilala tu](#build-from-source) in circa un minuto.

**Verificare il download (facoltativo):** ogni versione include un file `.sha256`. Nel Terminale:

```sh
shasum -a 256 -c TrayOTP-vX.Y.Z.zip.sha256
```

<a id="build-from-source"></a>
### Compilare dai sorgenti

Ti servono solo i **Command Line Tools** di Apple:

```sh
xcode-select --install                                 # salta se già installati
git clone https://github.com/outerstudio/trayotp.git
cd trayotp
make release                                           # compila build/TrayOTP.app
cp -R build/TrayOTP.app /Applications/
```

Le app che compili tu si aprono senza alcun avviso.

<a id="getting-started"></a>
## Primi passi

1. Fai clic sull’icona di TrayOTP nella barra dei menu (un lucchetto in un cerchio) e sblocca con Touch ID.
2. Aggiungi i tuoi token:
   - **Da un’altra app:** fai clic su **Aggiungi → Importa da file…**, oppure per Google Authenticator su
     **Aggiungi → Scansiona codice QR con la fotocamera…** (vedi [Importazione ed esportazione](#import-and-export)).
   - **Uno alla volta:** fai clic su **Aggiungi** e incolla il link di configurazione o il segreto (vedi [Aggiungere un token](#adding-a-token)).
3. Fai clic su un codice per copiarlo.

<a id="using-trayotp"></a>
## Usare TrayOTP

<a id="copying-codes"></a>
### Copiare i codici

- **Aprilo da qualsiasi punto:** imposta una combinazione di tasti in **⋯ → Imposta abbreviazione globale…** e premila in qualsiasi app.
  **Esc** chiude il pannello e ti riporta all’app in cui eri.
- **Fai clic su un codice** per copiarlo. Un messaggio lo conferma. Fai clic sul codice successivo a destra della riga (o clic destro → **Copia codice successivo**) per copiare quello.
- **Tastiera:** il campo di ricerca è attivo all’apertura del pannello. Digita per filtrare, **↑/↓** per selezionare, **Invio** (↩) per copiare e **→** per copiare il codice successivo.
  **↑** dalla prima riga torna al campo di ricerca.
- Per i token basati su contatore (HOTP), clic destro → **Codice successivo** per far avanzare il contatore.
- **Modificare un token:** clic destro → **Modifica…** per cambiare nome del servizio e account. Il codice resta lo stesso.
- **Chiudi dopo la copia** nel menu ⋯ chiude il pannello dopo ogni copia, così puoi incollare subito.
- I codici copiati sono nascosti ai gestori degli appunti e cancellati dagli appunti dopo 30 secondi.

<a id="adding-a-token"></a>
### Aggiungere un token

Fai clic su **Aggiungi** in fondo al pannello, poi incolla una di queste cose:

| Hai | Cosa fare |
|---|---|
| Un link di configurazione `otpauth://…` | Incollalo. Nome, account e impostazioni vengono presi dal link. |
| Una chiave segreta come `JBSW Y3DP EHPK 3PXP` | Incollala e scrivi un nome (ad es. “GitHub”). Spazi e minuscole vanno bene. |
| Un codice QR sullo schermo | Cattura lo schermo negli appunti (**⌃⇧⌘4**), o clic destro sull’immagine → **Copia immagine**. Poi apri **Aggiungi** (si compila da solo) o fai clic su **Incolla link, segreto o immagine QR**. |
| Un codice QR su un altro dispositivo o su carta | Fai clic su **Scansiona codice QR con la fotocamera…** e tienilo davanti alla fotocamera del Mac. |

Un’anteprima dal vivo mostra il codice prima di salvarlo, così puoi confrontarlo con il sito web.

> **Suggerimento: aggiungi il nuovo token anche al telefono, nello stesso momento.** Quando un sito mostra il codice QR per
> configurare la 2FA, scansionalo con l’app del telefono (Google Authenticator, 2FAS, Aegis…) *e* cattura lo schermo per TrayOTP (**⌃⇧⌘4**, poi **Aggiungi**).
> È lo stesso segreto, quindi entrambi mostrano gli stessi codici, e hai un backup se perdi il telefono o il Mac.
> Fallo prima di inserire il codice di conferma sul sito: la maggior parte dei siti non mostra più il codice QR.
> Nessun codice QR? Copia la chiave di configurazione (spesso sotto “Non riesci a scansionarlo?”) e inseriscila in entrambe le app.

<a id="groups"></a>
### Gruppi

- **Creare un gruppo:** **⋯ → Nuovo gruppo…**, o clic destro su un token → **Sposta nel gruppo → Nuovo gruppo…**.
- **Spostare un token:** clic destro → **Sposta nel gruppo**, oppure trascinalo sull’intestazione di un gruppo.
- **Riordinare:** trascina un token su un altro: la metà superiore della riga lo mette sopra, quella inferiore sotto.
  Oppure selezionalo e premi **⌘↑/⌘↓**; oltre la fine di un gruppo passa al successivo. Trascina l’intestazione di un gruppo su un’altra per riordinare i gruppi.
- **Comprimere:** fai clic sull’intestazione di un gruppo (anche “Senza gruppo”). La ricerca trova sempre i token nei gruppi compressi.
  Spostando la selezione in un gruppo compresso con ↑/↓ si apre finché non ne esci; solo un clic sull’intestazione salva
  lo stato aperto o chiuso.
- **Rinominare, spostare o eliminare un gruppo:** clic destro sull’intestazione. Eliminando un gruppo i suoi token restano; passano a “Senza gruppo”.

<a id="service-icons"></a>
### Icone dei servizi

TrayOTP non include loghi di marchi. Legge invece pacchetti di icone nel
[formato dei pacchetti di icone Aegis](https://github.com/beemdevelopment/Aegis/blob/master/docs/iconpacks.md):

1. Scarica `aegis-icons.zip` dalle [release di aegis-icons](https://github.com/aegis-icons/aegis-icons/releases)
   (o qualsiasi altro pacchetto compatibile con Aegis).
2. **⋯ → Installa pacchetto di icone Aegis…** e scegli il file ZIP.

I token ricevono automaticamente un’icona in base all’emittente o al nome (“Google Workspace” → Google).
Per il resto, clic destro su un token:

| Voce di menu | Cosa fa |
|---|---|
| **Modifica icona…** | Regola l’icona attuale (solo se il token ne ha una, non le iniziali) |
| **Scegli icona dal pacchetto…** | Cerca nel pacchetto installato e scegli un’icona a mano |
| **Imposta icona da file…** | Usa un file immagine (PNG, JPEG, SVG, HEIC, PDF…) |
| **Incolla icona** | Usa un’immagine copiata |
| **Scarica icona dal sito web…** | Scarica la favicon del sito (prima confermi il dominio) |
| **Rimuovi icona** | Torna all’icona automatica o alle iniziali colorate |

Per impostarne molte insieme, **⋯ → Importa icone da cartella…** abbina i nomi dei file immagine ai nomi dei token
(`github.png` → GitHub). Un’icona scelta da te ha sempre la precedenza sull’abbinamento automatico del pacchetto.

> **Nota sulla privacy:** **Scarica icona dal sito web…** scarica la favicon tramite il servizio di icone di DuckDuckGo, quindi
> DuckDuckGo vede quel dominio. Succede solo quando lo scegli, mai automaticamente.

<a id="import-and-export"></a>
### Importazione ed esportazione

**Importare:** **Aggiungi → Importa da file…**, poi scegli il file. TrayOTP riconosce l’app e chiede la password del backup se
il file è crittografato. Ciò che non può essere importato viene elencato alla fine.

**Esportare:** **⋯ → Esporta ▸**, poi scegli l’app. TrayOTP chiede prima Touch ID.

| App | Importazione | Esportazione | Gruppi |
|---|---|---|---|
| **2FAS** (`.2fas`) | In chiaro o crittografato | In chiaro o crittografato | ✓ |
| **Aegis** (`.json`) | In chiaro o crittografato | In chiaro o crittografato | ✓ (e icone) |
| **Ente Auth** (`.txt`) | Testo semplice | Testo semplice | ✓ (come tag) |
| **Google Authenticator** | Codici QR di “Trasferisci account” | Codici QR (30 s, 6 o 8 cifre) | — |
| **Bitwarden** e **Bitwarden Authenticator** (`.json`, `.csv`) | Non crittografato | JSON non crittografato (senza HOTP) | ✓ (cartelle) |
| **Proton Authenticator** (`.json`) | In chiaro o crittografato | — | — |
| **Stratum** / Authenticator Pro | In chiaro o crittografato | — | ✓ (categorie) |
| **andOTP** (`.json`, `.json.aes`) | In chiaro o crittografato | — | ✓ (primo tag) |
| **FreeOTP+** (`.json`) | ✓ | — | — |
| **Raivo OTP** (`.zip`, non testato, [segnalalo](https://github.com/outerstudio/trayotp/issues)) | ZIP protetto da password | — | — |
| **Password di Apple** (`.csv`) | Codici di verifica (colonna `OTPAuth`) | — | — |
| **Altri gestori di password** (`.csv`, non testato, [segnalalo](https://github.com/outerstudio/trayotp/issues)): 1Password, KeePassXC… | Una colonna chiamata `OTPAuth`, `TOTP` o `login_totp` | — | ✓ (cartella/gruppo) |
| Qualsiasi file di testo con link `otpauth://` | ✓ | ✓ | — |

**Google Authenticator:** sul telefono apri **⋮ → Trasferisci account → Esporta account**. Google blocca gli screenshot di
questa schermata, quindi in TrayOTP fai clic su **Aggiungi → Scansiona codice QR con la fotocamera…** e tieni il telefono
davanti alla fotocamera del Mac, a circa 20–30 cm e con la luminosità al massimo. Tutti gli account del codice vengono importati
insieme. Se Google mostra più codici QR, scansionali tutti. I codici densi sono più difficili da leggere per una webcam: se uno
non viene riconosciuto, esporta meno account alla volta.

Nessuna fotocamera integrata (Mac mini, Mac Studio, Mac Pro)? Va bene una webcam USB, e anche un iPhone o iPad (diverso da quello
con Google Authenticator) usato come webcam (Fotocamera Continuity). Oppure fotografa la schermata di trasferimento con un altro
telefono, porta la foto sul Mac (AirDrop, Foto di iCloud, e-mail…) e importala con
**Aggiungi → Importa da file…**: PNG, JPEG e HEIC funzionano.

**Verso Google Authenticator:** **⋯ → Esporta → Google Authenticator (codici QR)…** mostra gli account come codici QR,
10 per codice. In Google Authenticator apri **⋮ → Trasferisci account → Importa account** e scansionali uno per uno. Google
accetta solo codici da 30 secondi con 6 o 8 cifre, quindi gli altri token (e Steam) vengono esclusi, e ti viene detto quali.
La finestra è nascosta a screenshot e condivisione dello schermo e si chiude quando TrayOTP si blocca.

**Duplicati:** un token viene saltato se ne hai già uno con lo stesso segreto e account, quindi importare due volte lo stesso
file (o codici QR di Google sovrapposti) non aggiunge nulla. Un token con lo stesso nome e account di uno esistente ma con un
segreto diverso viene mantenuto, con l’ora in cui è stato aggiunto dopo il nome (ad es. `GitHub 2026-11-17 23:40`), ed elencato
dopo l’importazione. Di solito significa che il sito ha emesso un nuovo segreto: elimina il vecchio token quando il nuovo
funziona. Lo stesso vale quando aggiungi un token singolarmente.

**Non testato** significa che TrayOTP legge il formato come documentato, ma non è ancora stato provato con un file esportato da
quell’app. Se un’importazione non riesce o i codici non corrispondono,
[apri una issue](https://github.com/outerstudio/trayotp/issues) indicando l’app e la sua versione (non allegare mai il file:
contiene i tuoi segreti).

> **Prima di eliminare i token dalla vecchia app,** controlla che alcuni codici importati corrispondano a quelli che mostra.

Non supportati: esportazioni crittografate di Ente Auth (esporta invece come testo semplice da Ente), esportazioni crittografate
di Bitwarden, i backup del FreeOTP originale, Authy e Microsoft Authenticator (non possono esportare), e i token Yandex e mOTP.

> **Le esportazioni non crittografate contengono tutti i tuoi segreti in chiaro.** Elimina il file dopo averlo importato.
> Per un backup da conservare usa **Aegis (crittografato)**: la sua protezione con password (scrypt) è molto più difficile da
> violare di quella di 2FAS.

### Blocco e impostazioni

Tutto nel menu **⋯**:

| Impostazione | Cosa fa |
|---|---|
| **Richiedi sblocco** | Chiedi Touch ID o la password del Mac prima di mostrare i codici (attivo per impostazione predefinita). |
| **Resta sbloccato ▸** | Per quanto TrayOTP resta sbloccato dopo l’ultimo utilizzo: ogni volta, da 1 minuto a 1 ora, **Fino a stop o blocco del Mac**, o un numero di minuti personalizzato. Si blocca sempre quando il Mac va in stop o lo schermo si blocca. |
| **Imposta password principale…** | Proteggi la cassaforte con una tua password, digitata al posto di Touch ID (vedi [Sicurezza](#security)). |
| **Imposta abbreviazione globale…** | Apri il pannello da qualsiasi app con la combinazione di tasti che preferisci (con ⌘, ⌃ o ⌥). |
| **Mostra icona nella barra dei menu** | Disattiva per nascondere l’icona. L’abbreviazione globale (o riaprire TrayOTP dal Finder o da Launchpad) mostra allora il pannello in alto sullo schermo. |
| **Chiudi dopo la copia** | Chiudi il pannello appena un codice viene copiato, così puoi incollarlo subito. |
| **Apri al login** | Avvia TrayOTP quando accedi. |
| **Lingua ▸** | **Lingua di sistema** segue la lingua del Mac (inglese se TrayOTP non è tradotto in quella lingua), oppure scegli una delle traduzioni. TrayOTP si riavvia per cambiare. |

Fai clic su **Blocca** in fondo al pannello per bloccare subito.

<p align="center">
  <img src="../docs/screenshots/lock-screen.png" width="340" alt="Il pannello bloccato: “TrayOTP è bloccato”, la richiesta di Touch ID e i pulsanti Usa password… ed Esci">
</p>

<a id="security"></a>
## Sicurezza

### Come vengono conservati i tuoi segreti

- I token sono salvati crittografati (**AES-256-GCM**) sul Mac, in un file leggibile solo dal tuo account utente.
- La chiave di crittografia è una chiave casuale a 256 bit conservata nel **portachiavi di login**, mai accanto al file.
- Con **Richiedi sblocco** attivo, la cassaforte viene decrittografata solo dopo Touch ID o la password del Mac, e i token
  decrittografati vengono rimossi dalla memoria quando si blocca di nuovo.
- **Esportare** ed **eliminare un token** chiedono sempre di nuovo Touch ID, anche se TrayOTP è sbloccato.
- Nulla lascia il tuo Mac, tranne un dominio che scegli di cercare con **Scarica icona dal sito web…**.
- La fotocamera viene usata solo mentre è aperta la finestra **Scansiona codice QR**. I fotogrammi vengono letti in memoria e mai salvati.
  macOS chiede l’accesso alla fotocamera la prima volta, e potrebbe richiederlo dopo un aggiornamento (TrayOTP ha una firma ad hoc).

### Password principale opzionale

Con **⋯ → Imposta password principale…**, la chiave della cassaforte nel portachiavi viene a sua volta crittografata con una
chiave derivata dalla tua password (scrypt con N=2¹⁷, r=8, p=1: circa 0,5 s e 128 MB per tentativo). Chi entra nel tuo
portachiavi deve comunque indovinare la password. Da quel momento sblocchi con la password invece che con Touch ID.

Impostare, modificare o rimuovere la password principale passa a una nuova chiave della cassaforte, così le vecchie copie del
portachiavi (ad esempio in un backup di Time Machine) non possono più aprirla.

> **Se dimentichi la password principale, i token non possono essere recuperati.** Conserva un’esportazione crittografata in un luogo sicuro.

<a id="limitations"></a>
### Limitazioni

- TrayOTP non è firmato con un certificato Apple Developer, quindi macOS non gli permette di legare la chiave della cassaforte
  a Touch ID nel portachiavi. Touch ID è imposto dall’app, e se un’altra app chiede la chiave compare un avviso di macOS
  **“vuole usare il portachiavi”**. Dovresti vedere quell’avviso solo subito dopo aver aggiornato TrayOTP, quando lo apri.
  **Se compare in un altro momento, o nomina un’app diversa da TrayOTP, fai clic su Rifiuta:** qualcos’altro sta cercando di
  leggere la chiave che protegge i tuoi token.
- I tuoi segreti sono al sicuro quanto il tuo Mac. Attiva **FileVault**, **crittografa i backup di Time Machine** e usa una password
  di login robusta. Se venissero rubati sia il file della cassaforte sia il portachiavi di login, a fare da ostacolo è la password
  di login (più la password principale, se l’hai impostata).
- Le build usano il runtime protetto, che impedisce ad altri processi di iniettare codice in TrayOTP o di collegarvi un debugger.

Hai trovato un problema di sicurezza? Segnalalo in privato tramite la [scheda Security](https://github.com/outerstudio/trayotp/security)
del repository anziché in una issue pubblica.

<a id="troubleshooting"></a>
## Risoluzione dei problemi

**“TrayOTP vuole usare il portachiavi” dopo un aggiornamento**
macOS lo chiede di nuovo dopo ogni aggiornamento perché ogni versione è firmata separatamente. Inserisci la password del
portachiavi di login (di solito quella del Mac) e scegli **Consenti sempre**. Se compare in un altro momento, vedi
[Limitazioni](#limitations).

**Launchpad mostra un’icona vuota**
Launchpad elenca solo le app in `/Applications`. Se l’icona resta vuota dopo aver spostato lì l’app, esegui `killall Dock`.

**Un codice QR non viene riconosciuto**
Ritaglia lo screenshot più vicino al codice. Per Google Authenticator usa **Aggiungi → Scansiona codice QR con la fotocamera…**
(vedi [Importazione ed esportazione](#import-and-export)).

**“Password del backup errata”**
Usa la password impostata quando il backup è stato esportato dall’altra app (o da TrayOTP), non la password del Mac.

## Uso a proprio rischio

TrayOTP è software libero e gratuito fornito così com’è, senza alcuna garanzia (vedi la [licenza](../LICENSE)).
Gli autori non sono responsabili della perdita di accesso ai tuoi account, di segreti persi o divulgati né di altri danni.

Perdere i codici 2FA può chiuderti fuori dai tuoi account, quindi non fare di TrayOTP la tua unica copia:

- Salva i **codici di recupero** di ogni sito quando configuri la 2FA.
- Tieni il token anche in una seconda app, ad esempio sul telefono (vedi il suggerimento in [Aggiungere un token](#adding-a-token)).
- Esporta ogni tanto un backup crittografato (**⋯ → Esporta → Aegis (crittografato)**) e conservalo in un luogo sicuro.
- Dopo l’importazione, controlla alcuni codici prima di eliminare qualcosa dalla vecchia app.

## Supporto

TrayOTP è gratuito. Se ti fa risparmiare tempo, puoi [offrirmi un caffè](https://buymeacoffee.com/garyyeap)
(anche nel menu ⋯).

## Sviluppo

Compilazione, test, struttura del progetto, traduzioni e dettagli dei formati sono nel
[README in inglese](../README.md#development), così come i [riconoscimenti](../README.md#credits).

## Licenza

[MIT](../LICENSE) © 2026 outerstudio.com
