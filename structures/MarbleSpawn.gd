class_name MarbleSpawn
extends StructureBase

const PEDESTAL_HEIGHT: float = 0.15
const MARBLE_RADIUS:   float = 0.185  # matches SphereShape3D radius in marble.tscn

@export var marble_scene: PackedScene = preload("res://structures/marble.tscn")

var _marble: RigidBody3D = null

@onready var _pedestal: Node3D = $Pedestal
@onready var _detector: Area3D = $MarbleDetector

# ── StructureBase hooks ────────────────────────────────────────────────────────

func on_placed() -> void:
	if marble_scene == null:
		push_warning("MarbleSpawn: marble_scene is null")
		return
	_marble          = marble_scene.instantiate() as RigidBody3D
	_marble.position = Vector3(0.0, PEDESTAL_HEIGHT + MARBLE_RADIUS, 0.0)
	_detector.body_exited.connect(_on_marble_exited)
	add_child(_marble)

func on_removed() -> void:
	if _marble != null and is_instance_valid(_marble):
		_marble.queue_free()
	_marble = null

# ── Pedestal retraction ────────────────────────────────────────────────────────

func _on_marble_exited(body: Node3D) -> void:
	if not body.is_in_group(&"marble"):
		return
	_detector.body_exited.disconnect(_on_marble_exited)
	_detector.queue_free()
	_retract_pedestal()

func _retract_pedestal() -> void:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = load("res://assets/sounds/PedestalRetraction.wav")
	add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

	var tween := create_tween()
	tween.tween_property(_pedestal, "position:y", _pedestal.position.y - PEDESTAL_HEIGHT, 0.3)
