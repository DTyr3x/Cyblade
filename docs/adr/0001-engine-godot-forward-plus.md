# ADR 0001: Godot 4 com Forward+ e GDScript

- **Data:** 28/10/2026
- **Status:** decidido pelo PO

## Contexto

A pesquisa técnica sobre a demo de Dinghai (feita fora deste repositório, por observação externa de gravações próprias, sem engenharia reversa) recomendou Unreal Engine 5 pelo teto visual, pelas ferramentas de animação e de VFX. O principal risco apontado para a UE5 era a produtividade com IA, porque Blueprints e assets são binários.

## Decisão

O PO escolheu **Godot 4.7.2, renderizador Forward+, GDScript**. Cenas (`.tscn`) e recursos (`.tres`) são texto, o que facilita automação, revisão e histórico no Git.

## Consequências

- Vantagem: iteração rápida, arquivos legíveis por IA e por humanos, sem royalties, projeto leve.
- Custo: teto visual menor que o da UE5 (sem Nanite, GI dinâmica mais limitada) e menos ferramentas de animação. O Marco 2 mede isso cedo.
- As sugestões de configuração específicas da UE5 na pesquisa não se aplicam. As medidas de câmera e de combate continuam válidas como referência.
- Confirmado em 28/10/2026: o Forward+ roda em Vulkan 1.4 na RTX 5070 Ti.
