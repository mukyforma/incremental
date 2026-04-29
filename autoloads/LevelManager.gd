extends Node

signal objective_completed(index: int)
signal level_completed()
signal level_loaded(data: LevelData)

var _level_data: LevelData = null
var _completed:  Array[bool] = []

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	StructureEvents.structure_placed.connect(_on_structure_placed)

# ── Level loading ──────────────────────────────────────────────────────────────

func load_level(data: LevelData) -> void:
	_level_data = data
	_completed  = []
	_completed.resize(data.objectives.size())
	_completed.fill(false)
	level_loaded.emit(data)

# ── Structure registration (internal) ─────────────────────────────────────────

func _on_structure_placed(structure: Node) -> void:
	if structure is SpeedGate:
		_register_speed_gate(structure as SpeedGate)

func _register_speed_gate(gate: SpeedGate) -> void:
	if _level_data == null:
		return
	for i in range(_level_data.objectives.size()):
		var obj: ObjectiveData = _level_data.objectives[i]
		if obj.type == &"speed_gate" and not _completed[i]:
			gate.triggered.connect(_on_speed_gate_triggered.bind(i))
			return

# ── Objective notification ─────────────────────────────────────────────────────

## Generic entry point for objective progress; used by structures that don't
## have a direct signal connection (e.g. future types).
func notify_objective(type: StringName, payload: Dictionary) -> void:
	if _level_data == null:
		return
	for i in range(_level_data.objectives.size()):
		if _completed[i]:
			continue
		var obj: ObjectiveData = _level_data.objectives[i]
		if obj.type != type:
			continue
		if type == &"speed_gate":
			var speed: float = payload.get("speed", 0.0)
			if speed >= obj.min_speed:
				_complete_objective(i)
			else:
				print("Too slow: %.2f / %.2f" % [speed, obj.min_speed])
		return

# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_speed_gate_triggered(trigger_speed: float, index: int) -> void:
	if _level_data == null or index >= _level_data.objectives.size():
		return
	if _completed[index]:
		return
	var obj: ObjectiveData = _level_data.objectives[index]
	if trigger_speed >= obj.min_speed:
		_complete_objective(index)
	else:
		print("Too slow: %.2f / %.2f" % [trigger_speed, obj.min_speed])

# ── Completion ─────────────────────────────────────────────────────────────────

func _complete_objective(index: int) -> void:
	_completed[index] = true
	print("OBJECTIVE COMPLETE")
	objective_completed.emit(index)
#	AudioManager.play_sfx(load("res://assets/sounds/objective_completed.wav"))

	if _completed.all(func(c: bool) -> bool: return c):
		level_completed.emit()
