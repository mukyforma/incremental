extends CanvasLayer

signal saved(save_name: String)
signal loaded(save_name: String)

var _main_btns : VBoxContainer
var _load_panel : VBoxContainer
var _save_list  : VBoxContainer

func _ready() -> void:
	layer        = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	# ── Dim overlay ────────────────────────────────────────────────────────────
	var overlay := ColorRect.new()
	overlay.color        = Color(0, 0, 0, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# ── Centering ──────────────────────────────────────────────────────────────
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top",    28)
	margin.add_theme_constant_override("margin_bottom", 28)
	margin.add_theme_constant_override("margin_left",   36)
	margin.add_theme_constant_override("margin_right",  36)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# ── Title ──────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text                 = "MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	root.add_child(HSeparator.new())

	# ── Main buttons ───────────────────────────────────────────────────────────
	_main_btns = VBoxContainer.new()
	_main_btns.add_theme_constant_override("separation", 8)
	root.add_child(_main_btns)

	_add_btn(_main_btns, "Continuar",  _on_resume)
	_add_btn(_main_btns, "Salvar",     _on_save)
	_add_btn(_main_btns, "Carregar",   _on_open_load)

	# ── Load sub-panel ─────────────────────────────────────────────────────────
	_load_panel = VBoxContainer.new()
	_load_panel.add_theme_constant_override("separation", 8)
	_load_panel.visible = false
	root.add_child(_load_panel)

	var load_lbl := Label.new()
	load_lbl.text = "Selecione um save:"
	_load_panel.add_child(load_lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size    = Vector2(0, 200)
	scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	_load_panel.add_child(scroll)

	_save_list = VBoxContainer.new()
	_save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_save_list)

	_add_btn(_load_panel, "← Voltar", _on_back_to_main)

	visible = false

# ── Public API ─────────────────────────────────────────────────────────────────

func show_menu() -> void:
	_load_panel.visible = false
	_main_btns.visible  = true
	visible = true
	get_tree().paused = true

func hide_menu() -> void:
	visible = false
	get_tree().paused = false

func toggle() -> void:
	if visible:
		hide_menu()
	else:
		show_menu()

# ── Handlers ───────────────────────────────────────────────────────────────────

func _on_resume() -> void:
	hide_menu()

func _on_save() -> void:
	var dt   := Time.get_datetime_dict_from_system()
	var name := "%04d-%02d-%02d_%02d%02d%02d" % [
		dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
	]
	saved.emit(name)
	hide_menu()

func _on_open_load() -> void:
	_refresh_save_list()
	_main_btns.visible  = false
	_load_panel.visible = true

func _on_back_to_main() -> void:
	_load_panel.visible = false
	_main_btns.visible  = true

func _refresh_save_list() -> void:
	for child in _save_list.get_children():
		child.queue_free()

	var saves: Array[String] = SaveSystem.list_saves()
	if saves.is_empty():
		var lbl := Label.new()
		lbl.text = "(nenhum save encontrado)"
		_save_list.add_child(lbl)
		return

	for sname in saves:
		_add_btn(_save_list, sname, func(): _on_load_selected(sname))

func _on_load_selected(save_name: String) -> void:
	hide_menu()
	loaded.emit(save_name)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _add_btn(parent: Control, lbl: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text                 = lbl
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn
