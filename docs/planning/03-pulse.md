# 3 — Pulse (dados do sistema)

## Objetivo

Widget que mostra o uso do Mac: CPU, RAM, GPU, disco, bateria e rede.

## Referência

- Widget "Pulse" (4 células) no estilo **Anéis**: grade 3×2 de anéis
  coloridos com ícone e valor (CPU 28%, RAM 78%, GPU 59%, Disco 59%, Bateria
  100%, Rede ↓16K ↑83K).
- No Nook aparece outro estilo, **Gráficos**: cartões com valor (CPU 15%,
  RAM 71%) e um gráfico do histórico (linha para CPU, área para RAM).
- Ajustes: Estilo (Anéis/…), um toggle por métrica (CPU, RAM, GPU, Disco,
  Bateria, Rede), Explicar ao passar o ponteiro, Atualizar a cada (2 s).

## Comportamento esperado

- Cada métrica ligada aparece como um anel (ou cartão com gráfico) com uma cor
  fixa por métrica.
- Rede mostra download e upload por segundo em unidades curtas (K, M).
- Hover sobre uma métrica (se ligado): dica com o detalhe, por exemplo
  "RAM: 12,4 de 16 GB · pressão normal".
- As leituras só rodam com o widget visível (notch aberto ou preview de
  ajustes). O histórico guarda os últimos ~60 pontos para os gráficos.

## Configurações

| Chave | Padrão |
| --- | --- |
| `pulse.style` | `rings` (`rings` / `graphs`) |
| `pulse.metrics` | todas |
| `pulse.explainsOnHover` | true |
| `pulse.interval` | 2 s (1 / 2 / 5) |

## Design técnico

Leitores, todos com APIs públicas:

| Métrica | Fonte | Cálculo |
| --- | --- | --- |
| CPU | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Diferença de ticks entre amostras: (user+system+nice)/total |
| RAM | `host_statistics64(HOST_VM_INFO64)` + `ProcessInfo.physicalMemory` | (active + wired + compressed) × page size / total |
| GPU | IORegistry: serviço `IOAccelerator`, dicionário `PerformanceStatistics`, chave `"Device Utilization %"` | Valor direto, 0–100 |
| Disco | `URLResourceValues` do volume de boot: `volumeTotalCapacity`, `volumeAvailableCapacityForImportantUsage` | 1 − disponível/total |
| Bateria | `BatteryMonitor` existente | `reading.level` |
| Rede | `getifaddrs` + `if_data` (`ifi_ibytes`, `ifi_obytes`) nas interfaces `en*` ativas | Diferença de bytes / intervalo |

- `PulseSampler` (`@Observable`): um `Task` com `Task.sleep(for: interval)`,
  ativado e desativado pela visibilidade
  (`onAppear`/`onDisappear` do widget com contagem de observadores, para
  cobrir notch e preview ao mesmo tempo).
- Cada leitor é uma função pura que recebe a amostra anterior e devolve
  `(valor, novaAmostra)`. Assim dá para testar sem o sistema.
- Erro de leitura (ex.: GPU sem `PerformanceStatistics` em alguma máquina):
  a métrica mostra "—" com a explicação na dica. Nunca mostra 0% como se
  fosse leitura válida.

## Permissões e riscos

- Sem permissões.
- A chave de GPU não é um contrato documentado; pode mudar entre versões do
  macOS. Por isso ela tem o estado "indisponível" explícito.

## Critérios de aceite

- Com o notch fechado, nenhum leitor roda (verificável com o Instruments).
- Rodar uma compilação pesada eleva o anel de CPU em até um intervalo.
- Desligar uma métrica a remove do widget e reorganiza a grade.

## Perguntas em aberto

- Além de Anéis e Gráficos, há outros estilos desejados?
