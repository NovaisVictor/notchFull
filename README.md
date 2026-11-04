# NotchAgents

App de notch para macOS 26+, construído do zero. A primeira etapa é a base do
notch; a área de agents de IA vem depois.

## Requisitos

- macOS 26 e Xcode 26
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Gerar e rodar

O `.xcodeproj` é gerado a partir do `project.yml` e não é versionado.

```bash
xcodegen generate
open NotchAgents.xcodeproj
```

Ou pela linha de comando:

```bash
xcodegen generate
xcodebuild -project NotchAgents.xcodeproj -scheme NotchAgents -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/NotchAgents.app
```

Rode `xcodegen generate` de novo sempre que adicionar ou remover arquivos.

O app não tem ícone no Dock. Para sair, use o ícone na barra de menus →
**Quit NotchAgents**.

## Estrutura

```
NotchAgents/
  App/                 ponto de entrada SwiftUI, AppDelegate, item da barra de menus
  Notch/
    Geometry/          medidas do notch físico a partir do NSScreen
    State/             NotchViewModel (aberto/fechado)
    Views/             NotchView, NotchShape
    Window/            NotchWindow (NSPanel), NotchController (uma tela), WindowsManager (todas as telas)
docs/                  análise de referência do NotchNook
```

## Comportamento atual

- Um notch por tela com notch físico; sem nenhuma, usa a tela principal com um
  notch simulado.
- Passar o mouse sobre o notch abre; sair da área aberta fecha.
- Com o notch fechado, a janela ignora o mouse, para não bloquear a barra de
  menus.
