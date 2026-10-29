# H2: combate de katana

> **Atualização H2.2:** o golpe 2 deste documento (corte reverso, espelhado) foi substituído pelo **Kiriage de retorno** autoral (`docs/h2-2-kiriage.md`), e o golpe 1 pelo **Kesa avançado** (`docs/h2-1-combate-katana.md`). A arquitetura e as regras abaixo continuam valendo; os valores da tabela de parâmetros dos golpes 1 e 2 estão desatualizados (ver `game/data/katana_combo.tres`).

Status: **implementado e testado por script. NÃO aprovado: depende do playtest humano do PO.**
Branch `feat/h2-combate-katana`. Sem merge. Locomoção, câmera e esquiva aprovadas não foram alteradas.

## O que existe

Cadeia manual de 3 golpes de katana (botão **J**, **mouse esquerdo** ou **X** no gamepad), boneco de treino sem IA, detecção de acerto da lâmina, hitstop, rastro, faíscas, clarão, sons provisórios e tremor discreto de câmera só no golpe final.

Sequência jogável: corrida → golpe 1 → golpe 2 → golpe 3 → esquiva → corrida (`docs/h2/capturas/h2_01_...png`).

## Arquitetura (separação pedida)

| Responsabilidade | Arquivo | Observação |
|---|---|---|
| Dados dos golpes | `game/combat/strike_data.gd`, `combo_set.gd`, `game/data/katana_combo.tres` | Só dados, editáveis no inspetor do Godot. `ComboSet` já é a unidade que a futura Forja de Combos poderá montar |
| Estado de combate | `game/combat/combat_controller.gd` | Fases, buffer, encadeamento, janelas de cancelamento, hitstop. **Não conhece animação, alvos nem efeitos** (só sinais) |
| Controle de animação | `game/player/humanoid_visual.gd` + `game/combat/katana_clips.gd` | OneShot no `AnimationTree` sobre a locomoção; o modificador de pose apaga a postura de corrida enquanto o golpe manda |
| Detecção de impacto | `game/combat/hit_detector.gd` | Varre o segmento da lâmina em passos entre dois ticks; 1 acerto por alvo por golpe (`swing_id`) |
| Reação do alvo | `game/combat/training_dummy.gd` | Hurtbox analítica (cápsula), molas amortecidas, reação diferente por golpe |
| Efeitos visuais e sonoros | `game/combat/combat_effects.gd`, `generated_sounds.gd` | Só escuta sinais; remover o nó não quebra o combate |
| Orquestração de movimento | `game/player/player.gd` (estado `ATTACK`) | Avanço controlado, giro/mira, cancelamentos |

`WeaponStance` (katana) segue sendo a postura de corrida; durante o golpe o clipe assume (peso `strike_blend`).

## Regras de combate

- **A cápsula manda**, como na locomoção: nenhuma animação atrasa entrada, movimento ou esquiva.
- **Buffer de ataque** de 0,30 s: um aperto antes da janela de encadeamento fica guardado e o próximo golpe entra no instante em que a janela abre.
- **Cancelar por esquiva** a partir de `dodge_cancel_from` (cedo: a esquiva sempre responde). A esquiva em si é a aprovada, sem alteração (≈3,95 m, 0,25 s, recuperação 0,18 s).
- **Cancelar a recuperação por movimento** a partir de `move_cancel_from`: o jogador não fica preso depois de atacar.
- **Orientação responsiva:** o corpo gira até `turn_lock` para a direção pressionada; sem direção, para o alvo mais próximo na frente (assistência de mira, 6 m e 75°).
- **Avanço do golpe** em perfil suave; o momento da corrida é absorvido pela frenagem normal. Obstáculos bloqueiam (colisão normal).
- **Hitstop** congela só o relógio do golpe, o clipe do golpe e o boneco; câmera, física e resto do jogo seguem.
- **Tremor de câmera:** 0 nos golpes comuns; 0,03 m por 0,14 s no golpe final.

## Parâmetros editáveis (`game/data/katana_combo.tres`, valores atuais)

Tempos de clipe são divididos por `speed` para virar tempo real.

| Parâmetro | Golpe 1 corte diagonal | Golpe 2 corte reverso | Golpe 3 golpe final |
|---|---|---|---|
| Trecho do clipe (s) | 0,08 → 0,95 | 0,08 → 0,95 (espelhado) | 0,08 → 1,35 |
| `speed` (velocidade de ataque) | 1,80 | 1,85 | 1,35 |
| Duração real total | 0,48 s | 0,47 s | 0,94 s |
| Preparação até o contato (`active_start`) | 0,22 → 0,12 s | 0,22 → 0,12 s | 0,26 → 0,19 s |
| Fim do contato (`active_end`) | 0,46 → 0,26 s | 0,46 → 0,25 s | 0,50 → 0,37 s |
| Encadeia a partir de (`chain_open`) | 0,50 → 0,28 s | 0,50 → 0,27 s | 0,78 → 0,58 s |
| Cancela por esquiva a partir de | 0,10 → 0,06 s | 0,10 → 0,05 s | 0,10 → 0,07 s |
| Cancela por movimento a partir de | 0,62 → 0,34 s | 0,62 → 0,34 s | 0,85 → 0,63 s |
| Avanço (m) | 0,9 | 0,9 | 1,5 |
| Giro máximo (°/s) / trava do giro | 900 / 0,22 | 900 / 0,22 | 900 / 0,24 |
| Dano | 10 | 10 | 25 |
| Hitstop | 0,05 s | 0,05 s | 0,09 s |
| Recuo do alvo (m) / reação | 0,15 / leve esq. | 0,15 / leve dir. | 0,55 / pesada |
| Tremor de câmera | 0 | 0 | 0,03 m |

