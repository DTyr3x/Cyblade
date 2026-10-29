# H2.1: nova referência de combate e primeiro golpe autoral

Status: **pesquisa entregue e primeiro golpe jogável. NÃO aprovado: depende do playtest humano do PO.**
Branch `feat/h2-combate-katana` (PR #3, sem merge). Os golpes 2 e 3 continuam os do H2 (reprovados) até o golpe 1 ser aprovado.

## 1. Pesquisa: Phantom Blade Zero

### Fontes

- **Vídeos oficiais** na página da Steam ([app 4115450](https://store.steampowered.com/app/4115450/Phantom_Blade_Zero/)):
  - "Year of the Snake Gameplay Trailer";
  - Launch Trailer, Pre-Order Trailer e Release Date Trailer;
  - 5 clipes de jogabilidade da descrição da loja, de ~12 s cada.
- **Textos:** análises e prévias.
  - [Shacknews](https://shacknews.com/article/151138/phantom-blade-zero-review-score)
  - [The Outer Haven](https://theouterhaven.net/phantom-blade-zero-review)
  - [RPGFan](https://www.rpgfan.com/2026/10/08/phantom-blade-zero-hands-preview/)
  - [RPGamer](https://rpgamer.com/2026/06/phantom-blade-zero-sgf-play-days-impression/)
  - [Games.gg](https://games.gg/phantom-blade-0/guides/combat-sha-chi-parry-ghoststep/)
  - [TechNode](https://technode.com/?p=198072)
- **Kenjutsu:** artigos da [Itten Dojo](https://ittendojo.org/dbfiles/download/swordandspirit/pdf/32) e da [Universidade de Tsukuba](https://budo-world.taiiku.tsukuba.ac.jp/en/?p=283).

### Limitação

A análise quadro a quadro ficou limitada. Os vídeos foram lidos no navegador embutido, sem baixar arquivos. Com o painel oculto, porém, as capturas de tela ficam desatualizadas, e o PO preferiu seguir sem ele.

A tentativa de medir o tempo dos golpes pela diferença entre quadros também falhou: o vídeo carregado devolveu quadros duplicados ao buscar em passos de 1/60 s. Por isso **não há medição de tempo de golpe de PBZ** neste documento. Nenhum quadro do jogo foi versionado (são material protegido).

### Medido (dados reais)

- **Trailer de jogabilidade:** 5:57, 1920x1080 a **60 fps** (manifesto DASH oficial). HUD de combate a partir de ~36 s; os primeiros ~35 s são cinemáticos.
- **Clipes da loja:** 1170x658, 11,8 a 12,1 s.

### Observado (visual, baixa resolução)

- **Câmera:** terceira pessoa atrás do personagem, bem mais próxima que a de Dinghai. O personagem ocupa uma fração grande da tela, ao contrário dos ~10% de Dinghai.
- **Golpes:** arcos de lâmina claros e largos, faíscas e brasas no contato, borrão de movimento e inimigos deslocados ou arremessados.
- **Telas cheias de inimigos:** trechos com muitos oponentes, alternando com duelos contra chefes.

### Relatado pelas análises (não verificado por nós)

- **Golpes e defesa:** ataques leves e pesados encadeados; aparar (botão próprio) e esquiva integrados no mesmo fluxo. Pistas de cor indicam golpes inimigos a aparar ou a esquivar.
- **Recurso:** recurso de combate "Sha-Chi", gasto por golpes pesados e por bloqueio.
- **Armas:** cada arma com seu repertório (há 30 principais).
- **Comparações:** "Devil May Cry com Sekiro"; aparar importa, mas não é obrigatório o tempo todo.

### Hipóteses (não confirmadas; não presumimos sistemas internos)

- O impacto parece vir mais da pose e do arco da lâmina sincronizados ao contato do que do tremor de câmera.
- Os golpes parecem terminar em posições prontas para o próximo, sem voltar ao repouso.

## 2. Comparação

| Aspecto | Phantom Blade Zero (observado/relatado) | Dinghai (estudo anterior) | H2 atual (reprovado) |
|---|---|---|---|
| Câmera | Terceira pessoa próxima | Alta, ~10% da tela | Alta (Dinghai), mantida |
| Corpo no golpe | Corpo inteiro, arcos largos, deslocamento | Investidas curtas e rápidas | Um único clipe genérico recortado e espelhado |
| Pegada | Varia por arma | Espada curta, uma mão | Katana presa ao antebraço (uma mão) |
| Encadeamento | Golpes ligados, sem retorno ao repouso | Cadeias curtas | Janelas corretas, mas o corpo "reinicia" |
| Impacto | Faíscas, brasas, arco claro, reação forte | Golpes comuns sem tremor | Efeitos presentes, mas desligados da pose |
| Defesa | Aparar + esquiva integrados | Esquiva | Só esquiva (aparar fora do escopo) |

## 3. Identidade da katana do CYBLADE (proposta)

- **Base de duas mãos:** a mão direita junto à guarda, a esquerda no fim do cabo. Uma mão só em transições rápidas (corte reverso), nunca como padrão.
- **Postura:** baixa e funcional, com o pé direito à frente, inspirada no kenjutsu (o quadril conduz o avanço).
- **Corte e passo juntos:** passo deslizante (okuri-ashi) no corte. O pé da frente planta, o de trás acompanha. Sem salto.
- **Encadeamento:** cada golpe termina numa posição que inicia o próximo. Kesa termina baixo à esquerda, e daí sai o corte ascendente.
- **Impacto:** congelamento curto no contato real da lâmina, arco do rastro igual à trajetória e reação do alvo na direção do corte. Tremor de câmera só no golpe final.
- **Sem cópia:** nada de assets, sequências ou poses específicas de PBZ ou Dinghai. As poses vêm de princípios de esgrima.

## 4. Três movimentos originais

1. **Kesa avançado** (implementado, ver §6): corte diagonal descendente, do alto à direita para baixo à esquerda, com as duas mãos, passo deslizante e quadril que desce.
2. **Kiriage de retorno** (proposto): corte diagonal ascendente que nasce da posição final do kesa (baixo à esquerda). Gira sobre o pé da frente, o quadril abre e a lâmina sobe para a guarda alta direita, pronta para repetir ou para o golpe final.
3. **Tsuki de passo duplo** (proposto, golpe final): da guarda média, estocada com extensão total e impulso do pé de trás. Depois o corpo gira e a lâmina sai do alvo em corte horizontal curto. Tremor discreto só aqui.

## 5. Estratégia de animação escolhida

**Animação autoral, por poses-chave em código no Blender 4.5, com IK.**

- **Pacotes CC0:** o pacote CC0 atual tem só um clipe de espada, o que foi a causa do H2 reprovado.
- **Pacotes licenciados:** costumam proibir redistribuir os arquivos, e o repositório é público. Exigiriam compra e decisão do PO.
- **Mocap:** não disponível.
- **Como funciona:**
  - `tools/blender/author_katana_strike.py` define as poses-chave: quadril, giro e inclinação da coluna, mãos no cabo, direção da lâmina e pés.
  - O IK do Blender resolve braços e pernas e o script exporta a pose final.
  - `tools/blender_pose_to_godot.gd` converte para um `Animation` do Godot, com correção por osso calculada no repouso.
  - `tools/build_katana_strike.ps1` refaz tudo.
- **O avanço:** a animação é autorada no mundo, com os pés plantados, e o avanço da cápsula é subtraído. O pé da frente fica parado enquanto a cápsula avança. O perfil é o mesmo do `CombatController`.
- **Combinação futura:** clipes licenciados ou mocap podem entrar pelo mesmo campo `StrikeData.clip_resource`.

## 6. Golpe 1 jogável: Kesa avançado

| Fase | Quadros (60 Hz) | Tempo |
|---|---|---|
| Preparação (guarda alta à direita, peso atrás, tronco gira à direita) | 0 a 6 | 0 a 0,10 s |
| Contato (lâmina desce em diagonal; passo do pé direito; quadril desce 9 cm) | 7 a 13 | 0,12 a 0,22 s |
| Continuação (lâmina baixa à esquerda; pé esquerdo desliza) | 13 a 17 | até 0,28 s |
| Encadeia a partir de | 17 | 0,28 s |
| Movimento livre a partir de / fim (volta à guarda média) | 21 / 33 | 0,35 s / 0,55 s |

- **Avanço:** 0,9 m, o mesmo dos golpes aprovados, entre os quadros 3 e 15.
- **Esquiva:** cancela a partir do quadro 3 (0,05 s).
- **Hitstop:** 0,06 s.
- **Empunhadura:** nos golpes autorais a lâmina sai pelo lado do polegar e as duas mãos ficam no cabo. Na locomoção ela volta à empunhadura aprovada.

### Validado por teste

- **Resposta:** do aperto ao contato no boneco, 0,158 s.
- **Trajetória da ponta no contato:** desce 2,0 m e vai 1,0 m da direita para a esquerda (corte diagonal real).
- **Empunhadura:** mãos a no máximo 0,11 m uma da outra (as duas no cabo).
- **Peso:** o quadril desce 0,09 m.
- **Pé da frente:** plantado, com deriva de 0,063 m durante o avanço.

## 7. Testes e desempenho

- **Testes:** 210 verificações, 0 falhas. São as 197 anteriores e 13 novas do golpe autoral. Nenhuma tolerância foi reduzida. Um teste do H2 comparava o nome fixo "corte_diagonal" e passou a comparar com o id do golpe 1.
- **Playtest em janela:** 1080p, VSync desligado. No combate, 179 FPS médios, p99 de 14,7 ms e GPU média de 0,49 ms. Houve 3 quadros acima de 25 ms (máx. 26,6 ms). Acertos: 9 de 9. Esquivas de 3,95 a 3,99 m. Dados em `docs/h2-1/playtest/`.

## 8. Evidências

- `docs/h2-1/estudo/`: o golpe isolado no modelo, de frente e de lado, com a katana.
- `docs/h2-1/capturas/`: o golpe no jogo contra o boneco (`h2_02_golpe1_kesa_avancado.png`) e a sequência corrida → golpes → esquiva → corrida. A entrada é simulada.

## 9. Problemas conhecidos

- **Golpes 2 e 3:** ainda são os do H2. A transição do golpe 1 para eles muda de empunhadura. É esperado, até a aprovação do golpe 1.
- **Pose autoral:** não há mocap. Pode faltar sutileza nos ombros e clavículas, que ficam na pose de repouso, e nos punhos.
- **Pé e ponta da lâmina:** o pé da frente ainda deriva ~6 cm. A ponta da lâmina pode tocar o chão no fim do corte.
- **Pico de quadro:** quadros ocasionais de ~26 ms no combate.

## 10. Checklist de playtest humano (golpe 1)

Ataque com **J**, botão esquerdo do mouse ou **X**. Esquiva com **Espaço**. **F3** mostra o estado do combate. Teste **só o primeiro golpe**, apertando uma vez e esperando.

1. **Resposta:** o golpe sai na hora em que você aperta? A preparação parece rápida o bastante?
2. **Postura:** a guarda alta com as duas mãos parece de um espadachim de verdade?
3. **Pegada:** as duas mãos no cabo convencem? A lâmina sai da mão do jeito certo?
4. **Trajetória:** o corte desce em diagonal, do alto à direita para baixo à esquerda, de forma clara?
5. **Peso:** dá para sentir o quadril descer e o corpo ir para a frente com o passo?
6. **Pés:** o pé da frente planta no chão ou parece escorregar?
7. **Contato:** o congelamento curto acontece no momento em que a lâmina encontra o boneco?
8. **Impacto:** faíscas, clarão e reação do boneco combinam com a força do corte?
9. **Recuperação:** a volta à guarda média (zanshin) parece natural ou demorada?
10. **Esquiva:** esquivar no meio do golpe responde na hora e continua fluido?
11. **Corrida:** saindo do golpe para correr, a troca de empunhadura (duas mãos para uma) incomoda?
12. **Comparação:** em relação ao H2, melhorou resposta, corpo e impacto? O que ainda falta para lembrar a qualidade de Phantom Blade Zero?
