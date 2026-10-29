# H2.2: Kiriage de retorno (segundo golpe autoral)

Status: **APROVADO PELO PO após playtest humano (8 de 8 critérios, sem ressalvas).** Ver "Aprovação do PO" no fim deste documento.
Branch `feat/h2-combate-katana` (PR #3, sem merge). O Kesa avançado, aprovado sem ressalvas, **não foi alterado** (clipe com o mesmo SHA-256, mesmos tempos e dados). O terceiro golpe continua o provisório do H2; o Tsuki definitivo não foi feito.

## 1. Aprovação do Kesa

Registrada em `docs/h2-1-combate-katana.md` ("Aprovação do PO") e no PR #3. Prova de que o Kesa não mudou: o teste `Kesa: clipe idêntico ao aprovado` compara o SHA-256 de `katana_kesa.res` (`2a7cb0b2da3d2a9360e6b951dabd394ffd8124f3bf592790a5f87d33d0ae8e45`), e o gerador do Blender foi refatorado sem mudar a saída (mesmo hash do JSON antes e depois).

## 2. O golpe: Kiriage de retorno

Corte diagonal ascendente, de baixo à esquerda para o alto à direita, com as duas mãos no cabo. Ele nasce da pose em que o Kesa está quando a janela de encadeamento abre (quadro 17).

| Fase | Quadros (60 Hz) | O que o corpo faz |
|---|---|---|
| Continuação | 0 a 4 | A lâmina segue subindo pelo centro (mesma direção do fim do Kesa); o quadril carrega o peso na perna da frente e gira um pouco mais para a esquerda |
| Preparação | 4 a 8 | O pé direito avança (okuri-ashi); o quadril desenrola para a direita; a lâmina cruza a frente |
| Contato | 8 a 13 | Corte ascendente; o ombro direito sobe; o peso passa para a perna da frente |
| Encadeia a partir de | 17 | A lâmina está alta à direita |
| Movimento livre a partir de / fim | 20 / 30 | Pé esquerdo desliza para a frente; termina em guarda média-alta à direita, lâmina para a frente e para cima, pronta para uma estocada (Tsuki futuro) |

Avanço de 0,6 m entre os quadros 2 e 12. Pés planejados no mundo: o direito dá o passo, o esquerdo desliza depois. Hitstop de 0,06 s. Esquiva cancela a partir do quadro 3 (0,05 s). Reação do alvo: leve para a direita (oposta à do Kesa).

**Identidade própria:** não é o Kesa espelhado nem invertido. O quadril, o tronco e os pés percorrem outro caminho (carga e abertura para a direita, passo da perna direita, deslizar da esquerda) e a lâmina sobe em vez de descer.

## 3. Continuidade Kesa → Kiriage

### Como a ligação é tratada

- **Pose final do Kesa = pose inicial do Kiriage.** O primeiro quadro do Kiriage é gerado a partir dos mesmos valores do Kesa no quadro 17 (`tools/blender/katana_kiriage_keys.py` começa todos os canais do Kesa: quadril, giro e inclinação do tronco, mãos, direção da lâmina e pés). O IK é o mesmo, então a pose sai idêntica.
- **Sem retorno ao repouso.** No `AnimationTree` o encadeamento troca de clipe **dentro do mesmo OneShot** (`seamless_chain`). O corpo não volta à locomoção entre os dois golpes; antes, cada encadeamento refazia a mistura com a corrida.
- **Empunhadura.** O nó da katana fica na pegada de duas mãos durante toda a troca (sem troca instantânea de empunhadura).
- **Encadeamento tardio** (aperto no fim da recuperação do Kesa): a troca é suavizada (0,03 s, até 0,12 s conforme o atraso), em vez de um corte seco.
- **Avanço e pés.** O avanço do Kiriage é subtraído do clipe como no Kesa: o pé da frente fica plantado no mundo enquanto a cápsula anda.
- **Buffer.** Corrigi um defeito do controlador: o hitstop gastava o tempo do aperto guardado (o buffer vence em 0,30 s e o acerto congela 0,06 s). Agora o buffer congela junto com o relógio do golpe. Só afeta quando há acerto, e deixa o encadeamento mais confiável. Não altera nenhum dado do Kesa.

### Comparação das poses de transição

`docs/h2-2/estudo/transicao_kesa_kiriage.png`: linhas 1 e 3 mostram o Kesa nos quadros 13, 15, 17, 19 e 21; linhas 2 e 4 mostram o Kiriage nos quadros 0, 2, 4, 6 e 8. O terceiro quadro do Kesa e o primeiro do Kiriage são a mesma pose, de frente e de lado. Medido nos testes: a pose do corpo e da lâmina não salta na troca (os testes abaixo).

## 4. Medições

| Medida | Valor | Método |
|---|---|---|
| Aperto → **início perceptível** da animação, Kesa | 0,017 s | Mão ou quadril se move mais de 2 cm, amostrado a 120 Hz |
| Aperto → início perceptível, Kiriage isolado | 0,017 s | Idem. Dois ticks, o mínimo possível |
| Aperto → contato no boneco, Kesa | 0,158 s | Teste do H2.1 |
| Aperto → contato no boneco, Kiriage isolado | 0,142 s | Teste novo |
| Kesa → Kiriage: entrada do Kiriage | quando a janela abre (0,283 s depois do início do Kesa) | Teste de buffer |

Limitação: o início perceptível é medido no esqueleto da simulação, sem a latência de renderização e de tela real, que depende do equipamento.

## 5. Testes

**248 verificações, 0 falhas.** São as 210 anteriores e 38 novas. **Um teste foi adaptado**, porque a semântica mudou: "golpes 1 e 2 são espelhados entre si" agora é "golpe 2 tem clipe autoral próprio (não é o espelho do golpe 1)". Nenhuma tolerância foi reduzida.

Novas (resumo):

1. Kesa isolado igual ao aprovado: hash do clipe e dados.
2. Kiriage isolado.
3. Kesa → Kiriage (tempo e buffer).
4. Continuidade de empunhadura (o corpo nunca volta à locomoção; erro de pegada abaixo de 3°).
5. Continuidade de postura (nenhum osso salta na troca).
6. Lâmina sem salto (nenhum passo da ponta acima de 0,30 m; sem excesso na troca).
7. Encadeamento tardio.
8. Acerto e erro; um acerto por alvo por golpe; dano.
9. Buffer sobrevive ao hitstop.
10. Kiriage → esquiva → corrida (distância da esquiva preservada, velocidade volta, katana volta à pegada de corrida).
11. Cancelamento da recuperação por movimento; direção pressionada orienta o golpe.
12. Parede, locomoção e câmera: os testes anteriores seguem passando.

## 6. Desempenho

Playtest em janela, 1080p, VSync desligado, 3 execuções. **Atenção:** durante estas medições o Phantom Blade Zero estava aberto no computador (usando GPU e CPU), então os números **não são comparáveis** com os do H2 e H2.1.

| Execução | FPS no combate | p99 do quadro | GPU média | Acertos |
|---|---|---|---|---|
| 1 | 140 | 27,4 ms | 0,77 ms | 9 de 9 |
| 2 | 136 | 21,9 ms | 0,63 ms | 9 de 9 |
| 3 | 129 | 25,9 ms | 0,93 ms | 9 de 9 |

O trecho de movimento puro das mesmas execuções ficou igual ou pior (FPS 134 a 144, p99 21 a 31 ms), ou seja, o combate não piora o desempenho em relação ao movimento. As esquivas deram 3,95 a 3,99 m. Sem travamento. Recomendo repetir com o Phantom Blade Zero fechado. Dados em `docs/h2-2/playtest/`.

## 7. Evidências (`docs/h2-2/`)

- `estudo/`: o Kiriage isolado (`clip_katana_kiriage_frente.png`) e a comparação das poses de transição.
- `capturas/h22_01_frente_kesa_kiriage.png`: de frente, Kesa → Kiriage → corrida.
- `capturas/h22_02_lado_kesa_kiriage.png`: de lado.
- `capturas/h22_03_boneco_lado_kesa_kiriage.png`: de lado, contra o boneco (contato, faíscas, reação).
- `capturas/h22_04_camera_de_jogo.png`: pela câmera de jogo (alta), recorte ampliado.
- Entrada simulada por script; não há vídeo.

## 8. Limitações

- O terceiro golpe ainda é o provisório do H2 (clipe derivado do pacote): a ligação Kiriage → golpe final troca de pegada e de estilo. Resolve-se com o Tsuki.
- Poses autorais sem captura de movimento: ombros, clavículas e punhos seguem o IK, com pouca sutileza.
- A luz do estúdio de testes deixa a vista frontal escura (a figura contra a luz); a captura frontal usa uma luz de preenchimento.
- O avanço efetivo é menor que o autorado (a aceleração da cápsula limita a velocidade), como já era no Kesa; os pés podem deslizar um pouco.
- Som e rastro: o som do corte foi sincronizado ao meio da janela de contato; o som continua sintetizado e provisório.

## 9. Checklist curto de playtest humano

Ataque com **J**, mouse esquerdo ou **X**. Esquiva: Espaço. **F3** mostra o estado do combate. Aperte o ataque duas vezes em sequência (Kesa e Kiriage).

1. **Fluxo:** Kesa e Kiriage parecem um só movimento, sem pausa nem volta ao repouso entre os dois?
2. **Ligação:** a lâmina e as mãos "pulam" ou mudam de pegada no instante da troca?
3. **Corpo:** quadril, tronco, ombros e pernas fazem sentido no corte ascendente? O Kiriage parece um golpe novo, e não o Kesa ao contrário?
4. **Resposta:** o Kiriage sai logo quando você aperta?
5. **Impacto:** contato, congelamento, rastro, som e reação do boneco combinam no Kiriage?
6. **Pés:** algum deslize incômodo no passo do Kiriage?
7. **Esquiva:** esquivar no meio do Kiriage responde e continua fluido? E correr logo depois?
8. **Final:** a pose final (guarda média-alta, lâmina para a frente) parece pronta para um terceiro golpe?

## Aprovação do PO

O PO realizou o playtest humano do **Kiriage de retorno**: **8 de 8 critérios aprovados, sem ressalvas** (29/10/2026).

| Critério | Resultado |
|---|---|
| Continuidade Kesa → Kiriage | Aprovado |
| Ausência de saltos da lâmina ou das mãos | Aprovado |
| Naturalidade do corpo e identidade própria do Kiriage | Aprovado |
| Resposta ao comando | Aprovado |
| Sensação de impacto | Aprovado |
| Movimento dos pés | Aprovado |
| Transição para esquiva e corrida | Aprovado |
| Postura final preparada para o próximo golpe | Aprovado |

Decisão: **Kesa e Kiriage aprovados; não solicitar nem executar novos ajustes nesses dois golpes sem necessidade comprovada.** Estado aprovado:

- `assets/animations/katana/katana_kesa.res`: SHA-256 `2a7cb0b2da3d2a9360e6b951dabd394ffd8124f3bf592790a5f87d33d0ae8e45`
- `assets/animations/katana/katana_kiriage.res`: SHA-256 `b7a98a44fda967ed75ff0e6784221a77baf0dcb7e76ac04b1116e2e77b22361c`
- tempos e dados dos golpes 1 e 2 em `game/data/katana_combo.tres`.

Próximo: H2.3, Tsuki de passo duplo (`docs/h2-3-tsuki.md`).
