# Project Skills / Invariants

Facts that must be respected in all future prompts and implementations.

---

## Hex Grid

- **Layout**: FLAT-TOP
  - Vertices at: 0°, 60°, 120°, 180°, 240°, 300°
  - Edge midpoints at: 30°, 90°, 150°, 210°, 270°, 330°
- **Coordinate system**: odd-q offset, stored as `Vector2i(col, row)` (x = column, y = row)
- **Circumradius** (center → vertex): `HexGrid.HEX_SIZE = SQRT3/2 ≈ 0.866` — despite the name, this is NOT 1.0
- **Apothem** (center → edge midpoint): `circumradius × SQRT3/2 = 0.866 × 0.866 = 0.75`
- **UNIT_HEIGHT**: 0.289 m per stack level (`HexGrid.UNIT_HEIGHT`)
- **HEX_HEIGHT**: 0.02 m cosmetic tile thickness
- Internal representation uses axial coordinates for rotation math; convert via `HexGrid._offset_to_axial` / `_axial_to_offset`
- Axial rotation per 60° CW step: `(q, r) → (−r, q+r)`

## Entry Points

- Named `Entry_E{edge}_H{height}` — e.g. `Entry_E0_H0`, `Entry_E3_H2`
- Edge 0 is the first flat-top edge midpoint (30° from +X), edges increase clockwise in 60° steps
- **Position formula**: `angle = edge * 60° + 30°`, place marker at radius = apothem (0.866)
  ```
  angle_rad = deg_to_rad(edge * 60.0 + 30.0)
  x = cos(angle_rad) * 0.866
  z = sin(angle_rad) * 0.866
  y = height * UNIT_HEIGHT
  ```
- Edge names (flat-top, clockwise from right):

  | Edge | Angle | Name       |
  |------|-------|------------|
  | 0    |  30°  | Right      |
  | 1    |  90°  | Bottom     |
  | 2    | 150°  | Bottom-Left|
  | 3    | 210°  | Top-Left   |
  | 4    | 270°  | Top        |
  | 5    | 330°  | Top-Right  |

- Added via the **Entry Point Editor** plugin (EditorInspectorPlugin on StructureBase)
- Tracked at runtime by the **EntryPointRegistry** autoload

## Structure System

- `StructureBase` extends `GridObject` (Node3D); all placed structures inherit from it
- Multi-hex structures declare `hex_offsets: Array[Vector2i]` in axial coords
- Placement pipeline: `HexGrid.spawn_structure()` → `place_structure()` → `on_placed()` + `EntryPointRegistry.register_structure()`
- Removal pipeline: `HexGrid.despawn_structure()` → `EntryPointRegistry.unregister_structure()` → `on_removed()`
- Height spans > 1 are declared in `HexGrid.HEIGHT_SPANS`
- Solid structure support rules: ground (h=0) always valid; or solid directly below; or 2+ neighbors at same height

## Physics / Collision Layers

- Physics engine: **Rapier3D** (not Godot built-in physics)
- Collision layer 2 = `SolidHexFace` — assigned to every `StaticBody3D` inside solid structures so lateral face raycasts hit only them exclusively

## Save System

- Format: JSON at `user://saves/{name}.json`, schema version 1
- Per-structure data: `hex_x, hex_y, height, type, rotation_y`
- Types "marble" and blank are excluded from saves

## Autoloads (load order)

| Name                 | Path                                    |
|----------------------|-----------------------------------------|
| HexGrid              | res://HexGrid.gd                        |
| StructureRegistry    | res://StructureRegistry.gd              |
| PlacementController  | res://autoloads/PlacementController.gd  |
| SaveSystem           | res://SaveSystem.gd                     |
| LevelManager         | res://autoloads/LevelManager.gd         |
| EntryPointRegistry   | res://autoloads/EntryPointRegistry.gd   |
| DebugFlags           | res://autoloads/DebugFlags.gd           |
| StructureEvents      | res://autoloads/StructureEvents.gd      |
| AudioManager         | res://autoloads/AudioManager.gd         |
| StructureCatalog     | res://autoloads/StructureCatalog.gd     |
