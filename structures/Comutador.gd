class_name Comutador
extends StructureBase

## The scene instantiated as a visual marker on the base (socket) hex.
## Assign comutador_base.tscn in the Inspector (or via the .tscn export).
@export var base_scene: PackedScene

## Axial offset from sensor to base; can be overridden in the Inspector.
@export var base_offset: Vector2i = Vector2i(1, 0)

var _toggled       : bool     = false
var _sensor_hex    : Vector2i          # hex where the sensor (arch) currently sits
var _base_hex      : Vector2i          # hex that acts as the socket for guest structures
var _base_instance : Node3D  = null   # visual disc on the base hex

# ── Lifecycle ──────────────────────────────────────────────────────────────────

@onready var _sensor_area: Area3D = $SensorArea

func is_base_socket(hex: Vector2i) -> bool:
	return hex == _base_hex

func on_placed() -> void:
	super()
	_sensor_hex = hex_position
	_base_hex   = _calc_base_hex(_sensor_hex, rotation_steps)

	# Spawn the base disc as a sibling (Main receives spawn_requested and calls add_child)
	if base_scene != null:
		_base_instance = base_scene.instantiate() as Node3D
		StructureEvents.spawn_requested.emit(
			_base_instance,
			HexGrid.hex_to_world_at_height(_base_hex, height_level))

	_sensor_area.body_entered.connect(_on_marble_entered)
	HexGrid.register_comutador_base(_base_hex)

func on_removed() -> void:
	super()
	if is_instance_valid(_base_instance):
		_base_instance.queue_free()
	_base_instance = null
	HexGrid.unregister_comutador_base(_base_hex)

# ── Marble detection ──────────────────────────────────────────────────────────

func _on_marble_entered(body: Node3D) -> void:
	if not body.is_in_group("marble"):
		return
	_toggle()

# ── Toggle ────────────────────────────────────────────────────────────────────

func _toggle() -> void:
	# 1. Find any guest structure currently sitting on the base socket
	var base_structure: StructureBase = HexGrid.get_structure(_base_hex, 0)

	# 2. Move this node (sensor arch) to the base hex world position
	global_position = HexGrid.hex_to_world_at_height(_base_hex, height_level)

	# 3. Slide the Comutador's grid registration from sensor → base
	#    move_structure handles identity-guarded unregister so it won't
	#    clobber a guest that was just retrieved in step 1.
	HexGrid.move_structure(self, _base_hex)

	# 4. Slide the disc visual to the old sensor hex (new base)
	if is_instance_valid(_base_instance):
		_base_instance.global_position = \
			HexGrid.hex_to_world_at_height(_sensor_hex, height_level)

	# 5. Carry the guest structure from old base → old sensor
	if base_structure != null:
		var old_sensor := _sensor_hex
		base_structure.global_position = \
			HexGrid.hex_to_world_at_height(old_sensor, base_structure.height_level)
		HexGrid.move_structure(base_structure, old_sensor)

	# 6. Commit the hex swap
	var temp    := _sensor_hex
	_sensor_hex  = _base_hex
	_base_hex    = temp

	_toggled = not _toggled

# ── Helpers ───────────────────────────────────────────────────────────────────

## Computes the base hex from a given sensor position and rotation.
## Converts to axial space, applies the rotated offset, converts back.
func _calc_base_hex(sensor: Vector2i, rot: int) -> Vector2i:
	var axial_sensor := HexGrid._offset_to_axial(sensor)
	var rotated      := HexGrid.rotate_hex_offset(base_offset, rot)
	var axial_base   := axial_sensor + rotated
	return HexGrid._axial_to_offset(axial_base.x, axial_base.y)
