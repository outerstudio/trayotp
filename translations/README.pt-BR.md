<p align="center">
  <img src="../docs/app-icon.gif" width="128" alt="Ícone do TrayOTP">
</p>

<h1 align="center">TrayOTP</h1>

<p align="center">
  <a href="../README.md">English</a> · <a href="README.de.md">Deutsch</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> ·
  <a href="README.it.md">Italiano</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> ·
  <b>Português (Brasil)</b> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a>
</p>

<p align="center">
  <b>Seus códigos de dois fatores a um clique na barra de menus do macOS.</b><br>
  Importa do Google Authenticator, 2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator e outros. Criptografado, offline, código aberto.
</p>

<p align="center">
  <a href="https://github.com/outerstudio/trayotp/releases/latest"><img src="https://img.shields.io/github/v/release/outerstudio/trayotp?label=download" alt="Versão mais recente"></a>
  <a href="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml"><img src="https://github.com/outerstudio/trayotp/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14 ou posterior">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="Licença MIT"></a>
  <a href="https://buymeacoffee.com/garyyeap"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee"></a>
  <a href="https://ko-fi.com/garyyeap"><img src="https://img.shields.io/badge/Ko--fi-72a4f2?logo=kofi&logoColor=white" alt="Ko-fi"></a>
  <a href="https://liberapay.com/garyyeap"><img src="https://img.shields.io/badge/Liberapay-f6c915?logo=liberapay&logoColor=black" alt="Liberapay"></a>
  <a href="https://thanks.dev/u/gh/garyyeap"><img src="https://img.shields.io/badge/thanks.dev-000000?logo=thanksdotdev&logoColor=white" alt="thanks.dev"></a>
</p>

<p align="center">
  <a href="#install">Instalação</a> ·
  <a href="#getting-started">Primeiros passos</a> ·
  <a href="#using-trayotp">Usando o TrayOTP</a> ·
  <a href="#security">Segurança</a> ·
  <a href="#troubleshooting">Solução de problemas</a>
</p>

<p align="center">
  <img src="../docs/screenshots/panel.png" width="340" alt="O painel do TrayOTP sob seu ícone na barra de menus: um campo de busca, tokens com nome, código, conta e próximo código e os botões Adicionar, Bloquear e Encerrar">
  <img src="../docs/screenshots/deep-black.png" width="340" alt="O painel com o tema preto profundo: um fundo preto puro para telas OLED">
</p>

> Esta tradução pode estar desatualizada em relação ao [README em inglês](../README.md). Em caso de dúvida, vale a versão em inglês.

## Recursos

