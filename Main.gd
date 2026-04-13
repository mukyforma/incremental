extends Node

const HUD_SCENE      := preload("res://ui/HUD.tscn")
const SAVE_MENU_SCR  := preload("res://ui/SaveMenu.gd")

# ── Scene refs ─────────────────────────────────────────────────────────────────
var _cam_ctrl  : CameraController
var _renderer  : HexRenderer
var _plane     : Plane = Plane(Vector3.UP, 0.0)

var _spawn_structure : MarbleSpawn = null
var _save_menu       : CanvasLayer  = null

# ── Ghost preview ──────────────────────────────────────────────────────────────
var _ghost     : Node3D  = null
var _ghost_hex : Vector2i = Vector2i(2147483647, 2147483647)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_cam_ctrl = CameraController.new()
	add_child(_cam_ctrl)

	_renderer = HexRenderer.new()
	add_child(_renderer)
	_renderer.set_camera(_cam_ctrl.get_camera())
	_renderer.update_visible_region()

	_add_lighting()
	_add_hud()
	_add_save_menu()

	# Carrega o save mais recente automaticamente; se não houver, monta a demo
	var latest := SaveSystem.get_latest_save()
	if latest != "":
		_load_from_save(latest)
	else:
		_build_demo()

	PlacementController.selection_changed.connect(_on_placement_changed)
	_rebuild_ghost()

	print("─── Controls ───────────────────────────────")
	print("  WASD / arrows    Pan camera")
	print("  Scroll wheel     Zoom")
	print("  Right-drag       Pan (mouse)")
	print("  1–6              Select structure")
	print("  Q / E            Rotate structure CCW / CW")
	print("  B / X / C        Build / Delete / Eyedropper")
	print("  Left click       Place / Delete / Pick")
	print("  Space            Release marble from spawn")
	print("  R                Reset demo")
	print("────────────────────────────────────────────")

# ── HUD ────────────────────────────────────────────────────────────────────────
func _add_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var hud := HUD_SCENE.instantiate()
	canvas.add_child(hud)

# ── Save menu ──────────────────────────────────────────────────────────────────
func _add_save_menu() -> void:
	_save_menu = SAVE_MENU_SCR.new()
	add_child(_save_menu)
	_save_menu.saved.connect(_on_save_requested)
	_save_menu.loaded.connect(_on_load_requested)

# ── Demo scene ─────────────────────────────────────────────────────────────────
func _build_demo() -> void:
	# MarbleSpawn one tile in front of the cannon
	var spawn := HexGrid.spawn_structure(Vector2i(1, 0), 0, &"marble_spawn", self)
	_spawn_structure = spawn as MarbleSpawn

	# Cannon at (2,0) — rotation step 1 faces −X, pointing at the marble spawn
	var cannon := HexGrid.spawn_structure(Vector2i(2, 0), 0, &"launch_cannon", self)
	cannon.rotation.y = _hex_rotation(1)

	if HexGrid.can_place_solid_hex(Vector2i(-1, 0), 0):
		HexGrid.spawn_structure(Vector2i(-1, 0), 0, &"solid1", self)
	if HexGrid.can_place_solid_hex(Vector2i(-1, 0), 1):
		HexGrid.spawn_structure(Vector2i(-1, 0), 1, &"solid1", self)

func _reset_demo() -> void:
	# Collect all (hex, height) pairs without modifying dict mid-iteration
	var to_remove: Array = []
	for hex in HexGrid._cells:
		for h in HexGrid._cells[hex].stack.keys():
			to_remove.append([hex, h])
	for entry in to_remove:
		HexGrid.despawn_structure(entry[0], entry[1])
	_spawn_structure = null
	_build_demo()

# ── Lighting ───────────────────────────────────────────────────────────────────
func _add_lighting() -> void:
	var env_node := WorldEnvironment.new()
	var env      := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.05, 0.07, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.30, 0.35, 0.40)
	env.ambient_light_energy = 1.0
	env_node.environment     = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy     = 1.2
	sun.shadow_enabled   = true
	add_child(sun)

# ── Input (unhandled = UI didn't consume it) ───────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_save_menu.toggle()
			return

	# Bloqueia todo input de jogo enquanto o menu estiver aberto
	if _save_menu.visible:
		return

	_cam_ctrl.handle_input(event)

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if _spawn_structure != null:
					_spawn_structure.release_marble()
					print("Marble released!")
			KEY_R:
				_reset_demo()
				print("Demo reset.")

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(event.position)

func _process(delta: float) -> void:
	if _save_menu.visible:
		return
	_cam_ctrl.process_wasd(delta)
	_update_hover(get_viewport().get_mouse_position())
	_renderer.update_visible_region()

# ── Hover ──────────────────────────────────────────────────────────────────────
func _update_hover(screen_pos: Vector2) -> void:
	var cam : Camera3D = _cam_ctrl.get_camera()
	var hit            = _plane.intersects_ray(
		cam.project_ray_origin(screen_pos),
		cam.project_ray_normal(screen_pos))
	if hit != null:
		var hex := HexGrid.world_to_hex(hit)
		_renderer.set_hover(hex)
		_move_ghost(hex)

