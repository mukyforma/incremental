class_name StructureButton
extends Button

# ── Config ─────────────────────────────────────────────────────────────────────
const BTN_SIZE      : int   = 64
const CORNER        : int   = 6
const ACCENT        : Color = Color(0xF5A623FF)
const BG_NORMAL     : Color = Color(0.14, 0.14, 0.17, 1.0)
const BG_HOVER      : Color = Color(0.22, 0.22, 0.27, 1.0)
const BG_SELECTED   : Color = Color(0.20, 0.20, 0.25, 1.0)

@export var structure_type  : StringName = &""
@export var shortcut_key    : String     = ""
@export var preview_cam_size: float      = 1.5

var _viewport: SubViewport

# ── Setup ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	custom_minimum_size      = Vector2(BTN_SIZE, BTN_SIZE)
	size_flags_horizontal    = Control.SIZE_SHRINK_CENTER
	size_flags_vertical      = Control.SIZE_SHRINK_CENTER
	toggle_mode              = true
	focus_mode               = Control.FOCUS_NONE
	clip_contents            = true

	_setup_styles()
	_build_viewport()
	_build_shortcut_label()
	_build_preview()

	pressed.connect(_on_pressed)
	PlacementController.selection_changed.connect(_on_selection_changed)
	_on_selection_changed()

# ── Styles ─────────────────────────────────────────────────────────────────────
func _setup_styles() -> void:
	add_theme_stylebox_override("normal",        _make_style(BG_NORMAL,   false))
	add_theme_stylebox_override("hover",         _make_style(BG_HOVER,    false))
	add_theme_stylebox_override("pressed",       _make_style(BG_SELECTED, true))
	add_theme_stylebox_override("hover_pressed", _make_style(BG_SELECTED, true))
	add_theme_stylebox_override("focus",         _make_style(BG_NORMAL,   false))

func _make_style(bg: Color, selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                  = bg
	s.corner_radius_top_left    = CORNER
	s.corner_radius_top_right   = CORNER
	s.corner_radius_bottom_left = CORNER
	s.corner_radius_bottom_right = CORNER
	if selected:
		s.border_color        = ACCENT
		s.border_width_left   = 2
		s.border_width_right  = 2
		s.border_width_top    = 2
		s.border_width_bottom = 2
	return s

# ── SubViewport icon ───────────────────────────────────────────────────────────
func _build_viewport() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch      = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.size                    = Vector2i(BTN_SIZE, BTN_SIZE)
	_viewport.transparent_bg          = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.world_3d                = World3D.new()   # isolated world per button
	container.add_child(_viewport)

func _build_shortcut_label() -> void:
	var lbl := Label.new()
	lbl.text                                = shortcut_key
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.offset_left  = -16
	lbl.offset_top   = -16
	lbl.size         = Vector2(14, 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

# ── 3-D preview scene ──────────────────────────────────────────────────────────
func _build_preview() -> void:
	# Environment
	var env_node  := WorldEnvironment.new()
	var env       := Environment.new()
	env.background_mode       = Environment.BG_COLOR
	env.background_color      = Color(0.0, 0.0, 0.0, 0.0)   # transparent
	env.ambient_light_source  = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color   = Color(0.45, 0.45, 0.5)
	env.ambient_light_energy  = 0.9
	env_node.environment      = env
	_viewport.add_child(env_node)

	# Directional light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	light.light_energy     = 1.1
	_viewport.add_child(light)

	# Isometric camera
	var cam        := Camera3D.new()
	cam.projection  = Camera3D.PROJECTION_ORTHOGONAL
	cam.size        = preview_cam_size
	var pitch := deg_to_rad(60.0)
	var yaw   := deg_to_rad(45.0)
	var arm   := 10.0
	cam.position    = Vector3(
		cos(pitch) * sin(yaw) * arm,
		sin(pitch) * arm,
		cos(pitch) * cos(yaw) * arm)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	_viewport.add_child(cam)

	# Structure-specific preview
	var _def: StructureDefinition = StructureCatalog.get_by_type(structure_type)
	if _def != null:
		if _def.preview_mesh_path != "":
			_preview_glb(_def.preview_mesh_path)
		# else: skip mesh — same as current silent behavior
	else:
		match structure_type:
			&"marble_spawn":  _preview_marble_spawn()
			&"launch_cannon": _preview_launch_cannon()
			&"solid1":        _preview_glb("res://assets/solid1.glb")
			&"solid2":        _preview_glb("res://assets/solid2.glb")
			&"solid4":        _preview_glb("res://assets/solid4.glb")
			&"reto":          _preview_glb("res://assets/reto.glb")
			&"curva60":       _preview_glb("res://assets/curva60.glb")
			&"curva120":      _preview_glb("res://assets/curva120.glb")
			&"rampa1":        _preview_glb("res://assets/rampa1.glb")
			&"rampa2":        _preview_glb("res://assets/rampa2.glb")
			&"solid8":        _preview_glb("res://assets/solid8.glb")
			&"collector":     _preview_glb("res://assets/meshes/collector.glb")

func _add_preview_mesh(mesh: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, rot_y: float = 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.55
	mat.metallic     = 0.25
	var mi  := MeshInstance3D.new()
	mi.mesh              = mesh
	mi.material_override = mat
	mi.position          = pos
	mi.rotation.y        = rot_y
	_viewport.add_child(mi)

func _preview_marble_spawn() -> void:
	var ped := CylinderMesh.new()
	ped.top_radius = 0.08;  ped.bottom_radius = 0.08;  ped.height = 0.15
	_add_preview_mesh(ped, Color.WHITE, Vector3(0, 0.075, 0))

	var sph := SphereMesh.new()
	sph.radius = 0.12;  sph.height = 0.24
	_add_preview_mesh(sph, Color.WHITE, Vector3(0, 0.27, 0))

func _preview_launch_cannon() -> void:
	var base := CylinderMesh.new()
	base.top_radius = 0.35;  base.bottom_radius = 0.35
	base.height = 0.10;      base.radial_segments = 32
	_add_preview_mesh(base, Color(1.0, 0.5, 0.0), Vector3(0, 0.05, 0))

	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.08;  barrel.bottom_radius = 0.08;  barrel.height = 0.40
	_add_preview_mesh(barrel, Color(0.75, 0.3, 0.0), Vector3(0, 0.30, 0))

func _preview_solid_hex() -> void:
	var hex := CylinderMesh.new()
	hex.top_radius = 0.75;  hex.bottom_radius = 0.75
	hex.height = 0.45;      hex.radial_segments = 6
	_add_preview_mesh(hex, Color(0.5, 0.5, 0.5))

func _preview_glb(path: String) -> void:
	var scene: PackedScene = load(path)
	if scene == null:
		return
	var inst: Node3D = scene.instantiate() as Node3D
	if inst == null:
		return
	_viewport.add_child(inst)

# ── State sync ─────────────────────────────────────────────────────────────────
func _on_pressed() -> void:
	PlacementController.set_structure(structure_type)

func _on_selection_changed() -> void:
	set_pressed_no_signal(PlacementController.active_structure == structure_type)
