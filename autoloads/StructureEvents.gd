extends Node

signal structure_placed(structure: Node)

## Emitted by structures that need to spawn a sibling node.
## Receiver (Main) calls add_child(node) then sets node.global_position.
signal spawn_requested(node: Node3D, global_position: Vector3)

## Emitted by structures that need to reparent one of their children.
## Receiver (Main) calls node.reparent(new_parent).
signal reparent_requested(node: Node, new_parent: Node)
