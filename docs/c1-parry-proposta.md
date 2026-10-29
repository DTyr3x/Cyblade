# C1: Parry (proposta técnica e especificação jogável mínima)

Status: **proposta, aguardando aprovação do PO. Nada implementado.** Filosofia em `docs/combate-filosofia.md`.

Objetivo do C1: um protótipo jogável de **defesa ativa**. Um inimigo de treino ataca com ritmo legível, e o jogador decide entre esquivar, defender ou dar parry. O parry perfeito tem de ser difícil o bastante para valer a pena e claro o bastante para o jogador entender o que errou.

## 1. Funcionamento

Um só botão, **Defesa**. Apertar abre o parry; segurar mantém a guarda.

```
aperto ─┬─ janela perfeita (0,14 s) ─┬─ guarda normal (enquanto segurar) ─ soltar → livre
        │  contato aqui = PARRY      │  contato aqui = DEFESA
        └────────────────────────────┴─ soltou antes de qualquer contato = parry em falso
```

| Resultado | Quando | Para o jogador | Para o inimigo |
|---|---|---|---|
| **Parry perfeito** | O contato do golpe inimigo cai dentro da janela perfeita, contada a partir do **aperto** (a janela vale mesmo que o botão já tenha sido solto: "parry de toque") | Nenhum dano. Retorno forte (§6). Ganha pressão de postura sobre o inimigo e Energia Neural (contadores no C1, efeito no C2/C3) | **Desequilíbrio:** recuo de corpo, arma jogada para cima, ataque seguinte atrasado; vulnerável por 0,8 s (no C2: janela de contra-ataque) |
| **Defesa normal** | Contato com a guarda erguida, fora da janela perfeita | Dano reduzido a 20%, empurrão curto (0,2 m), custo de postura do jogador (C2), recuperação de bloqueio de 0,15 s (esquiva cancela) | Nada além do recuo normal do próprio ataque |
| **Fora do tempo, tarde** | Apertou depois do contato | Leva o golpe inteiro, reação de impacto de 0,3 s (esquiva cancela) | Nada |
| **Fora do tempo, parry em falso** | Tocou e soltou sem nenhum contato na janela | **Recuperação de defesa** de 0,25 s: um novo aperto nesse tempo só levanta a guarda normal, sem janela perfeita (anti-aperto repetido). Movimento, ataque e esquiva continuam livres | Nada |

Os três casos têm causa visível: o HUD de depuração (F3) mostra o último resultado e o **desvio em milissegundos** entre o aperto e o contato. Exemplo: "PARRY +62 ms", "DEFESA +190 ms", "TARDE −35 ms".

## 2. Controles sugeridos

| Ação | Teclado/mouse | Gamepad |
|---|---|---|
| Defesa / parry | **K** (ao lado do J de ataque) | **LB** |
| Ataque | J ou botão esquerdo (como hoje) | X (como hoje) |
| Esquiva | Espaço ou Shift (como hoje) | B (como hoje) |

Alternativa para decisão do PO: **botão direito do mouse** para defesa. Hoje ele gira a câmera quando segurado e arrastado; usá-lo exigiria passar o giro da câmera ao botão do meio, o que muda um controle aprovado. A recomendação é K/LB agora; o mapa de entrada já é uma tabela de dados (`input_setup.gd`), então trocar depois é simples.

## 3. Janelas iniciais configuráveis

Recurso novo `DefenseData` (`game/data/defense.tres`). Todos os valores em **segundos**, nenhum em quadros.

| Campo | Inicial | Faixa para playtest | Papel |
|---|---|---|---|
| `perfect_window` | **0,14** | 0,12 a 0,16 | Contato até este tempo depois do aperto = parry perfeito |
| `guard_startup` | 0,0 | 0 a 0,05 | Atraso até a guarda valer (0 = imediata) |
| `whiff_lockout` | 0,25 | 0,15 a 0,40 | Recuperação de defesa após parry em falso |
| `block_recovery` | 0,15 | 0,10 a 0,25 | Travamento curto depois de bloquear (esquiva cancela) |
| `block_damage_ratio` | 0,20 | 0 a 0,5 | Dano que passa pela defesa normal |
| `block_pushback` | 0,20 m | 0 a 0,5 | Empurrão do bloqueio |
| `guard_move_speed` | 2,5 m/s | 1,5 a 4 | Velocidade andando com a guarda erguida |
| `parry_hitstop` | 0,07 | 0,04 a 0,10 | Congelamento local (jogador e inimigo) no parry |
| `block_hitstop` | 0,03 | 0 a 0,05 | Idem no bloqueio |
| `input_buffer` | 0,10 | 0 a 0,15 | Aperto de defesa durante uma ação não cancelável fica guardado |

