# NotchFull

App de notch para macOS 26+, construído do zero. A primeira etapa é a base do
notch; a área de agents de IA vem depois.

## Requisitos

- macOS 26 e Xcode 26
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Gerar e rodar

O `.xcodeproj` é gerado a partir do `project.yml` e não é versionado.

```bash
xcodegen generate
open NotchFull.xcodeproj
```

Ou pela linha de comando:

```bash
xcodegen generate
xcodebuild -project NotchFull.xcodeproj -scheme NotchFull -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/NotchFull.app
```

Rode `xcodegen generate` de novo sempre que adicionar ou remover arquivos.

O app não tem ícone no Dock. As configurações abrem pela engrenagem no notch
aberto ou pelo ícone na barra de menus (**Settings…**, `⌘,`), onde também fica
**Quit NotchFull**.

## Estrutura

```
NotchFull/
  App/                 ponto de entrada SwiftUI, AppDelegate, AppServices (fontes de dados compartilhadas)
  Notch/
    Geometry/          medidas do notch físico a partir do NSScreen
    State/             NotchViewModel (aberto/fechado)
    Views/             NotchView, NotchShape
    Window/            NotchWindow (NSPanel), NotchController (uma tela), WindowsManager (todas as telas)
  Widgets/             catálogo (WidgetKind), layout persistido e widgets: música, calendário, to-dos, relógio, agents
  LiveActivities/      atividades do notch fechado: mídia (efeitos e captura de áudio), bateria, Bluetooth,
                       downloads e eventos próximos do calendário
  Settings/            janela de ajustes com previews: Aparência, Nook e Live Activities
```

## Comportamento atual

- Um notch por tela com notch físico; sem nenhuma, usa a tela principal com um
  notch simulado.
- Passar o mouse sobre o notch abre; sair da área aberta fecha.
- Com o notch fechado, a janela ignora o mouse, para não bloquear a barra de
  menus.
- Com música tocando (Spotify ou Music), o notch fechado mostra a capa à
  esquerda e um efeito à direita: espectrograma, onda, círculo vibrante ou GIF.

## Permissões

| Permissão | Quando é pedida |
| --- | --- |
| Calendário | Ao clicar em "Allow access" no widget de calendário |
| Automação (Spotify/Music) | Ao carregar a capa ou usar os controles pela primeira vez |
| Gravação de áudio do sistema | Ao ativar "React to the audio playing" |
| Bluetooth | Na primeira abertura, para mostrar dispositivos conectando |

Com assinatura ad-hoc, cada build muda a identidade do app e o macOS pode
pedir as permissões de novo.
