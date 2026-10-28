# Diário de desenvolvimento

Registro cronológico do que foi feito, por quem e como foi validado. O PO (Product Owner) define direção e aprova cada marco. O desenvolvimento é feito com ferramentas de IA (Claude Code); testes e auditorias poderão ser feitos também com Codex.

## 28/10/2026: pesquisa e Marco 0

- Pesquisa técnica da demo de Dinghai: The Ocean Pillar por **observação externa** (7 gravações de gameplay do PO e análise quadro a quadro), sem engenharia reversa, extração de assets ou modificação de arquivos. O contrato da Steam proíbe engenharia reversa; a ferramenta de análise binária (REA) não foi aplicada à demo. Relatório e capturas ficam fora deste repositório por conterem imagens de um jogo comercial.
- Decisão do PO: Godot 4 (ver ADR 0001).
- Marco 0: projeto Godot novo, estrutura de pastas, `.gitignore`, `.gitattributes`, README. Repositório publicado em `DTyr3x/Cyblade`. Verificação de autoria: o GitHub atribui o commit ao perfil do PO.

## 28/10/2026: Marco 1 (câmera e movimentação)

- Branch `feat/marco-1-camera-movimento`, commits locais.
- Implementados: mapa de entrada (teclado/mouse e gamepad), movimentação 3D com aceleração, giro e esquiva, câmera elevada com três presets, arena de testes, HUD de depuração e playtest scriptado.
- **Problemas encontrados e resolvidos durante o desenvolvimento**
  - O primeiro playtest mostrou o jogador colado na parede da arena (trecho em círculo saía do espaço livre): os trechos foram movidos para áreas centrais.
  - A rampa tinha um degrau de 0,18 m na emenda com a plataforma e o jogador não subia: geometria recalculada a partir da face da plataforma e teste de subida/descida adicionado.
  - O enquadramento de chefe deixava o jogador cortado na borda inferior (97% da altura da tela): deslocamento reduzido de 8 m para 5 m (83%), com teste.
  - Dois testes tinham expectativa errada (inversão de sentido e stick analógico com zona morta reescalada); corrigidos entendendo o comportamento do Godot, não afrouxando a tolerância.
- **Achado de desempenho:** o FPS ficou em ~117 mesmo em uma cena vazia, indicando um teto externo ao jogo; o custo de render medido é de ~0,4 ms de GPU. Ficou registrado como limitação, com um pico de ~61 ms na troca de enquadramento ainda sem causa isolada.
- Resultados, números e limitações: `docs/playtest/marco-1-resultados.md`.
- Decisões técnicas: ADRs 0002 e 0003.

## 28/10/2026: correção da esquiva

- O PO jogou a esquiva e achou que o personagem desacelerava ou travava ao terminar. Investigação antes de mexer: o perfil de velocidade terminava em zero e a recuperação de 0,18 s ignorava a entrada, então o personagem parava e recomeçava a correr do zero (~0,3 s de pausa). Um tick extra de velocidade zero por ponto flutuante agravava.
- Corrigido com saída da esquiva em velocidade de corrida, recuperação sem travar locomoção (configurável) e testes de fluidez. Detalhes no ADR 0002. Aguarda reteste do PO.