- **Fica na barra de menus.** Clique no ícone, clique em um código e ele é copiado. Sem ícone no Dock, sem janela para gerenciar.
- **Prévia do próximo código.** O próximo código aparece à direita de cada linha, e um preenchimento translúcido atrás da linha mostra o tempo restante do atual.
- **Só teclado ou só cliques, você escolhe.** Atalho global, digite para buscar, ↩ para copiar, ⌘↑/↓ para reordenar, Esc para fechar.
  Veja [Copiando códigos](#copying-codes) e [Grupos](#groups).
- **Todos os tipos comuns de token.** TOTP (SHA-1, SHA-256, SHA-512, 6–8 dígitos, qualquer período), HOTP (baseado em contador) e Steam Guard.
- **Adicione tokens sem celular.** Cole um link `otpauth://`, um segredo Base32 ou uma imagem com um código QR.
- **Entre e saia à vontade.** Importe do Google Authenticator, 2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator,
  Stratum, andOTP, FreeOTP+, Raivo OTP e CSVs de gerenciadores de senhas. Exporte para 2FAS, Aegis, Ente Auth, Bitwarden e Google Authenticator.
- **Grupos.** Seções recolhíveis, arrastar e soltar para ordenar e mover tokens; mantidos nas exportações do 2FAS, Aegis e Ente.
- **Ícones de serviços.** Use qualquer [pacote de ícones do Aegis](#service-icons), escolha ícones manualmente, use suas próprias imagens ou busque o favicon de um site.
- **Bloqueado por padrão.** Touch ID (ou a senha do Mac) antes de mostrar os códigos, com uma senha mestra opcional por cima.
- **Seguro.** Os tokens são criptografados com AES-256-GCM, com a chave guardada nas suas Chaves de início de sessão. Veja [Segurança](#security).
- **Privado.** Tudo fica no seu Mac. Sem conta, sem sincronização, sem análises.
- **No seu idioma.** English, Deutsch, Español, Français, Italiano, 日本語, 한국어, Português (Brasil), 简体中文 e
  繁體中文. Segue o idioma do Mac, ou escolha um em **⋯ → Idioma**.
- **Pequeno e nativo.** Swift e SwiftUI, poucos MB. Requer macOS 14 Sonoma ou posterior; roda em Apple silicon e Intel.

<a id="install"></a>
## Instalação

### Download

1. Baixe `TrayOTP-vX.Y.Z.zip` da [versão mais recente](https://github.com/outerstudio/trayotp/releases/latest).
2. Descompacte e mova **TrayOTP.app** para a pasta **Aplicativos**.
3. Abra o app. Na primeira vez, o macOS dirá que não consegue verificá-lo (veja abaixo).

**Por que o aviso?** O TrayOTP é de código aberto e não é assinado com um certificado pago do Apple Developer, então
o macOS não consegue verificar quem o criou. Para abri-lo mesmo assim:

- Siga o [guia da Apple para abrir um app de um desenvolvedor desconhecido](https://support.apple.com/pt-br/guide/mac-help/mh40616/26/mac/26) e escolha a sua versão do macOS na página.

Isso só é necessário uma vez por versão. Se preferir não confiar em uma versão baixada,
[compile você mesmo](#build-from-source) em cerca de um minuto.

**Verificar o download (opcional):** cada versão inclui um arquivo `.sha256`. No Terminal:

```sh
shasum -a 256 -c TrayOTP-vX.Y.Z.zip.sha256
```

<a id="build-from-source"></a>
### Compilar a partir do código-fonte

Você só precisa das **Command Line Tools** da Apple:

```sh
xcode-select --install                                 # pule se já estiverem instaladas
git clone https://github.com/outerstudio/trayotp.git
cd trayotp
make release                                           # compila build/TrayOTP.app
cp -R build/TrayOTP.app /Applications/
```

Apps compilados por você abrem sem nenhum aviso.

<a id="getting-started"></a>
## Primeiros passos

1. Clique no ícone do TrayOTP na barra de menus (um cadeado em um círculo) e desbloqueie com o Touch ID.
2. Adicione seus tokens:
   - **De outro app:** clique em **Adicionar → Importar de Arquivo…**, ou para o Google Authenticator em
     **Adicionar → Escanear Código QR com a Câmera…** (veja [Importar e exportar](#import-and-export)).
   - **Um por vez:** clique em **Adicionar** e cole o link de configuração ou o segredo (veja [Adicionando um token](#adding-a-token)).
3. Clique em qualquer código para copiá-lo.

<a id="using-trayotp"></a>
## Usando o TrayOTP

<a id="copying-codes"></a>
### Copiando códigos

- **Abra de qualquer lugar:** defina uma combinação de teclas em **⋯ → Definir Atalho Global…** e pressione-a em qualquer app.
  **Esc** fecha o painel e volta para o app em que você estava.
- **Clique em um código** para copiá-lo. Uma mensagem confirma. Clique no próximo código à direita da linha (ou clique com o botão direito → **Copiar Próximo Código**) para copiar esse.
- **Teclado:** o campo de busca fica ativo quando o painel abre. Digite para filtrar, **↑/↓** para selecionar, **Return** (↩) para copiar e **→** para copiar o próximo código.
  **↑** na primeira linha volta ao campo de busca.
- Em tokens baseados em contador (HOTP), clique com o botão direito → **Próximo Código** para avançar o contador.
- **Editar um token:** clique com o botão direito → **Editar…** para mudar o nome do serviço e a conta. O código continua o mesmo.
- **Sempre ocultar o código de um token:** clique com o botão direito → **Sempre Ocultar o Código**. Ele continua oculto mesmo com **Ocultar Códigos** em **Nunca**, até você clicar nele.
- **Fechar Após Copiar**, no menu ⋯, fecha o painel após cada cópia para você colar na hora.
- Códigos copiados ficam ocultos para gerenciadores de área de transferência e são apagados dela após 30 segundos.

<a id="adding-a-token"></a>
### Adicionando um token

Clique em **Adicionar** na parte de baixo do painel e cole um destes:

| Você tem | O que fazer |
|---|---|
| Um link de configuração `otpauth://…` | Cole. Nome, conta e ajustes vêm do link. |
| Uma chave secreta como `JBSW Y3DP EHPK 3PXP` | Cole e digite um nome (ex.: “GitHub”). Espaços e minúsculas não têm problema. |
| Um código QR na tela | Faça uma captura para a área de transferência (**⌃⇧⌘4**), ou clique com o botão direito na imagem → **Copiar Imagem**. Depois abra **Adicionar** (preenche sozinho) ou clique em **Colar Link, Segredo ou Imagem QR**. |
| Um código QR em outro dispositivo ou no papel | Clique em **Escanear Código QR com a Câmera…** e segure-o diante da câmera do Mac. |

Uma prévia ao vivo mostra o código antes de salvar, para você comparar com o site.

> **Dica: adicione o novo token ao celular ao mesmo tempo.** Quando um site mostrar o código QR de configuração da 2FA,
> escaneie com o app do celular (Google Authenticator, 2FAS, Aegis…) *e* faça uma captura para o TrayOTP (**⌃⇧⌘4** e depois **Adicionar**).
> É o mesmo segredo, então os dois mostram os mesmos códigos, e você tem um backup se perder o celular ou o Mac.
> Faça isso antes de digitar o código de confirmação no site: a maioria nunca mostra o código QR de novo.
> Sem código QR? Copie a chave de configuração (geralmente em “Não consegue escanear?”) e digite-a nos dois apps.

<a id="groups"></a>
### Grupos

- **Criar um grupo:** **⋯ → Novo Grupo…**, ou clique com o botão direito em um token → **Mover para Grupo → Novo Grupo…**.
- **Mover um token:** clique com o botão direito → **Mover para Grupo**, ou arraste-o até o cabeçalho de um grupo.
- **Reordenar:** arraste um token sobre outro: a metade de cima da linha o coloca acima, a de baixo, abaixo.
  Ou selecione-o e pressione **⌘↑/⌘↓**; passando do fim de um grupo, ele entra no próximo. Arraste o cabeçalho de um grupo sobre outro para reordenar os grupos.
- **Recolher:** clique no cabeçalho de um grupo (“Sem Grupo” também). A busca sempre encontra tokens em grupos recolhidos.
  Mover a seleção para um grupo recolhido com ↑/↓ o abre até você sair; só um clique no cabeçalho salva se ele fica
  aberto ou fechado.
- **Renomear, mover ou apagar um grupo:** clique com o botão direito no cabeçalho. Apagar um grupo mantém os tokens; eles vão para “Sem Grupo”.

<a id="service-icons"></a>
### Ícones de serviços

O TrayOTP não inclui logotipos de marcas. Em vez disso, ele lê pacotes de ícones no
[formato de pacote de ícones do Aegis](https://github.com/beemdevelopment/Aegis/blob/master/docs/iconpacks.md):

1. Baixe `aegis-icons.zip` das [versões do aegis-icons](https://github.com/aegis-icons/aegis-icons/releases)
   (ou qualquer outro pacote compatível com o Aegis).
2. **⋯ → Pacote de Ícones → Instalar Pacote de Ícones do Aegis…** e escolha o ZIP.

Os tokens ganham um ícone automaticamente pelo emissor ou nome (“Google Workspace” → Google).
Para o resto, clique com o botão direito em um token:

| Item de menu | O que faz |
|---|---|
| **Editar Ícone…** | Ajustar o ícone atual (só quando o token tem um, não iniciais) |
| **Escolher Ícone do Pacote…** | Buscar no pacote instalado e escolher um ícone manualmente |
| **Definir Ícone de Arquivo…** | Usar um arquivo de imagem (PNG, JPEG, SVG, HEIC, PDF…) |
| **Colar Ícone** | Usar uma imagem que você copiou |
| **Buscar Ícone do Site…** | Baixar o favicon do site (você confirma o domínio antes) |
| **Remover Ícone** | Voltar ao ícone automático ou às iniciais coloridas |

Para definir vários de uma vez, **⋯ → Pacote de Ícones → Importar Ícones de Pasta…** associa nomes de arquivos de imagem aos nomes dos tokens
(`github.png` → GitHub). Um ícone escolhido por você sempre tem prioridade sobre a correspondência automática do pacote.

> **Nota de privacidade:** **Buscar Ícone do Site…** baixa o favicon pelo serviço de ícones do DuckDuckGo, então o
> DuckDuckGo vê esse domínio. Isso só acontece quando você escolhe, nunca automaticamente.

<a id="import-and-export"></a>
### Importar e exportar

**Importar:** **Adicionar → Importar de Arquivo…** e escolha o arquivo. O TrayOTP detecta o app e pede a senha do backup se
o arquivo estiver criptografado. O que não puder ser importado é listado no final.

**Exportar:** **⋯ → Backup e Exportação ▸ → Exportar para outro app ▸** e escolha o app. O TrayOTP pede o Touch ID antes.

| App | Importar | Exportar | Grupos |
|---|---|---|---|
| **2FAS** (`.2fas`) | Sem criptografia ou criptografado | Sem criptografia ou criptografado | ✓ |
| **Aegis** (`.json`) | Sem criptografia ou criptografado | Sem criptografia ou criptografado | ✓ (e ícones) |
| **Ente Auth** (`.txt`) | Texto simples | Texto simples | ✓ (como tags) |
| **Google Authenticator** | Códigos QR de “Transferir contas” | Códigos QR (30 s, 6 ou 8 dígitos) | — |
| **Bitwarden** e **Bitwarden Authenticator** (`.json`, `.csv`) | Sem criptografia | JSON sem criptografia (sem HOTP) | ✓ (pastas) |
| **Proton Authenticator** (`.json`) | Sem criptografia ou criptografado | — | — |
| **Stratum** / Authenticator Pro | Sem criptografia ou criptografado | — | ✓ (categorias) |
| **andOTP** (`.json`, `.json.aes`) | Sem criptografia ou criptografado | — | ✓ (primeira tag) |
| **FreeOTP+** (`.json`) | ✓ | — | — |
| **Raivo OTP** (`.zip`, não testado, [avise-nos](https://github.com/outerstudio/trayotp/issues)) | ZIP protegido por senha | — | — |
| **Senhas da Apple** (`.csv`) | Códigos de verificação (coluna `OTPAuth`) | — | — |
| **Outros gerenciadores de senhas** (`.csv`, não testado, [avise-nos](https://github.com/outerstudio/trayotp/issues)): 1Password, KeePassXC… | Uma coluna chamada `OTPAuth`, `TOTP` ou `login_totp` | — | ✓ (pasta/grupo) |
| Qualquer arquivo de texto com links `otpauth://` | ✓ | ✓ | — |

**Google Authenticator:** no celular, abra **⋮ → Transferir contas → Exportar contas**. O Google bloqueia capturas desta
tela, então no TrayOTP clique em **Adicionar → Escanear Código QR com a Câmera…** e segure o celular diante da câmera do Mac,
a cerca de 20–30 cm e com o brilho no máximo. Todas as contas do código são importadas de uma vez. Se o Google mostrar
vários códigos QR, escaneie cada um. Códigos densos são mais difíceis para uma webcam ler: se algum não for reconhecido,
exporte menos contas por vez.

Sem câmera embutida (Mac mini, Mac Studio, Mac Pro)? Uma webcam USB funciona, assim como um iPhone ou iPad (que não seja o
que tem o Google Authenticator) usado como webcam (Câmera de Continuidade). Ou fotografe a tela de transferência com outro
celular, leve a foto para o Mac (AirDrop, Fotos do iCloud, e-mail…) e importe com
**Adicionar → Importar de Arquivo…**: PNG, JPEG e HEIC funcionam.

**Para o Google Authenticator:** **⋯ → Backup e Exportação → Exportar para outro app → Google Authenticator (Códigos QR)…** mostra as contas como códigos QR,
10 por código. No Google Authenticator, abra **⋮ → Transferir contas → Importar contas** e escaneie cada um. O Google só
aceita códigos de 30 segundos com 6 ou 8 dígitos, então os outros tokens (e Steam) ficam de fora, e você é informado de quais.
A janela fica oculta em capturas e no compartilhamento de tela e fecha quando o TrayOTP bloqueia.

**Duplicados:** um token é ignorado se você já tem um com o mesmo segredo e a mesma conta, então importar o mesmo arquivo duas
vezes (ou códigos QR do Google que se sobrepõem) não adiciona nada. Um token com o mesmo nome e conta de um existente, mas com
outro segredo, é mantido, com a hora em que foi adicionado após o nome (ex.: `GitHub 2026-11-17 23:40`), e listado após a
importação. Normalmente isso significa que o site emitiu um novo segredo; apague o token antigo quando o novo funcionar.
O mesmo vale ao adicionar um token por vez.

**Não testado** significa que o TrayOTP lê o formato conforme documentado, mas ainda não foi testado com um arquivo exportado
daquele app. Se uma importação falhar ou os códigos não baterem,
[abra uma issue](https://github.com/outerstudio/trayotp/issues) informando o app e a versão (nunca anexe o arquivo:
ele contém seus segredos).

> **Antes de apagar tokens do app antigo,** confira se alguns códigos importados batem com os que ele mostra.

Não compatíveis: exportações criptografadas do Ente Auth (exporte como texto simples no Ente), exportações criptografadas do
Bitwarden, backups do FreeOTP original, Authy e Microsoft Authenticator (não conseguem exportar) e tokens Yandex e mOTP.

> **Exportações sem criptografia contêm todos os seus segredos em texto simples.** Apague o arquivo depois de importá-lo.
> Para um backup que você vai guardar, use **Aegis (Criptografado)**: sua proteção por senha (scrypt) é muito mais difícil de
> quebrar que a do 2FAS.

### Bloqueio e ajustes

Tudo no menu **⋯**:

| Ajuste | O que faz |
|---|---|
| **Manter Desbloqueado ▸** | Quanto tempo o TrayOTP fica desbloqueado após o último uso: sempre bloquear, de 1 minuto a 1 hora, **Até o Mac repousar ou bloquear**, **Até eu bloquear**, ou um número de minutos personalizado. Ele bloqueia quando o Mac entra em repouso ou a tela é bloqueada, exceto com **Até eu bloquear**, que fica desbloqueado até você clicar em Bloquear. |
| **Definir Senha Mestra…** | A senha que você digita antes de exportar ou apagar tokens (veja [Segurança](#security)). Depois de definida, o menu oferece Alterar, Remover, **Desbloquear com senha em vez do Touch ID** e **Esqueci a senha…** para apagar todos os tokens e começar de novo. |
| **Lembrete de senha ▸** | Pedir a senha de novo a cada 7, 30 ou 90 dias (ou um número personalizado), para você não esquecê-la. 30 dias por padrão. |
| **Definir Atalho Global…** | Abrir o painel de qualquer app com a combinação de teclas que você escolher (com ⌘, ⌃ ou ⌥). |
| **Mostrar Ícone na Barra de Menus** | Desative para ocultar o ícone. O atalho global (ou abrir o TrayOTP de novo pelo Finder ou Launchpad) passa a mostrar o painel no topo da tela. |
| **Fechar Após Copiar** | Fechar o painel assim que um código é copiado, para você colar na hora. |
| **Limpar a área de transferência após 30 segundos** | Apagar um código copiado da área de transferência após 30 segundos (só se ela ainda contiver esse código). Ativado por padrão. |
| **Ocultar Códigos ▸** | Mascara os códigos com pontos até você agir: **Nunca** (padrão), **Até Passar o Mouse** (o ponteiro ou a seleção pelo teclado mostra uma linha) ou **Até Clicar** (clicar em uma linha copia o código e o mostra por 10 segundos). Copiar um código oculto também o mostra. |
| **Ocultar Painel no Compartilhamento de Tela** | Mantém o painel fora de compartilhamentos de tela, capturas e gravações (inclusive das suas próprias capturas). |
| **Backup e Exportação ▸** | Backup criptografado com um clique (formato Aegis; **Importar de arquivo…** restaura) em uma pasta escolhida uma vez, com um lembrete quando o último backup passar de 7, 30 (padrão) ou 90 dias. **Restaurar do backup…** abre o mesmo seletor de arquivos que **Adicionar → Importar de Arquivo…**. |
| **Tema preto profundo** | Fundo do painel preto puro em vez do material translúcido, para telas OLED. |
| **Abrir no Login** | Iniciar o TrayOTP ao fazer login. |
| **Verificar Atualizações…** | Abre uma janela com a versão atual, **Verificar Agora**, **Verificar Automaticamente** (uma vez por dia, ativado por padrão) e o **Canal de Atualização**: **Estável**, **Beta** ou **Alfa**. Uma versão mais nova também mostra um botão **Atualizar para ……** abaixo de Adicionar / Bloquear / Sair. |
| **Idioma ▸** | **Idioma do Sistema** segue o idioma do Mac (inglês se o TrayOTP não tiver tradução para ele), ou escolha uma das traduções. O TrayOTP reinicia para trocar. |

Clique em **Bloquear** na parte de baixo do painel para bloquear na hora.

<p align="center">
  <img src="../docs/screenshots/lock-screen.png" width="340" alt="O painel bloqueado: “O TrayOTP está bloqueado”, o pedido de Touch ID e os botões Usar Senha… e Encerrar">
</p>

<a id="security"></a>
## Segurança

### Como seus segredos são guardados

- Os tokens ficam criptografados (**AES-256-GCM**) no seu Mac, em um arquivo que só a sua conta de usuário pode ler.
- A chave de criptografia é uma chave aleatória de 256 bits guardada nas suas **Chaves de início de sessão**, nunca ao lado do arquivo.
- O cofre só é descriptografado após o Touch ID ou a senha do Mac, e os tokens
  descriptografados são descartados da memória quando ele bloqueia de novo.
- **Exportar**, **apagar um token** e **alterar a senha mestra** sempre pedem sua senha de novo, mesmo com o TrayOTP desbloqueado. Veja [Senha mestra](#master-password).
- Nada sai do seu Mac, exceto um domínio que você decida consultar com **Buscar Ícone do Site…**.
- A câmera só é usada enquanto a janela **Escanear Código QR** está aberta. Os quadros são lidos na memória e nunca salvos.
  O macOS pede acesso à câmera na primeira vez e pode pedir de novo após uma atualização (o TrayOTP tem assinatura ad hoc).

<a id="master-password"></a>
### Senha mestra

O Touch ID deixaria alguém usar seu dedo enquanto você dorme, então o TrayOTP pede uma senha que você digita.
Depois que você adiciona ou importa o primeiro token, o TrayOTP pede que você defina uma **senha mestra**. Ela fica na frente de:

- exportar seus tokens (a senha também criptografa o arquivo de backup por padrão; você pode escolher outra a cada exportação),
- apagar um token (depois de digitá-la uma vez, novas exclusões em até 2 minutos não pedem de novo),
- mostrar um único token como código QR (clique com o botão direito → **Exportar…**, para adicioná-lo a outro app autenticador;
  depois de digitar a senha uma vez, novos códigos QR em até 3 minutos não pedem de novo),
- alterar ou remover a senha.

Por padrão ela não substitui o Touch ID para abrir o TrayOTP. Ative **⋯ → Senha Mestra → Desbloquear com senha em vez do
Touch ID** e a chave do cofre nas Chaves é ela própria criptografada com uma chave derivada da mesma senha (scrypt com N=2¹⁷,
r=8, p=1: cerca de 0,5 s e 128 MB por tentativa). Quem entrar nas suas Chaves ainda precisa adivinhar a senha. Ativá-la,
desativá-la ou alterá-la troca para uma nova chave do cofre, então cópias antigas das Chaves (por exemplo, em um backup do
Time Machine) não conseguem mais abrir o cofre.

**Se você a esquecer, ela não pode ser recuperada.** Sem a opção de desbloqueio, o único caminho de volta é
**⋯ → Senha Mestra → Esqueci a senha…**, que apaga todos os seus tokens. Com ela, seus tokens não podem ser recuperados de
forma alguma. Certifique-se de conseguir entrar em cada conta de outra forma (seus códigos de backup ou uma exportação
criptografada) antes de depender só do TrayOTP. O **Lembrete de senha** pede a senha a cada tantos dias para que ela continue
fresca na memória.

Você pode pular digitando *Entendo o risco*. Então exportações e exclusões só pedem o Touch ID ou a senha do Mac, e qualquer
pessoa diante do seu Mac desbloqueado pode exportar todos os seus tokens. Isso também deixa uma brecha: se você pulou, quem
abrir o TrayOTP primeiro pode definir a senha. Ative depois em **⋯ → Definir Senha Mestra…**.

<a id="limitations"></a>
### Limitações

- O TrayOTP não é assinado com um certificado do Apple Developer, então o macOS não permite vincular a chave do cofre ao
  Touch ID dentro das Chaves. O Touch ID é exigido pelo app, e outro app pedindo a chave dispara um alerta do macOS
  **“deseja usar suas Chaves”**. Você só deve ver esse alerta logo após atualizar o TrayOTP, ao abri-lo. **Se ele aparecer em
  outro momento, ou citar um app que não seja o TrayOTP, clique em Negar:** outra coisa está tentando ler a chave que protege
  seus tokens.
- Seus segredos só estão tão seguros quanto o seu Mac. Ative o **FileVault**, **criptografe os backups do Time Machine** e use uma
  senha de login forte. Se o arquivo do cofre e as suas Chaves de início de sessão fossem roubados, o que fica no caminho é a senha
  de login (mais a senha mestra, se você definiu uma).
- As versões usam o runtime reforçado, que impede outros processos de injetar código no TrayOTP ou anexar um depurador.

Encontrou um problema de segurança? Informe em particular pela [aba Security](https://github.com/outerstudio/trayotp/security)
do repositório, e não em uma issue pública.

<a id="troubleshooting"></a>
## Solução de problemas

- **“TrayOTP deseja usar suas Chaves” após uma atualização**
  - O macOS pergunta de novo após cada atualização porque cada versão é assinada separadamente. Digite a senha das suas Chaves de
    início de sessão (normalmente a senha do Mac) e escolha **Sempre Permitir**. Se aparecer em outro momento, veja
    [Limitações](#limitations).
- **O Launchpad mostra um ícone em branco**
  - O Launchpad só lista apps em `/Applications`. Se o ícone continuar em branco depois de mover o app para lá, execute `killall Dock`.
- **Um código QR não é detectado**
  - Recorte a captura mais perto do código. Para o Google Authenticator, use **Adicionar → Escanear Código QR com a Câmera…**
    (veja [Importar e exportar](#import-and-export)).
- **“Senha do backup incorreta”**
  - Use a senha definida ao exportar o backup do outro app (ou do TrayOTP), não a senha do Mac.

## Use por sua conta e risco

O TrayOTP é software livre e gratuito, fornecido como está, sem garantia de nenhum tipo (veja a [licença](../LICENSE)).
Os autores não se responsabilizam por perda de acesso às suas contas, segredos perdidos ou vazados, nem qualquer outro dano.

Perder seus códigos 2FA pode trancar você fora das suas contas, então não deixe o TrayOTP ser sua única cópia:

- Guarde os **códigos de recuperação** de cada site ao configurar a 2FA.
- Mantenha o token também em um segundo app, como o do celular (veja a dica em [Adicionando um token](#adding-a-token)).
- Exporte um backup criptografado de vez em quando (**⋯ → Backup e Exportação → Fazer backup agora**) e guarde-o em um lugar seguro.
- Depois de importar, confira alguns códigos antes de apagar qualquer coisa do app antigo.

## Apoio

O TrayOTP é gratuito. Se ele economiza seu tempo, você pode [me pagar um café](https://buymeacoffee.com/garyyeap)
(também no menu ⋯), ou apoiar via [Ko-fi](https://ko-fi.com/garyyeap), [Liberapay](https://liberapay.com/garyyeap) ou
[thanks.dev](https://thanks.dev/u/gh/garyyeap).

## Desenvolvimento

Compilação, testes, estrutura do projeto, traduções e detalhes dos formatos estão no
[README em inglês](../README.md#development), assim como os [créditos](../README.md#credits).

## Licença

[MIT](../LICENSE) © 2026 outerstudio.com