**Precisão de tempo:** o instante do aperto é registrado no evento de entrada com relógio em microssegundos, e o instante do contato no passo de física (120 Hz) que o detecta. A comparação usa esses tempos, então o resultado não depende do FPS de render (30, 60 ou 144) e o erro máximo é de um passo de física (8,3 ms). O jogo deve manter **60 FPS estáveis**; nada depende de contar quadros.

## 4. Inimigo de treino ("Instrutor")

Um alvo novo ao lado do boneco atual, **sem IA**: um ciclo fixo de ataque com ritmo configurável. Corpo procedural no mesmo estilo do boneco, com um "braço-lâmina" que gira num pivô; nenhuma animação de terceiros.

```
ESPERA ──► PREPARAÇÃO (sinal) ──► GOLPE (contato) ──► RECUPERAÇÃO ──► ESPERA
                                        │
                     parry perfeito ────┴──► DESEQUILÍBRIO (0,8 s) ──► RECUPERAÇÃO
```

Recurso `EnemyAttackData` (um por tipo de ataque):

| Campo | Inicial | Papel |
|---|---|---|
| `windup` | 0,60 s | Preparação visível |
| `cue_lead` | 0,25 s | O sinal forte acontece este tempo antes do contato |
| `strike_time` | 0,12 s | Movimento ofensivo até o fim do contato |
| `active_start` / `active_end` | 0,06 / 0,12 s (dentro do golpe) | Janela de contato |
| `recovery` | 0,50 s | Recuperação |
| `range` / `arc_deg` | 2,2 m / 90° | Alcance e ângulo do golpe |
| `damage` | 20 | Dano no jogador |
| `posture_damage` | 15 | Pressão na postura do jogador (C2) |
| `parryable` | sim | Reservado para golpes não defensáveis futuros |

Ritmo (no nó do Instrutor): `interval` 1,4 s entre ataques; `jitter` 0 (desligado no início, para aprender); `pattern`: simples (C1.2) e depois "duplo" e "atrasado" (C1.4), para ensinar a não apertar no ritmo cego. O Instrutor sempre se vira para o jogador antes da preparação.

**Sinalização (legível pela câmera alta, com o inimigo a ~10% da tela):**
- Preparação: o braço-lâmina sobe e o corpo acende em âmbar, crescendo até o golpe.
- `cue_lead` antes do contato: um **brilho branco curto** na lâmina e um "tic" sonoro agudo. É o sinal de tempo; o jogador aprende a reagir a ele, e não a adivinhar.
- O golpe tem uma trajetória visível (rastro curto) e um contato que acontece sempre no mesmo ponto do movimento.

## 5. Regras de cancelamento e prioridade

**Prioridade quando duas entradas chegam no mesmo passo:** Esquiva > Defesa > Ataque. A esquiva continua sendo a saída garantida.

| Estado atual | Defesa (K/LB) | Ataque | Esquiva |
|---|---|---|---|
| Correndo / parado | Entra em GUARDA na hora (desacelera para `guard_move_speed`) | Golpe (como hoje) | Esquiva (como hoje) |
| Atacando (Kesa, Kiriage, Tsuki) | Cancela o golpe a partir de `parry_cancel_from`, um campo novo do `StrikeData` (valor inicial igual ao `dodge_cancel_from` de cada golpe); antes disso fica no buffer | Encadeamento (como hoje) | Como hoje |
| Esquivando | Fica no buffer e entra quando a esquiva termina (não interrompe a esquiva) | Buffer (como hoje) | Buffer (como hoje) |
| Recuperação da esquiva | Entra na hora | Como hoje | Como hoje |
| Em GUARDA | Já defendendo | Sai da guarda e golpeia na hora | Sai da guarda e esquiva na hora |
| Recuperação de bloqueio (0,15 s) | Continua defendendo | Buffer | **Cancela na hora** |
| Reação de impacto (0,3 s) | Buffer | Buffer | **Cancela na hora** |
| Recuperação de defesa (parry em falso, 0,25 s) | Só guarda normal, sem janela perfeita | Livre | Livre |

