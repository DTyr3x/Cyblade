# CYBLADE

> Nome provisório. Action roguelite 3D cyberpunk para PC Windows/Steam, single-player e offline.

**Estado:** Marco 0 (fundação). Ainda não há jogo executável.

## Visão

Um ninja com katana enfrenta robôs numa megacidade industrial, com qualidade visual cinematográfica e combate técnico baseado em habilidade. O diferencial planejado é a **Forja de Combos**: o jogador monta rotas de combo com cartas, memoriza as sequências e as executa manualmente.

## Tecnologia

- **Engine:** Godot 4.7.2, renderizador Forward+
- **Linguagem:** GDScript
- **Controles:** teclado/mouse e gamepad, ambos remapeáveis
- **Plataforma:** Windows (Steam)

## Marcos

| Marco | Escopo | Estado |
|---|---|---|
| 0 | Fundação: projeto, estrutura, Git | Em andamento |
| 1 | Câmera e movimentação | Planejado |
| 2 | Direção gráfica | Planejado |
| 3 | Combate | Planejado |
| 4 | Forja de Combos | Planejado |
| 5 | Roguelite | Planejado |

## Como abrir

1. Instale o Godot 4.7.2 (versão padrão, sem .NET).
2. Abra o Godot, escolha **Importar** e selecione o `project.godot` desta pasta.

## Desenvolvimento e transparência

- O jogo é desenvolvido do zero, sob direção do Product Owner (PO), com auxílio de ferramentas de IA (Claude Code; Codex previsto para testes e auditorias). O PO decide escopo, direção e validações.
- Decisões técnicas ficam em `docs/adr/`; testes de jogo em `docs/playtest/`.
- Nenhum modelo, código, animação ou recurso de jogos de referência é usado. Jogos de referência servem apenas para estudo de sensação de gameplay.
- Fluxo Git: `main` estável; branches `feat/`, `fix/`, `test/`, `docs/` e `chore/`; integração por Pull Request.

## Licença

A definir pelo PO.
