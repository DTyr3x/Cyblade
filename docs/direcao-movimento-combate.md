# Direção de movimentação e combate: referência Dinghai

Estudo para decisão do PO. Data: 28/10/2026. **Nada foi implementado.**

Referência: *Dinghai: The Ocean Pillar* (JUSTDAN, demo app 4654720). Ela é usada **apenas** como estudo de comportamento observável e de critério de qualidade. Não usamos código, modelos, animações, arquivos ou outros recursos da demo, e não fazemos engenharia reversa (Steam Subscriber Agreement §2.G).

## Legenda

| Marca | Significado |
|---|---|
| **[MEDIDO]** | Lido direto de quadro de vídeo ou de arquivo, com a incerteza indicada |
| **[ESTIMADO]** | Derivado com suposições declaradas |
| **[OBSERVADO]** | Qualitativo, visto nas gravações |
| **[PÚBLICO]** | Afirmado por fonte pública, sem confirmação nossa |
| **[DESCONHECIDO]** | Não determinável com as evidências atuais |
| **[DESIGN]** | Decisão ou proposta nossa, não vem de Dinghai |

### Fontes

- 7 gravações próprias de 28/10/2026, somando ~216 s. São 5 em 3838×~2150 a 30 fps nominais (~24 quadros únicos/s) e 2 em 2560×1440.
  - Elas já foram analisadas no relatório `C:\Cyblade\pesquisa-dinghai\relatorio.html`.
  - Nesta tarefa, fiz novos recortes de locomoção e de investida: `pesquisa-dinghai\evidencias\loc_corrida_virada.jpg` e `loc_investida_idle.jpg`.
