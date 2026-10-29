# H1.1: refinamento da locomoção

Status: **implementado e testado por script. Não aprovado: depende do playtest do PO.**
Branch `feat/h1-locomocao-humanoide` (PR #2). Sem merge. H2 não iniciado.

## O que mudou

| Pedido do PO | O que foi feito | Medido |
|---|---|---|
| 1. Menos balanço do braço da katana | O braço armado agora acompanha as oscilações rápidas do peito (referência lenta de ~1 passada) e conserva só 20% do balanço do clipe (`arm_swing_keep`) | Amplitude da mão no referencial do peito: **0,48 m (H1) → 0,20 m**. O clipe cru dava 0,29 m |
| 2. Estrutura por família de arma | Novo recurso `WeaponStance` (`game/player/weapon_stance.gd`): direções do braço, peso em repouso, balanço conservado, inclinação. `HumanoidPoseModifier.stance` o lê. Só a **katana** existe; `lamina_dupla`, `lanca`, `machado` e `adaga` estão reservadas e caem na katana com aviso | Testes de resolução de família |
| 3. Giros suaves | O quadril visual acompanha a frente da cápsula com constante de tempo de 0,05 s (máx. 60° de atraso) e o peito lidera, desfazendo 70% do desvio. É só visual: a cápsula, a velocidade e a direção não esperam | 45°: desvio visual máx. 28°; 90°: 40°; corpo continua girando em 0,03 s e 0,075 s; velocidade mínima 5,55 e 4,24 m/s (igual ao H1) |
| 4. Esquiva | Nenhuma alteração na física. Na esquiva o desvio visual é zerado (sem atraso) | 3,99 / 3,95 / 3,95 / 3,95 m em ~0,24 s nas 17 execuções, igual ao H1 |
| 5. Estabilidade | Ver abaixo | 17 execuções sem travamento |

## Estabilidade (travamentos em janela)

- Script novo `tools/stability_runs.ps1`: repete o playtest em janela com limite de tempo e encerra só o processo que ele iniciou.
- **17 execuções, 0 travamentos:** 13 isoladas, 3 com a suíte de testes rodando em paralelo (contenção de CPU) e 1 com o vigia.
- **Causa não reproduzida.** Não afirmo que foi corrigida. Hipótese mais provável: instâncias concorrentes do Godot durante o H1. O pico de um quadro (~60 a 85 ms) ao trocar de enquadramento continua existindo (pendência 2).
- Vigia no playtest (`tools/scripted_playtest.gd`): uma thread observa o contador de quadros; com 20 s parados registra o trecho e encerra o processo.

## Desempenho (playtest em janela, 1080p, VSync desligado, 17 execuções)

- FPS médio por trecho: ~235 a 260 (uma execução com 419). Observação: o teto externo de ~117 FPS visto no H1 não apareceu nestas execuções.
- Pior p99 de tempo de quadro por execução: 11 a 18 ms. Tempo de GPU médio: ~0,44 ms.
- Quadros acima de 25 ms por execução: 2 (os cortes de enquadramento); uma execução teve 14.
- Resumo por execução: `docs/h1-1/estabilidade-resumo.csv`.

## Testes

152 verificações, 0 falhas: as 133 anteriores (sem alterar nenhuma tolerância) e 19 novas (braço firme mas vivo, famílias de arma, giros de 45° e 90°, tronco que lidera, esquiva sem atraso visual).

## Capturas antes/depois (`docs/h1-1/`)

`antes/` e `depois/` têm as mesmas 5 folhas de contato (corrida, giros, esquivas, andar). `playtest/` tem as capturas do jogo em janela.

## Limitações

- A pose do braço na corrida ficou mais esticada para trás que no H1 (menos cotovelo dobrado). Só o PO pode dizer se está melhor.
- Na partida do repouso a katana aponta para baixo por ~0,3 s (a postura de corrida ainda está entrando).
- O quadril visual atrasado gira o corpo inteiro; sem clipes de giro ainda é uma aproximação (pendência 8).
- A medição de balanço é do esqueleto em ambiente de teste, não de sensação de jogo.

## Checklist de testes manuais (PO)

1. Corra em linha reta por 5 s. O braço da katana balança menos que antes e ainda parece vivo?
2. A katana fica para trás de forma natural, sem parecer presa ao corpo nem esticada demais?
3. Saia do repouso e comece a correr. A transição da postura (katana descendo e indo para trás) incomoda?
4. Corra e faça curvas de ~45°. O tronco e o quadril parecem acompanhar a curva com suavidade?
5. Corra e faça curvas de ~90° repetidas (zigue-zague). Há sensação de atraso do personagem em relação ao comando?
6. Corra e inverta (180°). O giro parece natural ou "torce" demais o corpo?
7. Faça giros parado (aperte uma direção e outra). O personagem vira sem estalo?
8. Esquiva correndo, esquiva parado e esquiva em sequência: o dash continua igual ao aprovado (distância, tempo, recuperação)?
9. Esquiva logo após uma curva fechada: alguma "torção" visual no início do dash?
10. Rampa e plataforma: algo piorou?
11. Troque os 3 enquadramentos de câmera várias vezes (1, 2, 3). Notou travada?
12. Jogue por 10 minutos seguidos: alguma janela travou ou algum erro apareceu?
13. Entre H1 e H1.1, qual corrida você prefere? Se for a anterior, diga o que mudou para pior.
