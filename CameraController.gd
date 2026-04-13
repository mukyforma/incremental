class_name CameraController
extends Node3D

# ── Exported config (tweak in Inspector) ───────────────────────────────────────
@export_group("Pan & Move")
@export var pan_speed   : float = 0.003  ## World units per pixel when dragging
@export var wasd_speed  : float = 12.0   ## World units per second
@export var pan_smooth  : float = 40.0   ## Lerp speed for pan (higher = snappier)

@export_group("Rotation")
@export var rotate_speed : float = 0.4   ## Degrees per pixel when rotating
@export var rot_smooth   : float = 14.0  ## Lerp speed for rotation

@export_group("Zoom")
@export var zoom_step : float = 1.25     ## Zoom multiplier per scroll tick
@export var zoom_min  : float = 4.0      ## Orthographic size (smaller = closer)
@export var zoom_max  : float = 40.0

@export_group("Initial View")
@export var isometric_angle : float = 60.0  ## Pitch from horizontal — steeper = more top-down
@export var initial_zoom    : float = 12.0  ## Starting orthographic size
@export var initial_yaw     : float = 45.0  ## Starting horizontal rotation in degrees

# ── State ──────────────────────────────────────────────────────────────────────
var _camera        : Camera3D
var _pivot         : Vector3 = Vector3.ZERO   # target pivot (set by input)
var _pivot_smooth  : Vector3 = Vector3.ZERO   # visually interpolated pivot
var _ortho_size    : float                    # current zoom (Camera3D.size)
var _yaw           : float                    # target yaw in degrees
var _yaw_smooth    : float                    # visually interpolated yaw
var _dragging      : bool    = false
var _drag_origin   : Vector2 = Vector2.ZERO
var _pivot_origin  : Vector3 = Vector3.ZERO
var _rotating      : bool    = false
var _rot_origin    : Vector2 = Vector2.ZERO
var _yaw_origin    : float   = 0.0

# ── Setup ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_camera)
	_ortho_size = initial_zoom
	_yaw        = initial_yaw
	_yaw_smooth = initial_yaw
	_yaw_origin = initial_yaw
	_apply_camera_transform()

func get_camera() -> Camera3D:
	return _camera

# ── Input ──────────────────────────────────────────────────────────────────────
func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			if _dragging:
				_drag_origin  = event.position
				_pivot_origin = _pivot
		MOUSE_BUTTON_MIDDLE:
			_rotating = event.pressed
			if _rotating:
				_rot_origin = event.position
				_yaw_origin = _yaw
		MOUSE_BUTTON_WHEEL_UP:
			_ortho_size = clampf(_ortho_size / zoom_step, zoom_min, zoom_max)
			_camera.size = _ortho_size
			_apply_camera_transform()
		MOUSE_BUTTON_WHEEL_DOWN:
			_ortho_size = clampf(_ortho_size * zoom_step, zoom_min, zoom_max)
			_camera.size = _ortho_size
			_apply_camera_transform()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _rotating:
		_yaw = _yaw_origin - (event.position.x - _rot_origin.x) * rotate_speed
		return
	if not _dragging:
		return
	var delta : Vector2 = event.position - _drag_origin
	var right : Vector3 = _cam_right_xz()
	var fwd   : Vector3 = _cam_fwd_xz()
	_pivot = _pivot_origin \
		   - right * (delta.x * pan_speed * _ortho_size) \
		   + fwd   * (delta.y * pan_speed * _ortho_size)

func process_wasd(delta: float, input: InputEvent = null) -> void:
	var speed : float   = wasd_speed * delta
	var right : Vector3 = _cam_right_xz()
	var fwd   : Vector3 = _cam_fwd_xz()
	var move  : Vector3 = Vector3.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move += fwd   * speed
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move -= fwd   * speed
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move -= right * speed
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move += right * speed

	if move != Vector3.ZERO:
		_pivot += move.normalized() * speed

	# Smooth pivot and yaw toward their targets every frame
	var t_pan : float = minf(1.0, pan_smooth * delta)
	var t_rot : float = minf(1.0, rot_smooth * delta)
	_pivot_smooth = _pivot_smooth.lerp(_pivot, t_pan)
	_yaw_smooth   = lerpf(_yaw_smooth, _yaw, t_rot)
	_apply_camera_transform()

# ── Camera basis helpers (XZ plane, Y=0) ──────────────────────────────────────

## Rightward direction on screen, projected onto the XZ ground plane.
func _cam_right_xz() -> Vector3:
	var b := _camera.global_transform.basis.x
	return Vector3(b.x, 0.0, b.z).normalized()

## Forward direction on screen (toward top of screen), projected onto XZ.
## Camera looks along local -Z, so world-forward = -basis.z.
func _cam_fwd_xz() -> Vector3:
	var b := _camera.global_transform.basis.z
	return Vector3(-b.x, 0.0, -b.z).normalized()

# ── Transform application ──────────────────────────────────────────────────────
func _apply_camera_transform() -> void:
	var pitch : float = deg_to_rad(isometric_angle)
	var yaw   : float = deg_to_rad(_yaw_smooth)
	var arm   : float = 100.0   # large fixed distance — clipping won't be an issue

	var offset := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)
	) * arm

	_camera.position = _pivot_smooth + offset
	_camera.look_at(_pivot_smooth, Vector3.UP)
	_camera.size = _ortho_size
