# NotchNook Pro 2.0.3 — mapa de arquitetura (Fase 1)

Referência para construir o notchFull do zero. Nada aqui é código do
NotchNook: são nomes de tipos, membros e APIs observados no binário, usados
para entender a arquitetura. A implementação do notchFull é própria.

## Legenda de confiança

- **Observado**: lido diretamente do artefato (símbolos, strings, assinatura).
- **Inferido**: conclusão a partir de nomes/símbolos; não verificado em
  pseudocódigo nem em execução.

## Fontes

| Fonte | Ferramenta | O que forneceu |
| --- | --- | --- |
| Bundle `/Applications/NotchNook Pro.app` | REA `inspect_desktop_application` | Inventário de 519 arquivos, frameworks, recursos |
| `Info.plist` | `plutil` | Bundle ID, versão, macOS mínimo, feed do Sparkle |
| Assinatura (arm64) | REA `inspect_signature` | Entitlements, hardened runtime |
| Binário (arm64, 60.462 procedimentos, 18.759 strings) | REA `open_binary` (Hopper demo), `binary_overview` | Contagens e segmentos |
| Símbolos Swift | `nm` + `swift-demangle` | 1.239 tipos nominais (177 classes, 813 structs, 249 enums), membros |
| Strings | `strings` | APIs privadas, seletores AppKit |

SHA-256 do executável: `ae70974d90bb8ae58d1e78ec8e5494f40f24360b9632776669b60885f08d8d27`.

## Plataforma e distribuição (observado)

- Bundle ID `com.getnotchnook.NotchNookPro`, versão 2.0.3, macOS mínimo 14.6.
- Binário universal arm64 + x86_64, ~141 MB.
- Assinado com Developer ID, **hardened runtime**, **sem App Sandbox**
  (não há `com.apple.security.app-sandbox`). Distribuição fora da App Store.
- Entitlements: apple-events (automação), audio-input, camera, contatos,
  calendários, localização.
- Atualização via Sparkle (feed em Cloudflare Workers).

Implicação para o notchFull: app fora da App Store e sem sandbox, para poder
ler `~/.claude`, `~/.codex` etc. e usar APIs privadas.

## Stack (observado: frameworks linkados e bundles SPM)

- Swift + SwiftUI + AppKit, Combine, SwiftData.
- Pacotes de terceiros: Lottie, Sparkle, Defaults, Settings, PermissionFlow,
  RichTextKit, Highlightr, SwiftTerm, SmoothGradient, MediaRemoteAdapter.
- Metal (2 `.metallib`), ScreenCaptureKit, AVFoundation, EventKit, Contacts,
  CoreBluetooth/IOBluetooth, CoreLocation, Speech, WebKit, JavaScriptCore,
  ServiceManagement, Carbon.

## Núcleo do notch

### Ciclo de vida e janelas

| Tipo (kind) | Membros observados | Papel (inferido) |
| --- | --- | --- |
| `AppDelegate` (class) | `applicationDidFinishLaunching`, `applicationWillTerminate` | Entrada AppKit; app sem janela principal |
| `WindowsManager` (class) | `showSettings`, `showOnboardingWindow`, `openNotchFromSettings`, `setNotchCaptureExcluded`, `performNavigationShortcut`, `suspendLicensedWindows` | Dono de todas as janelas (notch, settings, onboarding) |
| `BetterWindow` (class) | `init(contentRect:styleMask:backing:defer:)`, `convertWindowFrameToScreenFrame`, `takeScreenshot`, `setupIfNeeded(with:closing:cb:)`, `fakeFullscreenScreenshotWindow`, `onClose`, `whileClosing` | Janela do notch; anima abrir/fechar usando um screenshot/CALayer “falso” |
| `SwiftUIWindow`, `SwiftUIAnimatedWindow` (class) | `viewBuilder`, `onClose`, `openingOrigin`, `visibleFrame` | Janelas auxiliares que hospedam SwiftUI |
| `RoundedPanelWindow`, `LockScreenWindow`, `PocketWindow` (class) | — | Painéis flutuantes, tela de bloqueio, “pocket” |

