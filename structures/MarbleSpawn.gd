class_name MarbleSpawn
extends StructureBase

@export var marble_scene: PackedScene = preload("res://structures/marble.tscn")

var _marble: Marble = null

@onready var _spawn_origin: Marker3D = $SpawnOrigin

func on_placed() -> void:
	add_to_group("marble_spawn")
	if marble_scene == null:
		push_warning("MarbleSpawn: marble_scene is null")
		return
	_marble        = marble_scene.instantiate() as Marble
	_marble.freeze = true
	add_child(_marble)
	_marble.place_at(_spawn_origin.global_position)
	_marble.respawned.connect(_on_marble_respawned)
	_schedule_launch()

func _on_marble_respawned() -> void:
	_marble.place_at(_spawn_origin.global_position)
	_schedule_launch()

func _schedule_launch() -> void:
	await get_tree().create_timer(2.0).timeout
	activated.emit()

func on_removed() -> void:
	remove_from_group("marble_spawn")
	if _marble != null and is_instance_valid(_marble):
		_marble.queue_free()
	_marble = null
