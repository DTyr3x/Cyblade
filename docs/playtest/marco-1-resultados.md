# Marco 1: resultados dos testes (28/10/2026)

Branch `feat/marco-1-camera-movimento`. Godot 4.7.2 stable, Forward+ (Vulkan 1.4), RTX 5070 Ti, Ryzen 7 9800X3D, janela 1920×1080.

**Limite importante:** toda a entrada deste documento foi **simulada por script** (eventos de teclado e de gamepad). Não há controle físico conectado nesta máquina e nenhum humano jogou ainda. O que está medido é lógica, estabilidade e desempenho. A sensação de jogo depende do checklist humano (`marco-1-checklist.md`).

## 0. Playtest humano do PO (informado pelo PO)

Primeiro playtest humano, teclado/mouse. Resultado informado: **8 critérios positivos, nenhum negativo, 1 não avaliado.**

| Critério | Resultado |
|---|---|
| Movimentação confortável | Aprovado |
| Aceleração e frenagem naturais | Aprovado |
| Mudança de direção responsiva | Aprovado |
| Câmera acompanhando corretamente | Aprovado |
| Rotação pelo mouse confortável | Aprovado |
| Câmera mantém o personagem visível nos obstáculos | Aprovado |
| Rampa e plataforma funcionando | Aprovado |
| Ausência de travamentos perceptíveis | Aprovado |
| Sensação e responsividade da esquiva | **Pendente** (não avaliado) |

**Decisão do PO:** Marco 1 aprovado tecnicamente, com pendência de validação humana da esquiva. Guia para fechar a pendência: `marco-1-teste-esquiva.md`.

### Observação do PO sobre a esquiva (segundo playtest)

O PO testou a esquiva e relatou: **ao terminar, o personagem desacelera ou trava antes de voltar a correr**, o que quebra a fluidez. A causa e a correção estão no ADR 0002 (seção "Revisão"). Resultado automatizado após a correção: **95 verificações, 0 falhas**, incluindo 23 novas de fluidez. **O PO jogou de novo e confirmou: a transição está fluida (aprovado).**

Observação: o relato do PO é qualitativo. Ele não substitui as medições abaixo e não valida o gamepad físico.

## 1. Testes automatizados (sem janela)

Comando: `tools\run_tests.ps1` (equivale a `godot --headless --fixed-fps 120 -s res://tests/run_tests.gd`).
Resultado: **95 verificações, 0 falhas** (código de saída 0; eram 72 antes da correção da esquiva). Com `--fixed-fps 120` cada quadro vale exatamente 1 tick de física, então os tempos são determinísticos (resolução de 8,3 ms).

| Área | O que foi verificado | Resultado |
|---|---|---|
| Aceleração | Tempo até 6 m/s | 0,125 s (alvo 0,12 s) |
| Frenagem | Tempo até parar | 0,083 s (alvo 0,08 s) |
| Inversão de sentido | 180° em velocidade máxima | 0,20 s |
| Esquiva (distância) | Soma do perfil de velocidade | 4,000 m exato |
| Esquiva (cena) | Duração do deslocamento / recuperação / distância | 0,250 s / 0,175 s / 4,00 m |
| Invulnerabilidade | Janela configurada (design nosso) | 0,15 s dentro do deslocamento |
| Buffer de esquiva | Pedido no meio da recuperação dispara ao terminar | OK |
| Teclado simulado | WASD e setas, velocidade de cruzeiro, parada em 0,15 s | 6,00 m/s, para sem deslizar |
| Gamepad simulado | Stick esquerdo, zona morta de 20%, botão B | OK (analógico: 50% do stick = 37,5% da velocidade, por reescala da zona morta) |
| Mapa de entrada | Cada ação com tecla e, quando aplicável, botão/eixo de gamepad | 20 de 20 |
| Câmera | Inclinação 45,0°, FOV 34,0°, jogador a 10,0% da altura da tela | OK |
| Câmera | Atraso em movimento (≈0,23 m), recentraliza em 1,5 s | OK |
| Câmera | Preset chefe: 20°, 26 m, jogador a 83% da altura da tela | OK |
| Giro da câmera | Stick direito 140°/s | −70,0° em 0,5 s |
| Movimento relativo à câmera | Câmera girada 90° muda a direção de "frente" | OK |
| Rampa | Sobe de 0 a 4 m e desce de volta | 4,00 m / 0,00 m |

## 2. Playtest scriptado em janela (GPU real)

Comando: `tools\playtest.ps1`. Executa 8 trechos de jogo com entrada simulada (~50 s), 1920×1080, `--disable-vsync`, após um aquecimento de 5 s que visita as áreas e os três enquadramentos. Resultados brutos em `marco-1/m1_playtest_resultados.json`.

