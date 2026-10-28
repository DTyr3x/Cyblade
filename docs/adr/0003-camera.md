# ADR 0003: câmera elevada com presets

- **Data:** 28/10/2026
- **Status:** implementado no Marco 1, sujeito a playtest humano

## Referências

A pesquisa de Dinghai estimou: perspectiva de três-quartos, inclinação ~45° (±4°), FOV vertical ~34° (**baixa confiança**), personagem a 9–11% da altura da tela, acompanhamento com atraso sem antecipação, câmera de chefe baixa e frontal. Tremor de câmera em golpes comuns: nenhum detectado. Nos ataques do chefe: inconclusivo.

## Decisão

`CameraRig` com um **foco** (rig) inclinado e a `Camera3D` recuada `distance` metros. Três presets em `.tres`:

| Preset | Inclinação | Distância | FOV vertical | Notas |
|---|---|---|---|---|
| combate (padrão) | 45° | 20 m | 34° | Jogador a 10,0% da altura da tela |
| exploração | 50° | 22 m | 36° | Mais antecipação (0,8 m), mais folga |
| chefe | 20° | 26 m | 34° | Foco 3 m acima e deslocado 5 m à frente, jogador no terço inferior |

## Como funciona

- **Acompanhamento** por suavização exponencial (`1 − e^(−dt/τ)`), independente do FPS. τ = 0,10 s no combate (o atraso medido na referência foi de ~0,1 s).
- **Antecipação** do movimento configurável por preset (0,4 m no combate). Dinghai não antecipa; é escolha nossa para o ninja rápido, desligável com 0.
- **Troca de preset** suavizada (0,6 a 1,0 s), parâmetro por parâmetro.
- **Giro manual** (mouse com botão direito, stick direito, Q/E) a 140°/s no stick, com centralização. Sem inclinação manual. A direção do giro precisa de validação humana.
- A câmera **não** anda em `_physics_process`: roda em `_process` lendo a posição interpolada do jogador, com a interpolação de física desligada nos nós da câmera.
- Sem tremor de câmera no Marco 1 (a referência não mostrou tremor em golpes comuns). Fica para o Marco 3, junto com os impactos.

## O que não foi feito (de propósito)

Enquadramento por grupo de inimigos, oclusão por dither e câmera de chefe real dependem de inimigos e cenários (Marcos 2 a 5). Os presets deixam os parâmetros prontos.

## Medições do HUD

O HUD calcula a altura do jogador na tela projetando pés e cabeça, o que permite comparar com a referência de 9–11% sem estimar a olho.
