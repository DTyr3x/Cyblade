# Marco 1: checklist de playtest humano

Como jogar: dê dois cliques em `Jogar.bat` (ou `tools\run.ps1`). F3 liga e desliga o HUD de depuração. Esc sai.
Marque cada item e anote o que sentiu. Se algo estiver ruim, diga qual parâmetro mexer (os valores estão em `game/data/*.tres`, editáveis no Godot).

## Teclado e mouse

- [ ] O personagem **responde na hora** ao apertar WASD (sem sensação de atraso)?
- [ ] A **aceleração** parece boa (nem lenta, nem brusca)? Anote: ___
- [ ] A **frenagem** parece boa (sem deslizar demais, sem travar seco)?
- [ ] **Mudar de direção** rápido (zigue-zague no slalom azul) parece fluido?
- [ ] A **esquiva** (Espaço ou Shift) tem boa distância e ritmo? Parece curta, certa ou longa?
- [ ] A **recuperação** da esquiva é aceitável, sem parecer "presa" (≈0,18 s)?
- [ ] Apertar a esquiva um pouco antes de poder (buffer) funciona de forma natural?
- [ ] Com a esquiva e os giros, o personagem **atravessa ou prende** em algum obstáculo?
- [ ] Botão direito do mouse + arrastar (ou Q/E) **gira a câmera** de forma confortável? A direção do giro parece certa ou invertida?
- [ ] A tecla R centraliza a câmera?

## Gamepad (precisa de controle físico: não foi testado ainda)

- [ ] O controle é reconhecido (o HUD mostra "Dispositivo: gamepad" ao mexer)?
- [ ] O stick esquerdo tem **zona morta** adequada (personagem não anda sozinho)? Analógico: andar devagar com o stick pela metade funciona bem?
- [ ] B esquiva; stick direito gira a câmera; R3 centraliza; ← → trocam o enquadramento; Back liga o HUD.
- [ ] Algum botão parece mal posicionado?

## Câmera

- [ ] A câmera de combate (tecla 1, ≈45°) permite **ler o espaço** sem esforço?
- [ ] O **acompanhamento** é suave, sem tremor nem enjoo?
- [ ] A câmera parece **atrasada demais** ou **colada demais** ao correr e ao esquivar?
- [ ] A antecipação do movimento ajuda ou incomoda?
- [ ] A distância e o tamanho do personagem (~10% da altura da tela) parecem bons? Mais perto, mais longe?
- [ ] 45° cansa em sessão longa? Falta controle manual de inclinação?
- [ ] Os enquadramentos exploração (2) e chefe (3) parecem diferentes e úteis? A transição de ~1 s é agradável?
- [ ] Notou **travadas** ao trocar de enquadramento? (Suspeita de um pico de ~61 ms.)

## Arena e escala

- [ ] A régua de postes (1,75 m, 3,5 m, 7 m, 14 m) e a grade de 1 m ajudam a avaliar escala?
- [ ] A rampa (21°) sobe e desce bem, sem engasgar na emenda com a plataforma?
- [ ] Os pilares gigantes passam sensação de escala monumental?

## Desempenho (anote o HUD)

- [ ] FPS em jogo: ___ (esperado ~117; ver observação sobre o teto no relatório de resultados)
- [ ] Sentiu algum engasgo? Em que momento? ___

## Veredito

- [ ] Aprovado para seguir ao Marco 2 · [ ] Aprovado com ajustes (liste) · [ ] Reprovado (motivo)
