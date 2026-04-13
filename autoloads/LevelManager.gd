extends Node

## Ordered list of objective definitions.
## structure_node is assigned at runtime when a matching structure is placed.
var _objectives: Array = [
	{
		"type":           "speed_gate",
		"structure_node": null,
		"min_speed":      2.0,
	}
]

var _current_index: int = 0

# ── Registration ───────────────────────────────────────────────────────────────

## Called by SpeedGate.on_placed(). Connects the gate to the first unassigned
## speed_gate objective so its triggered signal drives the condition check.
func register_speed_gate(gate: Node) -> void:
	for obj in _objectives:
		if obj["type"] == "speed_gate" and obj["structure_node"] == null:
			obj["structure_node"] = gate
			gate.triggered.connect(_on_speed_gate_triggered.bind(obj))
			return

# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_speed_gate_triggered(trigger_speed: float, obj: Dictionary) -> void:
	if _current_index >= _objectives.size():
		return
	var current_obj: Dictionary = _objectives[_current_index]
	if current_obj != obj:
		return
	var min_speed: float = current_obj["min_speed"]
	if trigger_speed >= min_speed:
		_on_objective_complete()
	else:
		print("Too slow: %.2f / %.2f" % [trigger_speed, min_speed])

# ── Objective progression ──────────────────────────────────────────────────────

func _on_objective_complete() -> void:
	print("OBJECTIVE COMPLETE")
	_current_index += 1
	# TODO: reveal next objective
