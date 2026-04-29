class_name MarbleVFXComponent
extends Node

@export var base_hue_rate: float = 0.04
@export var speed_hue_gain: float = 0.25
@export var speed_smoothing: float = 0.12

const _LABEL_INTERVAL: float = 0.15

var _hue: float = 0.0
var _speed: float = 0.0
var _display_speed: float = 0.0
var _label_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO

var _shader_mat: ShaderMaterial
@onready var _label: Label3D = owner.get_node("Label3D") as Label3D

func _ready() -> void:
	_last_pos = (owner as Node3D).global_position
	_hue = randf()
	var mesh := owner.get_node("MeshInstance3D") as MeshInstance3D
	if mesh:
		_shader_mat = mesh.get_active_material(0) as ShaderMaterial

## Called each frame by Marble._process(). Receives the marble's current world position.
func tick(delta: float, current_pos: Vector3) -> void:
	if delta <= 0.0:
		return

	# Mede velocidade pelo delta de posição (freeze zera linear_velocity).
	var instant_speed: float = current_pos.distance_to(_last_pos) / delta
	_last_pos = current_pos
	_speed = lerp(_speed, instant_speed, speed_smoothing)

	# Acumula matiz. Como a taxa varia com a velocidade, integrar no script
	# garante que shader e luz nunca saiam de sincronia.
	var hue_rate: float = base_hue_rate + _speed * speed_hue_gain
	_hue = fposmod(_hue + delta * hue_rate, 1.0)

	if _shader_mat:
		_shader_mat.set_shader_parameter(&"hue_offset", _hue)
		_shader_mat.set_shader_parameter(&"swirl_speed", 1.2 + _speed * 0.6)

	_label.global_position = current_pos + Vector3.UP * 0.38

	_display_speed = lerp(_display_speed, _speed, 0.04)
	_label_timer += delta
	if _label_timer >= _LABEL_INTERVAL:
		_label_timer = 0.0
		_label.text = "%.1f m/min" % (_display_speed * 60.0)
