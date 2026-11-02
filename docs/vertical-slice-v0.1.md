# CYBLADE: Vertical Slice v0.1

Status: **implementado e testado por script. NÃO aprovado: depende do playtest humano do PO.**
Branch `feat/vertical-slice-v0.1`, criada de `feat/c2-postura` (`e8d0f5c`). Sem PR e sem merge. As branches H2, C1, C2 e a main não foram modificadas.

## 1. O que mudou no gameplay

Abrir o jogo agora leva a uma luta completa: **tela inicial → luta contra o robô → vitória ou derrota → lutar de novo**. O treino continua disponível na tecla T.

**Robô de combate.** Um robô flutuante que detecta o jogador, se aproxima, mantém distância, circula e reage aos golpes. Tem 1.500 de vida e três padrões, cada um com a área marcada no chão durante a preparação:

| Padrão | Quando | Sinal | Resposta |
|---|---|---|---|
| **Corte duplo** | Perto | Leque âmbar, dois tempos (o segundo é mais curto) | Parry, defesa ou esquiva |
| **Investida** | De longe | Faixa âmbar até onde ele chega | Parry, defesa ou esquiva; recuperação longa, boa para punir |
| **Varredura** | Perto | Círculo **vermelho** em volta dele | Só esquiva: não pode ser defendida |

**Pressão de postura.** O anel magenta no chão mostra a pressão; a parte opaca é a pressão cravada. Parry, contra-corte que acerta e esquiva justa cravam. Depois de um parry ou de uma esquiva justa, os golpes comuns valem ×1,5 por um instante.

**Esquiva justa.** Esquivar até 0,20 s antes do contato, estando dentro da ameaça, crava 14 de pressão. A esquiva aprovada não mudou.

**Quebra.** Com a postura cheia, o ataque do robô é interrompido, ele cai sobre um joelho, o visor apaga e o anel fica branco e esvazia como cronômetro (1,8 s, ou 2,2 s se o contra-corte completou a quebra). Sem finalizar, ele levanta e volta a atacar mais cedo. Cada quebra deixa a próxima mais difícil, até ×1,5 no confronto.

**Cravada (F ou Y).** Estocada vertical autoral, feita no Blender: a katana sobe acima da cabeça, gira e desce até cravar. Só sai com o inimigo quebrado ao alcance, nunca sozinha. Tira 25% da vida do robô e devolve 25 de vida ao jogador. Esquiva e defesa cancelam antes do contato, e a janela volta a correr.

**Fim da luta.** A vida do robô para em 1 e ele quebra: **a luta sempre termina numa Cravada**. Na vitória aparecem tempo, parries, esquivas justas, Cravadas, dano recebido e o melhor tempo.

**Correção de FPS.** O acerto da lâmina agora é igual de 30 a 144 FPS (seção 4).

## 2. Como executar e jogar

Dê dois cliques em `C:\Cyblade\Cyblade\Jogar.bat`. Feche antes qualquer janela antiga do jogo.

| Ação | Teclado e mouse | Gamepad |
|---|---|---|
| Começar, lutar de novo | Enter | Start |
| Mover | WASD | Stick esquerdo |
| Atacar | J ou botão esquerdo | X |
| Defesa e parry | K | LB |
| Esquiva | Espaço ou Shift | B |
| **Cravada** | **F** | **Y** |
| Treino (telas de início e fim) | T | n/d |
| HUD de depuração | F3 | Back |
| Sair | Esc | n/d |

F, Y, Enter, Start e T estavam livres, e um teste confere que nenhuma tecla ou botão se repete no mapa.

## 3. Vídeo

`C:\Cyblade\_videos\vs01_fluxo_completo.avi` (332 MB, 1280x720, abra no VLC). Tela inicial, luta completa com o bot, 3 Cravadas, vitória e reinício. O jogador do vídeo é o bot de teste, com entrada simulada.

Capturas: `docs/vs/capturas/` (Investida, pressão alta, quebra) e `docs/vs/estudo/cravada.png` (poses da Cravada).

## 4. Testes

| Suíte | Resultado |
|---|---|
| Regressão e combate (`tools\run_tests.ps1`) | **505 de 505**: 376 anteriores ao C2, 73 do C2.0 e 56 novas |
| Sequência completa do confronto (`tools\run_duel_checks.ps1`) | **23 de 23, em 30, 60 e 144 FPS** |
| Parry e postura por FPS (`tools\run_parry_fps.ps1`) | Sem falhas em 30, 60 e 144 FPS |
| Alcance por FPS (`tools\run_hit_reach.ps1`) | **Idêntico em 30, 60, 120 e 144 FPS** |
| Smoke em janela real, 1080p | 4 lutas completas, todas até a vitória, sem erro |

Os 6 clipes aprovados seguem com o mesmo SHA-256. Janela de parry de 0,14 s, janela de oportunidade de 0,8 s e tempos da esquiva seguem iguais, conferidos por teste.

**Testes antigos alterados, e por quê:** dois testes do C2.0 descreviam a etapa em que a quebra não existia. "Nenhuma fase de quebra existe" virou "com a quebra desligada, cheia não quebra", e "esquiva ainda não pressiona" virou "esquiva no tempo certo crava 14". `_c2_setup()` ganhou uma linha que desliga a quebra nos testes do núcleo. As 376 anteriores não mudaram nesta entrega.

