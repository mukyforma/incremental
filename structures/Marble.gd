class_name Marble
extends RigidBody3D

## Marble cannot extend StructureBase (already extends RigidBody3D),
## so the interface is duplicated here manually.

#const RADIUS: float = 0.12

@export var hex_position: Vector2i
@export var height_level: int
var structure_type: StringName = &""

## Velocidade base de troca de cor (ciclos por segundo) quando parada.
@export var base_hue_rate: float = 0.04
## Quanto a velocidade da esfera acelera a troca de cor.
@export var speed_hue_gain: float = 0.25
## Suavização da leitura de velocidade.
@export var speed_smoothing: float = 0.12

@onready var _mesh:  MeshInstance3D = $MeshInstance3D
@onready var _light: OmniLight3D    = $OmniLight3D
@onready var _label: Label3D        = $Label3D

var _shader_mat: ShaderMaterial
var _last_pos: Vector3
var _speed: float = 0.0
var _hue: float = 0.0

func _ready() -> void:
	freeze = true
	add_to_group(&"marble")
	_last_pos = global_position
	_shader_mat = _mesh.get_active_material(0) as ShaderMaterial
	_hue = randf()

func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	# Mede velocidade pelo delta de posição (freeze zera linear_velocity).
	var current_pos: Vector3 = global_position
	var instant_speed: float = current_pos.distance_to(_last_pos) / delta
	_last_pos = current_pos
	_speed = lerp(_speed, instant_speed, speed_smoothing)

	# Acumula matiz. Como a taxa varia com a velocidade, integrar no script
	# garante que shader e luz nunca saiam de sincronia.
	var hue_rate: float = base_hue_rate + _speed * speed_hue_gain
	_hue = fposmod(_hue + delta * hue_rate, 1.0)

	var col: Color = Color.from_hsv(_hue, 0.7, 1.0)

	if _shader_mat:
		_shader_mat.set_shader_parameter(&"hue_offset", _hue)
		# Opcional: o turbilhão acelera levemente junto com a esfera.
		_shader_mat.set_shader_parameter(&"swirl_speed", 1.2 + _speed * 0.6)

	_light.light_color = col
	_light.light_energy = 0.5 + min(_speed * 0.15, 1.5)

	_label.global_position = global_position + Vector3.UP * 0.38
	_label.text = "%.1f m/min" % (_speed * 60.0)

# ── StructureBase interface ────────────────────────────────────────────────────
func on_placed() -> void:
	pass

func on_removed() -> void:
	pass
