# 6 — HUD de volume e brilho

## Objetivo

Substituir o indicador do sistema de volume e brilho por um indicador no notch.

## Referência

Seção "Indicador ao vivo" com dois estilos em cards:

- **Clássico**: cresce abaixo do notch, com ícone, barra horizontal e
  porcentagem ("68%").
- **Embutido**: fica na linha do notch — à esquerda, ícone e nome ("Brilho");
  à direita, mini barra e o número ("68").

## Comportamento esperado

- Ao apertar as teclas de volume (incluindo mudo) ou de brilho, o indicador do
  NotchFull aparece no lugar do indicador do sistema, mostra o novo valor e some
  após ~1,5 s sem novas teclas.
- Ícone muda conforme o nível (alto-falante 0–3 ondas; mudo cortado).
- ⌥⇧ + tecla ajusta em passos finos (1/4 de passo), como no sistema.
- Volume mostra o dispositivo de saída quando não for o alto-falante interno
  (ex.: AirPods).
- O HUD é uma Live Activity de evento, com prioridade sobre as outras enquanto
  visível.

## Configurações

| Chave | Padrão |
| --- | --- |
| `hud.replacesVolume` | false (pede permissão ao ligar) |
| `hud.replacesBrightness` | false |
| `hud.style` | `embedded` (`classic` / `embedded`) |

## Design técnico

- **Interceptar as teclas**: `CGEvent.tapCreate` (`.cgSessionEventTap`,
  `.headInsertEventTap`) para eventos `NX_SYSDEFINED` subtipo 8 (teclas de
  mídia). Os códigos são `NX_KEYTYPE_SOUND_UP/DOWN`, `NX_KEYTYPE_MUTE`,
  `NX_KEYTYPE_BRIGHTNESS_UP/DOWN`.
  - Para esconder o HUD do sistema, o tap **consome** o evento (devolve `nil`) e
    o NotchFull aplica a mudança ele mesmo.
  - O tap precisa da permissão de **Acessibilidade**. Sem ela, a opção fica
    desligada e a página explica o motivo (F4).
  - Se o tap for desativado pelo sistema (`tapDisabledByTimeout`), reativar.
    Se o app travar com o tap ativo, as teclas ficam sem efeito até o tap
    morrer: o callback precisa ser mínimo e nunca bloquear.
- **Aplicar volume** (API pública): no dispositivo de saída padrão,
  `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` (0...1) e
  `kAudioDevicePropertyMute`, via `AudioObjectSetPropertyData`. Passo de 1/16,
  igual ao do sistema.
- **Aplicar brilho**: **não existe API pública** para o brilho da tela
  integrada em Apple Silicon. Opções:
  1. `DisplayServicesGetBrightness/SetBrightness` (framework privado
     DisplayServices). É o que apps desse tipo usam, mas viola a regra de não
     usar APIs privadas.
  2. Não substituir o brilho: só o volume é substituído, e as teclas de brilho
     seguem para o sistema.
- **Ouvir sem substituir** (alternativa sem permissão): um listener de
  propriedade do Core Audio
  (`AudioObjectAddPropertyListenerBlock` no volume) detecta mudanças de volume
  e mostra o HUD do NotchFull **junto** com o do sistema. Não pede
  Acessibilidade, mas não esconde o indicador do sistema.
- Estrutura: `MediaKeyTap` (dono do tap e do ciclo de vida), `VolumeController`
  e `BrightnessController` (aplicar e ler), `HUDActivity` como novo caso de
  `LiveActivityCenter.Activity`.

## Permissões e riscos

- **Acessibilidade** é sensível: o usuário concede ao app o poder de observar e
  alterar eventos de entrada. A página de ajustes precisa explicar o motivo.
- O brilho depende da decisão sobre API privada (ver acima).
- Monitores externos: brilho via DDC fica fora do escopo.

## Critérios de aceite

- Com a substituição de volume ligada e Acessibilidade concedida, as teclas de
  volume mudam o volume e só o HUD do NotchFull aparece.
- Sem Acessibilidade, as teclas funcionam como antes (nada é consumido).
- Desligar a opção devolve o comportamento do sistema na hora, sem reiniciar.

## Perguntas em aberto

- **Brilho**: aceitar a API privada DisplayServices, ou substituir só o volume?
- Vale ter o modo "ouvir sem substituir" como padrão sem permissão?
