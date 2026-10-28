# ADR 0004: humanoide animado, a cápsula manda

Data: 28/10/2026. Estado: proposto no H1, aguardando avaliação do PO.

## Contexto

O PO aprovou a movimentação do Marco 1 (aceleração, frenagem, giro, câmera, esquiva fluida) e pediu um personagem humanoide com animação natural, **sem tornar o controle lento para parecer realista**.

## Decisões

1. **A cápsula manda, a animação acompanha.** `Player` não muda. O `HumanoidVisual` lê velocidade e estado a cada quadro e nunca escreve de volta. Nenhum atraso de animação pode afetar a entrada. Os 95 testes do Marco 1 seguem passando sem alterar tolerâncias.
2. **Eixo de mistura = velocidade real em m/s.** O `AnimationNodeBlendSpace1D` usa como pontos as velocidades de autoria dos clipes (Idle 0, Walk 0,77, Jog 5,46, Sprint 8,25). Walk e Jog foram calibrados pela velocidade do pé em apoio.
3. **Escala de tempo em vez de misturar ritmos.** A corrida de 6 m/s é o Jog a 1,10× (até 1,25×); o Sprint só entra acima disso e na investida da esquiva. Reduziu o deslize médio dos pés de 3,7 para 0,57 m/s.
4. **Ajustes procedurais num `SkeletonModifier3D`** (inclinação, braço da katana, investida). Rotações no espaço do modelo, suavização exponencial independente da taxa de quadros.
5. **Esquiva visual = ciclo de Sprint + inclinação procedural**, não o clipe `Roll` (cambalhota acrobática, avaliado e descartado). A cápsula segue o perfil de velocidade aprovado.
6. **Sem root motion.** Usamos `UAL1_Standard.glb` (sem root motion); o deslocamento vem da cápsula.
7. **Ativos CC0 versionados** (redistribuição permitida), com registro em `docs/ativos/registro.md`.

## Alternativas descartadas

- Root motion ou máquina de estados que bloqueia a entrada durante transições: recriaria a pausa que corrigimos na esquiva.
- `Roll` do pacote como esquiva: visual desproporcional ao tempo de 0,25 s.
- Suavizar o ponto de mistura: adicionaria atraso visual; a mistura já é contínua porque a velocidade da cápsula é contínua.
- IK de pés com `TwoBoneIK3D` no H1: o solver não moveu os ossos em 4.7.2 na nossa configuração (ver `docs/h1-locomocao.md`, §7). Código removido; fica para o H2.

## Consequências

- Sem clipes de partida, parada e giro, essas transições são só misturas; a naturalidade depende de refinamentos no H2 (clipes autorais, IK, molas).
- O pipeline de modificadores custa ~1,4 ms por personagem; inimigos não devem usá-lo.
