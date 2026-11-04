# 2 — Comportamento

## Objetivo

Configurar como o notch abre, o que acontece enquanto o usuário digita, a
resposta tátil e os gestos de trackpad.

## Referência

Página "Comportamento":

- **Notch**: Sempre abrir ao passar o cursor; Resposta tátil.
- **Digitação**: Impedir fechar ao tirar o mouse; Bloquear enquanto digita.
- **Gestos**: Permitir gestos ao passar o mouse sobre o entalhe; Abrir e fechar
  com gestos verticais; Controlar as mídias com gestos horizontais; Inverter
  ações dos gestos de mídia.

## Comportamento esperado

| Opção | Ligada | Desligada |
| --- | --- | --- |
| Sempre abrir ao passar o cursor | Hover abre (hoje) | Hover só destaca; clique abre |
| Resposta tátil | Pulso no trackpad ao abrir/fechar e nas ações | Sem pulso |
| Impedir fechar ao tirar o mouse | Com um campo de texto em foco, o notch fica aberto (hoje fixo) | Fecha ao sair, mesmo digitando |
| Bloquear enquanto digita | O notch fica preso aberto até sair do campo (Esc ou clique fora) | — |
| Gestos sobre o entalhe | Rolagem no trackpad com o mouse sobre o notch vira gesto | Rolagem ignorada |
| Gestos verticais | Deslizar para baixo abre, para cima fecha | — |
| Gestos horizontais de mídia | Esquerda/direita = faixa anterior/próxima | — |
| Inverter gestos de mídia | Inverte esquerda/direita | — |

A diferença entre "Impedir fechar" e "Bloquear enquanto digita" precisa ser
confirmada (ver perguntas). A leitura deste plano: a primeira mantém aberto
enquanto o campo tem foco e o mouse está fora; a segunda também impede que um
novo hover ou gesto feche ou troque o notch durante a digitação.

## Configurações

| Chave | Padrão |
| --- | --- |
| `behavior.opensOnHover` | true |
| `behavior.haptics` | true |
| `behavior.keepsOpenWhileTyping` | true |
| `behavior.locksWhileTyping` | false |
| `behavior.gesturesEnabled` | true |
| `behavior.verticalGestures` | true |
| `behavior.horizontalMediaGestures` | true |
| `behavior.invertsMediaGestures` | false |

## Design técnico

- **`BehaviorSettings`** (`@Observable`, persistido como os outros ajustes) em
  `AppServices`.
- **Abertura por clique**: com `opensOnHover = false`, a região central do notch
  fechado aceita mouse (`ignoresMouseEvents = false`) enquanto o mouse está
  nela, e um clique chama `model.open()`. Hoje o `NotchController` só alterna
  `ignoresMouseEvents` ao abrir; passa a alternar por região, como já faz para
  os slots.
- **Resposta tátil**:
  `NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)`.
  Só funciona em trackpads com Force Touch; em outros dispositivos é ignorado
  sem erro.
- **Gestos**:
  - O monitor global já existente passa a escutar também `.scrollWheel`.
    Monitorar rolagem não exige Acessibilidade, como acontece com o movimento
    do mouse.
  - Considera só eventos de trackpad (`hasPreciseScrollingDeltas`) com o mouse
    sobre a área do notch.
  - `NotchGestureRecognizer` acumula `scrollingDeltaX/Y` entre `phase == .began`
    e `.ended`/`momentumPhase`, decide o eixo dominante e dispara uma vez ao
    passar de um limite (~40 pt), ignorando o momentum.
  - Ações: vertical → `open()`/`close()`; horizontal → `nowPlaying.send(.nextTrack/.previousTrack)`.
- **Digitação**: `NotchInteraction.isEditingText` (já existe) passa a respeitar
  `keepsOpenWhileTyping`; `locksWhileTyping` adiciona o bloqueio de gestos e
  hover enquanto há foco.

## Permissões e riscos

- Sem permissões novas.
- Monitores globais de rolagem recebem todos os eventos de rolagem do sistema.
  Filtrar cedo (área do notch + trackpad) mantém o custo baixo.

## Critérios de aceite

- Com "Sempre abrir ao passar o cursor" desligado, passar o mouse não abre, e
  clicar abre.
- Deslizar dois dedos para baixo sobre o notch fechado abre; para cima, fecha.
- Com música tocando, deslizar para a esquerda sobre o notch troca de faixa;
  com "Inverter" ligado, vai para a anterior.

## Perguntas em aberto

- Qual é a diferença exata esperada entre "Impedir fechar ao tirar o mouse" e
  "Bloquear enquanto digita"?
- Gestos horizontais só com música tocando, ou também para navegar entre
  páginas do Nook no futuro?