APIs AppKit observadas nas strings: `setLevel:`, `setCollectionBehavior:`,
`setIgnoresMouseEvents:`, `addGlobalMonitorForEventsMatchingMask:handler:`,
`addLocalMonitorForEventsMatchingMask:handler:`, `NSScreen.safeAreaInsets`,
`auxiliaryTopLeftArea`, `auxiliaryTopRightArea`.

Inferido: a posição e o tamanho do notch físico vêm de `safeAreaInsets.top` e
das áreas `auxiliaryTopLeft/RightArea` do `NSScreen`; a janela fica num nível
acima da barra de menus, em todos os Spaces, e alterna `ignoresMouseEvents`
conforme o hover.

### APIs privadas (observado nas strings)

| Símbolo | Uso provável (inferido) |
| --- | --- |
| `SLSMainConnectionID`, `SLSSpaceCreate`, `SLSSpaceSetAbsoluteLevel`, `SLSSpaceAddWindowsAndRemoveFromSpaces`, `SLSShowSpaces` (SkyLight) | Criar um Space próprio de nível alto para exibir a janela por cima de apps em tela cheia e da tela de bloqueio |
| `MRMediaRemoteGetNowPlayingClients`, `MRMediaRemoteSetElapsedTime` (MediaRemote) | Now Playing; complementado pelo `MediaRemoteAdapter.framework` e AppleScript (`executeAppleScript`) |

APIs privadas podem quebrar entre versões do macOS. No notchFull, isolar
cada uma atrás de um protocolo, com fallback.

### Estado e interação

| Tipo (kind) | Membros observados | Papel (inferido) |
| --- | --- | --- |
| `NotchNookState` (class) | `mode: NotchMode`, `hidden`, `locked`, `keyboardPinned`, `isEditing`/`editMode`, `nookDestination: NookDestination`, `effectivePresentation`, `QuickPeek`, `setHUDIndicator`, `hudHidesLiveActivities`, `timerDraft` | Estado global do notch (aberto/fechado, destino/página, edição, HUD) |
| `NotchViewModel` (class) | `notchState`, `hovering`, `pressing`, `scaleDown`, `scrub*` (`beginScrub`, `commitScrub`, `scrubExpansion`, `scrubOvershoot`…), `panPadding`, `hoveredDropTargetID`, `droppingCoords`, `showIntro` | Estado de interação: hover, “scrub” (arrastar para abrir), drop de arquivos |
| `NotchGesturer` (SwiftUI view) | `init(state: NotchViewModel)`, `onPan`, `onPanEnded`, `commitScrubOpen`, `commitScrubClose`, `canScrub` | Converte gestos de pan/trackpad em abrir/fechar |
| `NotchView` (SwiftUI view) | `body`, `SideEffectsModifier` (com tarefas async) | View raiz do notch |
| `NotchShape` (Shape) | `path(in:)`, `decorationPaths(in:)`, `decorationRadius(forSize:)` | Recorte do notch com as “orelhas” arredondadas |
| `NotchEarsShape`, `NotchGlassContentReveal`, `NotchNookWindowBackground` | — | Variações visuais e de fundo |
| `NotchState`, `NotchOpenSpeed` (enum) | — | Estados e velocidade de abertura |

### Widgets e layout

- `NookWidget` (enum, raw value): `id`, `name`, `icon`, `description`,
  `layoutSize`, `gridSizeType`, `editorMockSize`, `mockImage`, `prefs`.
  É um catálogo de widgets com tamanho em grade e editor de layout.
