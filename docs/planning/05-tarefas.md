# 5 — Tarefas (redesenho)

## Objetivo

Corrigir e completar o widget de tarefas, que hoje tem defeitos visíveis.

## Problemas atuais (observados no app)

- A lista aparece **centralizada** no card, com um vão grande entre a lista e o
  botão "Add a task". Causa provável: o `WidgetCard` centraliza o conteúdo e o
  `ScrollView` não se expande para o topo e a esquerda.
- **Não há forma visível de excluir** uma tarefa: só existe o menu de contexto
  (clique secundário), que ninguém descobre.
- Tarefas concluídas ficam na lista para sempre.

## Referência

- Card "To-dos": título pequeno, linhas com círculo (laranja quando concluída),
  título (riscado e esmaecido quando concluída) e um **chip de duração** à
  direita ("45m", "15m", "25m"). Embaixo, o botão "+ Add a task".
- Ajustes (Tarefas, 5 células): Largura, Mostrar tarefas concluídas, Mostrar
  atividade, Arquivar tarefas concluídas automaticamente (7 dias).

## Comportamento esperado

- Lista alinhada ao topo e à esquerda, com rolagem quando passar da altura.
- **Excluir**: ao passar o mouse numa linha, aparece um "×" à direita (no lugar
  do chip). O menu de contexto continua existindo. Tecla Delete com a linha
  focada também exclui.
- **Duração de foco**: cada tarefa pode ter uma duração (chip). Clicar no chip
  inicia o Pomodoro com essa duração, ligado à tarefa (ver
  [Pomodoro](07-pomodoro.md)). Definir a duração: menu do chip com 15/25/45/60
  min ou campo livre.
- **Reordenar** arrastando as linhas.
- **Prioridade** (opcional, campo já previsto no modelo): marca visual na linha.
- **Mostrar tarefas concluídas**: desligado esconde as concluídas.
- **Arquivar automaticamente**: concluídas há mais de N dias saem da lista e
  vão para um arquivo, que pode ser visto nos ajustes.

## Configurações

| Chave | Padrão |
| --- | --- |
| `todos.span` | 5 (via F2) |
| `todos.showsCompleted` | true |
| `todos.showsActivity` | false |
| `todos.autoArchiveDays` | 7 (0 = nunca; 1...30) |

## Design técnico

- **Modelo** (`TodoItem`), campos novos com decodificação tolerante
  (`decodeIfPresent`), para os arquivos atuais continuarem abrindo:
  - `focusMinutes: Int?`
  - `isPriority: Bool`
  - `sortOrder: Double`, para reordenar sem reescrever todos os índices.
  - `completedAt: Date?`, necessário para o arquivamento.
  - `archivedAt: Date?`
- **`TodoStore`**:
  - `move`, `setFocusMinutes`, `archiveExpired(now:)`.
  - O arquivamento roda ao abrir o app e a cada mudança de dia
    (`NSCalendarDayChanged`).
  - O arquivo de dados continua sendo um único JSON com escrita atômica. Os
    arquivados ficam no mesmo arquivo, filtrados na leitura.
- **View**:
  - `TodoWidgetView` com `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)`
    no conteúdo.
  - `TodoRow` com `onHover` para trocar o chip pelo "×".
  - Reordenação com `onMove` num `List` estilizado ou com `draggable`.
- **Ligação com o Pomodoro**: `PomodoroTimer.start(minutes:taskID:)`. Ao
  terminar o foco, a linha mostra o tempo acumulado; marcar como concluída é
  manual.

## Critérios de aceite

- Com 2 tarefas, a lista fica no topo, sem vão.
- Passar o mouse numa linha mostra o "×"; clicar exclui sem confirmação, com
  "Desfazer" por alguns segundos.
- Tarefas concluídas há mais de 7 dias somem da lista no dia seguinte.
- O `todos.json` atual abre sem perder tarefas.

## Perguntas em aberto

- O que "Mostrar atividade" deve exibir? Hipóteses: o tempo de foco acumulado
  por tarefa, ou o Pomodoro em andamento dentro do card.
- Excluir pede confirmação ou só oferece "Desfazer"? O plano assume "Desfazer".
