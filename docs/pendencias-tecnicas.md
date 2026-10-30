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

## Pendências abertas pelo H2 (combate de katana)

| # | Pendência | Impacto | Onde tratar |
|---|---|---|---|
| 10 | **Combo de 3 golpes autorais completo** (Kesa, Kiriage, Tsuki), aguardando a aprovação do Tsuki. Sem clipe do pacote no combo | Resolvida na implementação; depende do playtest | Playtest do PO |
| 11 | **Pés escorregam no avanço dos golpes:** o clipe é no lugar e o avanço vem da cápsula (0,9 m nos golpes 1 e 2, 1,5 m no final) | Média | H2.1: sincronizar o avanço com os apoios ou usar clipes com deslocamento (root motion) |
| 12 | **Pico de quadro de ~26 ms** (1 por execução em 2 de 4 execuções do playtest de combate) | Baixa | Perfilar com o profiler do Godot; suspeita de primeira compilação de pipeline |
| 13 | **Katana procedural presa ao punho** sem ajuste fino de empunhadura por golpe; o clipe foi feito para outra arma | Média | H2.1 |
| 14 | **Sons e efeitos provisórios** (sintetizados / primitivos) | Baixa | Marco de som e VFX |
| 15 | **Alvo único sem IA e sem fim de vida:** só registra dano; sem morte | Esperado | Marco de inimigos |
| 16 | **Desempenho medido com o Phantom Blade Zero aberto** (H2.2): FPS 129 a 144, p99 22 a 27 ms, não comparável com o H2/H2.1 | Baixa | Repetir `tools\playtest.ps1` com o jogo de referência fechado |
| 17 | **Execução de playtest em janela terminou sem gravar resultados** (1 de 4 no H2.3), sem estourar o tempo e sem causa conhecida; repetida, concluiu. Execuções em janela também já travaram em H1 e em capturas (HUD/painéis) | Baixa | Usar `tools\run_with_timeout.ps1` (encerra só o PID iniciado); investigar com o vigia do playtest |
| 18 | **Desempenho do H2.3 medido com o Phantom Blade Zero aberto** | Baixa | Repetir `tools\playtest.ps1` com o jogo de referência fechado |

## Pendências abertas pelo C1 (parry)

| # | Pendência | Impacto | Onde tratar |
|---|---|---|---|
| 19 | **Lâmina e sinal do Instrutor pequenos na câmera alta** (a preparação em âmbar é legível) | Média | Depois do playtest do PO: aumentar a lâmina ou o brilho só no Instrutor |
| 20 | **Sem animação de deflexão no parry** (pose de guarda estática) | Média | C1.x: clipe autoral curto de deflexão |
| 21 | **Desempenho do C1 medido com o Phantom Blade Zero aberto** | Baixa | Repetir com o jogo fechado |
| 22 | **Postura, Energia Neural e contra-ataque são só contadores** | Esperado | C2 / C3 |

## Pendências abertas pelo C1.1

| # | Pendência | Impacto | Onde tratar |
|---|---|---|---|
| 23 | **Deflexão e contra-corte por IK, sem captura de movimento** (ombros e punhos pouco sutis) e **um só contra-corte**, sem variação pela direção do golpe inimigo | Média | Refino depois do playtest do PO |
| 24 | **Abertura sinalizada só pelo visor branco do Instrutor** (pequeno na câmera alta) e pelo HUD | Média | Depois do playtest: avaliar indicador maior |
| 25 | **Segunda execução seguida do playtest em janela às vezes termina sem gravar resultados** (3 casos, nenhum estouro de tempo; repetida sozinha, funciona) | Baixa | Investigar com o vigia do playtest; ver pendência 17 |