**Direção e mira:** em GUARDA o corpo vira para o inimigo mais próximo à frente (a mesma assistência de mira dos golpes) ou para a direção pressionada. Andar de guarda é permitido.

Os golpes aprovados (Kesa, Kiriage) **não mudam**: o novo campo só acrescenta um ponto de cancelamento por defesa, e o valor inicial é o mesmo da esquiva.

## 6. Feedback visual e sonoro

| Evento | Som (sintetizado, como os atuais) | Visual | Tempo |
|---|---|---|---|
| **Parry perfeito** | Impacto metálico **agudo e longo**: dois parciais inarmônicos (~2,4 e ~3,9 kHz) com decaimento de 0,35 s e um estalo inicial. É o som mais "brilhante" do jogo | Faíscas **direcionais** saindo do ponto de contato, perpendiculares às lâminas; um anel branco pequeno e rápido (0,1 s); brilho na katana; o inimigo recua com a arma jogada para cima | Hitstop local de 0,07 s (jogador e inimigo; câmera e mundo seguem) |
| **Defesa normal** | Batida metálica **mais grave e curta** (~900 Hz, 0,15 s) com baque | Poucas faíscas, sem anel; empurrão curto do jogador | Hitstop de 0,03 s |
| **Golpe recebido** | Baque surdo e grave | Corpo do jogador pisca em vermelho por 0,15 s; reação de 0,3 s | Sem hitstop |
| **Parry em falso** | "Corte no ar" curto e seco | Nada no mundo; o HUD de depuração mostra "EM FALSO" | n/a |
| **Sinal do inimigo** | "Tic" agudo `cue_lead` antes do contato | Brilho branco na lâmina inimiga | n/a |

Sem tremor de câmera no C1. O parry é reconhecido pelo **som e pelas faíscas direcionais**, sem cobrir a tela.

Os contadores de **pressão de postura** (+25 no parry perfeito) e de **Energia Neural** (+10 no parry perfeito) entram no C1 só como números no HUD de depuração; o efeito é do C2 e do C3.

## 7. Especificação da futura quebra de postura (C2, não implementar agora)

Recurso `PostureData`, componente `Posture` no inimigo e, depois, no jogador.

| Item | Proposta inicial |
|---|---|
| Barra de postura do inimigo | 0 a 100 |
| Ganho | Parry perfeito +25; Kesa +8, Kiriage +8, Tsuki +18; contra-ataque +20 |
| Recuperação | Depois de 1,5 s sem pressão, cai 15 por segundo; o desequilíbrio pausa a recuperação |
| **Quebra** (chegou a 100) | Inimigo atordoado por 2,0 s, com sinal visual claro (corpo apaga, joelho no chão); abre a **finalização especial** (C3) |
| Contra-ataque (C2) | Golpe dentro do desequilíbrio do parry: dano e postura maiores, sem custo |
| Postura do jogador | Defesa normal enche a barra do jogador; cheia = guarda quebrada (1,0 s vulnerável). O parry perfeito não enche |
| Energia Neural (C3) | Ganha com parry perfeito, contra-ataque e quebra; gasta em técnicas especiais |

## 8. Critérios de aceitação do C1

Automáticos (testes headless):

1. Contato a +0,00, +0,07 e +0,13 s do aperto = **parry perfeito**; a +0,15 s, segurando = **defesa**; a −0,02 s (aperto depois do contato) = **golpe recebido**.
2. O resultado é o mesmo com render a 30, 60 e 144 FPS (física a 120 Hz).
3. Parry de toque: apertar e soltar em 0,03 s ainda dá parry se o contato vier dentro da janela.
4. Parry em falso aplica a recuperação de defesa; um novo aperto dentro dela só dá defesa normal; esquiva e ataque continuam livres.
5. Esquiva tem prioridade sobre defesa e ataque no mesmo passo; defesa cancela os golpes a partir de `parry_cancel_from`; nenhum estado prende o jogador por mais que o configurado.
6. Os testes atuais (287) passam sem alteração; Kesa e Kiriage seguem com o mesmo SHA-256.
7. Parry perfeito: dano zero, desequilíbrio do inimigo, contadores de postura e Energia somados, hitstop só nos dois participantes.
8. Desempenho: 60 FPS estáveis, sem aumento perceptível do p99 do quadro com o Instrutor em cena.

