class_name WeaponStance
extends Resource
## Postura de locomoção de uma FAMÍLIA de arma: como o braço armado e o tronco se comportam
## na corrida. Cada família (katana, lâmina dupla, lança...) terá a sua; hoje só existe a katana.
##
## Dados puros: o HumanoidPoseModifier lê estes valores, o HumanoidVisual constrói a arma.
## Direções no espaço do modelo (+Z frente, +Y cima, -X lado direito do personagem), relativas
## ao peito em repouso (acompanham a rotação do tronco).

const KATANA := &"katana"

## Famílias reservadas para o futuro. Sem postura própria, caem na katana (com aviso).
const PLANNED := [&"lamina_dupla", &"lanca", &"machado", &"adaga"]

@export var family: StringName = KATANA
@export var display_name := "Katana"
## Osso onde a arma é presa.
@export var grip_bone := "hand_r"
## Direções-alvo do braço (osso -> filho) na corrida.
@export var upper_dir := Vector3(-0.25, -0.55, -0.79)
@export var fore_dir := Vector3(-0.15, -0.05, -0.99)
## Peso mínimo da postura mesmo parado/andando.
@export_range(0.0, 1.0) var idle_amount := 0.55
## Fração do movimento do clipe que o braço ainda conserva na corrida (0 = travado, 1 = só o clipe).
## Pequena de propósito: tira o balanço excessivo mas deixa o braço vivo.
@export_range(0.0, 1.0) var arm_swing_keep := 0.2
## Inclinação do tronco à frente na velocidade máxima (graus) somada à do clipe.
@export var lean_forward_deg := 6.0


static func katana() -> WeaponStance:
	return WeaponStance.new()


## Postura da família pedida. Famílias ainda não implementadas usam a da katana.
static func for_family(id: StringName) -> WeaponStance:
	if id == KATANA:
		return katana()
	if id not in PLANNED:
		push_warning("WeaponStance: família desconhecida '%s', usando katana" % id)
	return katana()
