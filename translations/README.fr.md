<p align="center">
  <img src="../docs/app-icon.gif" width="128" alt="Icône de TrayOTP">
</p>

<h1 align="center">TrayOTP</h1>

<p align="center">
  <a href="../README.md">English</a> · <a href="README.de.md">Deutsch</a> · <a href="README.es.md">Español</a> · <b>Français</b> ·
  <a href="README.it.md">Italiano</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> ·
  <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a>
</p>

<p align="center">
  <b>Vos codes à deux facteurs, à un clic dans la barre des menus de macOS.</b><br>
  Importe depuis Google Authenticator, 2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator et d’autres. Chiffré, hors ligne, open source.
</p>

<p align="center">
  <a href="https://github.com/outerstudio/trayotp/releases/latest"><img src="https://img.shields.io/github/v/release/outerstudio/trayotp?label=download" alt="Dernière version"></a>
  <a href="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml"><img src="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14 ou ultérieur">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="Licence MIT"></a>
  <a href="https://buymeacoffee.com/garyyeap"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee"></a>
  <a href="https://ko-fi.com/garyyeap"><img src="https://img.shields.io/badge/Ko--fi-72a4f2?logo=kofi&logoColor=white" alt="Ko-fi"></a>
  <a href="https://liberapay.com/garyyeap"><img src="https://img.shields.io/badge/Liberapay-f6c915?logo=liberapay&logoColor=black" alt="Liberapay"></a>
  <a href="https://thanks.dev/u/gh/garyyeap"><img src="https://img.shields.io/badge/thanks.dev-000000?logo=thanksdotdev&logoColor=white" alt="thanks.dev"></a>
</p>

<p align="center">
  <a href="#install">Installation</a> ·
  <a href="#getting-started">Premiers pas</a> ·
  <a href="#using-trayotp">Utiliser TrayOTP</a> ·
  <a href="#security">Sécurité</a> ·
  <a href="#troubleshooting">Dépannage</a>
</p>

<p align="center">
  <img src="../docs/screenshots/panel.png" width="340" alt="Le panneau TrayOTP sous son icône de la barre des menus : un champ de recherche, des jetons avec nom, code, compte et code suivant, et les boutons Ajouter, Verrouiller et Quitter">
  <img src="../docs/screenshots/deep-black.png" width="340" alt="Le panneau avec le thème noir profond : un fond noir pur pour les écrans OLED">
</p>

> Cette traduction peut être en retard sur le [README anglais](../README.md). En cas de doute, la version anglaise fait foi.

## Fonctionnalités

