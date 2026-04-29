class_name SoundComponent
extends Node3D

@export var sound: AudioStream
@export var volume_db: float = 0.0
@export var pitch_scale: float = 1.0
@export var unit_size: float = 32.0

@onready var _player: AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready() -> void:
	if _player == null:
		push_error("SoundComponent [%s]: AudioStreamPlayer3D not found" % name)
		return
	_player.stream      = sound
	_player.volume_db   = volume_db
	_player.pitch_scale = pitch_scale
	_player.unit_size   = unit_size
	var parent := get_parent()
	if parent != null and parent.get(&"activatable"):
		parent.activated.connect(_play)

func _play() -> void:
	if _player == null or sound == null:
		return
	_player.stop()
	_player.play()

func _on_activated() -> void:
	_play()


func _on_collector_activated() -> void:
	pass # Replace with function body.