| Trecho | Quadros | FPS médio | Quadro p99 | 1% baixo | Render GPU médio / máx | Render CPU médio / máx |
|---|---|---|---|---|---|---|
| Andar (teclado) | 460 | 117,0 | 8,72 ms | 114,6 | 0,41 / 0,75 ms | 0,18 / 0,37 ms |
| Círculo (teclado) | 947 | 117,0 | 8,71 ms | 114,9 | 0,41 / 1,36 ms | 0,19 / 0,42 ms |
| Esquivas | 832 | 117,0 | 8,73 ms | 114,6 | 0,42 / 0,87 ms | 0,19 / 0,35 ms |
| Gamepad (simulado) | 492 | 117,0 | 8,83 ms | 113,2 | 0,42 / 0,84 ms | 0,18 / 0,38 ms |
| Rampa e plataforma | 678 | 117,0 | 8,73 ms | 114,6 | 0,44 / 0,92 ms | 0,16 / 0,39 ms |
| Câmera combate | 467 | 117,0 | 8,76 ms | 114,2 | 0,42 / 1,03 ms | 0,17 / 0,40 ms |
| Câmera exploração | 461 | 115,6 | 8,88 ms | 112,6 | 0,41 / 1,16 ms | 0,18 / 0,51 ms |
| Câmera chefe | 461 | 115,6 | 8,87 ms | 112,8 | 0,42 / 0,83 ms | 0,20 / 0,44 ms |

**Como ler estes números**

- **O FPS de ~117 é um teto externo ao jogo, não a capacidade da máquina.** Uma cena vazia do Godot, medida à parte na mesma máquina e janela, também dá exatamente 117,5 FPS, com VSync ligado e desligado. A origem do limite (driver, Windows ou configuração da GPU) não foi investigada. O custo real de render é o das colunas GPU e CPU: **~0,4 ms de GPU e ~0,2 ms de CPU por quadro**, ou seja, folga enorme nesta arena simples. Esses valores são do render do Godot e não incluem a lógica de jogo.
- Isto foi medido em 1920×1080, uma arena com geometria simples, poucas luzes e sem os efeitos do Marco 2. **Não permite concluir nada sobre o desempenho da direção gráfica final.**
- Os quadros afetados pela gravação das capturas (salvar PNG de 1080p custa dezenas de ms) foram **excluídos** das estatísticas: 24 quadros no total, listados no JSON por trecho (`frames_excluded_for_captures`).
- **Um pico de ~61 ms** (um quadro) ocorreu no início dos trechos "câmera exploração" e "câmera chefe", logo depois da troca de enquadramento. O custo no script é de 0,001 ms, então é trabalho de render. A causa não foi isolada (hipótese não verificada: compilação de variantes de shader ou cascatas de sombra na primeira vez que o novo ângulo mostra certas áreas). Nos demais 6 trechos não houve nenhum quadro acima de 25 ms. **A investigar no Marco 2**, porque a transição de enquadramento será usada em combate.

### Esquivas medidas em jogo (4 execuções)

| Execução | Distância | Deslocamento | Total até recuperar o controle |
|---|---|---|---|
| 1 | 4,00 m | 0,248 s | 0,427 s |
| 2 | 4,00 m | 0,253 s | 0,432 s |
| 3 | 4,00 m | 0,248 s | 0,427 s |
| 4 | 4,00 m | 0,248 s | 0,427 s |

Consistente (variação de ±1 tick de física = 8,3 ms). Referência de Dinghai (pesquisa): deslocamento ~0,23–0,27 s e total ~0,43 s, com incerteza de ±33 a ±67 ms. A comparação é apenas de ordem de grandeza.

### Câmera

| Enquadramento | Inclinação / distância / FOV | Altura do jogador na tela |
|---|---|---|
| Combate (padrão) | 45° / 20 m / 34° | **10,0%** (referência de Dinghai: ~9–11%, estimado) |
| Exploração | 50° / 22 m / 36° | 7,8% |
| Chefe | 20° / 26 m / 34° | 11,5% |

## 3. Logs

Playtest completo: **0 linhas** com `ERROR`, `WARNING` ou `SCRIPT` no log do Godot. Testes automatizados: nenhum erro. O projeto abre no editor sem erros de parse (importação e execução com `--quit-after`).

## 4. Capturas (`marco-1/`)

| Arquivo | Conteúdo |
|---|---|
| `m1_01_andar.png` | Corrida com teclado simulado |
| `m1_02_circulo.png` | Movimento em círculo |
| `m1_03_esquiva.png` | Esquiva em andamento (estado DODGE, i-frames "sim", HUD) |
| `m1_04_gamepad.png` | Movimento com stick e giro da câmera, gamepad simulado |
| `m1_05_rampa.png` | Subindo a rampa de 21° |
| `m1_06_camera_combate.png`, `_exploracao.png`, `_chefe.png` | Os três enquadramentos |

## 5. Limitações conhecidas

1. Nenhum teste com humano nem com controle físico. O mapeamento de gamepad foi validado por eventos simulados (botões B, D-pad, Back, R3 e eixos).
2. O remapeamento pela interface do jogo não existe ainda. A tabela de associações está em `game/input/input_setup.gd`, pronta para isso.
3. A causa do teto de 117 FPS e do pico de 61 ms na troca de enquadramento não foi investigada.
4. Na rampa, a altura máxima registrada foi 4,10 m (a plataforma tem 4,00 m): há um pequeno salto na emenda entre a rampa e a plataforma. Não afeta o uso, mas vale acertar a geometria no Marco 2.
5. O ninja é provisório (primitivas). Sem animação de esqueleto, o "peso" visual da esquiva (agachamento, rastro) é só indicativo.
6. Parry, cancelamentos e ataques não existem ainda (Marco 3). A janela de i-frames da esquiva é escolha de design nossa, sem evidência de Dinghai.