- **Vit dans la barre des menus.** Cliquez sur l’icône, cliquez sur un code, il est copié. Pas d’icône dans le Dock, pas de fenêtre à gérer.
- **Aperçu du code suivant.** Le prochain code s’affiche à droite de chaque ligne, et un remplissage translucide derrière la ligne indique le temps restant pour le code actuel.
- **Tout au clavier ou tout à la souris, à vous de choisir.** Raccourci global, saisie pour rechercher, ↩ pour copier, ⌘↑/↓ pour réordonner, Échap pour fermer.
  Voir [Copier des codes](#copying-codes) et [Groupes](#groups).
- **Tous les types de jetons courants.** TOTP (SHA-1, SHA-256, SHA-512, 6 à 8 chiffres, toute période), HOTP (basé sur un compteur) et Steam Guard.
- **Ajoutez des jetons sans téléphone.** Collez un lien `otpauth://`, un secret Base32 ou une image contenant un code QR.
- **Entrez et sortez librement.** Importez depuis Google Authenticator, 2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator,
  Stratum, andOTP, FreeOTP+, Raivo OTP et les CSV de gestionnaires de mots de passe. Exportez vers 2FAS, Aegis, Ente Auth, Bitwarden et Google Authenticator.
- **Groupes.** Sections repliables, glisser-déposer pour trier et déplacer les jetons, conservés dans les exportations 2FAS, Aegis et Ente.
- **Icônes de services.** Utilisez n’importe quel [pack d’icônes Aegis](#service-icons), choisissez des icônes à la main, utilisez vos propres images ou récupérez le favicon d’un site.
- **Verrouillé par défaut.** Touch ID (ou le mot de passe de votre Mac) avant l’affichage des codes, avec un mot de passe principal facultatif en plus.
- **Sûr.** Les jetons sont chiffrés en AES-256-GCM, avec la clé conservée dans votre trousseau de session. Voir [Sécurité](#security).
- **Privé.** Tout reste sur votre Mac. Pas de compte, pas de synchronisation, pas de statistiques.
- **Dans votre langue.** English, Deutsch, Español, Français, Italiano, 日本語, 한국어, Português (Brasil), 简体中文 et
  繁體中文. Suit la langue de votre Mac, ou choisissez-en une dans **⋯ → Langue**.
- **Léger et natif.** Swift et SwiftUI, quelques Mo. Nécessite macOS 14 Sonoma ou ultérieur ; fonctionne sur Apple silicon et Intel.

<a id="install"></a>
## Installation

### Téléchargement

1. Téléchargez `TrayOTP-vX.Y.Z.zip` depuis la [dernière version](https://github.com/outerstudio/trayotp/releases/latest).
2. Décompressez-le et déplacez **TrayOTP.app** dans le dossier **Applications**.
3. Ouvrez-la. La première fois, macOS indiquera qu’il ne peut pas vérifier l’app (voir ci-dessous).

**Pourquoi cet avertissement ?** TrayOTP est open source et n’est pas signé avec un certificat Apple Developer payant :
macOS ne peut donc pas vérifier qui l’a créé. Pour l’ouvrir malgré tout :

- Suivez le [guide d’Apple pour ouvrir une app d’un développeur inconnu](https://support.apple.com/fr-fr/guide/mac-help/mh40616/26/mac/26) et choisissez votre version de macOS sur cette page.

Il suffit de le faire une fois par version. Si vous préférez ne pas faire confiance à une version téléchargée,
[compilez-la vous-même](#build-from-source) en une minute environ.

**Vérifier le téléchargement (facultatif) :** chaque version comprend un fichier `.sha256`. Dans Terminal :

```sh
shasum -a 256 -c TrayOTP-vX.Y.Z.zip.sha256
```

<a id="build-from-source"></a>
### Compiler depuis les sources

Il vous suffit des **Command Line Tools** d’Apple :

```sh
xcode-select --install                                 # à ignorer si déjà installés
git clone https://github.com/outerstudio/trayotp.git
cd trayotp
make release                                           # compile build/TrayOTP.app
cp -R build/TrayOTP.app /Applications/
```

Les apps que vous compilez vous-même s’ouvrent sans avertissement.

<a id="getting-started"></a>
## Premiers pas

1. Cliquez sur l’icône TrayOTP dans la barre des menus (un cadenas dans un cercle) et déverrouillez avec Touch ID.
2. Ajoutez vos jetons :
   - **Depuis une autre app :** cliquez sur **Ajouter → Importer depuis un fichier…**, ou pour Google Authenticator
     **Ajouter → Scanner un code QR avec la caméra…** (voir [Importation et exportation](#import-and-export)).
   - **Un par un :** cliquez sur **Ajouter** et collez le lien de configuration ou le secret (voir [Ajouter un jeton](#adding-a-token)).
3. Cliquez sur un code pour le copier.

<a id="using-trayotp"></a>
## Utiliser TrayOTP

<a id="copying-codes"></a>
### Copier des codes

- **Ouvrir depuis n’importe où :** définissez une combinaison de touches dans **⋯ → Définir un raccourci global…**, puis utilisez-la dans n’importe quelle app.
  **Échap** ferme le panneau et vous ramène à l’app précédente.
- **Cliquez sur un code** pour le copier. Un message le confirme. Cliquez sur le code suivant à droite de la ligne (ou clic droit → **Copier le code suivant**) pour copier celui-ci.
- **Clavier :** le champ de recherche est actif à l’ouverture du panneau. Tapez pour filtrer, **↑/↓** pour sélectionner, **Entrée** (↩) pour copier et **→** pour copier le code suivant.
  **↑** depuis la première ligne ramène au champ de recherche.
- Pour les jetons basés sur un compteur (HOTP), clic droit → **Code suivant** pour avancer le compteur.
- **Modifier un jeton :** clic droit → **Modifier…** pour changer le nom du service et le compte. Le code reste le même.
- **Fermer après la copie** dans le menu ⋯ ferme le panneau après chaque copie, pour coller immédiatement.
- Les codes copiés sont masqués aux gestionnaires de presse-papiers et effacés du presse-papiers après 30 secondes.

<a id="adding-a-token"></a>
### Ajouter un jeton

Cliquez sur **Ajouter** en bas du panneau, puis collez l’un des éléments suivants :

| Vous avez | Que faire |
|---|---|
| Un lien de configuration `otpauth://…` | Collez-le. Le nom, le compte et les réglages sont repris du lien. |
| Une clé secrète comme `JBSW Y3DP EHPK 3PXP` | Collez-la et saisissez un nom (par ex. « GitHub »). Les espaces et minuscules ne posent pas de problème. |
| Un code QR à l’écran | Faites une capture vers le presse-papiers (**⌃⇧⌘4**), ou clic droit sur l’image → **Copier l’image**. Ouvrez ensuite **Ajouter** (rempli automatiquement) ou cliquez sur **Coller un lien, un secret ou une image QR**. |
| Un code QR sur un autre appareil ou sur papier | Cliquez sur **Scanner un code QR avec la caméra…** et présentez-le à la caméra du Mac. |

Un aperçu en direct affiche le code avant l’enregistrement, pour le comparer avec le site web.

> **Astuce : ajoutez un nouveau jeton à votre téléphone en même temps.** Quand un site affiche son code QR de configuration 2FA,
> scannez-le avec l’app de votre téléphone (Google Authenticator, 2FAS, Aegis…) *et* faites-en une capture pour TrayOTP (**⌃⇧⌘4**, puis **Ajouter**).
> C’est le même secret : les deux affichent les mêmes codes, et vous gardez une sauvegarde si vous perdez votre téléphone ou votre Mac.
> Faites-le avant de saisir le code de confirmation sur le site : la plupart des sites ne réaffichent jamais le code QR.
> Pas de code QR ? Copiez la clé de configuration (souvent sous « Impossible de scanner ? ») et saisissez-la dans les deux apps.

<a id="groups"></a>
### Groupes

- **Créer un groupe :** **⋯ → Nouveau groupe…**, ou clic droit sur un jeton → **Déplacer vers le groupe → Nouveau groupe…**.
- **Déplacer un jeton :** clic droit → **Déplacer vers le groupe**, ou faites-le glisser sur l’en-tête d’un groupe.
- **Réordonner :** faites glisser un jeton sur un autre : la moitié haute de la ligne le place au-dessus, la moitié basse en dessous.
  Ou sélectionnez-le et appuyez sur **⌘↑/⌘↓** ; au-delà de la fin d’un groupe, il passe dans le suivant. Faites glisser l’en-tête d’un groupe sur un autre pour réordonner les groupes.
- **Replier :** cliquez sur l’en-tête d’un groupe (y compris « Sans groupe »). La recherche trouve toujours les jetons des groupes repliés.
  Déplacer la sélection dans un groupe replié avec ↑/↓ l’ouvre jusqu’à ce que vous en sortiez ; seul un clic sur l’en-tête
  enregistre l’état ouvert ou fermé.
- **Renommer, déplacer ou supprimer un groupe :** clic droit sur son en-tête. Supprimer un groupe conserve ses jetons ; ils passent dans « Sans groupe ».

<a id="service-icons"></a>
### Icônes de services

TrayOTP n’inclut pas de logos de marques. Il lit à la place les packs d’icônes au
[format de pack d’icônes Aegis](https://github.com/beemdevelopment/Aegis/blob/master/docs/iconpacks.md) :

1. Téléchargez `aegis-icons.zip` depuis les [versions d’aegis-icons](https://github.com/aegis-icons/aegis-icons/releases)
   (ou tout autre pack compatible Aegis).
2. **⋯ → Installer le pack d’icônes Aegis…** et choisissez le ZIP.

Les jetons reçoivent automatiquement une icône d’après leur émetteur ou leur nom (« Google Workspace » → Google).
Pour le reste, clic droit sur un jeton :

| Élément de menu | Effet |
|---|---|
| **Modifier l’icône…** | Ajuster l’icône actuelle (seulement si le jeton en a une, pas des initiales) |
| **Choisir une icône du pack…** | Rechercher dans le pack installé et choisir une icône à la main |
| **Définir l’icône depuis un fichier…** | Utiliser un fichier image (PNG, JPEG, SVG, HEIC, PDF…) |
| **Coller l’icône** | Utiliser une image copiée |
| **Récupérer l’icône du site web…** | Télécharger le favicon du site (vous confirmez d’abord le domaine) |
| **Retirer l’icône** | Revenir à l’icône automatique ou aux initiales colorées |

Pour en définir plusieurs à la fois, **⋯ → Importer des icônes depuis un dossier…** associe les noms de fichiers image aux noms des jetons
(`github.png` → GitHub). Une icône que vous avez choisie l’emporte toujours sur l’association automatique du pack.

> **Confidentialité :** **Récupérer l’icône du site web…** télécharge le favicon via le service d’icônes de DuckDuckGo :
> DuckDuckGo voit donc ce domaine. Cela n’arrive que lorsque vous le choisissez, jamais automatiquement.

<a id="import-and-export"></a>
### Importation et exportation

**Importer :** **Ajouter → Importer depuis un fichier…**, puis choisissez le fichier. TrayOTP détecte l’app et demande le mot de passe de la
sauvegarde si le fichier est chiffré. Ce qui ne peut pas être importé est listé ensuite.

**Exporter :** **⋯ → Exporter ▸**, puis choisissez l’app. TrayOTP demande d’abord Touch ID.

| App | Importation | Exportation | Groupes |
|---|---|---|---|
| **2FAS** (`.2fas`) | Non chiffré ou chiffré | Non chiffré ou chiffré | ✓ |
| **Aegis** (`.json`) | Non chiffré ou chiffré | Non chiffré ou chiffré | ✓ (et icônes) |
| **Ente Auth** (`.txt`) | Texte brut | Texte brut | ✓ (comme tags) |
| **Google Authenticator** | Codes QR « Transférer des comptes » | Codes QR (30 s, 6 ou 8 chiffres) | — |
| **Bitwarden** et **Bitwarden Authenticator** (`.json`, `.csv`) | Non chiffré | JSON non chiffré (sans HOTP) | ✓ (dossiers) |
| **Proton Authenticator** (`.json`) | Non chiffré ou chiffré | — | — |
| **Stratum** / Authenticator Pro | Non chiffré ou chiffré | — | ✓ (catégories) |
| **andOTP** (`.json`, `.json.aes`) | Non chiffré ou chiffré | — | ✓ (premier tag) |
| **FreeOTP+** (`.json`) | ✓ | — | — |
| **Raivo OTP** (`.zip`, non testé, [signalez-le](https://github.com/outerstudio/trayotp/issues)) | ZIP protégé par mot de passe | — | — |
| **Mots de passe d’Apple** (`.csv`) | Codes de validation (colonne `OTPAuth`) | — | — |
| **Autres gestionnaires de mots de passe** (`.csv`, non testé, [signalez-le](https://github.com/outerstudio/trayotp/issues)) : 1Password, KeePassXC… | Une colonne nommée `OTPAuth`, `TOTP` ou `login_totp` | — | ✓ (dossier/groupe) |
| Tout fichier texte de liens `otpauth://` | ✓ | ✓ | — |

**Google Authenticator :** sur votre téléphone, ouvrez **⋮ → Transférer des comptes → Exporter des comptes**. Google bloque les
captures de cet écran : dans TrayOTP, cliquez sur **Ajouter → Scanner un code QR avec la caméra…** et présentez le téléphone à la
caméra du Mac, à environ 20–30 cm, luminosité au maximum. Tous les comptes du code sont importés en une fois. Si Google affiche
plusieurs codes QR, scannez-les tous. Les codes denses sont plus difficiles à lire pour une webcam : si l’un n’est pas reconnu,
exportez moins de comptes à la fois.

Pas de caméra intégrée (Mac mini, Mac Studio, Mac Pro) ? Une webcam USB fonctionne, tout comme un iPhone ou un iPad (autre que
celui qui exécute Google Authenticator) utilisé comme webcam (Caméra de continuité). Ou photographiez l’écran de transfert avec un
autre téléphone, transférez la photo sur votre Mac (AirDrop, Photos iCloud, e-mail…) et importez-la avec
**Ajouter → Importer depuis un fichier…** : PNG, JPEG et HEIC fonctionnent.

**Vers Google Authenticator :** **⋯ → Exporter → Google Authenticator (codes QR)…** affiche les comptes sous forme de codes QR,
10 par code. Dans Google Authenticator, ouvrez **⋮ → Transférer des comptes → Importer des comptes** et scannez chacun d’eux.
Google n’accepte que les codes de 30 secondes à 6 ou 8 chiffres : les autres jetons (et Steam) sont exclus, et vous savez lesquels.
La fenêtre est masquée aux captures et au partage d’écran, et se ferme quand TrayOTP se verrouille.

**Doublons :** un jeton est ignoré si vous en avez déjà un avec le même secret et le même compte : importer deux fois le même
fichier (ou des codes QR Google qui se chevauchent) n’ajoute rien. Un jeton avec le même nom et le même compte qu’un jeton existant
mais un secret différent est conservé, avec l’heure de son ajout après le nom (par ex. `GitHub 2026-11-17 23:40`), et listé après
l’importation. Cela signifie généralement que le site a émis un nouveau secret : supprimez l’ancien jeton une fois le nouveau
fonctionnel. Il en va de même quand vous ajoutez un jeton à la main.

**Non testé** signifie que TrayOTP lit le format tel qu’il est documenté, mais n’a pas encore été essayé avec un fichier exporté
par cette app. Si une importation échoue ou si les codes ne correspondent pas,
[ouvrez une issue](https://github.com/outerstudio/trayotp/issues) en indiquant l’app et sa version (ne joignez jamais le
fichier : il contient vos secrets).

> **Avant de supprimer des jetons de votre ancienne app,** vérifiez que quelques codes importés correspondent à ceux qu’elle affiche.

Non pris en charge : les exportations Ente Auth chiffrées (exportez plutôt en texte brut depuis Ente), les exportations
Bitwarden chiffrées, les sauvegardes du FreeOTP d’origine, Authy et Microsoft Authenticator (ils ne savent pas exporter),
ainsi que les jetons Yandex et mOTP.

> **Les exportations non chiffrées contiennent tous vos secrets en clair.** Supprimez le fichier une fois importé.
> Pour une sauvegarde à conserver, utilisez **Aegis (chiffré)** : sa protection par mot de passe (scrypt) est bien plus
> difficile à casser que celle de 2FAS.

### Verrouillage et réglages

Tout se trouve dans le menu **⋯** :

| Réglage | Effet |
|---|---|
| **Exiger le déverrouillage** | Demander Touch ID ou le mot de passe du Mac avant d’afficher les codes (activé par défaut). |
| **Rester déverrouillé ▸** | Durée pendant laquelle TrayOTP reste déverrouillé après sa dernière utilisation : à chaque fois, de 1 minute à 1 heure, **Jusqu’à la veille ou au verrouillage du Mac**, ou un nombre de minutes personnalisé. Il se verrouille toujours quand le Mac se met en veille ou que l’écran se verrouille. |
| **Définir un mot de passe principal…** | Le mot de passe que vous saisissez avant d’exporter ou de supprimer des jetons (voir [Sécurité](#security)). Une fois défini, le menu propose Modifier, Supprimer, **Déverrouiller avec le mot de passe au lieu de Touch ID** et **Mot de passe oublié…** pour effacer tous les jetons et repartir de zéro. |
| **Rappel du mot de passe ▸** | Redemander le mot de passe tous les 7, 30 ou 90 jours (ou un nombre personnalisé), pour ne pas l’oublier. 30 jours par défaut. |
| **Définir un raccourci global…** | Ouvrir le panneau depuis n’importe quelle app avec la combinaison de touches de votre choix (avec ⌘, ⌃ ou ⌥). |
| **Afficher l’icône dans la barre des menus** | Désactivez pour masquer l’icône. Le raccourci global (ou rouvrir TrayOTP depuis le Finder ou le Launchpad) affiche alors le panneau en haut de l’écran. |
| **Fermer après la copie** | Fermer le panneau dès qu’un code est copié, pour le coller immédiatement. |
| **Effacer le presse-papiers après 30 secondes** | Effacer un code copié du presse-papiers après 30 secondes (seulement s’il contient encore ce code). Activé par défaut. |
| **Thème noir profond** | Arrière-plan du panneau noir pur au lieu du matériau translucide, pour les écrans OLED. |
| **Ouvrir à la connexion** | Lancer TrayOTP à l’ouverture de session. |
| **Langue ▸** | **Langue du système** suit la langue de votre Mac (anglais si TrayOTP n’est pas traduit dans celle-ci), ou choisissez une des traductions. TrayOTP redémarre pour changer. |

Cliquez sur **Verrouiller** en bas du panneau pour verrouiller immédiatement.

<p align="center">
  <img src="../docs/screenshots/lock-screen.png" width="340" alt="Le panneau verrouillé : « TrayOTP est verrouillé », l’invite Touch ID et les boutons Utiliser le mot de passe… et Quitter">
</p>

<a id="security"></a>
## Sécurité

### Comment vos secrets sont stockés

- Les jetons sont stockés chiffrés (**AES-256-GCM**) sur votre Mac, dans un fichier que seul votre compte utilisateur peut lire.
- La clé de chiffrement est une clé aléatoire de 256 bits conservée dans votre **trousseau de session**, jamais à côté du fichier.
- Avec **Exiger le déverrouillage**, le coffre n’est déchiffré qu’après Touch ID ou le mot de passe du Mac, et les jetons
  déchiffrés sont retirés de la mémoire au verrouillage suivant.
- **Exporter**, **supprimer un jeton** et **modifier le mot de passe principal** demandent toujours à nouveau votre mot de passe, même quand TrayOTP est déverrouillé. Voir [Mot de passe principal](#master-password).
- Rien ne quitte votre Mac, sauf un domaine que vous choisissez de consulter avec **Récupérer l’icône du site web…**.
- La caméra n’est utilisée que lorsque la fenêtre **Scanner un code QR** est ouverte. Les images sont lues en mémoire et jamais enregistrées.
  macOS demande l’accès à la caméra la première fois, et peut redemander après une mise à jour (TrayOTP est signé ad hoc).

<a id="master-password"></a>
### Mot de passe principal

Touch ID laisserait quelqu’un utiliser votre doigt pendant que vous dormez : TrayOTP demande donc un mot de passe que vous saisissez.
Après l’ajout ou l’importation de votre premier jeton, TrayOTP vous invite à définir un **mot de passe principal**. Il protège :

- l’exportation de vos jetons (le mot de passe chiffre aussi le fichier de sauvegarde par défaut ; vous pouvez en choisir un autre à chaque exportation),
- la suppression d’un jeton (une fois saisi, les suppressions suivantes dans les 2 minutes ne le redemandent pas),
- l’affichage d’un seul jeton sous forme de code QR (clic droit → **Exporter…**, pour l’ajouter à une autre app d’authentification ;
  une fois le mot de passe saisi, les codes QR suivants dans les 3 minutes ne le redemandent pas),
- la modification ou la suppression du mot de passe.

Par défaut, il ne remplace pas Touch ID pour ouvrir TrayOTP. Activez **⋯ → Mot de passe principal → Déverrouiller avec le mot
de passe au lieu de Touch ID** et la clé du coffre dans le trousseau est elle-même chiffrée avec une clé dérivée du même mot
de passe (scrypt avec N=2¹⁷, r=8, p=1 : environ 0,5 s et 128 Mo par essai). Quelqu’un qui accède à votre trousseau doit encore
deviner le mot de passe. L’activer, le désactiver ou modifier le mot de passe fait passer à une nouvelle clé de coffre : les
anciennes copies du trousseau (par exemple dans une sauvegarde Time Machine) ne peuvent plus ouvrir le coffre ensuite.

**Si vous l’oubliez, il est irrécupérable.** Sans l’option de déverrouillage, le seul moyen de rentrer est
**⋯ → Mot de passe principal → Mot de passe oublié…**, qui efface tous vos jetons. Avec elle, vos jetons sont totalement
irrécupérables. Assurez-vous de pouvoir vous connecter à chaque compte autrement (ses codes de secours ou une exportation
chiffrée) avant de vous fier uniquement à TrayOTP. Le **Rappel du mot de passe** le redemande tous les quelques jours pour
qu’il reste frais en mémoire.

Vous pouvez l’ignorer en saisissant *Je comprends le risque*. Les exportations et suppressions ne demandent alors que Touch ID
ou le mot de passe du Mac, et toute personne devant votre Mac déverrouillé peut exporter tous vos jetons. Cela laisse aussi une
brèche : si vous l’avez ignoré, la première personne qui ouvre TrayOTP peut définir le mot de passe. Activez-le plus tard avec
**⋯ → Définir un mot de passe principal…**.

<a id="limitations"></a>
### Limites

- TrayOTP n’est pas signé avec un certificat Apple Developer, donc macOS ne lui permet pas de lier la clé du coffre à Touch ID
  dans le trousseau. Touch ID est imposé par l’app, et une autre app qui demande la clé déclenche une alerte macOS
  **« souhaite utiliser votre trousseau »**. Vous ne devriez voir cette alerte que juste après une mise à jour de TrayOTP, à son
  ouverture. **Si elle apparaît à un autre moment, ou nomme une autre app que TrayOTP, cliquez sur Refuser :** quelque chose
  d’autre essaie de lire la clé qui protège vos jetons.
- Vos secrets ne sont pas plus sûrs que votre Mac. Activez **FileVault**, **chiffrez vos sauvegardes Time Machine** et utilisez un
  mot de passe de session solide. Si le fichier du coffre et votre trousseau de session étaient volés, c’est le mot de passe de
  session qui fait obstacle (plus le mot de passe principal, si vous en avez défini un).
- Les versions utilisent le runtime renforcé, qui empêche d’autres processus d’injecter du code dans TrayOTP ou d’y attacher un débogueur.

Vous avez trouvé un problème de sécurité ? Signalez-le en privé via l’[onglet Security](https://github.com/outerstudio/trayotp/security)
du dépôt plutôt que dans une issue publique.

<a id="troubleshooting"></a>
## Dépannage

- **« TrayOTP souhaite utiliser votre trousseau » après une mise à jour**
  - macOS redemande après chaque mise à jour, car chaque version est signée séparément. Saisissez le mot de passe de votre trousseau
    de session (normalement celui de votre Mac) et choisissez **Toujours autoriser**. Si l’alerte apparaît à un autre moment, voir
    [Limites](#limitations).
- **Le Launchpad affiche une icône vide**
  - Le Launchpad ne liste que les apps de `/Applications`. Si l’icône reste vide après y avoir déplacé l’app, exécutez `killall Dock`.
- **Un code QR n’est pas détecté**
  - Recadrez la capture plus près du code. Pour Google Authenticator, utilisez **Ajouter → Scanner un code QR avec la caméra…**
    (voir [Importation et exportation](#import-and-export)).
- **« Mot de passe de sauvegarde incorrect »**
  - Utilisez le mot de passe défini lors de l’exportation de la sauvegarde depuis l’autre app (ou TrayOTP), pas celui de votre Mac.

## Utilisation à vos risques

TrayOTP est un logiciel libre et gratuit fourni tel quel, sans garantie d’aucune sorte (voir la [licence](../LICENSE)).
Les auteurs ne sont pas responsables d’une perte d’accès à vos comptes, de secrets perdus ou divulgués, ni d’aucun autre dommage.

Perdre vos codes 2FA peut vous bloquer hors de vos comptes : ne faites pas de TrayOTP votre seule copie.

- Enregistrez les **codes de récupération** de chaque site lorsque vous configurez la 2FA.
- Gardez aussi le jeton dans une deuxième app, par exemple sur votre téléphone (voir l’astuce dans [Ajouter un jeton](#adding-a-token)).
- Exportez de temps en temps une sauvegarde chiffrée (**⋯ → Exporter → Aegis (chiffré)**) et conservez-la en lieu sûr.
- Après une importation, vérifiez quelques codes avant de supprimer quoi que ce soit de votre ancienne app.

## Soutien

TrayOTP est gratuit. S’il vous fait gagner du temps, vous pouvez [m’offrir un café](https://buymeacoffee.com/garyyeap)
(aussi dans le menu ⋯), ou me soutenir via [Ko-fi](https://ko-fi.com/garyyeap), [Liberapay](https://liberapay.com/garyyeap) ou
[thanks.dev](https://thanks.dev/u/gh/garyyeap).

## Développement

Compilation, tests, structure du projet, traductions et détails des formats sont décrits dans le
[README anglais](../README.md#development), de même que les [remerciements](../README.md#credits).

## Licence

[MIT](../LICENSE) © 2026 outerstudio.com
