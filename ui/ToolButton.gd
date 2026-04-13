class_name ToolButton
extends Button

# ── Config ─────────────────────────────────────────────────────────────────────
const BTN_SIZE   : int   = 48
const CORNER     : int   = 6
const ACCENT     : Color = Color(0xF5A623FF)
const BG_NORMAL  : Color = Color(0.14, 0.14, 0.17, 1.0)
const BG_HOVER   : Color = Color(0.22, 0.22, 0.27, 1.0)
const BG_SELECTED: Color = Color(0.20, 0.20, 0.25, 1.0)

@export var tool_name    : StringName = &""
@export var shortcut_key : String     = ""
@export var icon_char    : String     = ""
@export var tool_label   : String     = ""

var _tooltip_lbl: Label

# ── Setup ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	custom_minimum_size   = Vector2(BTN_SIZE, BTN_SIZE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	toggle_mode           = true
	focus_mode            = Control.FOCUS_NONE
	clip_contents         = false   # tooltip overflows

	_setup_styles()
	_build_icon_label()
	_build_shortcut_label()
	_build_tooltip_label()

	mouse_entered.connect(_show_tooltip)
	mouse_exited.connect(_hide_tooltip)
	pressed.connect(_on_pressed)
	PlacementController.selection_changed.connect(_on_selection_changed)
	_on_selection_changed()

# ── Styles ─────────────────────────────────────────────────────────────────────
func _setup_styles() -> void:
	add_theme_stylebox_override("normal",        _make_style(BG_NORMAL,    false))
	add_theme_stylebox_override("hover",         _make_style(BG_HOVER,     false))
	add_theme_stylebox_override("pressed",       _make_style(BG_SELECTED,  true))
	add_theme_stylebox_override("hover_pressed", _make_style(BG_SELECTED,  true))
	add_theme_stylebox_override("focus",         _make_style(BG_NORMAL,    false))

func _make_style(bg: Color, selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                   = bg
	s.corner_radius_top_left     = CORNER
	s.corner_radius_top_right    = CORNER
	s.corner_radius_bottom_left  = CORNER
	s.corner_radius_bottom_right = CORNER
	if selected:
		s.border_color        = ACCENT
		s.border_width_left   = 2
		s.border_width_right  = 2
		s.border_width_top    = 2
		s.border_width_bottom = 2
	return s

# ── Children ───────────────────────────────────────────────────────────────────
func _build_icon_label() -> void:
	var lbl := Label.new()
	lbl.text                 = icon_char
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

func _build_shortcut_label() -> void:
	var lbl := Label.new()
	lbl.text = shortcut_key
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.offset_left  = -14
	lbl.offset_top   = -14
	lbl.size         = Vector2(12, 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

func _build_tooltip_label() -> void:
	_tooltip_lbl = Label.new()
	_tooltip_lbl.text    = tool_label
	_tooltip_lbl.visible = false
	_tooltip_lbl.add_theme_font_size_override("font_size", 11)
	_tooltip_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	var bg := StyleBoxFlat.new()
	bg.bg_color                   = Color(0.08, 0.08, 0.10, 0.95)
	bg.corner_radius_top_left     = 4
	bg.corner_radius_top_right    = 4
	bg.corner_radius_bottom_left  = 4
	bg.corner_radius_bottom_right = 4
	bg.content_margin_left   = 6.0
	bg.content_margin_right  = 6.0
	bg.content_margin_top    = 3.0
	bg.content_margin_bottom = 3.0
	_tooltip_lbl.add_theme_stylebox_override("normal", bg)

	# Sits above this button; parent is the button, positioned above it
	_tooltip_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tooltip_lbl.grow_vertical        = Control.GROW_DIRECTION_BEGIN
	_tooltip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip_lbl)

	# Reposition after first layout
	call_deferred("_reposition_tooltip")

func _reposition_tooltip() -> void:
	if _tooltip_lbl == null:
		return
	_tooltip_lbl.size.x         = max(size.x, _tooltip_lbl.size.x)
	_tooltip_lbl.position.y     = -_tooltip_lbl.size.y - 4.0
	_tooltip_lbl.position.x     = (size.x - _tooltip_lbl.size.x) * 0.5

func _show_tooltip() -> void:
	_reposition_tooltip()
	_tooltip_lbl.visible = true

func _hide_tooltip() -> void:
	_tooltip_lbl.visible = false

# ── State sync ─────────────────────────────────────────────────────────────────
func _on_pressed() -> void:
	PlacementController.set_tool(tool_name)

func _on_selection_changed() -> void:
	set_pressed_no_signal(PlacementController.active_tool == tool_name)
