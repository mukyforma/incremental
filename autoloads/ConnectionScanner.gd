extends Node

## Autoload: scans for possible straight rail connections between free entry points.

class Connection:
	var entry_a: Dictionary
	var entry_b: Dictionary
	var rail_type: StringName
	var hex_distance: int
	var midpoint_world: Vector3
	var direction: Vector3

# ── Public API ─────────────────────────────────────────────────────────────────

func scan_from(structure: StructureBase) -> Array:
	var results: Array = []
	var source_entries := EntryPointRegistry.get_free_entries(structure)
	var all_free := EntryPointRegistry.get_all_free_entries()

	for entry_a in source_entries:
		var edge_a := _parse_edge(entry_a.marker.name)
		var height_a := _parse_height(entry_a.marker.name)
		if edge_a < 0 or height_a < 0:
			continue
		var opposite_edge := (edge_a + 3) % 6

		for entry_b in all_free:
			if entry_b.structure == structure:
				continue
			var edge_b := _parse_edge(entry_b.marker.name)
			var height_b := _parse_height(entry_b.marker.name)
			if edge_b < 0 or height_b < 0:
				continue

			if edge_b != opposite_edge:
				continue
			if height_a != height_b:
				continue

			var dist := HexGrid.hex_distance(
				entry_a.structure.hex_position,
				entry_b.structure.hex_position)
			if dist < 1 or dist > 4:
				continue

			if not _are_aligned(entry_a, edge_a, entry_b):
				continue

			var rail_type := _rail_type_for_distance(dist)
			if rail_type == &"":
				continue

			var conn := Connection.new()
			conn.entry_a = entry_a
			conn.entry_b = entry_b
			conn.rail_type = rail_type
			conn.hex_distance = dist
			conn.midpoint_world = (
				entry_a.marker.global_position +
				entry_b.marker.global_position) * 0.5
			conn.direction = (
				entry_b.marker.global_position -
				entry_a.marker.global_position).normalized()
			results.append(conn)

	return results

# ── Helpers ────────────────────────────────────────────────────────────────────

func _parse_edge(marker_name: String) -> int:
	var parts := marker_name.split("_")
	if parts.size() < 2:
		return -1
	return int(parts[1].substr(1))

func _parse_height(marker_name: String) -> int:
	var parts := marker_name.split("_")
	if parts.size() < 3:
		return -1
	return int(parts[2].substr(1))

func _rail_type_for_distance(dist: int) -> StringName:
	match dist:
		1: return &"rail_short"
		2: return &"rail_medium"
		3: return &"rail_long"
		4: return &"rail_extra_long"
	return &""

func _are_aligned(entry_a: Dictionary, edge_a: int, entry_b: Dictionary) -> bool:
	var angle_rad := deg_to_rad(edge_a * 60.0 + 30.0)
	var expected_dir := Vector3(cos(angle_rad), 0.0, sin(angle_rad))
	var actual_dir: Vector3 = (
		entry_b.marker.global_position -
		entry_a.marker.global_position)
	actual_dir.y = 0.0
	if actual_dir.length_squared() < 0.0001:
		return false
	actual_dir = actual_dir.normalized()
	return expected_dir.dot(actual_dir) > 0.95
