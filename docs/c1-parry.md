# C1.0: defesa e parry (protótipo jogável)

Status: **APROVADO PELO PO após playtest humano (9 de 9 critérios, sem ressalvas).** Ver "Aprovação do PO" no fim deste documento.
Branch `feat/c1-parry`, criada a partir do HEAD de `feat/h2-combate-katana` (`5d398d8`). **Depende do H2** (combate do PR #3, ainda sem merge). Sem PR e sem merge nesta etapa; se um PR for aberto depois, a base deve ser `feat/h2-combate-katana`, para não repetir o H2 na comparação.

Proposta aprovada: `docs/c1-parry-proposta.md`. Filosofia: `docs/combate-filosofia.md`.

## 1. O que existe

- **Instrutor de treino** (a 7 m do ponto de partida, à direita do boneco). Ele ataca num ciclo fixo, sem IA: espera, preparação (o corpo acende em âmbar e o braço-lâmina sobe), sinal didático 0,25 s antes do contato (brilho branco na lâmina e um "tic"), golpe, recuperação. Só ataca com o jogador a até 4 m. Ele é também um alvo: os golpes do jogador o acertam.
- **Defesa normal:** segurar **K** (ou **LB**) levanta a guarda. A pose é autoral, feita no Blender, com as duas mãos e a lâmina cruzando a linha de ataque; só tronco e braços entram, e as pernas seguem andando. O dano cai para 20%, há um empurrão curto e um som metálico grave com poucas faíscas.
- **Parry perfeito:** um toque em K até 0,14 s antes do contato (vale mesmo soltando o botão). Dano zero. O Instrutor fica desequilibrado por 0,8 s (recua, braço jogado para cima), o som metálico é agudo e longo, as faíscas saem para o lado do ponto de contato, há um anel claro rápido e um congelamento local de 0,07 s só no jogador e no Instrutor. Somam-se os contadores do C1: +25 de pressão de postura e +10 de Energia Neural, visíveis no HUD (F3).
- **Falha de defesa:**
  - **tarde** (apertou depois do contato): dano inteiro, clarão vermelho no corpo, reação de 0,3 s que a esquiva cancela;
  - **em falso** (toque sem contato na janela): por 0,25 s um novo aperto só levanta a guarda normal. Movimento, ataque e esquiva continuam livres.
- **HUD (F3):** estado da defesa, último resultado com o **desvio em milissegundos** (por exemplo, "PARRY +62 ms" = apertou 62 ms antes do contato), "apertou X ms tarde", contagem de parry em falso, vida de treino (sem morte: zerou, volta cheia), Energia Neural e a fase e a pressão de postura do Instrutor.

## 2. Controles

| Ação | Teclado/mouse | Gamepad |
|---|---|---|
| Defesa / parry | **K** | **LB** |
| Ataque | J ou botão esquerdo | X |
| Esquiva | Espaço ou Shift | B |

O botão direito do mouse continua girando a câmera. A defesa é uma ação do mapa de entrada (`game/input/input_setup.gd`), pronta para remapeamento.

## 3. Regras e prioridades

- **No mesmo instante:** esquiva > defesa > ataque. Um ataque que chega até 20 ms depois da defesa conta como "mesmo instante" e é descartado.
- **Defesa durante um golpe:** interrompe o golpe na **mesma janela de cancelamento da esquiva** de cada golpe; antes disso, fica guardada 0,10 s. Os golpes aprovados não mudaram (os testes conferem o SHA-256 do Kesa e do Kiriage).
- **Durante a esquiva** a defesa não interrompe (fica no buffer). Na recuperação da esquiva, entra na hora.
- **Guarda:** andar a 2,5 m/s virado para o inimigo mais próximo; atacar ou esquivar sai da guarda na hora; depois de bloquear, a guarda fica 0,15 s (a esquiva cancela); soltar volta a correr sem pausa.
- **Hitstop:** o congelamento local guarda os apertos sem deixá-los expirar. Um ataque apertado no congelamento sai depois dele (testado).
- **Tempo:** tudo em segundos, no relógio de combate (um passo de física = 1/120 s). O aperto é lido pelo evento de entrada, e também pela borda de "segurado", para controles virtuais.

## 4. Parâmetros ajustáveis (arquivos editáveis no inspetor)

`game/data/defesa.tres` (`DefenseData`):

| Campo | Valor | Campo | Valor |
|---|---|---|---|
| Janela perfeita | 0,14 s | Recuperação de bloqueio | 0,15 s |
| Bloqueio de parry em falso | 0,25 s | Hitstop do parry / da defesa | 0,07 / 0,03 s |
| Dano que passa na defesa | 20% | Empurrão da defesa | 0,20 m em 0,10 s |
| Início da guarda | 0 s | Velocidade de guarda | 2,5 m/s |
| Reação ao golpe | 0,30 s | Recuo do golpe | 0,30 m |
| Buffer da defesa | 0,10 s | Pressão de postura / Energia por parry | 25 / 10 |

`game/data/instrutor_ataque.tres` (`EnemyAttackData`):

| Campo | Valor | Campo | Valor |
|---|---|---|---|
| Preparação | 0,60 s | Sinal antes do contato | 0,25 s |
| Golpe | 0,12 s (contato de 0,06 a 0,12 s) | Recuperação | 0,50 s |
| Desequilíbrio após parry | 0,80 s | Alcance / ângulo | 2,2 m / 90° |
| Dano | 20 | | |

No nó do Instrutor: intervalo entre ataques 1,4 s, distância de engajamento 4 m.

## 5. Arquitetura

| Parte | Arquivo |
|---|---|
| Dados de defesa e parry | `game/combat/defense_data.gd` |
| Leitura da entrada e prioridades | `game/player/player.gd` (estados GUARD e STAGGER, evento + borda) |
| Estado defensivo e resolução temporal | `game/combat/defense_controller.gd` (lógica pura, só tempos) |
| Relógio de combate | `game/combat/combat_clock.gd` |
| Ataque do Instrutor | `game/combat/enemy_attack_data.gd` + `training_instructor.gd` |
| Feedback audiovisual | `game/combat/defense_effects.gd` + sons em `generated_sounds.gd` |
| Vida de treino e contadores (postura, Energia) | `game/combat/combat_vitals.gd` e o Instrutor (`posture_pressure`) |
| Pose de guarda | `tools/blender/katana_guard_keys.py` → `assets/animations/katana/katana_guarda.res` |

Postura e Energia Neural são só contadores; o sistema completo fica para o C2 e o C3.

## 6. Testes

- **Suíte principal:** **331 verificações, 0 falhas.** As 287 anteriores não foram tocadas; 44 são novas:
  - lógica com tempos explícitos: janela, toque, sustentada, em falso, recuperação;
  - Instrutor: sinal 0,25 s antes, contato no instante agendado;
  - os três resultados no jogo, dano e um resultado por golpe;
  - prioridades e cancelamento na janela do golpe;
  - buffer durante o hitstop;
  - esquiva escapando do golpe e a esquiva não bloqueada pelo parry em falso;
  - continuidade da corrida depois da guarda;
  - `Input.action_press`;
  - Kesa e Kiriage intactos.
- **Variação de FPS** (`tools\run_parry_fps.ps1`): o mesmo jogo com render a **30, 60 e 144 FPS** (física em 120 Hz), contra o Instrutor:

| FPS de render | Parry (aperto pedido −0,07 s) | Defesa (−0,30 s, segurando) | Tarde (+0,05 s) |
|---|---|---|---|
| 30 | PARRY (aperto real −0,052 s) | DEFESA | GOLPE |
| 60 | PARRY (−0,060 s) | DEFESA | GOLPE |
| 144 | PARRY (−0,068 s) | DEFESA | GOLPE |

A 30 FPS a entrada só chega a cada quadro (33 ms), e a janela de 0,14 s absorve isso.

## 7. Desempenho

Playtest em janela, 1080p, VSync desligado, 3 execuções. O **Phantom Blade Zero continuava aberto** no computador.

| Execução | FPS no trecho de defesa | p99 do quadro | Pior quadro | Quadros acima de 25 ms | Parry / defesa |
|---|---|---|---|---|---|
| 1 | 207 | 14,4 ms | 28,7 ms | 1 | 2 / 2 |
| 2 | 203 | 14,5 ms | 15,9 ms | 0 | 2 / 2 |
| 3 | 224 | 12,5 ms | 17,9 ms | 0 | 2 / 2 |

O trecho de movimento puro das mesmas execuções ficou em 209 a 223 FPS, ou seja, o Instrutor e os efeitos não pesam. As esquivas deram 3,95 a 3,99 m. Dados: `docs/c1/desempenho-resumo.csv`.

**Correção encontrada no playtest:** o primeiro playtest deu golpe recebido em todas as defesas, porque o roteiro aperta por `Input.action_press`, que não gera evento. A leitura passou a usar também a borda de "segurado"; há um teste novo para isso.

## 8. Evidências

- `docs/c1/estudo/`: pose de guarda isolada (frente e lado).
- `docs/c1/capturas/`: cada cenário de lado e pela câmera de jogo (`c1_01` sem defesa, `c1_02` defesa normal, `c1_03` parry perfeito com contra-ataque Kesa → Kiriage no Instrutor desequilibrado). Entrada simulada.
- **Vídeos reais**, fora do repositório pelo tamanho (AVI MJPEG 960x540 a 60 FPS, entrada simulada; abra no VLC):
  - `C:\Cyblade\_videos\c1_parry_lado.avi` (56 MB, câmera lateral);
  - `C:\Cyblade\_videos\c1_parry_jogo.avi` (72 MB, câmera de jogo com o HUD de treino).
  - Os dois mostram os três cenários em sequência. Conferi o lateral montando quadros dele: aparecem o golpe, a defesa, o parry (anel e faíscas) e o contra-ataque.

## 9. Pendências e limitações

- **Legibilidade na câmera alta:** a preparação em âmbar é bem visível, mas o braço-lâmina e o brilho do sinal são pequenos de cima. Se o PO achar difícil ler, aumentar a lâmina ou o brilho (só no Instrutor).
- **Pose de guarda estática:** não há animação de "deflexão" no parry (o retorno vem do som, das faíscas, do anel e do congelamento).
- O Instrutor é um corpo procedural simples, com um só ataque; padrões "duplo" e "atrasado" ficam para o C1.4.
- **Sons sintetizados** (provisórios, originais).
- **Precisão de entrada:** a 60 FPS a entrada chega uma vez por quadro (até 16,7 ms de arredondamento), um limite do sistema de entrada, não do parry.
- **Desempenho medido com o Phantom Blade Zero aberto.**
- Postura, quebra de postura, contra-ataque com bônus e Energia Neural são só contadores (C2/C3, não iniciados).

## 10. Checklist de playtest humano

Vá até o Instrutor (à direita do boneco) e fique a uns 2 m dele. Use **K** (ou LB) para defender e **F3** para ver o desvio em milissegundos.

1. Dá para ver **quando** o Instrutor vai atacar? O brilho branco e o "tic" ajudam a acertar o tempo?
2. **Parry:** quando você acerta, dá vontade de acertar de novo? O som, as faíscas, o anel e o recuo do Instrutor recompensam?
3. Quando você erra, entende se foi **cedo ou tarde**? O HUD ajuda?
4. A janela de 0,14 s parece **fácil, justa ou difícil**? Sugira 0,12, 0,14 ou 0,16 s.
5. **Defesa normal** (segurar K): é uma opção segura, mas claramente pior que o parry? O empurrão e o som são diferentes do parry?
6. Apertar K sem parar é punido o bastante, sem frustrar?
7. **Responsividade:** a guarda sobe na hora em que você aperta?
8. A **pose de guarda** deixa claro que você está defendendo? Andar de guarda funciona?
9. Defender, atacar, esquivar e correr se misturam **sem travar**? Alguma vez ficou preso?
10. A **esquiva** continua fluida, mesmo saindo da guarda ou depois de um parry em falso?
11. Os efeitos atrapalham a visão em algum momento, na câmera de jogo?
12. Depois de alguns minutos: **dá vontade de dominar o parry?**

## Aprovação do PO

O PO realizou o playtest humano do **C1.0** e o aprovou definitivamente (30/10/2026): **9 de 9 critérios aprovados, sem ressalvas.**

Aprovados: defesa, penalidades (golpe recebido e parry em falso), efeitos, responsividade e fluidez. **A janela perfeita de 0,14 s está mantida.**

O C1.0 passa a ser uma **base protegida contra regressões**: os valores de `game/data/defesa.tres` e `game/data/instrutor_ataque.tres` (janela 0,14 s, bloqueio de parry em falso 0,25 s, defesa deixa 20%, hitstops, tempos do Instrutor) só mudam com nova autorização do PO. Os testes `C1: lógica da defesa` e `C1: Instrutor, parry, defesa e golpe recebido` (e a verificação por FPS) protegem esse comportamento.

Próximo: C1.1, deflexão autoral e contra-ataque de oportunidade (`docs/c1-1-deflexao-contra-ataque.md`).