**Acerto por FPS, pendência 26: corrigida.** A causa era a pose da lâmina, que só existe por quadro de render. Tentei primeiro mover a animação para a física, mas isso não resolveu a 30 FPS e quebrou 3 testes aprovados, então reverti. A correção isolada é uma tabela da trajetória da lâmina, calculada do clipe ao carregar: o acerto depende só do tempo do golpe e da posição da cápsula. **Nada do que aparece na tela mudou.** Com uma folga de 0,11 m, o alcance ficou em 2,15 m para Kesa e contra-corte em todas as taxas, próximo do que você aprovou (antes, 2,10 a 2,15 m a 60 FPS, variando nas outras taxas).

**Lutas simuladas** (bot com entrada real, 3 sementes por linha; não é medição de humano):

| Estilo | Acerto da defesa | Resultado | Tempo | Cravadas |
|---|---|---|---|---|
| Parry, contra-corte e cadeia | 90% | 3 vitórias | 31 a 32 s | 3 |
| Parry, contra-corte e cadeia | 60% | 3 vitórias | 31 a 32 s | 3 |
| Parry, contra-corte e cadeia | 35% | 3 derrotas | 25 a 27 s | 1 |
| Esquiva e cadeia, sem parry | 90% | 3 vitórias | 34 a 35 s | 3 |
| Esquiva e cadeia, sem parry | 60% | 3 vitórias | 31 a 36 s | 3 |
| Só atacar | Não defende | 3 derrotas | 13 s | 0 |

Parry é o mais rápido, sem ser obrigatório, e martelar J perde.

## 5. Problemas conhecidos

- **Dificuldade sem validação humana.** O bot reage com perfeição de tempo quando acerta; uma luta humana deve ser mais longa e mais difícil. Vida do robô e do jogador são os primeiros valores a ajustar.
- **Gamepad físico não testado** (pendência 4): só eventos simulados.
- **Robô simples.** Corpo procedural flutuante, sem animação de golpe própria e sem desvio de obstáculos (a arena não tem nenhum). Golpes não interrompem o ataque dele: só a quebra interrompe.
- **Sem arte final.** Arena reduzida, sons sintetizados, queda do jogador procedural.
- **Tsuki:** continua na cadeia, soma 7 de pressão e **segue sem aprovação humana**.
- **Faíscas de acerto:** o ponto vem da tabela do clipe, e em golpes rápidos pode ficar até ~0,3 m da lâmina vista na tela. O acerto em si não muda.
- **Desvios da proposta C2, por decisão técnica:**
  - O bônus de 0,4 s vale para quebra com contra-corte, porque parry nunca passa de 80.
  - O contra-corte não recebe a exposição ×1,5, para preservar os valores do C2.0.
  - O arco da Cravada é de 180°, não 120°, para o botão não falhar com o inimigo ao lado.
  - A Varredura não defensável é um terceiro padrão, além dos dois pedidos.
  - A regra de terminar sempre em Cravada é nova.
- **A proposta C2** (`docs/c2-postura-proposta.md`) e o modelo (`docs/c2/`) continuam locais, sem commit, aguardando sua decisão.

## 6. Desempenho

Janela de 1080p, luta completa, RTX 5070 Ti. Uma janela antiga do CYBLADE (DEBUG), aberta por você, ficou aberta durante as medições.

| Medição | FPS médio | p50 | p99 | Pior quadro | 1% baixo |
|---|---|---|---|---|---|
| **Limite de 60 FPS**, luta 1 | 60 | 16,67 ms | 16,98 ms | 22,0 ms | 59 |
| **Limite de 60 FPS**, luta 2 | 60 | 16,67 ms | 16,94 ms | 20,7 ms | 59 |
| Sem limite, luta 1 | 1357 | 0,62 ms | 2,20 ms | 7,3 ms | 455 |
| Sem limite, luta 2 | 1366 | 0,62 ms | 2,10 ms | 10,0 ms | 476 |

60 FPS estáveis, nenhum quadro acima de 25 ms. Dados em `docs/vs/desempenho/`.

## 7. Commits da entrega

Branch `feat/vertical-slice-v0.1`:

- `3b03f60`: acerto independente do FPS
- `d76b11e`: anel, esquiva justa, quebra, Cravada, robô, arena e fluxo
- Commit final desta entrega: balanceamento do robô, melhor tempo, demonstração e este relatório

## 8. Checklist humano

1. Abrindo o jogo, dá para entender o que fazer e começar a luta?
2. O robô parece uma ameaça de verdade? Aproximação e distância parecem naturais?
3. Os sinais no chão avisam a tempo? A diferença entre âmbar (defensável) e vermelho (só esquiva) é clara?
4. Combos, parry, contra-ataque e esquiva continuam iguais ao que você aprovou?
5. O anel mostra bem a pressão? Você percebe quando crava?
6. A esquiva justa parece justa?
7. A quebra é inconfundível e dá tempo de reagir?
8. A Cravada tem peso e identidade? F é confortável? Alguma vez saiu sem querer?
9. Vencer e perder parecem justos? A dificuldade está boa?
10. **Terminou a luta e quis jogar de novo?**