- `CustomLayoutManager`, `EditWidgetsFloatingWidgetView`: edição do layout.
- Views de widget observadas: `MediaPlayerWidgetView`, `CalendarWidgetView`,
  `WeatherWidgetView`, `TrayWidgetView`, `ClipboardWidgetView`,
  `NotesWidgetView`, `TodoWidgetView`, `PomodoroWidgetView`,
  `ShortcutsWidgetView`, `VolumeWidgetView`, `MirrorWidgetView`,
  `PulseWidgetView`, `AIUsageWidgetView`, `LockScreenSmallWidgetView`.
- `LiveActivity` (enum: `id`, `name`, `icon`, `isUserConfigurable`),
  `ActiveLiveActivitiesManager`, `LiveActivityView`,
  `LiveActivityCompactBubble`: atividades compactas exibidas com o notch
  fechado (ex.: música tocando, timer, agente).

## Inventário de funcionalidades (por contagem de tipos com o termo no nome)

| Área | Tipos | Exemplos de tipos |
| --- | --- | --- |
| Settings | 125 | `NotchNookSettingsView`, `NotchNookSettingsWindowController` |
| Widgets | 92 | ver acima |
| Clipboard | 52 | `ClipboardStore`, `ClipboardShelfController`, `ClipboardPanel` |
| Agents | 47 | `AgentSessionStore`, `AgentsPanel`, `AgentBridgeServer` (fora do escopo desta fase) |
| AI usage | 40 | `AIUsageStore`, `AIUsageWindow` |
| Live Activities | 39 | `ActiveLiveActivitiesManager` |
| Onboarding | 38 | `OnboardingWindow`, `OnboardingNotchPanel` |
| Media / Music / Lyrics | 32 / 11 / 12 | `MediaManager`, `AppleMusicQueueProvider`, `LyricsManager` |
| Tray / Drop / File | 32 / 16 / 16 | `TrayConverterManager`, `TrayWidgetView` |
| Notes / Todo | 32 / 24 | `ExpandedNoteManager`, `TodoWindowController` |
| Timer / Pomodoro | 29 / 7 | `TimersManager`, `NookTimersStore`, `TimerAlarmController` |
| Calendar | 26 | `CalendarManager`, `CalendarWorkspacePanel` |
| Volume / Brightness / HUD | 24 / 7 / 5 | `AppVolumeMixer`, `CoreAudioOutputController`, `BrightnessCoordinator` |
| Shortcuts | 20 | `ShortcutsManager`, `NavigationShortcutsManager` |
| Bluetooth / Battery | 17 / 9 | `BluetoothManager`, `NativeBluetoothHUDManager` |
| Weather | 15 | `WeatherStore` |
| License / Update | 12 / 14 | `SparkleManager`, `UpdateWindowController` |
| Terminal | 8 | `TerminalPanel`, `NotchTerminalNSView` (SwiftTerm) |
| Mirror / Camera | 6 / 3 | `CameraManager` |
| Lock screen | — | `LockScreenManager`, `LockScreenWindow` |
| Outros | — | `PermissionsManager` (fluxo de permissões), `NookVideoManager`, `PocketManager`, `PrompterScriptsWindowController` |

## Padrões arquiteturais (inferido)

1. **App de barra de menus sem janela principal**: `AppDelegate` cria o
   `WindowsManager`, que é dono de todas as janelas.
2. **Uma janela AppKit hospedando SwiftUI** para o notch, com estado em
   classes `ObservableObject` (`NotchNookState`, `NotchViewModel`).
3. **Managers/Stores por funcionalidade** (`MediaManager`, `CalendarManager`,
   `WeatherStore`, `ClipboardStore`…), consumidos pelas views de widget.
4. **Catálogo de widgets em enum** com tamanho em grade e layout editável.
5. **Live Activities** como camada separada para o estado fechado.
6. **Permissões centralizadas** num `PermissionsManager`.

## Proposta de estrutura base para o notchFull (sem agents)

Escopo da primeira etapa: o notch funcionando, com uma camada de widgets e
Live Activities pronta para receber o módulo de agents depois.