Também editáveis em `ComboSet`: `input_buffer_time` (0,30 s), `combo_reset_time` (0,55 s), `aim_assist_range` (6 m), `aim_assist_angle_deg` (75°). Regerar o arquivo: `godot --headless --path . -s res://tools/make_combo_resource.gd`.

## Animações e licenças

O pacote UAL Standard (CC0) tem **um único clipe de espada** (`Sword_Attack`). Os 3 golpes são derivados dele (recorte, espelhamento do golpe 2, ritmo, avanço), sem arquivo novo. Registro em `docs/ativos/registro.md`. Sons sintetizados em código (originais). **Esta é a principal limitação do H2:** os golpes compartilham a mesma base corporal. Evidência do clipe de origem e do espelhamento: `docs/h2/pesquisa/`.

## Testes

197 verificações, 0 falhas: as 152 anteriores (sem tocar em nenhuma tolerância) e 45 novas do H2:

1. cadeia de 3 golpes e retorno ao golpe 1; golpe individual sem combo (reinício da cadeia);
2. buffer e janela de encadeamento (o golpe 2 entra quando a janela abre); sem aperto não há encadeamento;
3. cancelamento para esquiva (distância da esquiva preservada) e golpe → esquiva → corrida sem queda de velocidade;
4. acerto e erro (de costas), dano correto, sem dano duplicado, hitstop (duração e congelamento só do golpe);
5. assistência de mira e prioridade da direção pressionada;
6. `AnimationTree` (OneShot, mistura sobe e volta a Idle);
7. cancelamento da recuperação por movimento; avanço contra parede sem atravessar;
8. rastro, sons e tremor de câmera só no golpe final; dados e janelas válidos.

## Desempenho (playtest em janela, 1080p, RTX 5070 Ti, VSync desligado)

Segmento de combate (3 rodadas de 3 golpes + esquiva), 4 execuções: FPS médio 162 a 327; p99 do quadro 12,5 a 20,6 ms; GPU média 0,53 a 0,80 ms; quadros acima de 25 ms: 0 a 1 por execução (máx. 27 ms). O segmento de movimento puro da mesma execução fica em p99 12 a 23 ms, ou seja, o combate não piora o p99. Em todas: 9 acertos de 9 golpes, 0 erros, esquivas de 3,95 a 3,99 m. Dados: `docs/h2/desempenho-resumo.csv`, `docs/h2/playtest/`.

## Evidências

- `docs/h2/capturas/`: folhas de contato do jogo real (corrida → 3 golpes → esquiva → corrida; cada golpe isolado). Entrada simulada.
- `docs/h2/playtest/`: capturas do jogo em janela com o HUD de combate e o JSON de desempenho.
- Não há vídeo: só sequências de capturas.

## Problemas conhecidos

Ver `docs/pendencias-tecnicas.md`, itens 10 a 15. Em resumo: um único clipe de espada, pés escorregam no avanço, pico ocasional de ~26 ms, katana procedural sem ajuste de empunhadura por golpe, sons e efeitos provisórios, alvo sem morte.

## Checklist de playtest humano (PO)

Teclas: **J** ou mouse esquerdo ataca, **Espaço** esquiva, **F3** mostra o modo de depuração (golpe, fase, buffer, acertos). O boneco fica a 4,5 m à frente do ponto de partida.

1. Aperte ataque uma vez. O golpe sai na hora ou há sensação de atraso entre o aperto e a lâmina?
2. Encadeie 3 golpes apertando no ritmo. O ritmo parece bom? Rápido demais, lento demais?
3. Aperte ataque várias vezes antes do golpe acabar. O encadeamento perdoa o timing (buffer) ou perde apertos?
4. Os 3 golpes parecem diferentes entre si? O espelhado (2) parece natural ou estranho?
5. O corpo parece ter peso: transferência de peso, quadril, tronco? Ou parece um clipe genérico?
6. O avanço de cada golpe ajuda a alcançar o boneco? Algum avança demais ou de menos?
7. Os pés escorregam de forma incômoda durante o avanço?
8. A mira: sem apertar direção, o golpe vai para o boneco? Apertando uma direção, ele obedece a direção?
9. Impacto: o hitstop é perceptível e agradável? Faíscas, clarão e rastro ajudam ou exageram?
10. A reação do boneco diferencia os golpes? O golpe final parece mais forte?
11. O tremor de câmera do golpe final é discreto o bastante? Os golpes comuns não tremem?
12. Esquiva durante o golpe: cancela quando você espera? A transição golpe → esquiva → corrida é fluida?
13. Depois de atacar, você alguma vez se sentiu preso (sem poder se mover ou esquivar)?
14. Ataque perto de uma parede ou obstáculo: algo estranho (atravessar, travar)?
15. A corrida, os giros e a esquiva continuam iguais ao que foi aprovado?
16. Jogue 10 minutos: travou ou deu erro? Qual a sensação geral do combate comparada à de Dinghai?
