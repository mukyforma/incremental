class_name Marble
extends RapierRigidBody3D
# implements GridObject interface — see base/GridObject.gd
#const RADIUS: float = 0.12

# ── Grid ──────────────────────────────────────────────────────────────────────
@export var hex_position: Vector2i
@export var height_level: int
var structure_type: StringName = &""
func _get_class() -> String: return "GridObject"

# ── Components ────────────────────────────────────────────────────────────────
@onready var _vfx: MarbleVFXComponent = $VFX

signal respawned
var spawn_position: Vector3

func _ready() -> void:
	# Rapier defaults para marble run.
	# body_skin: folga ao redor do collider, evita tremor nas calhas.
	# soft_ccd:  interpola posição entre frames, evita tunneling em rampas rápidas.
	super()
	freeze = true
	add_to_group(&"marble")

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_vfx.tick(delta, global_position)

# ── Reset ─────────────────────────────────────────────────────────────────────
## Freeze and clear all motion. Position is set externally by MarbleSpawn.
## Called by Collector when the marble enters its DeliveryArea.
func reset() -> void:
	freeze            = true
	linear_velocity   = Vector3.ZERO
	angular_velocity  = Vector3.ZERO
	_vfx._speed        = 0.0
	_vfx._display_speed = 0.0
	respawned.emit()

func place_at(pos: Vector3) -> void:
	global_position = pos
	_vfx._last_pos  = pos

# ── StructureBase interface ───────────────────────────────────────────────────
func on_placed() -> void:
	pass

func on_removed() -> void:
	pass
