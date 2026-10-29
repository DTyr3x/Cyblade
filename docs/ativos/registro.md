# Registro de ativos externos

Todo recurso de terceiros do projeto é listado aqui, com origem, licença e condições. Nenhum recurso de *Dinghai: The Ocean Pillar* é usado.

## UAL1_Standard.glb (Quaternius, Universal Animation Library)

| Campo | Valor |
|---|---|
| Arquivo no projeto | `assets/characters/ual/UAL1_Standard.glb` (versão **sem root motion**, 7,6 MB) |
| Origem | https://quaternius.itch.io/universal-animation-library (download "Universal Animation Library[Standard].zip", 15 MB, versão v3.0 de 16/06/2026) |
| Autor | Quaternius (animações com ajuda de Gonzalo Furnier, citado pelo autor) |
| Licença | **CC0 1.0 Universal** (domínio público). Texto distribuído com o pacote: `assets/licencas/quaternius-ual/License.txt` |
| Condições | Uso pessoal, educacional e comercial; redistribuição permitida; sem atribuição obrigatória (agradecemos o autor no README) |
| Baixado em | 28/10/2026, pelo Claude Code por autorização do PO; SHA-256 do zip: `cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724` |
| Não incluídos | `UAL1_Standard_RM.glb` (root motion) e os `.fbx` do Unity: não são necessários, a cápsula comanda o movimento |
| Conteúdo (43 clipes, esqueleto de 65 ossos, malha "Mannequin") | A_TPose, Idle_Loop, Walk_Loop, Walk_Formal_Loop, Jog_Fwd_Loop, Sprint_Loop, Crouch_Idle_Loop, Crouch_Fwd_Loop, Roll, Sword_Idle, Sword_Attack, Hit_Chest, Hit_Head, Death01, Jump_*, Punch_*, Pistol_*, Spell_*, Swim_*, Sitting_*, Push_Loop, Dance_Loop, Driving_Loop, Interact, PickUp_Table, Fixing_Kneeling, Bandage… |
| **Ausente nesta versão** | Locomoção em 8 direções (só existe `Jog_Fwd_Loop`/`Sprint_Loop` para a frente), animação de dash dedicada. A página do autor lista locomoção em 8 direções na edição paga (Pro). **Nada disso foi inventado**: veja `docs/h1-locomocao.md` para como cada falta foi tratada |

Velocidades de autoria medidas por nós (versão com root motion, só para calibrar): Walk ≈ 0,97 m/s, Jog ≈ 5,36 m/s, Sprint ≈ 8,25 m/s.

### Modificações feitas por nós
Descritas em `docs/h1-locomocao.md` (ajustes procedurais de postura em código, katana modelada por nós). O arquivo `.glb` em si **não foi modificado**.

## Ferramentas (não distribuídas)

| Ferramenta | Versão | Uso |
|---|---|---|
| Godot | 4.7.2 stable | Engine (MIT) |
| Blender | 4.5.10 LTS (winget `BlenderFoundation.Blender.LTS.4.5`) | Inspeção e ajustes de animação (GPL; nada do Blender é distribuído) |

## Clipes de golpe da katana (H2, derivados de `Sword_Attack`)

| Campo | Valor |
|---|---|
| Origem | **Nenhum ativo novo.** Os três golpes são derivados do clipe `Sword_Attack` (1,53 s) do mesmo pacote UAL (CC0) acima |
| Como | `game/combat/katana_clips.gd`: recorte de trecho, amostragem a 60 Hz e, no golpe 2, espelhamento esquerda/direita (troca de ossos `_l`/`_r` e quaternion `(x, -y, -z, w)`). Gerado em memória na carga, nenhum arquivo de animação novo no repositório |
| Licença / redistribuição | CC0 (a mesma do pacote); obras derivadas permitidas |
| Limite conhecido | O pacote Standard tem **um único** clipe de espada: os três golpes compartilham a mesma base de movimento (diferem por trecho, espelhamento, ritmo e avanço). Clipes autorais distintos ficam como pendência (`docs/pendencias-tecnicas.md`, item 10) |

## Sons provisórios (H2)

| Campo | Valor |
|---|---|
| Origem | **Sintetizados em código** (`game/combat/generated_sounds.gd`): ruído filtrado para o corte, estalo + toque metálico para o contato |
| Licença | Originais do projeto; sem arquivo de áudio de terceiros, nada a verificar. Provisórios: devem ser trocados por áudio de verdade no marco de som |

## Efeitos visuais (H2)

Rastro, faíscas e clarão são feitos em código (malha dinâmica, `CPUParticles3D`, textura de gradiente gerada em código). Nenhum asset externo.
