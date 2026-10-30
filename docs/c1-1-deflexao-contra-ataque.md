# C1.1: deflexão autoral do parry e contra-ataque de oportunidade

Status: **implementado e testado por script. NÃO aprovado: depende do playtest humano do PO.**
Branch `feat/c1-parry` (depende do H2 do PR #3, ainda sem merge). Sem PR e sem merge. Não modifiquei `feat/h2-combate-katana`. O C1.0 (aprovado, janela de 0,14 s) é base protegida e **nenhum valor dele foi alterado**; Kesa, Kiriage e Tsuki continuam idênticos (SHA-256 conferido por teste).

## 1. Aprovação do C1.0

Registrada em `docs/c1-parry.md` ("Aprovação do PO": 9 de 9 critérios, sem ressalvas, janela de 0,14 s mantida) e no histórico da branch (commit `8b54058`).

## 2. Deflexão autoral do parry perfeito

Animação curta (0,30 s), original, feita no Blender com IK (`tools/blender/katana_deflect_keys.py` → `assets/animations/katana/katana_deflexao.res`).

| Fase | Tempo desde o contato | O que o corpo faz |
|---|---|---|
| Impacto | 0 a 0,03 s | As lâminas se encontram: as mãos recuam e cedem, o tronco absorve. **O jogo congela o corpo aqui** durante o hitstop de 0,07 s (o "choque" fica visível) |
| Desvio | 0,03 a 0,15 s | O tronco gira para a direita (de +10° a −26°), os ombros conduzem, as mãos varrem do peito-esquerda ao quadril-direita e a lâmina desce em arco empurrando a arma inimiga para fora |
| Pronto | 0,15 a 0,30 s | Assenta com a lâmina à frente, na altura do quadril, mãos no quadril direito, peso à frente |

- **Só tronco, cabeça e braços** (como a guarda): as pernas seguem a locomoção. Dá para correr ou esquivar durante a deflexão, sem bloqueio.
- **Sincronia:** a deflexão começa no mesmo passo do parry, junto com o som, as faíscas e o congelamento. O ponto de contato das faíscas é agora o ponto real entre a katana do jogador e a lâmina do Instrutor (menor segmento entre as duas). Medido no jogo: **0,18 m da katana do jogador e 0,19 m da lâmina do Instrutor**.
- **Saída:** a pose de pronto segura 0,20 s e solta a mistura em 0,12 s. Se o jogador pressionar J, esquivar ou correr, a deflexão cede na hora.
- A guarda do C1.0 é a mesma (pose, janela, defesa normal), só que no parry perfeito o clipe de deflexão toma o lugar da pose estática.

## 3. Contra-ataque de oportunidade

**Três partes separadas**, em `DefenseData` (todas em arquivo editável, com os valores do C1.0 intactos):

| Parte | Campo | Valor | Regra |
|---|---|---|---|
| **Janela** | `counter_window` | 0,80 s | Tempo depois do parry perfeito. É independente do desequilíbrio do Instrutor (`off_balance`, 0,80 s): os dois tempos podem ser ajustados separadamente |
| **Elegibilidade** | `counter_requires_perfect` | sim | Só o parry perfeito abre a oportunidade. Defesa normal, golpe recebido e parry em falso não abrem |
| **Consumo** | `counter_charges` | 1 | Um parry rende um contra-ataque. A oportunidade é gasta **quando o contra-ataque começa** (acertando ou errando) ou quando o tempo acaba. A esquiva não a gasta |

- **Manual:** o jogador aperta **J**. Sem J, nada acontece (testado: depois de 0,8 s a oportunidade expira sem nenhum golpe).
- **Contra-corte** (`katana_contra.res`, `tools/blender/katana_counter_keys.py`): corte horizontal curto e rápido, da direita para a esquerda, na altura do peito, com passo curto e giro de quadril. Nasce da pose de pronto em que a deflexão termina (primeira pose igual à última da deflexão). 0,37 s no total: contato de 0,08 a 0,17 s, esquiva cancela desde 0,03 s, livre para mover desde 0,23 s, avanço 0,7 m, dano 30, hitstop 0,09 s. Sem tremor de câmera, sem partículas extras: usa os efeitos de impacto leve que já existem.
- **Resposta imediata:** o J apertado no hitstop do parry fica guardado e o contra-corte sai logo depois do congelamento (testado, nada se perde).
- **Prioridade:** esquiva > defesa > ataque, como antes. Esquiva e J no mesmo passo: a esquiva vence, e a oportunidade continua disponível.
- **Combo atual preservado:** fora da oportunidade o J faz a cadeia normal (Kesa → Kiriage → Tsuki), exatamente como antes. O contra-corte **não faz parte da cadeia** (`ComboSet.counter_strike`, separado de `strikes`). Dentro da oportunidade, o J gasta a oportunidade e executa o contra-corte em vez do Kesa. Um segundo J na mesma janela vira Kesa (sem contra-ataque grátis). Depois do contra-corte, a próxima cadeia recomeça no Kesa.
- **Sem dano duplicado:** o contra-corte usa o mesmo detector de acerto (um acerto por alvo por golpe).
- **Abertura legível:** enquanto a oportunidade está aberta, o **visor do Instrutor passa de ciano a branco** (discreto, sem partículas), e o HUD (F3) mostra "ABERTURA x,xx s: J contra-ataca" e a contagem de aberturas abertas, usadas e expiradas.

## 4. Princípio de design respeitado

O parry perfeito continua recompensador por si só (dano zero, deflexão, som, faíscas, desequilíbrio). O contra-ataque é uma **escolha**: dá para ignorar a abertura, atacar normalmente, esquivar ou se reposicionar; nada é automático.

## 5. Arquitetura

| Parte | Arquivo |
|---|---|
| Janela, elegibilidade e consumo (dados) | `game/combat/defense_data.gd` (grupo "Contra-ataque de oportunidade") |
| Oportunidade (lógica pura) | `game/combat/defense_controller.gd` (`grant_opportunity`, `consume_opportunity`, `update_opportunity`) |
| Contra-golpe fora da cadeia | `game/combat/combo_set.gd` (`counter_strike`), `combat_controller.gd` (`start_counter`) |
| Entrada e consumo | `game/player/player.gd` (`_try_start_attack`) |
| Deflexão no AnimationTree | `game/player/humanoid_visual.gd` (seletor guarda/deflexão, `play_deflect`) |
| Ponto de contato real | `Player._contact_point` + lâmina do Instrutor (`blade_base`, `blade_tip`) |
| Clipes autorais | `tools/blender/katana_deflect_keys.py`, `katana_counter_keys.py` (pipeline Blender existente) |

## 6. Testes

- **Suíte principal:** **376 verificações, 0 falhas.** As 331 anteriores (C1.0, H2, H1) não foram tocadas; **45 são novas**:
  - lógica pura da oportunidade: janela, elegibilidade, consumo, expiração;
  - integridade: SHA-256 de Kesa, Kiriage, Tsuki e da guarda; janela de 0,14 s; cadeia de 3 golpes;
  - deflexão: começa no passo do parry, congela no hitstop e continua depois, fica visível com o botão solto;
  - sincronia: som e faíscas no mesmo passo, ponto de contato junto às duas lâminas;
  - transições da deflexão: → corrida, → esquiva e → contra-ataque;
  - contra-ataque só com parry perfeito (não com defesa normal nem golpe recebido), sem J nada acontece;
  - consumo único e expiração;
  - dentro e fora do alcance; um acerto só, dano 30;
  - prioridade da esquiva; buffer e hitstop;
  - contra-ataque → esquiva → corrida.
- **Variação de FPS** (`tools\run_parry_fps.ps1`): parry, defesa, golpe recebido e agora o contra-ataque (J a +0,20 s = contra-corte; J a +0,95 s, fora da janela, = cadeia normal), com render a **30, 60 e 144 FPS**: **resultado idêntico nos três**.

## 7. Desempenho

Playtest em janela, 1080p, VSync desligado, 3 execuções, com o roteiro de parry → contra-ataque. **O Phantom Blade Zero estava fechado** (primeira medição limpa desde o H2.2).

| Execução | FPS no trecho de defesa | p99 do quadro | Pior quadro | Quadros acima de 25 ms | GPU média |
|---|---|---|---|---|---|
| 1 | 1444 | 1,9 ms | 4,4 ms | 0 | 0,46 ms |
| 2 | 1479 | 2,3 ms | 8,5 ms | 0 | 0,48 ms |
| 3 | 1488 | 2,2 ms | 5,0 ms | 0 | 0,49 ms |

O trecho de movimento puro das mesmas execuções ficou em 1467 a 1549 FPS, ou seja, a deflexão e o contra-ataque não pesam. Em cada execução: 2 parries perfeitos, 2 defesas normais, 2 contra-ataques, 2 acertos no Instrutor. Esquivas de 3,95 a 3,99 m. Os números anteriores (~200 FPS) eram com o Phantom Blade Zero aberto, que dominava a GPU e a CPU. Dados: `docs/c1-1/desempenho-resumo.csv`.

**Ocorrência:** de novo, a segunda execução seguida terminou sem gravar resultados e sem estourar o tempo; repetida sozinha, concluiu. É o mesmo comportamento já registrado (pendência 17).

## 8. Evidências

- `docs/c1-1/estudo/deflexao_e_contra.png`: poses da deflexão (quadros 0, 2, 5, 9, 18) e do contra-corte (0, 4, 8, 11, 22), de frente e de lado.
- `docs/c1-1/capturas/`: **parry → deflexão → contra-ataque** e **parry → esquiva → corrida**, de lado e pela câmera de jogo (`c11_01_...`, `c11_02_...`). Entrada simulada.
- **Vídeos reais**, fora do repositório pelo tamanho (AVI MJPEG 960x540 a 60 FPS; abra no VLC):
  - `C:\Cyblade\_videos\c11_parry_contra_lado.avi` (44 MB, câmera lateral);
  - `C:\Cyblade\_videos\c11_parry_contra_jogo.avi` (57 MB, câmera de jogo, com HUD).
  - Os dois mostram o Instrutor atacando, o parry com a deflexão, o contra-corte e depois parry → esquiva → corrida. Conferi o lateral montando quadros dele. Na segunda sequência a câmera lateral segue o ponto médio entre os dois, então quando o jogador corre para longe ele sai de quadro.

## 9. Limitações

- A deflexão é uma pose de 0,30 s por IK, sem captura de movimento; ombros e punhos têm pouca sutileza.
- O contra-corte tem um só movimento; não há variação por direção do golpe inimigo.
- O contato visual usa o menor segmento entre as lâminas: se o jogador estiver girado ou longe, o ponto cai para o peito.
- O brilho do visor é a única indicação visual da abertura (pequena de cima); o HUD ajuda em treino.
- Sons e efeitos continuam sintetizados e provisórios.
- Postura, quebra de postura e Energia Neural seguem só como contadores (C2/C3, não iniciados).

## 10. Checklist de playtest humano

Fique a uns 2 m do Instrutor (à direita do boneco). K (ou LB) = defesa/parry, J = ataque/contra-ataque, Espaço = esquiva, F3 = HUD com a abertura.

1. **Deflexão:** no parry perfeito você realmente vê o ninja **mover a espada** para desviar o golpe, e não só uma pose com efeitos?
2. O **contato visual** das lâminas coincide com o som, as faíscas e o congelamento?
3. A deflexão é **legível pela câmera alta**?
4. **Contra-ataque:** depois do parry, o J sai **na hora**? O contra-corte parece uma continuação natural da deflexão?
5. O contra-corte tem **identidade própria** e é rápido, sem ser exagerado?
6. A **abertura** (visor branco) é fácil de notar? A janela de 0,8 s parece boa?
7. Ignorar a abertura é uma opção livre? Nada acontece sozinho?
8. **Parry → esquiva → corrida:** continua fluido, sem pausa?
9. Atacar, esquivar e defender durante a abertura se misturam sem travar? Alguma vez o J virou contra-ataque quando você não queria?
10. O feedback do contra-ataque é satisfatório sem excesso de efeitos?
11. Você sente a sequência: **"li o ataque, acertei o momento, desviei a arma e aproveitei a oportunidade"**?
