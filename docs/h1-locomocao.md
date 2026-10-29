# H1: locomoção humanoide

Branch `feat/h1-locomocao-humanoide`. Data: 28/10/2026.

**Estado: implementado e testado por script. NÃO aprovado.** A aprovação depende de o PO jogar e avaliar a naturalidade corporal, a postura do ninja e a fluidez das transições (checklist no §9). Nada aqui afirma equivalência com Dinghai.

## 1. Merge do Marco 1

| Item | Resultado |
|---|---|
| PR | [DTyr3x/Cyblade#1](https://github.com/DTyr3x/Cyblade/pull/1), estado `MERGED` |
| Método | merge commit (**sem squash**, sem force push, sem reescrita de histórico) |
| SHA de integração | `b25d0cc3582ae2e0f7c04ed0407327e1dcd07b82` |
| Commits preservados | 16 commits individuais do Marco 1 + o commit de merge (17 desde a fundação `2d6f8c2`) |
| Antes do merge | PR `MERGEABLE`, estado `CLEAN`; 95 testes: 95 ok, 0 falhas |
| Depois do merge | `main` local atualizada por `git pull --ff-only`; a `main` contém a correção `cce315f` (fluidez da esquiva); 95 testes: 95 ok, 0 falhas |

## 2. O que foi construído

O ninja de primitivas foi trocado por um **humanoide com `Skeleton3D` de 65 ossos**, animado por um `AnimationTree`. A cápsula do Marco 1 (`Player`, `PlayerTuning`, `MotionMath`) **não foi alterada**: o visual só lê velocidade e estado.

| Arquivo | Função |
|---|---|
| `game/player/humanoid_visual.gd` | Instancia o modelo, monta o `AnimationTree` (BlendSpace1D + escala de tempo), liga modificador e katana |
| `game/player/humanoid_pose_modifier.gd` | `SkeletonModifier3D`: inclinação por velocidade e curva, braço da katana, investida da esquiva |
| `game/player/katana.gd` | Katana procedural (primitivas), presa ao osso `hand_r` |
| `tools/anim_sheet.gd` / `.ps1` | Folhas de contato com capturas reais da locomoção (entrada simulada) |
| `assets/characters/ual/UAL1_Standard.glb` | Modelo e animações CC0 (ver `docs/ativos/registro.md`) |

### Regra central: a animação nunca atrasa o controle

- `Player._process` chama `visual.update_pose(velocidade, estado)`. Nada volta do visual para a cápsula.
- O ponto de mistura do ciclo de passada é a **velocidade real** da cápsula no mesmo quadro. Não há suavização no ponto de mistura (testado: `erro máx` ≤ 0,05 m/s).
- A transição esquiva → corrida continua a da cápsula (aprovada pelo PO). O visual não introduz freada: o ciclo de corrida segue o tempo todo (testado).

### Como cada comportamento foi montado

| Comportamento | Implementação |
|---|---|
| Idle, andar, correr | `AnimationNodeBlendSpace1D` com Idle (0), Walk (0,77), Jog (5,46) e Sprint (8,25), eixo = velocidade em m/s |
| Corrida a 6 m/s | Jog tocando a 1,10× (velocidade de reprodução = velocidade real ÷ velocidade de autoria), até 1,25× antes de misturar com Sprint. Evita misturar passadas de ritmos diferentes |
| Pés sem deslizar | Calibração dos clipes (ver §6): Walk 0,77 e Jog 5,46 m/s, medidos pela velocidade do pé em apoio |
| Postura de espadachim | O braço direito é conduzido para uma direção-alvo (para trás, ligeiramente para fora); a katana segue a mão. Peso mínimo de 0,55 mesmo parado (nunca como bengala), 1,0 na corrida |
| Inclinação do corpo | Tronco e quadril inclinam para a frente com a velocidade (+6°) e para o lado nas curvas (até 9°) |
| Esquiva (investida) | Ciclo de Sprint + inclinação extra de 26° e braço da katana para trás, com entrada em 0,03 s e saída em 0,09 s |
| Partida, parada e giro | Não há clipes: o corpo gira a 1080°/s (cápsula), a mistura segue a velocidade. A parada passa de Jog a Idle em < 0,2 s (testado) |

## 3. Animações do pacote

O pacote tem **43 clipes**; **4 são usados**:

| Clipe | Uso |
|---|---|
| `Idle` | Parado |
| `Walk` | Andar com stick analógico parcial |
| `Jog_Fwd` | Corrida (6 m/s a 1,10×) |
| `Sprint` | Investida da esquiva |

Os outros 39 não são usados no H1. Conferido no arquivo baixado:

- **Existem:** idle, andar, jog, sprint, `Sword_Idle`, `Sword_Attack`, `Roll`, `Hit_*`, `Death01`, etc.
- **Não existem** nesta versão (Standard): locomoção em 8 direções (só frente), clipes de partida, parada e giro, e dash. Nada foi inventado: partida, parada e giro são resolvidos pelo controle e pelos ajustes procedurais.
- **`Roll` foi testado e descartado** como esquiva: comprimido a 0,35 s vira uma cambalhota acrobática de corpo invertido, sem relação com a investida baixa de Dinghai. O resultado visual foi gravado em captura de teste. A investida atual é o ciclo de Sprint com inclinação procedural; **não é um clipe do pacote**, é um ajuste nosso.

## 4. Comparação com a locomoção observável de Dinghai

Base: `docs/direcao-movimento-combate.md` (gravações de 28/10/2026, ~24 quadros únicos por segundo, personagem a ~10% da tela). **Medições de Dinghai têm ±33 a ±67 ms; a comparação visual é qualitativa.**

| Característica observada em Dinghai | CYBLADE no H1 | Avaliação honesta |
|---|---|---|
| Corrida de espadachim: tronco inclinado, passada longa, espada para trás | Tronco +6° sobre a inclinação do clipe, katana para trás quase horizontal (capturas) | **Direção certa.** A passada é a de um jog genérico do pacote, não a de Dinghai; só o PO pode julgar a semelhança |
| Parada quase imediata, com pose de prontidão | Parada em < 0,2 s (Jog → Idle), sem pose de prontidão | **Falta:** a parada mostra o Idle, não uma pose baixa |
| Virada de ~90° em ≤ 0,13 s, sem pivô | Corpo completa 90° em ~0,08 s; sem clipe de virada | **Equivalente no tempo.** O corpo roda como um bloco com inclinação lateral; não há transferência de peso visível |
| Casaco, capa e cachecol que balançam | Não há | **Falta.** Possível com `SpringBoneSimulator3D` (H2) |
| Investida de esquiva baixa, com fumaça | Investida com sprint e 26° de inclinação, sem fumaça nem rastro | **Parecida na silhueta**, sem VFX |
| Terreno irregular | Não há IK de pés (ver §7) | **Falta.** Pés atravessam ~4 cm da rampa no pior apoio |
| Postura parada ereta e relaxada, espada baixa | Idle do pacote com katana baixa e para trás | **Parecida em intenção** |

## 5. Resultados dos testes

Comando: `tools\run_tests.ps1` (headless, 120 ticks/s, entrada simulada). **133 verificações, 0 falhas:** as 95 originais do Marco 1 (sem mudar nenhuma tolerância) e 38 novas do H1.

| Área (novas, H1) | Verificações |
|---|---|
| Esqueleto e ativos | 65 ossos; 23 ossos humanoides obrigatórios; os 4 clipes de locomoção existem; `AnimationTree` ativo; modificador ligado ao esqueleto; katana em `hand_r`; pés acima do piso |
| Parado | Animação em Idle |
| Corrida → parada | Animação = velocidade da cápsula (erro máx < 0,05 m/s); Jog puro a 1,10×; postura de espadachim > 95%; chega a Idle em < 0,2 s; sem salto brusco no ponto de mistura; postura de corrida se desfaz |
| Corrida → giro → corrida | 45° e 90°: giro do corpo em < 0,2 s; corrida não para (mínimo > 60% da velocidade); animação segue em corrida; volta à velocidade máxima |
| Giro de 180° | Corpo em < 0,25 s; volta à velocidade máxima |
| Corrida → esquiva → corrida | Pose de investida aparece (> 0,8); ciclo de Sprint; velocidade da cápsula não cai (≥ 95%); animação segue em corrida (> 90%); investida se desfaz |
| Esquiva sem direção | Pose de investida; volta ao Idle e a MOVE |
| Rampa | O corpo sobe; animação segue a velocidade horizontal |
| Deslize dos pés | Houve apoios medidos; deslize médio < 1,0 m/s |

Ressalvas: os testes verificam a lógica, os tempos e a coerência do esqueleto, **não a beleza do movimento**. O teste de 180° não exige corrida contínua porque a inversão de sentido passa por velocidade baixa por regra de controle (~0,2 s), já aprovada no Marco 1.

## 6. Deslize dos pés (medição)

Medido em corrida constante a 6 m/s: velocidade horizontal **no mundo** do osso do tornozelo enquanto está a menos de 3 cm do ponto mais baixo (apoio). Pé parado no chão = 0.

| Configuração | Deslize médio em apoio |
|---|---|
| Mistura Jog + Sprint com eixo = velocidade (primeira versão) | 3,74 m/s |
| Sprint deslocado para 12 m/s | 1,95 m/s |
| Sprint deslocado para 20 m/s | 1,17 m/s |
| **Jog puro a 1,10× (atual)** | **0,57 m/s** (p95 2,34 m/s) |

0,57 m/s é ~10% da velocidade de corrida. O p95 vem das fases de apoio e saída do pé (o tornozelo ainda está baixo mas já se move). **Não é zero:** o pé ainda desliza um pouco, principalmente na saída de cada passada. Sem IK de pés e com um clipe genérico, é o que se obtém; só o PO pode dizer se incomoda.

## 7. IK para rampas e desníveis (avaliação)

**Medido:** altura do tornozelo acima do chão local durante os apoios (percentil 10), corrida de 6 m/s.

| Terreno | Tornozelo no apoio (p10) | Mínimo |
|---|---|---|
| Plano | 0,130 m | 0,117 m |
| Rampa de 21°, subindo | 0,047 m | −0,005 m (4 ticks em 300 abaixo da superfície) |
| Rampa, descendo | 0,105 m | 0,047 m |

Em subida, o tornozelo fica ~8 cm mais baixo que no plano, ou seja, a sola atravessa ~4 a 5 cm a rampa no pior apoio. Em descida o pé fica ~2,5 cm mais baixo.

**Tentativa:** montei um `TwoBoneIK3D` (novo no Godot 4.6) por perna, com alvo calculado por raycast e peso que cai com a altura do pé. Em 4.7.2 o solver **não moveu os ossos** nos testes (alvo 30 cm acima, influência 1,0, o pé permaneceu parado, com e sem polo). Não consegui descobrir o requisito de configuração que falta no tempo disponível. **Removi o código** em vez de deixar IK sem efeito e custo.

**Decisão:** não entregar IK no H1. O atravessamento é pequeno e restrito a rampas íngremes. **Próximo passo (H2):** solver analítico de duas ossos próprio (comprimentos de coxa e canela, ajuste do quadril), ou investigar o requisito do `TwoBoneIK3D`.

## 8. Desempenho

Playtest scriptado em janela (`tools\playtest.ps1`, 1920×1080, `--disable-vsync`, entrada simulada, 50 s, capturas de tela excluídas das estatísticas), com o humanoide animado:

| Trecho | Quadros | FPS médio | Quadro p99 | 1% baixo | Render GPU médio | Render CPU médio | Quadros > 25 ms |
|---|---|---|---|---|---|---|---|
| Andar (teclado) | 460 | 117,0 | 8,69 ms | 115,0 | 0,41 ms | 0,15 ms | 0 |
| Círculo (teclado) | 948 | 117,0 | 8,72 ms | 114,7 | 0,41 ms | 0,17 ms | 0 |
| Esquivas | 831 | 117,0 | 8,76 ms | 114,1 | 0,43 ms | 0,16 ms | 0 |
| Gamepad (simulado) | 492 | 117,0 | 8,80 ms | 113,6 | 0,43 ms | 0,16 ms | 0 |
| Rampa e plataforma | 677 | 116,9 | 9,14 ms | 109,4 | 0,44 ms | 0,16 ms | 0 |
| Câmera combate | 467 | 117,0 | 9,10 ms | 109,8 | 0,43 ms | 0,16 ms | 0 |
| Câmera exploração | 461 | 115,4 | 8,70 ms | 115,0 | 0,42 ms | 0,16 ms | 1 |
| Câmera chefe | 461 | 115,5 | 8,72 ms | 114,7 | 0,43 ms | 0,17 ms | 1 |

- **FPS ~117 é o teto externo já registrado** (pendência 5 do Marco 1), não a capacidade da máquina. Os valores de quadro são os mesmos de antes do H1.
- **Render:** GPU ~0,43 ms, CPU ~0,16 ms. Não incluem o custo de animação.
- **Linhas de log com `ERROR`, `WARNING` ou `SCRIPT` no playtest:** **0**
- **Pico de ~63 ms** (um quadro) ao trocar para os enquadramentos exploração e chefe: o mesmo registrado no Marco 1, não é do H1.
- **Esquivas medidas em jogo:** 3,95 a 3,99 m, deslocamento 0,239 a 0,248 s, total 0,419 a 0,427 s: iguais às do Marco 1.

**Custo de animação (monitor de desempenho do Godot, média em corrida, 1 personagem):** o tempo de processamento de física sobe de 0,22 ms para ~1,7 ms com `AnimationTree` + modificador ativos. Medindo separadamente: o `AnimationTree` sozinho não é distinguível de ruído (0,22 → 0,29 ms); o script do modificador custa ~36 µs por quadro; o restante (~1,4 ms) é o custo do próprio pipeline de modificadores do esqueleto na engine. **É suficiente para 1 jogador** (8,3 ms de orçamento a 120 fps), mas com 10 inimigos usando o mesmo pipeline seria um problema. Registrado em riscos; investigação e mitigação são do H2 (modificadores só no jogador, inimigos só com `AnimationTree`).

## 9. Checklist de playtest humano (PO)

Abra com `Jogar.bat`. Aperte **F3** para ver o HUD. A câmera é a de combate; use as teclas **1, 2, 3** para os outros enquadramentos. Responda sim/não e, quando "não", diga onde e como.

**Correr e parar**
1. Aperto W e o personagem parte **na hora**, sem atraso entre a tecla e a corrida?
2. A corrida parece a de um espadachim (corpo inclinado, katana para trás), e não de um boneco?
3. Os pés parecem **presos ao chão** ou escorregam?
4. Ao soltar W, a parada é natural e sem tranco?

**Giros**
5. Em corrida, giros de 45° e 90° (W e depois A ou D) acontecem sem o corpo parecer travar?
6. O giro de 180° (D e depois A) fica convincente, ou o personagem parece "inverter de repente"?
7. A inclinação nas curvas ajuda ou incomoda?

**Esquiva**
8. Correndo e apertando **Espaço** ou **Shift**: a investida parece uma esquiva natural?
9. Ao terminar a esquiva, o personagem volta à corrida **sem pausa** (continua aprovado)?
10. Esquiva parado: a pose comunica o movimento?

**Rampa**
11. Subindo e descendo a rampa, os pés atravessam o chão de forma que incomoda?

**Postura**
12. A katana (cilindro simples) está na posição certa? Parece segura na mão?
13. O **corpo é visível o suficiente** na câmera alta (material provisório mais claro)?

**Geral**
14. Em comparação com o Marco 1 (ninja de primitivas), o movimento parece mais "vivo"? E o controle continua tão responsivo quanto antes?
15. Em relação à locomoção de Dinghai, o que **mais** falta para chegar perto?

## 10. Limitações e próximos refinamentos

| Limitação | Efeito | Refinamento |
|---|---|---|
| Sem clipes de partida, parada e giro (não existem no pacote Standard) | Transições entre Idle e corrida são só mistura de ciclos; falta transferência de peso | H2: clipes autorais no Blender, ou pacote com locomoção direcional/transições |
| Deslize residual dos pés (0,57 m/s médio) | Pés ainda deslizam um pouco, sobretudo na saída da passada | H2: ajuste fino de ritmo, IK de pés |
| Sem IK em rampas | ~4 cm de atravessamento no pior apoio de uma rampa de 21° | H2: solver próprio ou investigar `TwoBoneIK3D` |
| Pose da katana procedural | Braço dirigido por código, sem animação de punho nem de ombro autoral; bloom deixa a lâmina estourada em alguns quadros | H2: animação autoral; material da lâmina |
| Sem casaco, cachecol, cabelo | Silhueta de manequim genérico | H2: `SpringBoneSimulator3D`; modelo definitivo |
| Modelo é o manequim genérico do pacote | Não representa o ninja | Marco 2 |
| Investida da esquiva é ajuste nosso, sem clipe | Visual simples, sem fumaça nem rastro | H2/Marco 2: VFX e pose autoral |
| Custo do pipeline de modificadores (~1,4 ms) | Escala mal com muitos personagens | H2: modificadores só no jogador |
| Corpo escuro na câmera alta | Pouco contraste com o piso | Material provisório mais claro e com leve emissão; direção de arte no Marco 2 |
| Teto externo de ~117 FPS e pico de ~63 ms ao trocar enquadramento | Não medem o custo real nem o H1 | Pendências 2 e 5 do Marco 1 |
| Teste humano com gamepad físico não feito | Só eventos simulados | Pendência 4 |
