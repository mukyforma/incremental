class_name LaunchCannon
extends StructureBase

# ── Config ─────────────────────────────────────────────────────────────────────
## World-unit radius to scan for marbles (1 adjacent hex center ≈ 1.73 units).
const DETECT_RANGE : float = 2.0
## Minimum dot product with forward direction — must be within ±60° of barrel.
const FRONT_DOT    : float = 0.5
## Speed below which a marble is considered stationary (m/s).
const STILL_SPEED  : float = 0.08
## How long the marble must be still before firing (seconds).
const STILL_TIME   : float = 0.8
## Cooldown after firing before scanning again (seconds).
const FIRE_COOLDOWN: float = 1.5
## How often to search for a marble (seconds).
const SCAN_RATE    : float = 0.1

@export var launch_force: float = 30.0

signal launched(marble: RigidBody3D)

# ── State ──────────────────────────────────────────────────────────────────────
var _tracked_marble : RigidBody3D = null
var _still_timer    : float       = 0.0
var _cooldown_timer : float       = 0.0
var _scan_timer     : float       = 0.0

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func on_removed() -> void:
	_tracked_marble = null

# ── Per-frame logic ────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# Wait out cooldown after a shot
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		_tracked_marble  = null
		return

	# Periodically scan for a marble in front
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer     = SCAN_RATE
		_tracked_marble = _find_front_marble()

	if _tracked_marble == null or not is_instance_valid(_tracked_marble):
		_still_timer    = 0.0
		_tracked_marble = null
		return

	# Accumulate stationary time (frozen body counts as v=0)
	var speed: float = 0.0 if _tracked_marble.freeze else _tracked_marble.linear_velocity.length()
	if speed < STILL_SPEED:
		_still_timer += delta
		if _still_timer >= STILL_TIME:
			_fire()
	else:
		_still_timer = 0.0

# ── Marble search ──────────────────────────────────────────────────────────────
## Searches the "marble" group for a body that is within DETECT_RANGE and
## in the forward half of the cannon. Works for frozen and unfrozen marbles.
func _find_front_marble() -> RigidBody3D:
	var fwd    : Vector3 = _get_forward()
	var origin : Vector3 = global_position

	for node in get_tree().get_nodes_in_group(&"marble"):
		if not (node is RigidBody3D):
			continue
		var rb   : RigidBody3D = node as RigidBody3D
		var diff : Vector3     = rb.global_position - origin
		diff.y = 0.0
		var dist : float = diff.length()
		if dist < 0.05 or dist > DETECT_RANGE:
			continue
		if fwd.dot(diff.normalized()) >= FRONT_DOT:
			return rb

	return null

## World-space horizontal forward direction of the cannon (unit length).
func _get_forward() -> Vector3:
	var fwd : Vector3 = -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		return Vector3.FORWARD
	return fwd.normalized()

# ── Firing ─────────────────────────────────────────────────────────────────────
func _fire() -> void:
	if not is_instance_valid(_tracked_marble):
		return
	var fwd : Vector3 = _get_forward()
	_tracked_marble.freeze          = false
	_tracked_marble.linear_velocity  = Vector3.ZERO
	_tracked_marble.angular_velocity = Vector3.ZERO
	_tracked_marble.apply_central_impulse(fwd * launch_force)
	launched.emit(_tracked_marble)
	print("LaunchCannon [%s]: fired!" % name)
	_still_timer    = 0.0
	_tracked_marble = null
	_cooldown_timer = FIRE_COOLDOWN
