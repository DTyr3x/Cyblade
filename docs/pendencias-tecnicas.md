# Pendências técnicas

Itens registrados para acompanhamento. Nenhum bloqueia o Pull Request do Marco 1.

| # | Pendência | Origem | Impacto | Onde tratar |
|---|---|---|---|---|
| 1 | **Esquiva: correção de fluidez aguardando reteste do PO.** O PO relatou travada ao fim da esquiva; corrigido em `fix: preserve movement flow after dash` (ADR 0002, "Revisão"). Falta o PO confirmar jogando | Playtest humano do PO | Média: é a mecânica central do Marco 3 | Guia: `playtest/marco-1-teste-esquiva.md`. Ajuste de valores em `game/data/player_tuning.tres` |
| 2 | **Pico de ~61 ms** (um quadro) ao alternar para os enquadramentos exploração e chefe. Custo no script: 0,001 ms, logo é trabalho de render. Causa não isolada | Playtest scriptado | Baixa agora, relevante no combate | Marco 2: capturar com o profiler do Godot e testar variantes de shader e sombra |
| 3 | **Pequena irregularidade na emenda da rampa com a plataforma** (altura máxima registrada 4,10 m para uma plataforma de 4,00 m) | Playtest scriptado e PO | Baixa | Marco 2: refazer a geometria da emenda ao construir a arena final |
| 4 | **Gamepad físico não validado.** Só eventos simulados foram testados | Falta de controle na máquina | Média | Checklist de gamepad em `playtest/marco-1-checklist.md`, quando houver controle |
| 5 | **FPS limitado a ~117 por fator externo não identificado.** Uma cena vazia do Godot também dá 117,5 FPS, com VSync ligado e desligado | Sonda de FPS | Impede medir o teto de desempenho | Marco 2: investigar (perfil de energia, configuração de limite de FPS do driver, janela vs. tela cheia exclusiva, monitor) antes das medições de FPS |
