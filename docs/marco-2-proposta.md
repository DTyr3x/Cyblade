# Marco 2: proposta técnica de direção gráfica (NÃO IMPLEMENTADO)

Status: proposta para aprovação do PO. Nada deste documento foi implementado. Godot 4.7.2, Forward+.

**Limites desta proposta**

- A **imagem de referência aprovada pelo PO** (ninja cyberpunk contra robôs numa megacidade industrial) não está no repositório nem foi enviada a esta sessão. A direção abaixo parte da descrição do briefing. O primeiro passo do Marco 2 é receber a imagem e transformá-la em um quadro de estilo.
- Os números de desempenho são **orçamentos propostos**, não medições. A única medição disponível (arena simples, ~0,4 ms de GPU) não permite extrapolar.
- As capacidades do Godot citadas devem ser **confirmadas em um spike curto** na versão 4.7.2 antes de serem adotadas.
- O FPS na máquina de desenvolvimento está limitado por um fator externo não identificado (pendência 5); isso precisa ser resolvido antes de medir.

## 1. Objetivo e critério de sucesso

Uma **vertical slice visual**: uma arena industrial cinematográfica com o ninja original, em que uma captura em gameplay seja comparável à imagem de referência em composição, atmosfera e legibilidade, mantendo o combate responsivo.

Critérios de aceitação propostos:

1. Quadro de estilo aprovado pelo PO antes de produzir ativos finais.
2. Comparação lado a lado com a referência, em 3 ângulos, aprovada pelo PO.
3. Orçamento de desempenho cumprido na RTX 5070 Ti e em uma configuração-alvo mais fraca (a definir pelo PO, por exemplo uma GPU da classe RTX 3060).
4. Legibilidade: o jogador, os ataques e os perigos continuam claros com todos os efeitos ligados (teste humano).
5. Sem erros nos logs e testes automatizados do Marco 1 ainda passando.

## 2. Pilares gráficos

### 2.1 Personagem ninja original
- **Concepto e silhueta primeiro:** armadura tecnológica escura, detalhes vermelhos emissivos, katana. Silhueta legível a 10% da altura da tela (a câmera de combate), então o design precisa funcionar pequeno: formas grandes, poucos detalhes finos, contraste vermelho.
- **Produção:** modelagem e rig em Blender, exportação glTF. Esqueleto compatível com o `AnimationTree` do Godot. Orçamento inicial: 40 a 60 mil triângulos no LOD0, 2 LODs.
- **Materiais:** PBR com mapas de albedo, rugosidade, metal, normal e emissão. Cabelo/tecido (cachecol) com `SkeletonModifier3D`/física secundária, se a spike mostrar custo aceitável.
- **Animação no Marco 2:** apenas as básicas (parado, correr, esquiva) para avaliar o visual em movimento. O conjunto de combate é do Marco 3.
- **Origem dos ativos:** apenas autorais ou de licença livre registrada em `assets/LICENSES.md`. Nada de jogos de referência.
- **Decisão que cabe ao PO:** quem modela (autoral, IA generativa, kit licenciado). Afeta prazo, custo e portfólio.

### 2.2 Arena industrial cinematográfica
- **Kit modular** (vigas, passarelas, tubulações, painéis, pilares) montado em cena, para variar a arena sem custo de arte única.
- **Profundidade:** três planos (primeiro plano jogável, plano médio com estruturas e fumaça, fundo monumental em camadas). O fundo pode ser de baixo custo (cartões, silhuetas, geometria simplificada).
- **Composição para a câmera de 45°:** nada de teto que bloqueie a vista; estruturas altas aparecem nas bordas. A régua de escala do Marco 1 é mantida como cena de teste.
- **Legibilidade de combate:** o piso jogável tem valor e saturação mais baixos que os elementos de perigo (vermelho reservado a ataques inimigos).

### 2.3 Iluminação avançada
Estratégia em camadas, com decisões baseadas em spike:

