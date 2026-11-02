# Filosofia de combate do CYBLADE

Decisão do PO (29/10/2026). Substitui as metas de equivalência com outros jogos. Registro formal: `docs/adr/0006-combate-identidade-propria.md`.

## Princípio

O CYBLADE tem um combate **próprio**, de ninja cyberpunk: extremamente responsivo, satisfatório e recompensador de dominar. A satisfação vem das **decisões, da precisão e do domínio do jogador**, não do excesso de efeitos. Referências externas não são mais metas de equivalência, e não haverá novas pesquisas de comparação para definir o combate.

## O que o combate valoriza

1. **Controle manual e responsivo.** A cápsula manda; nenhuma animação atrasa a entrada (regra mantida desde o H1).
2. **Golpes com identidade** e animações convincentes (Kesa, Kiriage e, em avaliação, Tsuki).
3. **Parry com timing recompensador** (C1).
4. **Esquiva fluida** (aprovada).
5. **Contra-ataques** (C1.1, aprovado).
6. **Quebra de postura** (C2).
7. **Finalização manual** (C2).
8. **Energia Neural** recompensando execução habilidosa (C3).
9. **Feedback audiovisual sincronizado** ao instante real do contato.
10. **Clareza visual e curva de aprendizado justa:** o jogador entende por que acertou ou errou.

## Regras de projeto

- **Tempo em segundos, nunca em quadros.** Toda janela é dado configurável em segundos; a lógica roda na física a 120 Hz e funciona a 60 FPS estáveis ou mais.
- **Dados separados da lógica:** defesa, parry, ataques inimigos, postura, Energia Neural, reações e feedback em recursos editáveis e componentes separados.
- **Reaproveitar o que existe** (`CombatController`, `StrikeData`, `HitDetector`, `CombatEffects`, boneco de treino) e evitar reescritas grandes.
- **Sem travamentos artificiais:** toda consequência tem duração curta, explicada e cancelável por esquiva.
- **Efeito proporcional ao feito:** quanto mais difícil a ação, mais forte o retorno, sem esconder a cena.
- **Escopo incremental:** C1 → C2 → C3 → C4, cada etapa jogável e aprovada pelo PO antes da próxima.

## Estado preservado

| Sistema | Estado |
|---|---|
| Locomoção H1.1 | Aprovada, sem mudanças |
| Esquiva e transições | Aprovadas, sem mudanças |
| Kesa avançado | Aprovado, congelado (SHA-256 em `docs/h2-1-combate-katana.md`) |
| Kiriage de retorno | Aprovado, congelado (SHA-256 em `docs/h2-2-kiriage.md`) |
| Tsuki de passo duplo | Implementado, **não aprovado** |
| Mira, colisões, buffer, infraestrutura | Mantidos |
| PR #3 | Aberto, sem merge |

## Roteiro

| Etapa | Conteúdo | Situação |
|---|---|---|
| C1 | Parry, deflexão e contra-ataque de oportunidade, com inimigo de treino | C1.0 e C1.1 aprovados pelo PO |
| C2 | Pressão de postura, quebra e finalização manual. Sem postura do jogador | Direção aprovada pelo PO. C2.0 em avaliação (`docs/c2-0-nucleo-postura.md`); C2.1 a C2.4 sem implementação |
| C3 | Combate contra inimigo, Energia Neural, refinamento da cadeia de 3 golpes | Só planejamento |
| C4 | Polimento de efeitos e áudio, legibilidade, curva de aprendizado, integração com a Forja de Combos | Só planejamento |
