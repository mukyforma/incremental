class_name SpeedGate
extends StructureBase

signal triggered(trigger_speed: float)

const _MARBLE_SCENE: PackedScene = preload("res://structures/marble.tscn")
const MARBLE_RADIUS: float = 0.185
const ARCH_RADIUS:   float = 0.05
const SEAT_HEIGHT:   float = 0.05

var _top_marble: RigidBody3D = null

@onready var _gate_area: Area3D = $GateArea
@onready var _marble_spawn: Node3D = $MarbleSpawn

# ── StructureBase hooks ────────────────────────────────────────────────────────

func _ready() -> void:
	super._ready()

func on_placed() -> void:
	_top_marble = _MARBLE_SCENE.instantiate() as RigidBody3D
	add_child(_top_marble)
	_top_marble.freeze = true
	_top_marble.position = _marble_spawn.position
	_gate_area.body_entered.connect(_on_body_entered_gate)
	StructureEvents.structure_placed.emit(self)

func on_removed() -> void:
	if is_instance_valid(_top_marble):
		_top_marble.queue_free()
	_top_marble = null

# ── Gate detection ─────────────────────────────────────────────────────────────

func _on_body_entered_gate(body: Node3D) -> void:
	if not body.is_in_group(&"marble"):
		return
	var speed: float = (body as RigidBody3D).linear_velocity.length()
	print("SpeedGate triggered at speed: %.2f" % speed)
	triggered.emit(speed)
	_launch_top_marble(speed)

# ── Top-marble launch ──────────────────────────────────────────────────────────

func _launch_top_marble(trigger_speed: float) -> void:
	if not is_instance_valid(_top_marble):
		return
	# First pass: marble is still seated as our child — unfreeze and reparent it.
	# Subsequent passes: it already lives in the parent scene, just re-impulse it.
	if _top_marble.get_parent() == self:
		_top_marble.freeze = false
		StructureEvents.reparent_requested.emit(_top_marble, get_parent())
	_top_marble.apply_central_impulse(Vector3.UP * trigger_speed * 2.0)