```
notchFull/
  App/                 AppDelegate, ponto de entrada, LSUIElement
  Notch/
    Window/            NotchWindow (NSPanel), posicionamento por NSScreen
    Geometry/          detecção do notch (safeAreaInsets, auxiliaryTop*Area)
    State/             NotchState (fechado/peek/aberto), NotchViewModel
    Gestures/          hover, clique, pan para abrir/fechar
    Views/             NotchView, NotchShape
  Widgets/             protocolo Widget, registro, layout em grade
  LiveActivities/      protocolo LiveActivity, gerenciador, views compactas
  Platform/            wrappers de APIs privadas (SkyLight, MediaRemote) com fallback
  Settings/            preferências e janela de ajustes
  Permissions/         fluxo de permissões
```

Decisões em aberto, para validar antes de escrever código:

- Xcode project ou Swift Package com app target.
- macOS mínimo (o NotchNook exige 14.6).
- Usar ou não APIs privadas na primeira etapa (SkyLight para tela cheia e
  tela de bloqueio). Recomendação: começar sem e adicionar atrás de protocolo.
- Quais widgets entram na primeira etapa (sugestão: nenhum além de um
  placeholder; o primeiro widget real será o de agents).

## Janela do notch: confirmado no pseudocódigo (observado)

Fonte: REA `procedure_pseudo_code` (Hopper) em
`WindowsManager.init` (`0x1006c0ee0`),
`WindowsManager.setupDisplayKitForScreen(_:)` (`0x1006c6f94`) e
`BetterWindow.init(contentRect:styleMask:backing:defer:)` (`0x100416898`).

### Uma janela por tela

- `WindowsManager` é um singleton (`static shared`) com
  `displayKits: [DisplayKit]`, um por `NSScreen`.
- No `init`, observa `NSApplicationDidChangeScreenParametersNotification`
  (→ `screenDidChange` → `debouncedUpdateWindows` → `updateWindows`) e
  `NSMenuDidBegin/EndTrackingNotification` (para não brigar com menus abertos).
  Guarda `lastKnownScreenConfigurations` e só recria janelas quando
  `hasSignificantScreenChanges()`.
- `setupDisplayKitForScreen(_:)` cria, para cada tela: um `NotchNookState`
  próprio, a `RootView` SwiftUI dentro de um `AcceptingFirstClickHostingView`
  (subclasse de `NSHostingView` que aceita o primeiro clique) com
  `sizingOptions` vazio, e a janela `ForceFocusableWindow`, embrulhada num
  `NSWindowController`.

### Geometria

- Largura do notch: se `screen.safeAreaInsets.top != 0` (tela com notch),
  `largura = screen.pointsPerInch × 1.44313723`. Ou seja, o app estima a
  largura física do notch (~1,44 polegada) a partir da densidade da tela.
  Sem notch, usa um valor padrão.
- Escala opcional por configuração (`NSScreen.nookDisplayScale`).
- Altura da janela: `NotchView.windowHeight × escala` (constante estática).
- A janela fica centralizada horizontalmente e colada no topo da tela
  (`y = alturaDaTela − alturaDaJanela + 1`). A janela é bem maior que o
  notch; o recorte visível é desenhado em SwiftUI (`NotchShape`).

### Configuração da janela

| Propriedade | Valor | Significado |
| --- | --- | --- |
| Classe | `ForceFocusableWindow` | Subclasse com `cancelOperationCb` (Esc) e `firstResponderCb` |
| `styleMask` | `0x80` | `.nonactivatingPanel`: não rouba o foco do app ativo |
| `level` | `25` | `NSWindow.Level.statusBar` |
| `collectionBehavior` | `0x40151` | `.canJoinAllSpaces`, `.stationary`, `.ignoresCycle`, `.fullScreenAuxiliary`, `.canJoinAllApplications` |
| `isOpaque` / `backgroundColor` / `hasShadow` | `false` / `.clear` / `false` | Janela transparente; o visual vem do SwiftUI |
| `sharingType` | `.none` ou `.readOnly` | Por tela, conforme `setNotchCaptureExcluded`: pode esconder o notch de screenshots e compartilhamento de tela |
| `isMovable`, `isReleasedWhenClosed`, `hidesOnDeactivate` | `false` | Fixa e persistente |
| `becomesKeyOnlyIfNeeded` / `worksWhenModal` | `false` / `true` | Pode virar key para receber teclado (notas, terminal) |
| Título | oculto, titlebar transparente | — |
| Content view | layer-backed, fundo `clear` | — |
| Exibição | `orderFrontRegardless()` | Mostra sem ativar o app |