| Camada | Opção principal | Alternativa |
|---|---|---|
| Luz direta | 1 luz direcional fraca (lua/neon do céu) com sombras em cascata | Luzes de preenchimento sem sombra |
| GI | **LightmapGI** nas partes estáticas (melhor custo/qualidade em arena fixa) | SDFGI (dinâmico, mais barato de configurar, mais ruído e vazamento) ou VoxelGI por zona |
| Luzes de cena | Poucas omni/spot com sombra, muitas sem sombra; emissivos que iluminam via GI | Decalques de luz falsos para o fundo |
| Reflexos | **SSR** + reflection probes nas poças e metais | Probes estáticas apenas |
| Oclusão ambiente | SSAO/SSIL (ver custo) | Ambiente baked no lightmap |
| Contato de personagem | Luz de recorte (rim) vermelha e ciano ligada ao personagem | Sombra falsa em blob |

Regra: luz dinâmica de efeitos (faíscas, rastros) é emissiva + glow; evitar muitas luzes com sombra.

### 2.4 Materiais PBR
- Fluxo albedo/rugosidade/metal/normal/AO, texturas de 2K nos itens principais e 1K/512 nos secundários, com **mipmaps e compressão VRAM** (BPTC/S3TC).
- Variação de superfície por **triplanar/detalhe** em shaders compartilhados (sujeira, ferrugem, desgaste), poças molhadas por máscara.
- Painéis de neon/hologramas por emissão e shader animado (varredura, flicker).
- Biblioteca de materiais em `game/materials/`, com um arquivo de padrões de cor da paleta.

### 2.5 Névoa e atmosfera
- **Névoa volumétrica** do Godot (volumetric fog) com densidade baixa e luzes selecionadas, mais **névoa de altura** barata para o fundo. Ambas são caras em 4K: orçar à parte.
- Camadas de **fumaça/vapor** por GPUParticles3D com sprites e billboard no plano médio.
- Cor atmosférica por distância para criar profundidade (ciano frio ao fundo, âmbar/vermelho perto de perigos).
- **Raios de luz** (god rays) falsos com cartões aditivos, mais baratos que volumetria completa.

### 2.6 Efeitos visuais
- **Rastro da katana:** malha em fita gerada por script (ou shader com histórico de posições), material aditivo vermelho-branco, persistência ~0,3 s como medido na referência para golpes pesados (valor de ponto de partida).
- **Esquiva:** rastro/after-image e poeira; marcador de início (sem dano ainda).
- **Faíscas e partículas de impacto:** GPUParticles3D com colisão desligada; orçamento de partículas por efeito.
- **Impacto:** clarão de material (parâmetro de shader no inimigo, 2 a 3 quadros), glow e leve distorção.
- **Pós-processo:** glow/bloom controlado, tonemapper **AgX ou ACES** (comparar), correção de cor, vinheta leve, aberração cromática mínima, DOF só em cenas especiais. Motion blur desligado por padrão (a referência o teve desligado nas configurações observadas).
- Efeitos de combate completos ficam para o Marco 3; o Marco 2 entrega a **biblioteca de efeitos** e o orçamento.

## 3. Otimização e testes de desempenho

**Orçamento inicial proposto (a calibrar)**

| Item | Meta |
|---|---|
| Tempo de quadro | 60 fps estáveis na configuração-alvo mínima; 120+ fps na máquina de desenvolvimento a 1440p |
| GPU (quadro) | ≤ 8 ms na máquina de desenvolvimento em 1440p com tudo ligado |
| Luzes com sombra | até 4 simultâneas; luzes sem sombra em maior número |
| Draw calls | monitorar; usar MultiMesh e instâncias para o kit modular |
| Triângulos visíveis | a definir após a spike de oclusão |

**Técnicas:** occlusion culling, **visibility ranges** (HLOD), LOD automático de malhas, MultiMesh para repetição, luzes estáticas bakeadas, atlas de texturas, upscaling (TAA/FSR 2 do Godot) como opção de qualidade, escalabilidade por configuração (Baixo/Médio/Alto/Cinematográfico).

**Testes:**
1. Resolver o teto de ~117 FPS (pendência 5) para medir de verdade.
2. Reaproveitar `tools\playtest.ps1` para medir FPS, p99 e tempo de render GPU/CPU por trecho em cada configuração gráfica.
3. Perfilar o pico de ~61 ms ao trocar enquadramento (pendência 2).
4. Teste de estresse: arena cheia de partículas e luzes, medir degradação.
5. Capturas padronizadas (mesmos 3 ângulos) a cada etapa, comparadas com a referência.
6. Testes automatizados do Marco 1 mantidos verdes.

## 4. Riscos gráficos e alternativas dentro do Godot

