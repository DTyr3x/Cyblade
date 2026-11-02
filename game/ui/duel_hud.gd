class_name DuelHud
extends CanvasLayer
## HUD do confronto: vida do jogador, vida do robô e a mensagem central. A postura fica no anel, no chão.

const PLAYER_COLOR := Color(0.2, 0.85, 1.0)
const ROBOT_COLOR := Color(1.0, 0.16, 0.18)

var _player_bar: ColorRect
var _robot_bar: ColorRect
var _player_trail: ColorRect
var _robot_trail: ColorRect
var _title: Label
var _subtitle: Label
var _veil: ColorRect
var _player_ratio := 1.0
var _robot_ratio := 1.0


func _ready() -> void:
	_veil = ColorRect.new()
	_veil.color = Color(0.0, 0.0, 0.03, 0.55)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	var left := _bar(Vector2(40, 1000), Vector2(460, 16), "NINJA", PLAYER_COLOR)
	_player_bar = left[0]
	_player_trail = left[1]
	var top := _bar(Vector2(560, 34), Vector2(800, 14), "ROBÔ DE COMBATE", ROBOT_COLOR)
	_robot_bar = top[0]
	_robot_trail = top[1]
	_title = _label(72, 400.0)
	_subtitle = _label(26, 500.0)
	_subtitle.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))


func _bar(pos: Vector2, size: Vector2, text: String, color: Color) -> Array[ColorRect]:
	var back := ColorRect.new()
	back.color = Color(0.03, 0.04, 0.07, 0.8)
	back.position = pos - Vector2(3, 3)
	back.size = size + Vector2(6, 6)
	add_child(back)
	var trail := ColorRect.new()
	trail.color = Color(1, 1, 1, 0.75)
	trail.position = pos
	trail.size = size
	add_child(trail)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = pos
	fill.size = size
	add_child(fill)
	var label := Label.new()
	label.text = text
	label.position = pos + Vector2(0, -26)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)
	return [fill, trail]


func _label(font_size: int, top: float) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.offset_top = top
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	return label


func set_player_health(ratio: float) -> void:
	_player_ratio = clampf(ratio, 0.0, 1.0)


func set_robot_health(ratio: float) -> void:
	_robot_ratio = clampf(ratio, 0.0, 1.0)


## Mensagem central. Vazia = luta em andamento, sem véu.
func show_message(title: String, subtitle := "") -> void:
	_title.text = title
	_subtitle.text = subtitle
	_veil.visible = title != ""


func message() -> String:
	return _title.text


func _process(delta: float) -> void:
	_set_ratio(_player_bar, _player_trail, _player_ratio, 460.0, delta)
	_set_ratio(_robot_bar, _robot_trail, _robot_ratio, 800.0, delta)


## A barra acompanha na hora; o rastro branco desce devagar e mostra o tamanho do golpe.
func _set_ratio(bar: ColorRect, trail: ColorRect, ratio: float, width: float, delta: float) -> void:
	bar.size.x = width * ratio
	trail.size.x = maxf(bar.size.x, lerpf(trail.size.x, bar.size.x, MotionMath.smooth_alpha(delta, 0.25)))
