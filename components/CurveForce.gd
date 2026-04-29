class_name CurveForce
extends Node3D

@export var force_strength: float = 2.0
@export var debug: bool = false

var _area: Area3D
var _label: Label3D

func _ready() -> void:
	# owned=false is required: RapierArea3D lives in the parent scene, so its
	# scene-owner is the parent root, not this instanced subscene.
	_area = find_child("RapierArea3D", true, false)
	if _area == null:
		_area = get_parent().find_child("RapierArea3D", true, false)
	if _area == null:
		push_warning("CurveForce: no RapierArea3D found near " + name)
		return
	print("CurveForce [", name, "]: area found -> ", _area.get_path())

	if debug:
		_label = Label3D.new()
		_label.font_size = 32
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.position = Vector3(0, 0.6, 0)
		add_child(_label)
		_update_label([])

func _physics_process(_delta: float) -> void:
	if _area == null:
		return

	var marbles: Array = _area.get_overlapping_bodies().filter(
		func(b): return b.is_in_group("marble")
	)

	for body in marbles:
		var marble := body as RigidBody3D
		if marble.linear_velocity.length() > 0.01:
			marble.apply_central_force(
				marble.linear_velocity.normalized() * force_strength
			)

	if debug and _label:
		_update_label(marbles)

func _update_label(marbles: Array) -> void:
	if marbles.is_empty():
		_label.text = "CurveForce\nidle"
		_label.modulate = Color(0.6, 0.6, 0.6)
	else:
		_label.text = "CurveForce ACTIVE\n%d marble(s) | F=%.1f" % [marbles.size(), force_strength]
		_label.modulate = Color(0.2, 1.0, 0.4)
