# Seleção de ativos CC0 para o H1 (proposta)

Data: 28/10/2026. **Nada foi baixado nem importado ainda.** Este documento registra a seleção, a verificação de licença e a política. O registro definitivo (arquivo a arquivo) será `docs/ativos/registro.md`, criado no download.

Decisões do PO: animações CC0 sem conta; arquivos de terceiros só entram no Git se a licença permitir redistribuição; repositório público.

## Política

- CC0 permite redistribuição, então os arquivos CC0 **podem** ser versionados, mas cada um entra com entrada no registro (origem, URL, autor, licença, data, quem baixou, alterações).
- Cópia do texto/página da licença guardada em `assets/licencas/`.
- Qualquer ativo com licença que não permita redistribuição fica fora do Git (`.gitignore`) e é só referenciado no registro.
- Nenhum recurso de Dinghai.

## Candidatos

| Pacote | Licença verificada | O que traz para o H1 | Observação |
|---|---|---|---|
| **Quaternius, Universal Animation Library** ([site](https://quaternius.com/packs/universalanimationlibrary.html), [itch.io](https://quaternius.itch.io/universal-animation-library)) | CC0; "livre para uso pessoal, educacional e comercial"; sem exigência de atribuição na página | 120+ animações em rig humanoide universal: locomoção em 8 direções, jog, sprint, idles; exportações para Godot; formatos GLB/FBX/Blend | **Primeira escolha** para idle, andar, correr e variações. A versão Standard (45 animações) é gratuita; a Source (com .blend) pode ser paga |
| **Quaternius, Universal Animation Library 2** ([itch.io](https://quaternius.itch.io/universal-animation-library-2)) | CC0; "nome o seu preço" (42 animações gratuitas; a Source de $14,99+ inclui o .blend) | Combos de espada (`SWORD_REGULAR_A`, `SWORD_DASH`), locomoção com root motion | Mesmo rig do pacote 1. **Útil no C1** (golpes), não necessário no H1 |
| **KayKit, Character Animations** ([itch.io](https://kaylousberg.itch.io/kaykit-character-animations)) | CC0; uso pessoal e comercial, sem atribuição | Rig_Medium: animações de uma mão, defesa, golpe pesado | **Reserva** se o rig do Quaternius não servir |
| **KayKit, Adventurers** (personagens) | CC0 (a verificar no download) | Modelos estilizados low-poly | Só para o corpo provisório, se necessário. O estilo não combina com o realismo desejado |

Não escolhido: Mixamo (exige conta Adobe e tem restrições de redistribuição dos arquivos brutos), por decisão do PO.

## Escolha proposta

1. **Rig e animações:** Quaternius UAL (Standard gratuito) para idle, andar, correr e esquiva (a pasta deve ser conferida: **dodge/roll não aparece na lista pública**; se faltar, a esquiva usa o `SWORD_DASH` do UAL 2 ou um clipe autoral feito no Blender).
2. **Corpo provisório:** o personagem de demonstração que acompanha o pacote (mesmo rig), com a katana modelada por nós (cilindro/malha simples) presa à mão, e postura de corrida de espadachim (espada para trás) feita com ajuste autoral no Blender sobre o clipe de corrida.
3. **Ajustes autorais no Blender:** inclinação do tronco, braço da espada para trás no ciclo de corrida, e esquiva se não houver clipe adequado. O resultado é "baseado em CC0, ajustado por nós", sem afirmar que a importação equivale à qualidade de Dinghai.

## Pendências desta seleção

- Conferir no pacote baixado os nomes reais dos clipes, o esqueleto (nomes de ossos, compatibilidade com `SkeletonProfileHumanoid` e `BoneMap`) e a presença de arquivo de licença.
- O download no itch.io é gratuito e sem conta, mas exige confirmação na página. Peço autorização antes de baixar (arquivo, origem e tamanho serão informados).
