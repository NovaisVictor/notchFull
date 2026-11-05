# 4 — Notas rápidas

> **Status: feito.** Decisões: **sem dependência** — o modo código usa um
> destaque próprio por expressões regulares para Swift, JavaScript/TypeScript,
> Python, JSON e shell, com a linguagem detectada por palavras-chave e símbolos
> (texto monoespaçado sem cores quando nada se destaca). O modo código é
> **global para o widget**; uma nota editada nele perde a formatação e passa a
> ser salva como texto puro (`<id>.txt`), as ricas ficam em `<id>.rtfd`. As
> cores do destaque nunca vão para o arquivo. A troca de notas é um menu (não
> miniaturas), com nova nota, exportar (Markdown, texto ou RTF) e excluir com
> "Undo". A janela expandida mostra a nota atual; trocar de nota nela troca no
> widget também. Como o app não tem menu principal, o editor trata ⌘X/⌘C/⌘V/
> ⌘A/⌘Z/⇧⌘Z além de ⌘B/⌘I/⌘U. Imagens coladas não são aceitas.

## Objetivo

Widget de notas dentro do notch, com texto rico e um modo para código.

## Referência

- Widget "Notas" (5 células): área de texto com barra de formatação embaixo
  (cor, expandir, tamanho "A", **B**, *I*, U) e controles à direita (lista,
  indicador).
- Ajustes: Largura (5), Mostrar indicador de rolagem, Modo código.

## Comportamento esperado

- Clicar no widget põe o cursor no texto; o notch fica aberto enquanto há foco
  (já suportado por `NotchInteraction`).
- Formatação: negrito, itálico, sublinhado, tamanho, cor do texto. Atalhos
  ⌘B/⌘I/⌘U.
- **Várias notas**: miniaturas para trocar de nota e criar uma nova; a última
  aberta é lembrada.
- **Expandir**: abre a nota numa janela própria, maior, sincronizada com o
  widget.
- **Modo código**: fonte monoespaçada, sem formatação rica e com destaque de
  sintaxe pela linguagem detectada.
- Salvamento automático com pequeno atraso após parar de digitar.
- Exportar a nota (Markdown, RTF ou texto) pelo menu da nota.

## Configurações

| Chave | Padrão |
| --- | --- |
| `notes.span` | 5 (via F2) |
| `notes.showsScrollIndicator` | false |
| `notes.codeMode` | false |

## Design técnico

- **Editor**: `NSTextView` (TextKit 2) dentro de um `NSViewRepresentable`. O
  `TextEditor` do SwiftUI não oferece atributos ricos nem controle de seleção
  suficiente no macOS.
- **Modelo**: `Note` (`id`, `title` derivado da primeira linha, `content` como
  RTFD ou `AttributedString`, `isCode`, `language?`, `updatedAt`).
- **`NoteStore`**: um arquivo por nota em
  `Application Support/NotchFull/Notes/<id>.rtfd`, mais um `index.json`. Escrita
  atômica, como o `TodoStore`. Salvamento com debounce de ~500 ms.
- **Janela expandida**: `NSWindow` comum com o mesmo `NoteStore`; editar numa
  ponta reflete na outra pelo store observável.
- **Modo código**:
  - Detecção de linguagem por heurística (palavras-chave e símbolos por
    linguagem) ou pelo NaturalLanguage, que não reconhece código bem.
  - Destaque de sintaxe: opções em "Perguntas em aberto".

## Permissões e riscos

- Sem permissões.
- O destaque de sintaxe é o maior custo do plano. Sem uma dependência, só dá
  para um destaque simples por expressões regulares.

## Critérios de aceite

- Digitar, fechar o app e reabrir mantém a nota com a formatação.
- ⌘B aplica negrito na seleção.
- Em modo código, colar Swift mostra cores de palavras-chave e strings.

## Perguntas em aberto

- **Destaque de sintaxe**: usar uma biblioteca (ex.: Highlightr, baseada em
  highlight.js via JavaScriptCore; nova dependência) ou fazer um destaque
  simples próprio para poucas linguagens?
- O modo código é por nota ou global para o widget (a referência sugere global)?
