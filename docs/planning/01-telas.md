# 1 — Telas

> **Status: feito.** A telas sem notch usam a altura real da barra de menus como
> faixa de hover e de Live Activities; o manipulador é só o desenho em repouso.
> "Show handle" desligado deixa a área invisível, mas o hover continua abrindo.

## Objetivo

Escolher em quais telas o notch aparece, como ele se comporta com apps em tela
cheia e como aparece em telas sem notch físico.

## Referência

Página "Telas" com:

- **Mostrar em**: cards de cada tela conectada com miniatura do papel de parede,
  nome ("Tela Retina Integrada", "Tempest 34'"), tipo ("Integrado · Notch ·
  Principal", "Externa") e resolução. O check em cada card liga ou desliga a
  tela. O rodapé diz "Em 2 de 2 telas" e tem atalhos "Todas as telas · Somente
  telas com notch".
- **Tela inteira**: três opções em cards — Todas as telas; Telas com notch;
  Nunca (ocultar quando um app estiver em tela cheia).
- **Telas sem notch**: Mostrar manipulador (toggle), Largura (slider, ex.: 184),
  Altura (slider, ex.: 8), Manipulador transparente (toggle).

## Comportamento esperado

- Por padrão, aparece em todas as telas. Telas sem notch mostram o
  **manipulador**: uma barra fina e arredondada no topo, centralizada, em vez do
  notch simulado de 200×32 de hoje. Passar o mouse no manipulador abre o notch
  normalmente.
- Manipulador transparente: invisível, mas continua sendo área de hover.
- Tela cheia:
  - **Todas as telas**: o notch continua aparecendo sobre apps em tela cheia.
  - **Telas com notch**: em tela cheia, só aparece nas telas com notch físico,
    onde a área do notch não tem conteúdo do app.
  - **Nunca**: some de qualquer tela que tenha um app em tela cheia.
- Uma tela desconectada e reconectada mantém a escolha.

## Configurações

| Chave | Tipo | Padrão |
| --- | --- | --- |
| `screens.enabledDisplayUUIDs` | `[String]?` (nil = todas) | nil |
| `screens.fullscreenPolicy` | `allScreens` / `notchScreens` / `never` | `notchScreens` |
| `screens.showsHandle` | Bool | true |
| `screens.handleWidth` | Double, 80...300 | 184 |
| `screens.handleHeight` | Double, 4...16 | 8 |
| `screens.handleIsTransparent` | Bool | false |

## Design técnico

- **Identidade da tela**: `CGDisplayCreateUUIDFromDisplayID` gera um UUID que
  continua o mesmo entre reinícios e reconexões. O `NSScreenNumber` muda e não
  serve para persistir.
- **Metadados para os cards**:
  - Nome: `NSScreen.localizedName`.
  - Integrada: `CGDisplayIsBuiltin`.
  - Notch: `safeAreaInsets.top > 0`.
  - Principal: `NSScreen.screens.first`.
  - Resolução: `frame.size`.
  - Miniatura: `NSWorkspace.shared.desktopImageURL(for:)`.
- **`WindowsManager.eligibleScreens()`** passa a filtrar pela seleção salva e
  pela política de tela cheia. Também deixa de usar `NSScreen.main`, que é a
  tela da janela em foco, e usa `NSScreen.screens.first`, a tela da barra de
  menus. Isso corrige o defeito atual com monitores externos.
- **`NotchGeometry`** ganha o caso `handle(width:height:)`, além do notch físico.
  A altura de referência da barra de menus é
  `screen.frame.maxY - screen.visibleFrame.maxY` (com fallback para
  `NSStatusBar.system.thickness` quando a barra fica oculta).
- **Detecção de tela cheia** (`FullscreenMonitor`, `@Observable`, estado por
  tela):
  - Reavalia em `NSWorkspace.activeSpaceDidChangeNotification`,
    `didActivateApplicationNotification` e
    `NSApplication.didChangeScreenParametersNotification`.
  - Critério: existe janela de layer 0 do app ativo cujo `kCGWindowBounds` cobre
    o frame inteiro da tela (`CGWindowListCopyWindowInfo` com
    `.optionOnScreenOnly`). Ler limites não pede permissão de Gravação de Tela;
    títulos pediriam, e não são necessários.
  - O `WindowsManager` esconde ou mostra a janela daquela tela, sem recriá-la.

## Permissões e riscos

- Sem permissões novas.
- **"Todas as telas" em tela cheia**: com o `collectionBehavior` atual
  (`.fullScreenAuxiliary`), a janela aparece sobre apps em tela cheia na maioria
  dos casos. Alguns apps e o Space de tela cheia podem escondê-la. A solução
  completa usa a API privada SkyLight, que está fora do escopo.
- A heurística de tela cheia pode errar com janelas maximizadas sem tela cheia
  real, cobrindo a tela inteira com a barra de menus oculta. Aceitável: o
  efeito é o mesmo para o usuário.

## Critérios de aceite

- Com o MacBook fechado e só um monitor externo, o manipulador aparece na tela
  da barra de menus e abre o notch.
- Desmarcar uma tela remove o notch dela na hora; reconectar a tela mantém a
  escolha.
- Com "Nunca", abrir um vídeo em tela cheia esconde o notch daquela tela e só
  dela.

## Perguntas em aberto

- O manipulador deve acompanhar a altura real da barra de menus, ou só a
  configuração de altura?