Também observa `NSWindowDidResignKeyNotification` (provavelmente para fechar
ou desfocar o notch ao perder o foco).

### Preferências

Cada área tem uma chave do pacote Defaults injetada na `RootView`:
`generalSettings`, `liquidGlassSettings`, `gestureControlSettings`,
`liveActivitiesSettings`, `nookSettings`, `traySettings`, `dropAreaSettings`,
`mediaLiveActivitySettings`, `calendarLiveActivitySettings` e uma por widget
(`mediaWidgetSettings`, `calendarWidgetSettings`, `notesWidgetSettings`,
`todoListWidgetSettings`, `aiUsageWidgetSettings`, `timerWidgetSettings`…).

### Outros detalhes

- `BetterWindow.init` apenas zera os campos e define `delegate = self`.
- O app usa o framework Observation (`@Observable`) além de
  `ObservableObject`.

## Estrutura de pastas do projeto original (observado)

O binário foi compilado com instrumentação de cobertura (`__LLVM_COV`), que
preserva os caminhos dos 777 arquivos-fonte. A organização, resumida:

```
NotchNook/
  main.swift, AppDelegate.swift
  components/                 views reutilizáveis (BetterWindow, SwiftUIWindow, VisualEffectView…)
    Notch/
      Agents/                 AgentsPanel, AgentProgressPage, AgentUsagePage
      GlassBackground/        fundo "liquid glass" (DynamicGlass…)
      Nook/                   NookView + Widgets/<Widget>/…
      TopBar/                 barra do notch fechado
        liveActivities/       LiveActivityView, CompactBubble, activities/<Tipo>/…
      Tray/, DropArea/, Clipboard/, Terminal/, Prompter/, CalendarWorkspace/
    Indicator/, LockScreen/, Pocket/, intro/, ButtonStyles/
  models/
    singletons/               managers globais (ActiveLiveActivitiesManager, CalendarManager, TimersManager…)
    MonitorsAndListeners/     PowerMonitor, HUD de volume/brilho, MediaKeyTap
    AgentBridge/              10 arquivos (subsistema de agents)
    AIUsage/, media/, Weather/, Messages/, SwiftData/, settings/, enums/
    WindowsManager.swift, NotchNookState.swift, PermissionsManager.swift, License*.swift
  views/
    NotchView/                NotchView, NotchViewModel, modifiers/
      modifiers/              Animations, Gestures, LockedIndicator,
                              EnvironmentsModifier/functions/{openNotch,closeNotch,hideNotch}
                              ShapeModifier/{NotchGesturer, drop*}
                              SideEffectsModifier/onAppearTasks/
    Settings/, Onboarding/, EditWidgets/, NotesWindow/, TodoWindow/, Update/, Changelog/
  extensions/, utils/, decorators/
```

Padrão observado: a `NotchView` é composta por modifiers (gestos, forma,
animações, efeitos colaterais), e as ações abrir/fechar/esconder ficam em
funções separadas.

## Próximos passos

- Validar as decisões em aberto e criar o esqueleto do notchFull.
- Opcional: pseudocódigo de `openNotch`/`closeNotch`, `NotchGesturer` e
  `NotchShape.path(in:)`, se precisarmos reproduzir a animação de perto.
- Mapear o subsistema de agents (`models/AgentBridge/`,
  `components/Notch/Agents/`, `AIUsage`) quando a base estiver pronta.
