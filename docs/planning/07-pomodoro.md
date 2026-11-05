# 7 — Pomodoro e o círculo flutuante

> **Status: feito.** Decisões: a pausa começa sozinha ao fim do foco e o
> próximo foco espera um clique; sem pausa longa; a chuva é **sintetizada** em
> tempo real (ruído marrom + chiado + gotas), sem arquivo de áudio nem licença;
> o sino usa sons do sistema. A régua aceita só arrasto (rolagem lateral exigia
> interceptar eventos por baixo do SwiftUI). Notificações do sistema ficaram de
> fora.

## Objetivo

Um timer de foco e pausa no Nook, com indicação contínua do tempo restante fora
do notch, num círculo flutuante (o satélite da [fundação F3](00-fundacoes.md#f3--satélite-flutuante)).

## Referência

- Widget "Pomodoro" (6 células):
  - Seletor **Focus / Break** no topo.
  - **Régua** de minutos (15, 20, 25, 30, 35…) com marcador no valor escolhido.
  - Botões: play, som (ambiente), cronômetro.
  - Tempo grande em laranja ("25:00").
- Ajustes: Foco (10 min), Pausa (5 min), Mostrar no notch durante a execução,
  Sino (som, ex.: "Nítido", com botão de pré-escuta), Tocar sino, Chuva durante
  as pausas.
- Quando ativo: um **círculo flutuante ao lado do notch, fora dele**, com o
  tempo restante.

## Comportamento esperado

- Escolher a duração arrastando ou rolando a régua (passo de 1 min). Os
  extremos vêm dos ajustes (ex.: 5–60).
- Play inicia a fase atual; o mesmo botão pausa e retoma.
- Fim do foco: toca o sino (se ligado), passa para a pausa e pode iniciá-la
  automaticamente (ver perguntas).
- **Modo cronômetro**: conta para cima, sem fim.
- **Chuva durante as pausas**: som ambiente em loop enquanto a pausa roda.
- **Durante a execução**:
  - **Satélite**: círculo com anel de progresso e o tempo ("12:30"); clicar abre
    o notch no Pomodoro.
  - **No notch** (se ligado): uma Live Activity contínua com ícone de timer e o
    tempo restante.
- O timer sobrevive a fechar e reabrir o app: o estado é salvo com o horário de
  término, não com uma contagem.
- Iniciado a partir de uma tarefa ([Tarefas](05-tarefas.md)), usa a duração da
  tarefa e mostra o título dela no satélite (dica) e no widget.

## Configurações

| Chave | Padrão |
| --- | --- |
| `pomodoro.focusMinutes` | 25 (1...120) |
| `pomodoro.breakMinutes` | 5 (1...60) |
| `pomodoro.showsInNotch` | true |
| `pomodoro.showsSatellite` | true |
| `pomodoro.chimeSound` | um dos sons do sistema |
| `pomodoro.playsChime` | true |
| `pomodoro.rainDuringBreaks` | false |
| `pomodoro.autoStartsBreak` | true |

## Design técnico

- **`PomodoroTimer`** (`@Observable`):
  - `phase` (`.focus`/`.break`), `state` (`.idle`, `.running(endDate)`,
    `.paused(remaining)`), `isStopwatch`, `taskID: UUID?`.
  - O tempo restante é **derivado**: `endDate - now`. Nada de decrementar a cada
    segundo; as views usam `TimelineView(.periodic(by: 1))`.
  - Fim da fase: um único `Task.sleep(until: endDate)`, cancelado ao pausar.
  - Persistência: o estado inteiro é salvo em `UserDefaults` a cada transição.
    Ao abrir o app, um `running` com `endDate` no passado vira "terminou
    enquanto fechado" (toca o sino uma vez e avança a fase).
- **Régua**: `Canvas` com as marcas, mais `DragGesture` e `onScrollWheel`,
  convertidos em minutos com snap. Resposta tátil a cada minuto (se ligada em
  [Comportamento](02-comportamento.md)).
- **Sino**: os sons do sistema em `/System/Library/Sounds` (`NSSound(named:)`)
  dispensam assets próprios. A pré-escuta usa o mesmo caminho.
- **Chuva**: precisa de um áudio de chuva em loop com licença livre, tocado com
  `AVAudioPlayer` (`numberOfLoops = -1`) e fade de entrada e saída.
- **Integrações**:
  - `LiveActivityCenter.Activity.pomodoro`: contínua, prioridade abaixo dos
    eventos curtos e acima da música.
  - `SatelliteCenter` (F3): o satélite é registrado enquanto o timer está em
    `running` ou `paused`.
- **Notificação ao terminar** com o app em segundo plano: opcional, via
  `UNUserNotificationCenter` (pede permissão de notificações).

## Permissões e riscos

- Sem permissões obrigatórias; notificações são opcionais.
- O áudio de chuva é um asset novo: precisa de fonte com licença compatível com
  a distribuição pública do app.

## Critérios de aceite

- Iniciar 25 min, fechar o app e reabrir 5 min depois mostra ~20 min restantes.
- O satélite aparece ao iniciar, mostra o tempo atualizado a cada segundo e
  some ao terminar ou resetar.
- Com o sino ligado, o fim do foco toca o som escolhido uma vez.

## Perguntas em aberto

- A pausa começa automaticamente ao fim do foco, ou espera um clique?
- Ciclos longos (pausa maior a cada 4 focos) entram no escopo?
- Origem do som de chuva: gravar ou usar um áudio de licença livre (CC0)?
