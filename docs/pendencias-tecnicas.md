# Pendências técnicas

Itens registrados para acompanhamento. Nenhum bloqueia o Pull Request do Marco 1.

| # | Pendência | Origem | Impacto | Onde tratar |
|---|---|---|---|---|
| 1 | **Esquiva: fluidez corrigida e aprovada pelo PO em reteste.** O PO relatou travada ao fim da esquiva; corrigido em `fix: preserve movement flow after dash` (ADR 0002, "Revisão"). Confirmado pelo PO jogando | Playtest humano do PO | Média: é a mecânica central do Marco 3 | Guia: `playtest/marco-1-teste-esquiva.md`. Ajuste de valores em `game/data/player_tuning.tres` |
| 2 | **Pico de ~61 ms** (um quadro) ao alternar para os enquadramentos exploração e chefe. Custo no script: 0,001 ms, logo é trabalho de render. Causa não isolada | Playtest scriptado | Baixa agora, relevante no combate | Marco 2: capturar com o profiler do Godot e testar variantes de shader e sombra |
| 3 | **Pequena irregularidade na emenda da rampa com a plataforma** (altura máxima registrada 4,10 m para uma plataforma de 4,00 m) | Playtest scriptado e PO | Baixa | Marco 2: refazer a geometria da emenda ao construir a arena final |
| 4 | **Gamepad físico não validado.** Só eventos simulados foram testados | Falta de controle na máquina | Média | Checklist de gamepad em `playtest/marco-1-checklist.md`, quando houver controle |
| 5 | **FPS limitado a ~117 por fator externo não identificado.** Uma cena vazia do Godot também dá 117,5 FPS, com VSync ligado e desligado | Sonda de FPS | Impede medir o teto de desempenho | Marco 2: investigar (perfil de energia, configuração de limite de FPS do driver, janela vs. tela cheia exclusiva, monitor) antes das medições de FPS |

## Pendências abertas pelo H1

| # | Pendência | Impacto | Onde tratar |
|---|---|---|---|
| 6 | **IK de pés ausente.** Em rampa de 21° o tornozelo fica ~8 cm mais baixo no apoio (sola atravessa ~4 a 5 cm). `TwoBoneIK3D` do Godot 4.7.2 não moveu os ossos na nossa configuração | Baixa/média | H2: solver analítico próprio ou investigar o requisito do `TwoBoneIK3D` |
| 7 | **Custo do pipeline de modificadores do esqueleto:** ~1,4 ms por personagem (medido; o script do modificador custa ~36 µs). Não escala para muitos inimigos | Média | H2: modificadores só no jogador; inimigos só com `AnimationTree` |
| 8 | **Sem clipes de partida, parada e giro** (não existem no pacote Standard); deslize residual dos pés (0,57 m/s médio) | Média: é o ponto principal da "naturalidade" | H2: clipes autorais no Blender ou pacote com transições |
| 9 | **Intermitência no playtest em janela: não reproduzida.** No H1, 2 de 5 execuções travaram ao trocar de enquadramento. No H1.1: 17 execuções seguidas sem travar (13 isoladas, 3 com testes headless rodando em paralelo, 1 com o vigia novo). Hipótese mais provável: concorrência com outras instâncias do Godot durante a sessão do H1 (não confirmada). O playtest agora tem um vigia (20 s sem quadros: registra trecho e quadro e encerra), então um travamento futuro gera diagnóstico. Dados em `docs/h1-1/` | Baixa | Reabrir se o vigia disparar |
