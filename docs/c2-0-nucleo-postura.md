# C2.0: núcleo de pressão de postura

Status: **implementado e testado por script. NÃO aprovado: depende do playtest humano do PO.**
Branch `feat/c2-postura`, criada do HEAD de `feat/c1-parry` (`d05842e`). Sem PR e sem merge. As branches do C1 e do H2 e a main não foram modificadas. C2.1 a C2.4 não foram iniciados.

## 1. O que existe agora

O Instrutor tem um núcleo de postura. Só o HUD F3 mostra isso: nenhum inimigo tem animação, anel, som, quebra ou finalização novos.

| Conceito | Regra |
|---|---|
| **Pressão atual** (`current`) | Sobe com cada fonte. Depois de 1,5 s sem nova pressão, cai 15 por segundo |
| **Pressão cravada** (`locked`) | Piso da pressão atual. Não diminui com a recuperação. Limitada a 80% da postura máxima |
| **Últimos 20%** | Parry e esquiva param em 80. Só um golpe que acerta leva a pressão de 80 a 100 |
| **Fim do confronto** | 8 s sem pressão: o piso e o escalonamento somem, e a pressão atual volta a cair até zero |
| **Postura cheia** | Só é registrada (`full_reached`, `[CHEIA]` no F3). O Instrutor continua atacando. A quebra é do C2.2 |

**Sem contagem duplicada.** A pressão cravada não é uma segunda conta: é uma marca dentro da pressão atual. Cravar nunca soma pontos. Vale sempre `0 ≤ cravada ≤ atual ≤ máximo`, e um parry sobre pressão zero dá 25 atual e 25 cravada, nunca 50.

**Eventos repetidos.** Cada fonte aceita um número de evento uma única vez (número do golpe do jogador ou do ataque inimigo). Um golpe entregue de novo é recusado e contado em `rejected_events`.

**Normalização quando a postura máxima muda.** A **fração preenchida não muda**: pressão atual e cravada são reescaladas juntas pelo mesmo fator. Aumentar o máximo não dá nem tira progresso, e os limites de 80% acompanham o novo máximo. Exemplo medido em teste: 65 atual e 55 cravada em 100 viram 97,5 e 82,5 em 150. O escalonamento soma sobre o valor base: duas aplicações de 25% dão ×1,5, e a terceira é recusada. No fim do confronto ele volta a zero. O método existe e está testado, mas só o C2.2 vai chamá-lo.

## 2. Fontes de pressão

| Fonte | Pressão | Crava? | Situação no C2.0 |
|---|---|---|---|
| Kesa, Kiriage que acertam | 3 | Não | Ativo |
| Tsuki que acerta | 7 (provisório) | Não | Ativo; golpe ainda sem aprovação |
| Contra-corte que acerta | 12 | Sim | Ativo. Errar gasta a oportunidade do C1.1 e não pressiona |
| Parry perfeito | 25 | Sim | Ativo. Usa o `parry_posture_pressure` do C1, sem mudança |
| Esquiva justa | 14 | Sim | **Só preparada** (`apply_evade`). Ninguém chama no jogo: a detecção de ameaça real é do C2.1 |
| Golpe que erra, defesa normal, parry em falso, golpe recebido, esquiva | 0 | Não | Testado no jogo |

Não implementado nesta etapa: exposição (×1,5), que pertence ao C2.1, e rebote, que pertence ao C2.2.

## 3. Dados configuráveis

`game/data/postura_instrutor.tres` (`PostureData`), editável no inspetor:

| Campo | Valor | Por quê (hipótese de playtest) |
|---|---|---|
| `max_posture` | 100 | Escala simples; só importa em relação aos ganhos |
| `recovery_delay` | 1,5 s | Esquivar e voltar não deve apagar a pressão |
| `recovery_rate` | 15/s | Afastar-se custa, sem zerar de imediato |
| `combat_reset_time` | 8 s | Não dá para guardar pressão indefinidamente |
| `lock_cap_ratio` | 0,80 | Teto da pressão cravada, decisão do PO |
| `offense_only_ratio` | 0,20 | Trecho final só com golpe que acerta, decisão do PO |
| `max_single_gain_ratio` | 0,40 | Proteção para perfis futuros; sem efeito no Instrutor |
| `hit_/parry_/evade_gain_ratio` | 1,0 | Multiplicadores por tipo de inimigo |
| `evade_pressure` | 14 | Integração preparada |
| `escalation_per_step` / `escalation_max_steps` | 0,25 / 2 | Duas aplicações de 25% por confronto, decisão do PO |