Humanos (playtest do PO):

9. O sinal do inimigo é legível pela câmera alta.
10. O parry perfeito é difícil o bastante para recompensar e justo o bastante para o jogador entender o erro.
11. O retorno do parry é satisfatório sem atrapalhar a visão.

## 9. Plano incremental de implementação

Cada passo é jogável, tem testes e vira um commit. A sugestão é uma branch nova `feat/c1-parry` a partir da `feat/h2-combate-katana`, já que o C1 usa a infraestrutura do PR #3, ainda sem merge. A ordem das branches é decisão do PO.

| Passo | Entrega | Testes principais |
|---|---|---|
| C1.0 | `DefenseData`, ação "Defesa" no mapa de entrada, `DefenseController` (aperto com relógio em µs, janela, guarda, parry em falso, recuperações) e estado GUARDA no `Player` | Janelas, parry de toque, anti-repetição, prioridades, cancelamentos; contatos simulados sem inimigo |
| C1.1 | Inimigo "Instrutor": `EnemyAttackData`, ciclo espera → preparação → golpe → recuperação, sinalização, corpo procedural | Fases e tempos do ciclo; o sinal acontece `cue_lead` antes do contato; ritmo configurável |
| C1.2 | Resolução do contato: golpe inimigo contra o jogador → parry, defesa ou golpe recebido; vida do jogador só para treino (sem morte); reação de impacto | Os três resultados com o inimigo real; um resultado por golpe; esquiva escapa do golpe |
| C1.3 | Feedback: sons sintetizados, faíscas direcionais, anel, hitstop local, desequilíbrio do inimigo, contadores de postura e Energia no HUD | Hitstop só nos participantes; desequilíbrio atrasa o próximo ataque |
| C1.4 | Ferramentas de treino: desvio em ms no HUD, padrões "duplo" e "atrasado", modo lento para aprender | Padrões e ajustes |
| C1.5 | Capturas, vídeo, playtest em janela e desempenho; relatório e checklist | Regressão completa |

Arquivos previstos: `game/combat/defense_data.gd`, `defense_controller.gd`, `enemy_attack_data.gd`, `training_instructor.gd`; extensões pequenas em `player.gd`, `combat_effects.gd`, `generated_sounds.gd`, `input_setup.gd`, `debug_hud.gd` e `strike_data.gd` (só o novo campo). Nenhuma reescrita do sistema atual.

## 10. Checklist de playtest humano (para quando o C1 existir)

1. Dá para ler, pela câmera de jogo, **quando** o Instrutor vai atacar? O brilho e o "tic" ajudam a acertar o tempo?
2. O parry perfeito parece **justo**: quando você erra, entende se foi cedo ou tarde?
3. O parry perfeito parece **recompensador**: som, faíscas e reação do inimigo dão vontade de acertar de novo?
4. O retorno atrapalha a visão em algum momento?
5. A defesa normal é uma opção segura, mas claramente pior que o parry?
6. Apertar a defesa sem parar é punido o suficiente, sem ser frustrante?
7. Defender, atacar e esquivar se misturam sem travar? Alguma vez você ficou preso?
8. A esquiva continua sendo a saída confiável, mesmo no meio da defesa?
9. Andar de guarda e virar para o inimigo funcionam bem?
10. A janela de 0,14 s parece fácil, justa ou difícil demais? (Sugira 0,12, 0,14 ou 0,16 s)
11. Depois de alguns minutos, dá vontade de dominar o parry?

## 11. Decisões pendentes do PO

1. **Aprovar esta proposta** para iniciar o C1.0.
2. **Controle de defesa:** K/LB (recomendado) ou botão direito do mouse (exige mover o giro da câmera).
3. **Branch:** `feat/c1-parry` empilhada sobre a do PR #3 (recomendado) ou esperar o merge do PR #3.
4. O **Tsuki** segue em avaliação; o C1 não depende dele.
