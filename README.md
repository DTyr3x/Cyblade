# CYBLADE

> Nome provisório. Action roguelite 3D cyberpunk para PC Windows/Steam, single-player e offline.

**Estado:** Marco 1 (câmera e movimentação, com esquiva fluida) aprovado pelo PO e integrado à `main`. H1/H1.1 (locomoção humanoide) aprovados e integrados. Em avaliação pelo PO: **H2, combate de katana** (`docs/h2-combate-katana.md`): cadeia de 3 golpes, boneco de treino, acerto, hitstop e efeitos. Pendências técnicas: `docs/pendencias-tecnicas.md`.

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
| 0 | Fundação: projeto, estrutura, Git | Concluído |
| 1 | Câmera e movimentação | Concluído (aprovado pelo PO; PR #1 integrado) |
| H1 | Locomoção humanoide (esqueleto, AnimationTree, esquiva integrada), H1.1 refinamento | Aprovado pelo PO e integrado à `main` |
| H2 | Combate de katana (3 golpes, alvo de treino, acerto, efeitos) | Em avaliação pelo PO (PR aberto) |
| H2.1 | Pesquisa Phantom Blade Zero e golpe 1 autoral (Kesa avançado, Blender + IK) | Em avaliação pelo PO (PR #3) |
| H2.2 | Kiriage de retorno (2º golpe autoral, continuação do Kesa) | Aprovado pelo PO (8 de 8) |
| H2.3 | Tsuki de passo duplo (3º golpe autoral; combo Kesa → Kiriage → Tsuki) | Em avaliação pelo PO (PR #3) |
| C1.0 | Defesa e parry (Instrutor de treino, guarda, parry perfeito, falha de defesa) | Aprovado pelo PO (9 de 9; base protegida) |
| C1.1 | Deflexão autoral do parry e contra-ataque de oportunidade | Em avaliação pelo PO (branch `feat/c1-parry`, sem PR) |
| 2 | Direção gráfica | Planejado |
| 3 | Combate | Planejado |
| 4 | Forja de Combos | Planejado |
| 5 | Roguelite | Planejado |

## Como jogar o protótipo (Windows)

Dê dois cliques em `Jogar.bat` (ou rode `tools\run.ps1`). O script procura o Godot 4.7 na Área de Trabalho, em Downloads, em `C:\Godot` e no PATH; ou defina `CYBLADE_GODOT` com o caminho do `.exe`. `Jogar.bat -Editor` abre no editor.

| Ação | Teclado e mouse | Gamepad |
|---|---|---|
| Mover | WASD ou setas | Stick esquerdo |
| Esquiva | Espaço ou Shift | B |
| Girar câmera | Botão direito + mouse, ou Q/E | Stick direito |
| Centralizar câmera | R | R3 |
| Enquadramento | 1, 2, 3 ou Tab | ← → |
| HUD de depuração | F3 | Back |
| Sair | Esc | n/d |

**Esquiva:** toque **Espaço** (ou **Shift**) para deslocar ~4 m na direção em que você está se movendo (ou para onde o personagem está virado, se parado). Dura ~0,25 s mais ~0,18 s de recarga; durante a recarga você já pode correr (a esquiva só não pode ser repetida), e um toque nesse período fica guardado por 0,15 s e dispara ao terminar. Correndo, a esquiva termina na velocidade de corrida, sem freada. Como testar: `docs/playtest/marco-1-teste-esquiva.md`.

## Testes

- `tools\run_tests.ps1`: 133 verificações automatizadas, sem janela. Entradas simuladas.
- `tools\playtest.ps1`: playtest scriptado em janela, com FPS, esquivas medidas e capturas.
- Resultados e limitações: `docs/playtest/marco-1-resultados.md`. Checklist para teste humano: `docs/playtest/marco-1-checklist.md`.

## Como abrir no editor

1. Instale o Godot 4.7.2 (versão padrão, sem .NET).
2. Abra o Godot, escolha **Importar** e selecione o `project.godot` desta pasta.

## Desenvolvimento e transparência

- O jogo é desenvolvido do zero, sob direção do Product Owner (PO), com auxílio de ferramentas de IA (Claude Code; Codex previsto para testes e auditorias). O PO decide escopo, direção e validações.
- Decisões técnicas ficam em `docs/adr/`; testes de jogo em `docs/playtest/`.
- Animações e malha do humanoide provisório: Universal Animation Library, de Quaternius (CC0). Registro e licenças em `docs/ativos/registro.md`.
- Nenhum modelo, código, animação ou recurso de jogos de referência é usado. Jogos de referência servem apenas para estudo de sensação de gameplay.
- Fluxo Git: `main` estável; branches `feat/`, `fix/`, `test/`, `docs/` e `chore/`; integração por Pull Request.

## Licença

Projeto proprietário, por decisão do PO. Todos os direitos reservados. O código fica visível neste repositório como portfólio, mas não é licenciado para uso, cópia ou redistribuição.
