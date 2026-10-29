extends SceneTree
## Grava os valores iniciais do C1 em arquivos editáveis no inspetor:
## game/data/defesa.tres (DefenseData) e game/data/instrutor_ataque.tres (EnemyAttackData).
##   godot --headless --path . -s res://tools/make_c1_resources.gd
func _initialize() -> void:
	print("[c1] defesa: ", error_string(ResourceSaver.save(DefenseData.new(), DefenseData.DEFAULT_PATH)))
	print("[c1] instrutor: ", error_string(ResourceSaver.save(EnemyAttackData.new(), EnemyAttackData.DEFAULT_PATH)))
	quit()