| Risco | Probabilidade / impacto | Mitigação e alternativa |
|---|---|---|
| Teto visual do Godot abaixo da referência (sem Nanite, GI dinâmica limitada) | Alta / Alto | Compensar com arte dirigida: geometria simplificada bem iluminada, lightmaps, fundo em camadas. **Alternativa:** definir um nível-alvo "estilizado cinematográfico" em vez de realismo |
| Custo de volumetric fog e SSR/SSIL em 4K | Média / Alto | Medir cedo; versões baratas (névoa de altura, cartões, probes); escalabilidade |
| SDFGI com ruído/vazamento em estruturas finas | Média / Médio | Usar LightmapGI nas partes estáticas; VoxelGI por zona |
| Muitas luzes com sombra | Alta / Alto | Orçamento fixo; emissivos e GI em vez de luzes |
| Legibilidade perdida com bloom, névoa e partículas | Média / Alto | Paleta com cor de perigo exclusiva; teste humano; ajuste de intensidade por configuração |
| Cabelo/tecido e animação fluida (sem motion matching) | Alta / Médio | Animações autorais de boa qualidade; blend por AnimationTree; secundária simples |
| Ativos do ninja originais de qualidade e licença | Média / Alto | Definir a origem (PO); registrar licenças; começar com o quadro de estilo |
| Transição de shaders (stutter na primeira vez) | Média / Médio | Pré-aquecimento de shaders, cache de pipeline, tela de carregamento |
| Compatibilidade de GPU alvo | Média / Médio | Configuração-alvo mais fraca definida pelo PO e testada |
| Teto de FPS externo mascarando medidas | Já observado / Médio | Resolver primeiro (pendência 5) |

**Alternativas se a spike mostrar limites:** reduzir a resolução de render com upscaling, trocar volumetria por névoa de altura, travar a GI em lightmap, simplificar sombras (apenas direcional), usar renderizador Mobile só se o ganho compensar a perda de recursos (provável **não**).

## 5. Plano de execução proposto

| Etapa | Entrega | Critério |
|---|---|---|
| 2.0 Preparação | Receber a referência; quadro de estilo (paleta, materiais, silhuetas); resolver teto de FPS; configuração-alvo mais fraca | Quadro de estilo aprovado pelo PO |
| 2.1 Spike técnico | Cena de teste com GI (Lightmap vs SDFGI), névoa, SSR e partículas; medições | Relatório curto com custos e recomendação |
| 2.2 Arena blockout → kit modular | Arena montada com materiais PBR provisórios | Escala e legibilidade aprovadas |
| 2.3 Iluminação e atmosfera | Luzes, GI, névoa, pós-processo | Comparação lado a lado com a referência |
| 2.4 Ninja | Concepto → modelo → rig → materiais → animações básicas | Silhueta legível a 10% de altura |
| 2.5 Biblioteca de VFX | Rastro, impacto, esquiva, faíscas | Orçamento de partículas cumprido |
| 2.6 Otimização e testes | Escalabilidade, playtest scriptado, capturas | Metas de desempenho e logs limpos |
| 2.7 Entrega | Relatório, capturas, vídeo, ADRs, PR | Avaliação do PO |

Tudo em branches `feat/marco-2-*`, com commits reais, PR por etapa relevante, sem merge sem aprovação.

## 6. Decisões que dependem do PO

1. Envio da **imagem de referência aprovada** (e se há outras).
2. **Quem produz o ninja** e a arte da arena (autoral, ferramentas de IA, kit licenciado) e o orçamento.
3. **Configuração-alvo mínima** de hardware.
4. Nível de realismo: **realista cinematográfico** ou **estilizado dirigido por arte** (recomendado, pelo teto do Godot).
5. Se Blender e demais ferramentas podem ser instalados (nenhum pacote grande foi instalado sem autorização).
6. Se o teto de ~117 FPS é conhecido (perfil de energia, limitador do driver, monitor).

## 7. Referência de Dinghai: o que usar

- Câmera com duas funções (alta para combate, baixa para chefes), já implementada nos presets.
- Impacto em camadas e curto (clarão, número, rastro persistente).
- Telegrafia vermelha consistente, paleta contida com acento saturado.
- Efeitos fortes sem tremor de câmera nos golpes comuns.

Só observações visuais; nada de ativos, código ou dados proprietários.