# ── Click dispatch ─────────────────────────────────────────────────────────────
func _on_left_click(screen_pos: Vector2) -> void:
	var cam : Camera3D = _cam_ctrl.get_camera()
	var hit            = _plane.intersects_ray(
		cam.project_ray_origin(screen_pos),
		cam.project_ray_normal(screen_pos))
	if hit == null:
		return

	var hex : Vector2i = HexGrid.world_to_hex(hit)

	match PlacementController.active_tool:
		&"build":
			_do_build(hex)
		&"delete":
			_do_delete(hex)
		&"eyedropper":
			_do_eyedrop(hex)
		&"select_area":
			pass   # placeholder

func _do_build(hex: Vector2i) -> void:
	var type   : StringName = PlacementController.active_structure
	var top_h  : int        = HexGrid.get_top_height(hex)
	var height : int        = max(0, top_h + 1)

	if type in HexGrid.SOLID_TYPES and not HexGrid.can_place_solid_hex(hex, height):
		print("Cannot place SolidHex at %s height %d — support rules not met" % [hex, height])
		return

	var span: int = HexGrid.HEIGHT_SPANS.get(type, 1)
	for i in range(1, span):
		var cell := HexGrid.get_cell(hex)
		if cell != null and cell.stack.has(height + i):
			print("Cannot place %s: height %d is already occupied" % [type, height + i])
			return

	var s := HexGrid.spawn_structure(hex, height, type, self)
	if s == null:
		return

	# Apply placement rotation (snapped to the 6 hex neighbour directions)
	s.rotation.y = _hex_rotation(PlacementController.placement_rotation)

	# Track new MarbleSpawn so Space releases it
	if s is MarbleSpawn:
		_spawn_structure = s

	print("Placed %s at col=%d row=%d height=%d rot=%d°" % [
		type, hex.x, hex.y, height, PlacementController.placement_rotation * 60])

func _do_delete(hex: Vector2i) -> void:
	var top_h : int = HexGrid.get_top_height(hex)
	if top_h < 0:
		return
	HexGrid.despawn_structure(hex, top_h)
	print("Deleted structure at col=%d row=%d height=%d" % [hex.x, hex.y, top_h])

func _do_eyedrop(hex: Vector2i) -> void:
	var type : StringName = HexGrid.get_top_structure_type(hex)
	if type != &"":
		PlacementController.set_structure(type)
		print("Eyedropper: picked '%s'" % type)
	PlacementController.set_tool(&"build")

# ── Ghost preview ──────────────────────────────────────────────────────────────

## Called whenever active tool or structure changes.
func _on_placement_changed() -> void:
	_rebuild_ghost()

func _rebuild_ghost() -> void:
	# Destroy old ghost
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

	# Only show ghost in build mode
	if PlacementController.active_tool != &"build":
		return

	var scene: PackedScene = StructureRegistry.get_scene(PlacementController.active_structure)
	if scene == null:
		return

	_ghost = scene.instantiate() as Node3D
	# Disable processing so scripts don't run (no physics, no timers)
	_ghost.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_ghost)
	_ghost.visible = false

	# Apply ghost visuals: transparent blue tint + disabled collisions
	_ghost_apply_visuals(_ghost)

func _ghost_apply_visuals(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	if node is CollisionObject3D:
		var co := node as CollisionObject3D
		co.collision_layer = 0
		co.collision_mask  = 0
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.85, 1.0, 0.40)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_ghost_apply_visuals(child)

func _move_ghost(hex: Vector2i) -> void:
	if not is_instance_valid(_ghost):
		return
	var top_h  : int = HexGrid.get_top_height(hex)
	var height : int = max(0, top_h + 1)
	_ghost.global_position = HexGrid.hex_to_world_at_height(hex, height)
	_ghost.rotation.y      = _hex_rotation(PlacementController.placement_rotation)
	_ghost.visible         = true

## Converts a Q/E rotation step (0–5) to a rotation.y angle (radians).
## Each step is exactly 60°. Directional structures (e.g. LaunchCannon) bake
## an additional 30° into their own BarrelPivot so their barrel aligns with
## the 6 hex neighbour directions without offsetting all other structures.
func _hex_rotation(step: int) -> float:
	return step * (PI / 3.0)

# ── Save / Load ────────────────────────────────────────────────────────────────

func _on_save_requested(save_name: String) -> void:
	if SaveSystem.save(save_name):
		print("Salvo: " + save_name)
	else:
		push_error("Falha ao salvar: " + save_name)

func _on_load_requested(save_name: String) -> void:
	_load_from_save(save_name)

func _load_from_save(save_name: String) -> void:
	var structures: Array = SaveSystem.load_save(save_name)
	if structures.is_empty():
		push_error("Nenhuma estrutura no save: " + save_name)
		return

	# Limpa o grid atual
	var to_remove: Array = []
	for hex in HexGrid._cells:
		for h in HexGrid._cells[hex].stack.keys():
			to_remove.append([hex, h])
	for entry in to_remove:
		HexGrid.despawn_structure(entry[0], entry[1])
	_spawn_structure = null

	# Recria as estruturas salvas
	for s_data in structures:
		var hex    := Vector2i(int(s_data.hex_x), int(s_data.hex_y))
		var height := int(s_data.height)
		var stype  := StringName(str(s_data.type))
		var rot    := float(s_data.rotation_y)

		var s := HexGrid.spawn_structure(hex, height, stype, self)
		if s != null:
			s.rotation.y = rot
			if s is MarbleSpawn:
				_spawn_structure = s

	print("Save carregado: " + save_name)
