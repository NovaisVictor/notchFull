# Planejamento de features

Planos de desenvolvimento das próximas features do NotchFull. Nada aqui está
implementado. Cada plano tem objetivo, comportamento esperado, configurações,
design técnico, permissões e riscos, critérios de aceite e perguntas em aberto.

As referências visuais vêm de capturas do NotchNook Pro que o produto toma como
inspiração. A implementação é própria: os planos descrevem comportamento, não
código de terceiros.

## Planos

| # | Feature | Tamanho | Depende de |
| --- | --- | --- | --- |
| [F](00-fundacoes.md) | Fundações: shell de ajustes, células de widget, satélite flutuante, central de permissões (F1, F2 e F3 feitas) | G | — |
| [1](01-telas.md) | Telas: em quais telas aparece, tela cheia, manipulador em telas sem notch | M | F1 |
| [2](02-comportamento.md) | Comportamento: abertura, resposta tátil, digitação e gestos | M | F1 |
| [3](03-pulse.md) | Pulse: dados do sistema (CPU, RAM, GPU, disco, bateria, rede) — feito | M | F1, F2 |
| [4](04-notas.md) | Notas rápidas: texto rico, modo código, várias notas — feito | G | F1, F2 |
| [5](05-tarefas.md) | Tarefas: redesenho do widget, excluir, duração de foco, arquivamento | M | F1, F2 |
| [6](06-hud.md) | HUD de volume e brilho — feito (brilho via API privada DisplayServices, com carga dinâmica e fallback) | G | F1, F4 |
| [7](07-pomodoro.md) | Pomodoro e o círculo flutuante (satélite) — feito | G | F1, F2, F3 |

Tamanho: P (até 1 dia), M (2–4 dias), G (1 semana ou mais), considerando
implementação, testes e revisão.

## Ordem recomendada

1. **Fundações F1 e F2**: quase todo o resto precisa de páginas de ajuste por
   widget e de largura em células.
2. **Tarefas**: o widget atual tem defeitos visíveis (layout centralizado, sem
   forma óbvia de excluir).
3. **Telas**: corrige o uso só com monitor externo e já inclui as correções
   pendentes de tela principal e altura do notch simulado.
4. **Comportamento**.
5. **Pomodoro + satélite (F3)**: o satélite é reutilizável pela parte de agents.
6. **Pulse**.
7. **Notas rápidas**.
8. **HUD**: por último, porque depende de decisões sobre API privada e da
   permissão de Acessibilidade.

## Decisões em aberto (transversais)

- **Idioma da interface**: hoje a UI está em inglês e as referências estão em
  português. Localizar (pt-BR + en) antes de multiplicar telas de ajuste evita
  retrabalho.
- **APIs privadas**: evitadas por padrão; cada exceção é decisão explícita do
  usuário e fica isolada, com carga dinâmica e fallback. Exceção aprovada: o
  brilho do HUD (DisplayServices). O "manter acima da tela cheia" via SkyLight
  continua fora.
- **Dependências de terceiros**: nenhuma até agora; o destaque de sintaxe das
  notas é próprio e a chuva do Pomodoro é sintetizada.

## Pendências já conhecidas (fora destes planos)

- Commitar o "peek" da música (capa → nome e artista abaixo do notch).
- Binário universal (arm64 + x86_64) no workflow de release.
- Atualizar `actions/checkout` (aviso de Node 20) no workflow.
- Notarização (exige Apple Developer Program).
- Letra sincronizada no peek ou no widget de música (aparece na referência do
  HUD; não tem plano ainda).