Em `game/data/katana_combo.tres`: `posture_pressure` (3, 3, 7, 12) e `posture_locks` (só contra-corte). O boneco de treino continua sem postura.

Os valores são os da proposta, sem ajuste para atingir tempos. **Os tempos simulados não são medições.** O modelo de bancada foi refeito com as condições do PO, e duas coisas mudaram: só parry, ou parry + contra-corte sem cadeia, agora **nunca enchem** a postura; e a razão entre agressivo com esquiva e parry subiu de 1,40 para **1,63** no jogador médio, pouco acima do limite proposto de 1,6. Não mexi em nenhum valor por isso. A comparação real entre estilos é o trabalho do C2.4.

## 4. Evidência: pressão temporária e cravada

`tools/c20_demo.gd` joga contra o Instrutor real com entrada simulada. Curva completa em `docs/c2-0/pressao.csv`.

| t (s) | Evento | Atual | Cravada | O que mostra |
|---|---|---|---|---|
| 1,05 a 1,84 | Kesa, Kiriage, Tsuki | 13 | 0 | Cadeia sem precisão não crava |
| 4,51 | Sem novos golpes | 0 | 0 | Pressão temporária some |
| 5,69 | Parry perfeito | 25 | 25 | Gera e crava, sem duplicar |
| 5,96 | Contra-corte acerta | 37 | 37 | Soma uma vez e crava o acumulado |
| 7,14 a 7,48 | Kesa, Kiriage | 43 | 37 | Sobe só a pressão atual |
| 9,63 | Sem novos golpes | 37 | 37 | Recuperação para no piso |
| 11,67 / 14,32 | Dois parries | 80 | 80 | O segundo rendeu só 18, parando no teto |
| 16,97 | Terceiro parry | 80 | 80 | Ganho 0: parry não passa de 80 |
| 18,08 a 20,15 | 6 golpes | 100 | 80 | Só golpes completam os 20% finais |
| 20,15 | Postura cheia | 100 | 80 | Só registra; sem quebra |
| 23,62 | Sem novos golpes | 80 | 80 | Volta ao piso de 80 |
| 28,83 | 8 s sem pressão | 69,8 | 0 | Confronto acabou; o piso sumiu |

Capturas com o F3 em `docs/c2-0/capturas/`. Vídeo com o HUD, fora do repositório pelo tamanho: `C:\Cyblade\_videos\c20_postura_jogo.avi` (282 MB, abra no VLC).

## 5. Testes

- **Suíte principal: 449 verificações, 0 falhas.** As 376 anteriores continuam, e **73 são novas**, independentes: pressão atual, piso, recuperação, limite de 80%, pressão duplicada, golpes que acertam e erram, parry perfeito, contra-ataque válido e que erra, eventos repetidos, passos de tempo diferentes, normalização, isolamento e regressões.
- **FPS** (`tools\run_parry_fps.ps1`, ampliado): parry, defesa, golpe recebido, contra-ataque e agora a sequência parry → contra-corte → Kesa → recuperação, a **30, 60 e 144 FPS: valores idênticos** (25/25, 37/37, 40/37, 37/37).

**Isolamento (autorizado pelo PO).** `PostureController.enabled` é a configuração explícita de treino. Desligado, nenhuma fonte altera a pressão, mas o contador do C1 continua somando. `_c1_setup()` ganhou **uma linha**: `ins.posture.enabled = false`. Nenhuma tolerância mudou, nenhum teste antigo foi alterado além disso, e os testes novos ligam a postura em `_c2_setup()`.

**Conferência extra de regressão:** rodei o arquivo `tests/run_tests.gd` **original do C1, sem nenhuma mudança e com a postura ligada**, sobre o código do C2.0: **376 de 376**. Hoje o isolamento é uma precaução; ele passa a ser necessário quando a quebra existir, no C2.2.

## 6. C1 íntegro

- SHA-256 inalterado em 6 clipes: Kesa, Kiriage, Tsuki, guarda, deflexão e contra-corte (os dois últimos agora protegidos por teste).
- Janela perfeita de 0,14 s, parry em falso de 0,25 s, janela de contra-ataque de 0,80 s, 1 carga: inalterados e testados.
- Movimentação, esquiva e câmera: nenhum arquivo tocado (`player.gd`, `humanoid_visual.gd`, `defense_*.gd`, `camera_rig.gd` não têm diff). Tempos e dano de Kesa e Kiriage conferidos por teste.
- Com a postura ligada, o parry continua abrindo a oportunidade e o desequilíbrio.

