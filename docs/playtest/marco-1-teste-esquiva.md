# Como testar a esquiva (teclado e mouse)

Objetivo: fechar a pendência "sensação e responsividade da esquiva" do Marco 1.

## Comando

- **Esquiva: Espaço ou Shift esquerdo.** Direção: a do movimento (WASD/setas) no instante do toque. Sem direção pressionada, esquiva para onde o personagem está virado.
- Abra o jogo com `Jogar.bat`. Aperte **F3** para ver o HUD: quando a esquiva está ativa, a linha "Jogador" mostra `DODGE` (deslocamento), `RECOVERY` (recuperação) e "i-frames: sim" na janela de invulnerabilidade.
- A grade do piso tem linhas finas a cada 1 m e fortes a cada 5 m. A esquiva leva o personagem a **4 m** (quatro quadrados finos).

## O que deve acontecer (referência técnica)

| Fase | Duração | Observação |
|---|---|---|
| Deslocamento | ~0,25 s | Sai rápido e desacelera até parar, sem "frear seco" |
| Recuperação | ~0,18 s | Sem controle; total ~0,43 s |
| Invulnerabilidade | 0,05 a 0,20 s | Só indicada no HUD; ainda não há inimigos |
| Pedido antecipado | até 0,15 s antes | Apertar durante a recuperação dispara a esquiva ao terminar |

## Roteiro de 3 minutos

Use a área aberta à esquerda da régua de postes (x negativo, longe das paredes).

1. **Esquiva parada:** aperte Espaço sem mexer. O personagem desliza 4 m para onde está virado?
2. **Esquiva em 8 direções:** segure W, depois W+D, D, S+D etc. e toque Espaço em cada uma. A direção bate com a que você queria?
3. **Esquiva repetida:** toque Espaço 5 vezes seguidas com ritmo. Dá para encadear sem a sensação de "travar"? O pedido antecipado parece natural?
4. **Esquiva e câmera:** esquive em linha reta e observe se a câmera acompanha sem tremer nem ficar para trás demais.
5. **Esquiva e obstáculos:** esquive contra a caixa e o cilindro. O personagem para, desliza ou atravessa?
6. **Esquiva na rampa:** suba a rampa e esquive nela, para cima e para baixo.
7. **Esquiva depois de correr e depois de parar:** nota alguma diferença de sensação?

## Perguntas para anotar

- Resposta: o personagem parte **na hora** quando você aperta? (sim / há atraso perceptível)
- Distância: **curta, certa ou longa**? Se errada, em quantos metros?
- Duração do deslocamento: **rápida demais, certa ou lenta**?
- Recuperação: parece **presa**, certa ou solta demais?
- Tecla: Espaço ou Shift, qual é mais confortável? As duas?
- O visual (agachar levemente, sem rastro ainda) comunica bem a esquiva ou falta algo?

## Como ajustar depois do teste

Edite `game/data/player_tuning.tres` no Godot (ou me passe os números):

| Sensação | Parâmetro |
|---|---|
| Distância | `dodge_distance` (4,0) |
| Rapidez do deslocamento | `dodge_duration` (0,25) |
| Recuperação | `dodge_recovery` (0,18) |
| Pedido antecipado | `dodge_buffer_time` (0,15) |
| Invulnerabilidade | `dodge_iframe_start` e `dodge_iframe_end` |

Os testes automatizados (`tools\run_tests.ps1`) cobrem os valores atuais; se mudar os parâmetros, parte deles precisará de nova tolerância.