- Página da Steam ([app 4542740](https://store.steampowered.com/app/4542740/Dinghai_The_Ocean_Pillar/)): "Dual Weapon Combat System" e troca livre entre dois tipos de arma durante o combate.
- Comentários públicos de jogadores da demo: [discussão na Steam](https://steamcommunity.com/app/1627720/discussions/0/3820788693475660222), [itch.io](https://itch.io/post/15723331) e [wiki incompleta](https://thegameswiki.com/dinghai-the-ocean-pillar/wiki/combat). Não são fontes oficiais.
- Godot 4.7.2: classes e métodos **verificados no executável instalado** via `ClassDB`, além da documentação oficial.

### Limite da análise visual

O personagem ocupa ~10% da altura da tela. As gravações têm ~24 quadros únicos por segundo, ou seja, ±33 a ±67 ms por medida, e não registram a entrada do controle. Por isso:
- **contato dos pés, ciclo de passada e latência não são mensuráveis com confiança**;
- movimentos de quadril e ombro aparecem só de forma grosseira.

Para medir esses itens é preciso uma nova gravação a 120 fps, mais próxima e com overlay de entrada (ver §9).

---

## 1. Características observáveis de Dinghai

### A. Locomoção

| Característica | O que se vê | Marca |
|---|---|---|
| Corrida | Tronco inclinado à frente (~15–25°), passada longa e joelhos altos. A espada vai **numa mão, estendida para trás** na horizontal, como corrida de espadachim, não de pessoa comum | [OBSERVADO] r3 9,50–10,30 s; ângulo [ESTIMADO] |
| Velocidade de corrida | ~5–7 m/s | [ESTIMADO] (relatório anterior) |
| Aceleração | ≤ ~0,15 s até a velocidade máxima | [ESTIMADO] |
| Parada | Quase imediata, emendando numa **pose baixa de prontidão/ataque** | [OBSERVADO] r3 11,1–11,3 s |
| Virada em corrida (~90°) | Concluída em ≤ ~0,13 s, **sem pausa nem animação de pivô visível**; a corrida continua | [MEDIDO] ±67 ms, r3 9,87→10,00 s; ângulo [ESTIMADO] |
| Viradas de 45° e 180° isoladas | Não há trecho limpo nas gravações | [DESCONHECIDO] |
| Corrida lateral (strafe) | Não observada; ao correr, o corpo aponta para o movimento | [DESCONHECIDO] |
| Movimento secundário | Casaco, capa e cachecol balançam atrasados e acompanham as viradas. A opção "Cloth Simulation" existe nas configurações | [OBSERVADO]; opção [MEDIDO] (.ini) |
| Postura parada | Ereta e relaxada, espada baixa ao lado do corpo | [OBSERVADO] cap2 4,75–6,0 s |
| Investida | Disparada agachada e muito baixa, com rastro de fumaça escura e rastro vermelho no cachecol. Termina em ataque carregado | [OBSERVADO] cap2 3,5–4,25 s; r3 9,2–9,47 s |
| Travessia contextual | Aviso "F Hurdle" perto de raízes, ou seja, um salto de obstáculo contextual | [OBSERVADO] r3 ~8,9–9,3 s |
| Rampas e terreno irregular | O terreno é ondulado. O ajuste dos pés (IK) não é distinguível nesta resolução | [DESCONHECIDO] |
| Recuperação após esquiva | Recuo de ~0,23–0,27 s com fumaça, aterrissagem de ~0,1–0,2 s e próxima ação em ~0,43 s no total | [MEDIDO] ±67 ms (relatório anterior) |
| Mudança de direção durante ataque | Cada golpe começa já virado para o alvo, com aparente reorientação no início do golpe | [OBSERVADO] r2; mecanismo [DESCONHECIDO] |

### B. Combate

| Característica | O que se vê | Marca |
|---|---|---|
| Golpe leve | Preparação ≤ ~0,13 s até o contato; o golpe encadeado leva ~0,07–0,10 s | [MEDIDO] ±67 ms |
| Ritmo da cadeia | ~0,53 s entre impactos encadeados | [MEDIDO] |
| Corpo inteiro | Golpes com arco amplo, o corpo **avança em direção ao inimigo** durante o golpe (deslocamento visível) e a pose termina estendida | [OBSERVADO] r2 |
| Ataque carregado | Sinal de "carga pronta" (estrela anamórfica) ~0,47 s após o golpe anterior. Investida e contato em ~0,07 s, rastro vermelho de ~0,3 s **atravessando** o inimigo | [MEDIDO] |
| Troca de arma | Corpo a corpo ↔ arco no meio do combo. Dois tipos por partida | [OBSERVADO] r3 2,3–2,85 s; [PÚBLICO] Steam |
| Quantidade de armas | Cinco tipos (três corpo a corpo e dois à distância), dois escolhidos por partida | [PÚBLICO] wiki incompleta |
| Esquiva | Recuo com fumaça, sem invulnerabilidade visível | [MEDIDO] tempo; i-frames [DESCONHECIDO] |
| Cancelamentos | Indício de esquiva → mira em ≤ 0,2 s após aterrissar. As janelas reais não foram medidas | [DESCONHECIDO] |
| Parry/bloqueio | Não visto nas nossas gravações. Jogadores dizem que existe, que a janela é estreita e que o parry **arremessa o inimigo para longe** | [PÚBLICO] Steam e itch.io; [DESCONHECIDO] nosso |
| Reação de inimigo comum (golpe leve) | Recuo pequeno e clarão branco de ~70–100 ms; quase não se desloca | [MEDIDO] clarão; [OBSERVADO] recuo |
| Reação de elite (golpe forte) | Pose travada por ~0,33–0,37 s, clarão de ~0,1 s e arremesso de ~0,3 s | [MEDIDO] |
| Atordoamento | O arremesso e a pose travada sugerem um estado de atordoamento/quebra, mas a regra não é visível | [DESCONHECIDO] |
| Rastros e partículas | Rastro branco ou de gelo nos golpes leves, vermelho e longo nos carregados; faíscas, bloom forte e números de dano em ~0,07–0,13 s | [MEDIDO] tempos; [OBSERVADO] estilo |
| Câmera no impacto | **Sem tremor** em golpes comuns e carregados (< 0,6% da largura). O impacto vem da luz e das partículas. No chefe, inconclusivo | [MEDIDO] |
| Hitstop | Não separável nesta taxa de quadros: ≤ ~100 ms, se existir | [DESCONHECIDO] |
| Telegrafia | Brilho e mancha vermelha no inimigo e no chão antes do golpe, com opção de exibição | [OBSERVADO]; opção [MEDIDO] |
| Opiniões públicas | "Um pouco travado (clunky)", janela de parry estreita, hitbox de chefe que pega a esquiva | [PÚBLICO] comentários isolados |

### C. Técnicas de animação de Dinghai

**Nenhuma técnica interna de Dinghai é afirmada aqui.** A demo é UE5 ([MEDIDO], metadados), mas não sabemos se usa root motion, motion matching, IK de pés, Control Rig ou montagens. O que se observa é só o resultado: deslocamento nos golpes, viradas sem pausa e tecido simulado. O mesmo resultado pode ser obtido com técnicas diferentes.

---

## 2. O que já existe no CYBLADE

| Item | Estado | Marca |
|---|---|---|
| Corrida responsiva | 6 m/s, aceleração 0,12 s e frenagem 0,08 s (verificados em teste) | [MEDIDO] |
| Giro do corpo | 1080°/s, virada de 90° em ~0,08 s | [MEDIDO] teste / [DESIGN] |
| Esquiva | 4 m em 0,25 s, recarga de 0,18 s, buffer de 0,15 s, i-frames de 0,05–0,20 s e **transição fluida para a corrida** (aprovada pelo PO) | [MEDIDO] |
| Câmera | Combate a 45°/20 m/FOV 34° com jogador em 10,0% da tela, exploração e chefe; atraso τ 0,10 | [MEDIDO] |
| Física | 120 Hz com interpolação; lógica independente do FPS | [MEDIDO] |
| Rampa e plataforma | Sobe e desce | [MEDIDO] |
| Testes | 95 verificações automatizadas e playtest scriptado em janela | [MEDIDO] |
| Personagem | Ninja de **primitivas** com inclinação e agachamento procedurais. Sem esqueleto | [OBSERVADO] |

## 3. O que falta

| Área | Falta |
|---|---|
| Corpo | Personagem humanoide com esqueleto, malha e espada presa à mão |
| Locomoção animada | Parado, andar e correr com passada sincronizada à velocidade (sem pé deslizando), início, parada, virada, inclinação na curva, pés no chão em rampa (IK) e tecido/cachecol |
| Esquiva animada | Pose de esquiva em 0,25 s e aterrissagem que emenda na corrida |
| Combate | Golpes, cadeia, fases (preparação, ativo, recuperação), cancelamentos, carga, troca de arma e parry |
| Acertos | Hitboxes da lâmina, hurtboxes, dano, hitstop e regras de reação |
| Inimigos | Boneco de treino, depois inimigo com IA, telegrafia, reações, atordoamento e arremesso |
| Feedback | Rastro da lâmina, faíscas, clarão, números de dano, som e câmera (FOV, tremor só no pesado) |
| Mira | Seleção de alvo suave (soft-lock) para orientar golpes |

---

## 4. Técnicas recomendadas no Godot 4.7.2

Todas as classes abaixo foram **verificadas no executável instalado** (`ClassDB.class_exists`).

### Decisão central [DESIGN]: a cápsula manda, a animação acompanha

O controle aprovado no Marco 1 continua na cápsula (`CharacterBody3D`), em código, a 120 Hz. **A animação lê o estado do jogador e nunca atrasa a entrada.** Isso:
- preserva o que o PO aprovou;
- mantém tudo testável sem janela;
- evita a principal causa de controle "lento" em jogos com root motion.

O deslocamento de golpes e esquivas vem de **curvas em dados**, como já acontece na esquiva. Elas podem ser extraídas do root motion de uma animação, uma vez, por ferramenta. No jogo, a animação toca no lugar (*in place*).

### Locomoção

| Necessidade | Técnica no Godot | Suporte |
|---|---|---|
| Parado, andar e correr | `AnimationTree` com `AnimationNodeBlendSpace1D` pela velocidade real | Nativo |
| Sem pé deslizando | Velocidade de reprodução = velocidade real ÷ velocidade de autoria do clipe (`AnimationNodeTimeScale`), com `AnimationNodeSync` | Nativo; a regra é nossa |
| Estados (locomoção, esquiva, ataque, reação) | `AnimationNodeStateMachine`. As transições têm `xfade_time`, `xfade_curve`, `priority`, `advance_expression` e `switch_mode` | Nativo |
| Início, parada e virada de 180° | Clipes curtos de sobreposição, **só visuais**: a cápsula já se move no tick da entrada | Nativo + regra nossa |
| Inclinação na curva e no arranque | `SkeletonModifier3D` próprio em GDScript que gira quadril e tronco pela aceleração lateral, ou poses aditivas (`AnimationNodeAdd2`) | Nativo (base); lógica nossa |
| Pés no chão em rampa | `TwoBoneIK3D` (novo no Godot 4.6) por perna, raycast por pé e ajuste da altura do quadril | Solver nativo; raycasts, travamento do pé e quadril são nossos |
| Cabeça e olhar para o alvo | `LookAtModifier3D` | Nativo |
| Casaco, cachecol e cabelo | `SpringBoneSimulator3D`, mais barato que tecido real; `SoftBody3D` só se precisar | Nativo |
| Virada sem pausa | Rotação do corpo em código (já existe) e a animação segue | Já existe |
| Motion matching | **Não existe no Godot.** Só como plugin de terceiros ou implementação própria | Não recomendado agora |

### Combate

| Necessidade | Técnica | Suporte |
|---|---|---|
| Ataques de corpo inteiro | `AnimationNodeOneShot` ou estado da máquina, com mistura de entrada curta (0,03–0,06 s) | Nativo |
| Fases e cancelamentos | **Máquina de combate em código** com tempos em dados (`AttackData.tres`). Os marcadores de animação (`Animation.add_marker`) só conferem que dados e animação batem | Marcadores nativos; lógica nossa |
| Ataque andando (só tronco) | `AnimationNodeBlend2` com filtro de ossos, se a arma pedir | Nativo |
| Avanço do golpe | Curva de deslocamento em dados, aplicada na cápsula (mesmo método da esquiva) | Nosso |
| Hitbox da lâmina | `ShapeCast3D` varrido entre a posição anterior e a atual da lâmina a cada tick (sem "túnel"), com `BoneAttachment3D` na mão | Nativo + lógica nossa |
| Hurtbox | `Area3D` por inimigo, com uma por parte do corpo se precisar | Nativo |
| Hitstop | Escala de tempo **por entidade** (pausa o `AnimationTree` e a cápsula por N ms), nunca `Engine.time_scale` global | Nosso |
| Reações | Clipes de reação mais curva de recuo ou arremesso em dados; ragdoll (`PhysicalBoneSimulator3D`) só para morte, depois | Nativo + nosso |
| Rastro da lâmina | Malha de faixa própria (amostras da ponta e da base da lâmina por tick) com shader de desvanecimento. `GPUParticles3D` para faíscas | Nativo (base); rastro nosso |
| Câmera | O rig atual mais um pequeno avanço de FOV e tremor por "trauma" só no golpe pesado. Dinghai não treme em golpes comuns | Nosso |

---

## 5. Estratégia de produção de animações

**Restrição fundamental:** a qualidade de animação de Dinghai vem de animação humana bem feita, captura ou mão de animador. **Código e IA não substituem isso.** Claude Code e Codex fazem bem integração, dados, máquinas de estado, procedurais, ferramentas e testes, mas não criam movimento humano de qualidade a partir do zero.

| Fase | Fonte | Uso | Licença (confirmar na hora de baixar) |
|---|---|---|---|
| 1. Protótipo | Mixamo (Adobe): locomoção e alguns golpes de espada | Validar a arquitetura e a sensação | Segundo cópias do FAQ, gratuito para uso comercial em jogos, sem royalties nem crédito. Proíbe redistribuir os arquivos brutos e usar para treinar IA. Exige conta Adobe, então **o PO baixa** |
| 1. Alternativa | Bibliotecas CC0 (ex.: Quaternius) | Mesmo uso, sem conta | CC0, a verificar por pacote |
| 2. Produção inicial | Pacote comercial de katana em [Fab](https://www.fab.com) (há pacotes com ~60 a 180 animações de katana, root motion e no lugar) | Base da cadeia de golpes e reações | A licença padrão do Fab permite uso em qualquer engine ([CG Channel](https://www.cgchannel.com/2024/11/epic-games-to-share-new-free-assets-on-fab-every-two-weeks)); confirmar a EULA e cada anúncio. **Evitar** licenças "só Unity" (Unity Companion License) e NC |
| 3. Identidade | Captura própria (traje inercial ou captura por vídeo), mais limpeza e ajuste por animador | Golpes autorais da Forja de Combos | Nossa |
| Sempre | Ajuste autoral: tempos, poses-chave e golpes reencenados em Blender | Diferenciar de pacotes genéricos | Nossa |

Requisitos práticos:

- **Esqueleto padrão humanoide** (`SkeletonProfileHumanoid` + `BoneMap` na importação). Assim, pacotes diferentes se reaproveitam por retarget no importador do Godot.
- **Blender** é necessário para retarget, limpeza e extração de curvas. Não está instalado; a instalação depende de autorização.
- **Registro de ativos obrigatório:** `docs/ativos/registro.md`. Para cada arquivo: origem, URL, autor, licença, data, quem baixou e o que foi alterado. Uma cópia da licença fica em `assets/licencas/`.
- Os clipes de jogo ficam na pasta do projeto. Nada de arquivos brutos de terceiros redistribuíveis num repositório público: **o repositório é público como portfólio**. Os brutos podem ir para um local privado, com Git LFS ou fora do Git.
- Modelo do ninja: comprado ou encomendado, com esqueleto padrão. Um provisório licenciado basta para os primeiros marcos.

---

## 6. Arquitetura proposta [DESIGN]

```
game/
  actors/
    player/          Player (cápsula, estados de movimento já aprovados)
    enemy/           Enemy base, TrainingDummy
  locomotion/        LocomotionMotor (velocidade, giro, esquiva; extraído do Player atual)
  combat/
    combat_state.gd  CombatStateMachine: IDLE, STARTUP, ACTIVE, RECOVERY, HITSTUN, PARRY...
    attack_data.gd   AttackData (Resource): tempos, janelas de cancelamento, curva de avanço,
                     forma e tempo de hitbox, dano, hitstop, tipo de reação, IDs de efeito e som
    combo_graph.gd   ComboGraph (Resource): nós (ataques) e arestas (entrada + janela)
    hit_resolver.gd  HitResolver: varredura da lâmina, alvo único por golpe, eventos de acerto
    hitstop.gd       escala de tempo por entidade
  animation/
    anim_driver.gd   AnimDriver: lê os estados e escreve parâmetros no AnimationTree. Sem lógica de jogo
    modifiers/       inclinação, pés (IK), olhar
  feedback/
    feedback_bus.gd  recebe eventos (hit, parry, carga pronta) e dispara VFX, som e câmera
    vfx/             rastro da lâmina, faíscas, clarão
  data/              .tres de ajuste: PlayerTuning, AttackData, ComboGraph, ReactionData
```

As separações pedidas pelo PO:

| Camada | Dono | Regra |
|---|---|---|
| Movimento | `LocomotionMotor` | Só a cápsula; 120 Hz; já testado |
| Estado de combate | `CombatStateMachine` | Tempos em segundos vindos de dados, nunca de quadros de animação |
| Animação | `AnimDriver` + `AnimationTree` | Só lê estados; trocar uma animação não muda as regras |
| Dados | `.tres` em texto | Editáveis por IA e no editor; validados em teste |
| Efeitos | `FeedbackBus` + `vfx/` | Ouvem eventos; podem ser desligados sem afetar a lógica |
| Colisões e acertos | `HitResolver` + hurtboxes | Determinísticos por tick; testáveis sem janela |

A integração futura com a **Forja de Combos** fica assim: cada carta vira um nó de `ComboGraph` (um `AttackData` mais a condição de entrada). Montar a rota é editar o grafo em dados. O motor de combate não muda.

O desenho foi pensado para IA: tudo em texto (`.gd`, `.tres`, `.tscn`), com testes sem janela por estado, tempo, cancelamento e acerto. Os testes rodam os mesmos `AttackData` que o jogo, e um playtest scriptado grava métricas e capturas. As edições manuais ficam restritas a importar animações e ajustar poses.

---

## 7. Plano incremental [DESIGN]

Cada marco tem entrega jogável, branch própria e PR com testes. Os números são metas iniciais de playtest.

| Marco | Entrega jogável | Principais critérios |
|---|---|---|
| **H1 Humanoide correndo** (primeiro) | Ninja provisório licenciado com esqueleto: parado, andar, correr, esquiva e retorno à corrida, com a cápsula do Marco 1 intocada | 95 testes atuais passam sem mudar tolerâncias; deslize do pé ≤ 3 cm por apoio na corrida; estado de animação = estado de jogo em todos os ticks; ≥ 120 FPS de render na arena |
| **H2 Polimento de locomoção** | Início, parada e virada de 180° visuais; inclinação em curva; IK de pés em rampa; cachecol e casaco com molas | Pés a ≤ 2 cm do chão na rampa; nenhuma mudança de latência (testes iguais); aprovação do PO no checklist |
| **C1 Primeiro golpe** | Cadeia de 3 golpes leves de katana contra boneco de treino; hitbox varrida, clarão, hitstop, rastro, faíscas e som provisório; cancelar em esquiva | Preparação 0,10 s ±1 tick; cadeia ~0,5 s; buffer de 0,15 s; cancelamento em esquiva a partir do contato; 0 acertos duplicados por golpe; 0 "túneis" a 21 m/s |
| **C2 Peso e reações** | Golpe carregado com sinal de carga pronta; reações leves, pesadas e arremesso no boneco; câmera com avanço de FOV e tremor só no pesado | Clarão em ≤ 1 quadro do contato; arremesso pela curva de dados; câmera sem tremor nos leves |
| **C3 Inimigo de treino ativo** | Robô simples com telegrafia vermelha, ataque, atordoamento; i-frames da esquiva valendo; protótipo de parry | Janela de parry configurável (proposta 120–180 ms); telegrafia ≥ 0,4 s antes do golpe |
| **C4 Fluxo** | Soft-lock de alvo, troca de arma (se o PO quiser), vários inimigos | p99 do quadro dentro do orçamento com 6–10 inimigos |
| Depois | Forja de Combos (grafo por cartas), arena definitiva e direção gráfica completa | Marcos próprios |

**Ordem com o Marco 2 (gráficos):** a proposta do Marco 2 inclui o ninja definitivo. Recomendo **trocar a ordem**: H1 primeiro, com personagem provisório, e depois a direção gráfica. O esqueleto e a escala do personagem, decididos no H1, condicionam o modelo definitivo e a câmera.

---

## 8. Riscos técnicos e de desempenho

| Risco | Impacto | Mitigação |
|---|---|---|
| **Qualidade das animações disponíveis** (pacotes genéricos e o estilo de espada numa mão, para trás) | Alto: é o que mais define a "sensação Dinghai" | Comprar pacote bom cedo; orçamento para animador ou captura na fase 3 |
| **Conflito entre resposta e realismo** (pé deslizando quando a cápsula vira a 1080°/s) | Médio | A cápsula manda; inclinação e velocidade de reprodução escondem; tolerar algum deslize nas viradas rápidas, como jogos de ação fazem |
| Root motion versus controle | Médio | Nada de root motion em tempo real; curvas extraídas e testadas |
| IK do Godot recente (4.6) | Médio: API nova, documentação incompleta | Isolar num modificador nosso; teste de rampa |
| Complexidade do `AnimationTree` difícil de testar | Médio | `AnimDriver` fino; testes sem janela verificando estado de animação × estado de jogo |
| Licenças de ativos | Alto se errar | Registro obrigatório; evitar NC e "só Unity"; repositório público só com ativos redistribuíveis |
| CPU de animação com muitos inimigos | Baixo/médio: esqueleto, árvore e IK por inimigo | IK e molas só no jogador e nos inimigos próximos; inimigos com árvore simples; medir no C4 |
| Túnel de hitbox em golpes rápidos | Médio | Varredura entre ticks (`ShapeCast3D`) a 120 Hz |
| Hitstop global quebrando a física | Médio | Escala por entidade |
| Teto de ~117 FPS ainda não explicado | Médio: impede medir a folga real | Resolver a pendência 5 antes do C4 |
| Escopo: animação é o maior custo do projeto | Alto | Marcos pequenos; parar em cada um para avaliação do PO |
| Dependência de ferramenta externa (Blender) e de downloads com conta | Baixo | Autorização do PO; o PO baixa ativos de serviços com login |

---

## 9. Critérios de aceitação gerais

**Preservar (regressão):** os 95 testes do Marco 1 continuam passando **sem afrouxar tolerâncias**, cobrindo aceleração, frenagem, giro, esquiva de 4 m/0,25 s, fluidez esquiva → corrida e câmera.

**Locomoção animada:**
- Deslize do pé ≤ 3 cm por fase de apoio em velocidade constante (medido em teste pela posição do osso do pé).
- Mistura entre estados de locomoção ≤ 0,15 s.
- Nenhuma animação atrasa o início do movimento: ele começa no mesmo tick da entrada.

**Combate:**
- Os tempos de `AttackData` são respeitados com ±1 tick (8,3 ms).
- Uma esquiva pedida no quadro de contato ou depois cancela o golpe.
- Cada golpe acerta cada alvo no máximo uma vez.
- O feedback visual de acerto sai no mesmo tick do contato.

**Desempenho (1080p, máquina de desenvolvimento):** p99 do quadro ≤ 8,3 ms na arena de testes com o jogador animado, e com até 10 inimigos no C4. Isso só depois de entender o teto de 117 FPS.

**Validação humana:** o PO aprova cada marco pelo checklist abaixo.

**Para medir Dinghai melhor** (opcional, pelo PO): gravar a 120 fps, com a câmera mais próxima se houver opção e overlay de entrada, seguindo um roteiro:
- correr e parar;
- virar 45°, 90° e 180°;
- esquivar parado e correndo;
- fazer a cadeia leve completa;
- carregar um ataque;
- tentar o parry;
- trocar de arma.

Isso converte boa parte das linhas [ESTIMADO] e [DESCONHECIDO] em [MEDIDO].

## 10. Checklist de playtest

Responder sim/não e, quando "não", onde e como.

**Locomoção**
1. O personagem parte **na hora** quando aperto a direção?
2. A corrida parece de um espadachim (postura, braços, espada) e não de um boneco?
3. Os pés parecem "presos" ao chão ou escorregam?
4. Viradas de 90° e 180° são rápidas e ainda parecem ter peso?
5. Ao parar, a pose final é natural e sem tranco?
6. Em rampa, os pés acompanham o chão?
7. Casaco e cachecol reagem ao movimento sem exagero?

**Esquiva**
8. A esquiva continua fluida até a corrida (aprovado no Marco 1)?
9. A pose da esquiva comunica o movimento?

**Combate (a partir do C1)**
10. O golpe sai na hora ao apertar?
11. A cadeia de 3 golpes tem ritmo, sem pausa estranha nem pressa?
12. Dá para sentir o impacto (clarão, parada curta, som, faísca)?
13. Consigo cancelar o golpe em esquiva quando preciso?
14. O personagem se vira para o alvo sem perder o controle?
15. A reação do boneco mostra se o golpe foi leve ou pesado?
16. O golpe carregado tem sinal claro de "pronto"?
17. A câmera ajuda a ler o combate e não treme demais?

**Geral**
18. Em comparação com a referência, está "mais travado", "igual" ou "mais solto"? Onde?

---

## 11. Recomendação: primeira implementação

**Marco H1, humanoide correndo e esquivando**, nesta forma:

1. Branch `feat/h1-humanoide-locomocao`.
2. Extrair o movimento do `Player` atual para `LocomotionMotor` **sem mudar nenhum número**. Os 95 testes provam que nada mudou.
3. Importar um personagem provisório licenciado e com esqueleto humanoide, mais 6 a 10 animações: parado, andar, correr, partida, parada, esquiva e aterrissagem. A fonte é Mixamo baixado pelo PO, ou um pacote CC0.
4. Criar o `AnimDriver` e o `AnimationTree`: blend space pela velocidade, velocidade de reprodução sincronizada e esquiva como estado de 0,25 s que emenda na corrida.
5. Escrever testes novos: estado de animação × estado de jogo, deslize do pé e latência inalterada. Rodar o playtest scriptado e gerar capturas.
6. Criar o registro de ativos.

**O que o PO precisa decidir antes:**

| # | Decisão | Opções |
|---|---|---|
| 1 | Fonte das animações do H1 | (a) Mixamo, com o PO baixando com a conta Adobe; (b) pacote CC0 sem conta; (c) comprar já um pacote de katana no Fab |
| 2 | Instalar o Blender | Sim/não. É necessário a partir do H1 para retarget e ajustes |
| 3 | Ordem dos marcos | H1 antes do Marco 2 (recomendado) ou manter o Marco 2 primeiro |
| 4 | Política de ativos no repositório público | Brutos de terceiros fora do Git (recomendado), ou tornar o repositório privado |
| 5 | Orçamento futuro de animação | Comprar pacote, contratar animador ou fazer captura própria (fases 2 e 3) |