## 7. Desempenho em janela

1080p, VSync desligado, entrada simulada, trecho de defesa com parry e contra-ataque. Comparei com o **C1 aprovado (`d05842e`) nas mesmas condições**, em cópia temporária já removida.

| Execução | FPS | p99 | Pior quadro | Acima de 25 ms | CPU média | GPU média |
|---|---|---|---|---|---|---|
| C1, 1 | 1540 | 1,66 ms | 12,2 ms | 0 | 0,137 ms | 0,47 ms |
| C1, 2 | 1696 | 1,17 ms | 6,1 ms | 0 | 0,134 ms | 0,45 ms |
| C1, 3 | 1678 | 1,19 ms | 6,4 ms | 0 | 0,136 ms | 0,45 ms |
| **C2.0, 1** | 1680 | 1,18 ms | 4,8 ms | 0 | 0,136 ms | 0,45 ms |
| **C2.0, 2** | 1669 | 1,22 ms | 4,5 ms | 0 | 0,137 ms | 0,45 ms |
| **C2.0, 3** | 1683 | 1,17 ms | 11,0 ms | 0 | 0,135 ms | 0,45 ms |

**Sem custo mensurável.** Em cada execução: 2 parries, 2 defesas, 2 contra-ataques acertando, esquivas de 3,99 e 3,95 m. Dados em `docs/c2-0/desempenho-resumo.csv` e `docs/c2-0/playtest/`.

Duas ressalvas: uma janela do CYBLADE (DEBUG) do PO ficou aberta durante as medições, e uma primeira série do C2.0 deu 1253 a 1308 FPS, com a mesma CPU e GPU de 0,59 ms. Repetida logo depois da medição do C1, deu os valores acima, então a queda foi do ambiente, não do código. A causa exata não foi isolada.

**Intermitência (pendências 17 e 25):** não ocorreu nas 9 execuções em janela desta etapa, feitas uma por vez. O playtest agora grava `m1_playtest_progresso.txt` a cada trecho, para uma execução sem resultados mostrar até onde chegou.

## 8. Limitações e pendências

- **Alcance no limite depende do FPS de render (achado novo, anterior ao C2).** A pose da lâmina é atualizada por quadro de render. Até 2,0 m do centro do alvo, Kesa e contra-corte acertam igual em 30, 60, 120 e 144 FPS. No limite, não: a 30 FPS o contra-corte erra a partir de 2,05 m, enquanto nos demais acerta até 2,10 m; a 2,20 m o Kesa acerta a 30 e 144 FPS e erra a 60 e 120. Como a postura só conta golpes que acertam, herda essa diferença. A lógica de pressão em si é invariante. Não corrigi porque isso muda como golpes aprovados são detectados; decisão do PO (pendência 26).
- A pressão só aparece no F3. O anel é do C2.1.
- Sem esquiva justa nem exposição, o estilo de esquiva ainda não pressiona no jogo.
- Valores sem validação humana; o modelo não é medição.
- O Tsuki soma 7 de forma provisória.
- Postura do jogador fora do C2, por decisão do PO.

## 9. Checklist de playtest humano

Feche qualquer janela aberta do jogo e rode `Jogar.bat` de novo: a pasta agora está em `feat/c2-postura`. Vá até o Instrutor, com F3 ligado, e olhe a última linha do HUD: `postura x/100  cravada y`.

1. **Pressão:** ao acertar o Instrutor, a postura sobe de um jeito que faz sentido? Golpes que erram não contam?
2. **Peso do parry:** um parry perfeito (+25) parece um salto claro em relação aos golpes (+3)?
3. **Cravar:** depois do parry, pare de atacar por 2 s. A postura para no valor cravado em vez de zerar?
4. **Sem cravar:** só com golpes, a postura some depois de você parar?
5. **Trecho final:** com vários parries a postura para em 80, e só golpes levam a 100? Em 100 aparece `[CHEIA]` e nada mais acontece, como esperado nesta etapa.
6. **Nada mudou:** golpes, parry, deflexão, contra-ataque, esquiva, corrida e câmera continuam iguais ao que você aprovou?
7. **Ritmo:** os valores parecem encaminhar uma luta com decisões, ou uma corrida para encher a barra?
