# ADR 0002: modelo de movimento e esquiva

- **Data:** 28/10/2026
- **Status:** implementado no Marco 1, sujeito a playtest humano

## Referências e como foram usadas

Os valores iniciais vêm da pesquisa de Dinghai e são tratados como **pontos de partida**. A pesquisa tem incerteza de ±33 a ±67 ms nas durações e não mediu latência de entrada. Itens sem evidência (parry, cancelamentos, i-frames) não são tratados como característica de Dinghai.

| Parâmetro | Valor | Origem |
|---|---|---|
| Velocidade máxima | 6 m/s | Faixa medida de ~5–7 m/s |
| Tempo até a velocidade máxima | 0,12 s | Câmera de referência: ~0,13 s ao partir (o do personagem é limitado por ela) |
| Frenagem | 0,08 s | Parada "quase imediata" (observação qualitativa) |
| Inversão de sentido | freia 1,5× mais rápido até cruzar zero | Escolha nossa |
| Giro do corpo | 1080°/s | Proposta nossa |
| Esquiva: distância | 4 m | Estimativa de 3–5 m |
| Esquiva: deslocamento | 0,25 s | Medido ~0,23–0,27 s |
| Esquiva: recuperação | 0,18 s (total 0,43 s) | Medido ~0,43 s no total |
| Esquiva: i-frames | 0,05–0,20 s dentro do deslocamento | **Escolha de design nossa, sem evidência** |
| Buffer de esquiva | 0,15 s | Escolha nossa |

## Decisões de implementação

1. **Física a 120 Hz com interpolação** (`physics_interpolation`). O movimento usa só `delta`, então a sensação não depende do FPS de render. A câmera lê a posição interpolada do jogador.
2. **Perfil de velocidade da esquiva** `v(s) = v0·(1 − s²)`: sai rápida e desacelera até zero, sem parada seca. Em vez de integrar a velocidade, o deslocamento por tick é a diferença da função de distância `1,5·s − 0,5·s³`. Resultado: a distância total é exata (4,000 m), independente do tamanho do tick, e verificada em teste.
3. **Estados MOVE → DODGE → RECOVERY.** *(Revisado após o playtest do PO, ver "Revisão" abaixo.)* A recuperação dura 0,18 s e impede uma nova esquiva (recarga), mas **não trava a locomoção**: o jogador já controla o movimento. Uma esquiva pedida durante a recuperação dispara ao terminar (buffer).
4. **Funções puras em `MotionMath`**, testáveis sem cena.
5. **Parâmetros em `PlayerTuning` (`.tres`)**, editáveis no Godot sem tocar no código.
6. **Entrada analógica** com zona morta de 20% do Godot (reescalada): o stick a 50% dá 37,5% da velocidade.

## Alternativas descartadas

- Velocidade constante na esquiva: parece "deslizar" e termina em parada seca.
- Controle durante a recuperação: era descartado na decisão original; revertido após o playtest do PO (ver "Revisão").

## Revisão: fluidez após a esquiva (28/10/2026)

O PO notou uma desaceleração ou travada ao fim da esquiva, antes de voltar a correr.

**Causa (medida em teste, mínimo de velocidade depois da esquiva = 0,00 m/s):**

1. O perfil `v0·(1 − s²)` terminava com velocidade **zero**: o personagem parava por completo ao fim do deslocamento.
2. A recuperação (0,18 s) **ignorava a entrada** e freava a zero.
3. Depois, a corrida recomeçava do zero (0,12 s de aceleração).
4. Um tick extra com velocidade zero por arredondamento de ponto flutuante (`state_time` = 0,2499999) somava mais 8 ms de parada.

Somados, são ~0,3 s de pausa mesmo com a direção segurada.

**Correção:**

- `MotionMath.dodge_distance_at` aceita `exit_fraction`: o perfil vira `e·s + (1−e)·(1,5·s − 0,5·s³)`. A distância total continua exata (4 m) e o deslocamento continua 0,25 s; só a velocidade final passa de 0 para a velocidade de corrida (`dodge_exit_speed_ratio` × `max_speed`). Só se aplica se há direção pressionada ao iniciar a esquiva; parado, a esquiva termina parada.
- A recuperação usa a locomoção normal (aceleração, frenagem, giro) quando `dodge_recovery_locks_movement` é falso (padrão). Verdadeiro restaura o travamento, para ações de combate futuras (ex.: recuperação de ataque) sem acoplar isso à capacidade de correr.
- Tolerância de ponto flutuante no fim do deslocamento.
- Soltar todas as direções após a esquiva: o personagem desacelera naturalmente (0,08 s).
