# F — Fundações compartilhadas

Peças que as features seguintes reutilizam. Construí-las antes evita que cada
feature invente a própria versão.

## F1 — Shell de ajustes por seções e páginas de widget

### Objetivo

Os ajustes hoje têm três páginas (Appearance, Nook, Live Activities). As
features novas precisam de páginas próprias e de ajustes por widget.

### Comportamento esperado

- Barra lateral agrupada:
  - **Geral**: Geral, Aparência, Telas, Comportamento, Permissões.
  - **Espaços de trabalho**: Nook e uma página por widget (Música, Tarefas,
    Notas, Pulse, Pomodoro, Calendário, Agentes).
  - **Recursos**: Atividades ao vivo, HUD, Downloads, Atalhos de teclado.
  - **Sobre**: versão, link do repo, checar atualização.
- Busca de ajustes no topo da barra lateral (filtra páginas e linhas pelo
  título).
- Cabeçalho de página centralizado com ícone, título e descrição curta, como na
  referência.
- **Nook interativo**: no preview do Nook, clicar num widget o seleciona
  (contorno roxo e botão "×" para remover) e mostra os ajustes dele logo abaixo.
  Arrastar no preview reordena. O rodapé mostra "N widgets · M células".
- Página de cada widget: cabeçalho com ícone, nome, células e um botão
  **Remover do Nook** (ou **Adicionar ao Nook**).
- **Restaurar widgets padrão** na página Nook.

### Design técnico

- `SettingsPane` vira uma árvore de seções com um `SettingsPaneID` estável.
  Cada página é uma view registrada nessa tabela, sem `switch` espalhado.
- Busca: cada página declara as palavras-chave das suas linhas
  (`SettingsSearchEntry`), e a busca filtra essa lista. Não varre a árvore de
  views.
- Seleção no preview: `NookEditorState` (`@Observable`) guarda o widget
  selecionado. O preview usa `WidgetGrid` com um modo de edição que desativa a
  interação com os widgets e mostra os controles de seleção.
- Reordenar por arrasto no preview: `draggable`/`dropDestination` com o
  `WidgetKind` como payload (`Transferable` com o raw value).

### Critérios de aceite

- Toda página nova entra só com a declaração na tabela.
- Selecionar um widget no preview mostra os ajustes dele sem trocar de página.
- A busca encontra "Largura" e leva à linha certa.

## F2 — Largura de widget em células

### Objetivo

Widgets como Notas e Tarefas têm largura ajustável ("Largura 5"). Hoje o
`span` é fixo por `WidgetKind`.

### Design técnico

- `WidgetKind` passa a declarar `defaultSpan` e `spanRange`, por exemplo
  Tarefas `3...8`.
- `WidgetLayoutStore` guarda, além da ordem, o span escolhido para cada widget.
  A persistência muda de `[String]` para um array de
  `{ kind, span }` codificado em JSON.
- **Migração**: se o valor salvo for o `[String]` antigo, converter com os spans
  padrão. Nunca descartar o layout do usuário.
- `WidgetGridMetrics` calcula as larguras a partir do span salvo.
- A célula base passa de 140 pt para uma unidade menor (~56 pt), para permitir
  ajustes finos. Os spans atuais são convertidos para a mesma largura visual.

### Critérios de aceite

- Mudar a largura reflete no notch e no preview na hora.
- Um layout salvo no formato antigo abre sem perder widgets.

## F3 — Satélite flutuante

### Objetivo

Um círculo pequeno, fora do notch e ao lado dele, que mostra um estado em
andamento (primeiro uso: o tempo restante do Pomodoro). Precisa servir para
outros usos no futuro, como agentes rodando ou gravação de tela.

### Comportamento esperado

- Círculo de ~28 pt ancorado à direita (ou à esquerda) do notch, na mesma tela,
  com um pequeno espaço entre os dois.
- Mostra conteúdo compacto: anel de progresso e texto curto ("12:30").
- Hover: cresce um pouco e pode mostrar uma dica. Clique: executa a ação do
  satélite, por exemplo abrir o notch no widget do Pomodoro.
- Vários satélites ao mesmo tempo ficam empilhados lado a lado, em ordem de
  prioridade.
- Aparece e some com animação de mola, "saindo" do notch.

### Design técnico

- `SatelliteCenter` (`@Observable`, em `AppServices`) guarda os satélites
  ativos: `[Satellite]`.
- `Satellite`: `id`, `priority`, `anchor` (`.trailing`/`.leading`), uma view
  compacta (closure `() -> AnyView` ou um enum fechado `SatelliteKind`) e uma
  ação de clique.
  - Recomendação: um enum fechado `SatelliteKind`, como o `LiveActivityCenter`.
    Menos abstração, e o compilador cobra os casos novos.
- Janela: um `NSPanel` não ativante por tela, ao lado da janela do notch, com
  `level = .statusBar` e o mesmo `collectionBehavior`. Ela ignora o mouse fora
  do círculo, com a mesma estratégia de regiões do `NotchController`.
- Posição: calculada a partir de `NotchGeometry` e de `closedDisplaySize`, para
  acompanhar quando uma Live Activity alarga o notch.
- O satélite fica numa janela separada, e não dentro da janela do notch, para
  não alterar a área de hover nem o recorte do notch.

### Critérios de aceite

- Iniciar o Pomodoro faz o círculo aparecer ao lado do notch em todas as telas
  ativas. Pausar mostra o estado pausado; terminar o remove.
- O círculo nunca bloqueia cliques na barra de menus fora dele.

### Perguntas em aberto

- O satélite aparece em todas as telas ou só na tela principal?
- Ele pode ser arrastado pelo usuário para outra posição?

## F4 — Central de permissões

### Objetivo

Hoje cada permissão é pedida no momento do uso, sem um lugar para ver o estado
de todas. O HUD e os gestos adicionam Acessibilidade e talvez Monitoramento de
Entrada.

### Comportamento esperado

Página **Permissões** com uma linha por permissão: ícone, para que serve, estado
(concedida, negada, não pedida) e um botão (**Permitir** ou **Abrir Ajustes do
Sistema**).

| Permissão | Usada por | Como checar |
| --- | --- | --- |
| Acessibilidade | HUD (event tap), gestos de teclado | `AXIsProcessTrusted()` |
| Bluetooth | Atividade de Bluetooth | `CBManager.authorization` |
| Calendário | Widget e lembretes | `EKEventStore.authorizationStatus` |
| Automação (Spotify/Music) | Capa, controles | Tentativa com `AEDeterminePermissionToAutomateTarget` |
| Gravação de áudio do sistema | Visualizador com áudio real | Estado da última tentativa de tap |

### Design técnico

- `PermissionsCenter` (`@Observable`) com um `PermissionStatus` por tipo,
  reavaliado quando o app volta a ficar ativo
  (`NSApplication.didBecomeActiveNotification`).
- Cada fonte de dados continua dona do seu pedido de permissão. A central só lê
  o estado e oferece o atalho para os Ajustes do Sistema.
