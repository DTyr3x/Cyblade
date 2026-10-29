# H2.3: Tsuki de passo duplo (terceiro golpe autoral)

Status: **implementado e testado por script. NÃO aprovado: depende do playtest humano do PO.**
Branch `feat/h2-combate-katana` (PR #3, sem merge). Kesa e Kiriage, aprovados, **não foram alterados** (SHA-256 dos clipes e dados verificados por teste). O combo agora é **Kesa → Kiriage → Tsuki**; o clipe genérico do H2 não é mais usado.

## 1. Aprovação do Kiriage

Registrada em `docs/h2-2-kiriage.md` ("Aprovação do PO", 8 de 8 critérios) e no PR #3.

## 2. O golpe: Tsuki de passo duplo

Estocada final com as duas mãos, pé direito à frente, com deslocamento mais comprometido que os cortes. Nasce da pose do Kiriage no quadro 17 (quando a janela de encadeamento dele abre: lâmina alta à direita).

| Fase | Quadros (60 Hz) | O que o corpo faz |
|---|---|---|
| Guarda de estocada | 0 a 6 | A lâmina desce do alto-direita para a linha do quadril direito; o peso vai para a perna de trás; o quadril e o tronco giram para a direita |
| Passo 1 | 6 a 13 | O pé esquerdo (de trás) desliza quase até o da frente; as mãos ficam junto ao quadril direito, a lâmina aponta para a frente |
| Passo 2 (fumikomi) | 13 a 17 | O pé direito dá a passada longa; o peso passa da perna de trás para a da frente; as mãos disparam; o quadril quadra com o alvo |
| Contato e extensão | 14 a 21 | Braços estendidos, perna de trás esticada, tronco inclinado à frente, lâmina na altura do peito |
| Encadeia (reinicia a sequência) / livre / fim | 28 / 26 / 36 | A lâmina volta à guarda média, o pé de trás desliza para perto; livre para esquivar ou correr |

Valores em `game/data/katana_combo.tres` (editáveis): duração 0,60 s (velocidade normal, sem câmera lenta), avanço 1,2 m entre os quadros 4 e 20, dano 25, **hitstop 0,10 s** (Kesa e Kiriage: 0,06), recuo do alvo 0,8 m (os cortes: 0,15), reação pesada, **tremor de câmera discreto 0,03 m só neste golpe**, esquiva cancela a partir do quadro 3 (0,05 s).

**Identidade própria:** estocada em linha reta, com dois passos, em vez de arco; o corpo termina baixo e longo, ao contrário dos cortes. Não usa clipe do pacote: animação original feita no Blender (`tools/blender/katana_tsuki_keys.py`), com o mesmo pipeline dos outros dois golpes.

## 3. Continuidade Kiriage → Tsuki

- Todos os canais do Tsuki começam do valor do Kiriage no quadro 17 (`katana_tsuki_keys.build(k0)`): quadril, tronco, mãos, lâmina e pés. O primeiro quadro do Tsuki é a pose do Kiriage nesse quadro (veja `docs/h2-3/estudo/transicao_kiriage_tsuki.png`).
- O `AnimationTree` troca de clipe dentro do mesmo OneShot (`seamless_chain`), sem voltar à locomoção, com a empunhadura de duas mãos mantida e suavização para encadeamento tardio. É o mesmo mecanismo aprovado no Kesa → Kiriage.
- O gerador do Blender foi generalizado (Kiriage e Tsuki partem do golpe anterior) **sem alterar a saída dos dois golpes aprovados**: o JSON de cada um tem o mesmo hash antes e depois.

## 4. Medições (testes, simulação a 120 Hz)

| Medida | Valor |
|---|---|
| Aperto → início perceptível, Tsuki isolado | 0,017 s |
| Aperto → contato no boneco, Tsuki isolado (depois do Kiriage terminar) | 0,250 s |
| Alcance da estocada (ponta à frente da cápsula, na janela de contato) | 1,51 m, altura de 1,19 m |
| Kesa → Kiriage → Tsuki | encadeia sempre que a janela abre; nenhum osso muda de velocidade de forma brusca (acima de 0,02 m por quadro) |

O início perceptível é medido no esqueleto da simulação, sem a latência real de tela.

## 5. Testes

**287 verificações, 0 falhas.** São as 248 anteriores, sem nenhuma alteração nem relaxamento de tolerância, e 39 novas:

1. Integridade dos golpes aprovados: SHA-256 dos clipes do Kesa e do Kiriage e dados dos três golpes.
2. Tsuki: clipe próprio, duas mãos, janelas em ordem, impacto mais expressivo que os anteriores, duração abaixo de 0,7 s.
3. Sequência Kesa → Kiriage → Tsuki: ordem, troca sem volta à locomoção, empunhadura abaixo de 3° de erro na sequência inteira, nenhum osso salta (posição e velocidade) na troca para o Tsuki.
4. Lâmina sem teletransporte; estocada legível (ponta à frente, na altura do peito).
5. Esqueleto de 65 ossos e ossos finitos durante a sequência inteira.
6. Três acertos no boneco, um por golpe, dano 10 + 10 + 25, sem dano duplicado; tremor só no Tsuki; três erros de costas.
7. Resposta: início perceptível e contato do Tsuki isolado.
8. Buffer durante o hitstop do Tsuki (sobrevive e reinicia a sequência) e congelamento do relógio.
9. Esquiva durante o Tsuki (distância 3,95 m preservada), Tsuki → esquiva → corrida e Tsuki → corrida.
10. Parede: a sequência inteira não a atravessa; a direção pressionada orienta o Tsuki.
11. Regressão: os testes anteriores de locomoção, câmera, esquiva e dos outros golpes continuam passando.

## 6. Desempenho

Playtest em janela, 1080p, VSync desligado, 3 execuções. **O Phantom Blade Zero continuava aberto no computador** (não pude fechá-lo, não é meu processo), então não houve medição com ele fechado.

| Execução | FPS no combate | p99 do quadro | Pior quadro | GPU média | Quadros acima de 25 ms | Acertos |
|---|---|---|---|---|---|---|
| 1 | 181 | 18,5 ms | 21,0 ms | 0,61 ms | 0 | 9 de 9 |
| 2 | 186 | 13,3 ms | 21,8 ms | 0,53 ms | 0 | 9 de 9 |
| 3 | 200 | 15,3 ms | 22,9 ms | 0,51 ms | 0 | 9 de 9 |

O trecho de movimento puro das mesmas execuções deu 173 a 182 FPS e p99 de 20 a 21 ms, ou seja, o combate não piora o desempenho. As esquivas deram 3,95 a 3,99 m. **Ocorrência:** uma quarta execução terminou sem gravar resultados e sem estourar o tempo (causa não identificada; repetida em seguida, concluiu normalmente). Dados em `docs/h2-3/playtest/` e `docs/h2-3/desempenho-resumo.csv`.

## 7. Evidências

- `docs/h2-3/estudo/`: o Tsuki isolado no modelo (frente e lado) e a comparação das poses Kiriage → Tsuki (`transicao_kiriage_tsuki.png`).
- `docs/h2-3/capturas/`:
  - `h23_01` a `h23_03`: Tsuki isolado (frente, lado, contra o boneco);
  - `h23_04` a `h23_06`: Kesa → Kiriage → Tsuki (frente, lado, contra o boneco);
  - `h23_07`: corrida → três golpes → esquiva → corrida;
  - `h23_08`: pela câmera de jogo (alta), recorte ampliado.
- **Vídeo real** (gameplay renderizado quadro a quadro pelo Movie Maker do Godot, entrada simulada, AVI MJPEG 960x540 a 60 FPS; abra em um player como o VLC). Ficam **fora do repositório** pelo tamanho (38 e 45 MB):
  - `C:\Cyblade\_videos\h23_combate_lado.avi`: câmera lateral, corpo em detalhe.
  - `C:\Cyblade\_videos\h23_combate_jogo.avi`: câmera alta do jogo.
  - Conteúdo de cada um: corrida → Kesa → Kiriage → Tsuki → esquiva → corrida. A verificação por montagem de quadros confirmou a sequência no vídeo lateral.

## 8. Limitações

- A vista frontal e as da câmera de testes são escuras (a figura contra a luz da arena). A frontal usa luz de preenchimento.
- Poses autorais sem captura de movimento: ombros e punhos seguem o IK, com pouca sutileza.
- O avanço efetivo da cápsula (1,2 m autorado) é menor por causa da aceleração; os pés podem deslizar um pouco.
- O alcance depende do alvo estar a até ~1,5 m; o boneco colide com a cápsula e limita o avanço.
- O som é sintetizado e provisório; o flash do impacto forte ocupa bastante tela em câmera próxima.
- Desempenho medido com o Phantom Blade Zero aberto.

## 9. Checklist de playtest humano

Ataque com **J**, mouse esquerdo ou **X**. Esquiva: Espaço. **F3** mostra o estado. Primeiro bata três vezes em sequência (Kesa → Kiriage → Tsuki), depois o Tsuki sozinho (bata Kesa e Kiriage, espere e bata de novo).

1. **Fluxo:** os três golpes parecem um único movimento, sem retorno ao repouso entre eles, principalmente na ligação Kiriage → Tsuki?
2. **Ligação:** a lâmina ou as mãos "pulam" ou mudam de pegada na troca para o Tsuki?
3. **Estocada:** é clara e legível pela câmera alta? A direção e a altura parecem certas?
4. **Corpo:** os dois passos, a transferência de peso, o quadril, o tronco e os ombros convencem?
5. **Peso sem lentidão:** o Tsuki parece comprometido e pesado sem ficar lento?
6. **Resposta:** o Tsuki sai logo quando você aperta?
7. **Impacto:** congelamento, recuo e reação do boneco, rastro, som e tremor de câmera combinam? O tremor é discreto?
8. **Pés:** algum deslize incômodo nos passos?
9. **Esquiva e corrida:** esquivar no meio do Tsuki e correr logo depois estão fluidos?
10. **Recuperação:** o fim do Tsuki permite esquivar ou voltar a correr sem pausa artificial?
11. **Sequência completa:** o combo Kesa → Kiriage → Tsuki parece finalizado como uma sequência, e o Tsuki parece um bom finalizador?
