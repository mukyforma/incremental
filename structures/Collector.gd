class_name Collector
extends StructureBase

@onready var _delivery_area: Area3D = $DeliveryArea

# ── StructureBase hooks ────────────────────────────────────────────────────────

func _ready() -> void:
	super._ready()

func on_placed() -> void:
	_delivery_area.body_entered.connect(_on_body_entered_delivery)

# ── Delivery detection ─────────────────────────────────────────────────────────

func _on_body_entered_delivery(body: Node3D) -> void:
	if not body.is_in_group(&"marble"):
		return
	if body.has_method("reset"):
		body.reset()
	activated.emit()
