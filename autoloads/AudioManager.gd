extends Node

var _sfx_volume_db:   float = 0.0
var _music_volume_db: float = 0.0

func play_sfx(stream: AudioStream, position: Vector3 = Vector3.ZERO) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream   = stream
	player.position = position
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func set_sfx_volume(db: float) -> void:
	_sfx_volume_db = db

func set_music_volume(db: float) -> void:
	_music_volume_db = db
