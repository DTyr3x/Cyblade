# ADR 0005: combate de katana (H2)

Status: proposto, aguardando o playtest do PO.

## Contexto

Depois da locomoção humanoide aprovada (H1/H1.1), o H2 entrega o primeiro combate: cadeia de 3 golpes, alvo de treino, acerto e retorno de impacto, preservando movimento, câmera e esquiva aprovados. O estudo de Dinghai (`docs/direcao-movimento-combate.md`) mostra golpes comuns sem tremor de câmera detectável, esquiva que cancela, avanço curto nos golpes.

## Decisões

1. **A cápsula manda.** O estado `ATTACK` do `Player` decide movimento, avanço e giro; a animação só reage. Nenhum atraso artificial na entrada.
2. **Dados separados de comportamento.** `StrikeData` e `ComboSet` são `Resource`s. Tempos no tempo do clipe, divididos por `speed`: um parâmetro muda o ritmo sem desalinhar as janelas. Valores iniciais em `game/data/katana_combo.tres`.
3. **`CombatController` não conhece animação nem alvos.** Emite sinais; visual, detector e efeitos escutam. Permite a Forja de Combos trocar o `ComboSet` sem mexer no controlador.
4. **Animação:** `OneShot` do `AnimationTree` sobre a locomoção, com seletor de clipe e escala de velocidade. Clipes derivados de `Sword_Attack` em tempo de carga (`KatanaClips`), sem arquivos novos. Golpe 2 espelhado (fórmula do quaternion validada visualmente; as outras duas fórmulas testadas giravam o corpo).
5. **Acerto por varredura analítica** (segmento da lâmina contra cápsula) em vez de física: determinístico nos testes, sem dependência da taxa de quadros, com passos entre amostras para lâmina rápida. 1 acerto por alvo por `swing_id`.
6. **Hitstop local:** congela o relógio do golpe, o clipe do golpe e o alvo; o resto do jogo segue.
7. **Esquiva cancela cedo** (`dodge_cancel_from` baixo) e a recuperação cancela por movimento: o jogador não fica preso. Esquiva sem alteração de parâmetros.
8. **Sons sintetizados em código** como provisórios (sem licença de terceiros).
9. **Tremor de câmera só no golpe final** (0,03 m), conforme a observação do estudo.

## Consequências

- Os 3 golpes compartilham uma única base de movimento do pacote (limitação principal, pendência 10). A arquitetura aceita clipes novos: basta trocar a origem em `KatanaClips` por golpe.
- Avanço pela cápsula com clipes no lugar faz os pés escorregarem (pendência 11).
- A estrutura já separa o que a Forja de Combos precisará (dados, estado, efeitos), sem implementar editor, cartas ou árvore de combos.
