@tool
extends Node

## Editor utility: drops hand-placed objects onto the Terrain3D surface. Assign the
## terrain and objects, then tick `Snap Now`. It sets each object's Y to the sampled
## terrain height — an edit-time bake (save afterwards), not a runtime pass.

## The Terrain3D node to sample heights from.
@export var terrain: Node3D

## Containers whose direct Node3D children all get snapped (e.g. the `Trees` node).
@export var containers: Array[Node3D] = []

## Individual nodes to snap (e.g. the lone Willow, the Wolf, the Player spawn).
@export var nodes: Array[Node3D] = []

## Added to the sampled terrain height (use a small value if a base floats/sinks).
@export var base_offset: float = 0.0

## Momentary inspector button — tick to snap, it pops back off.
@export var snap_now: bool = false:
	set(value):
		if value:
			_snap_all()

func _snap_all() -> void:
	if terrain == null:
		push_warning("TerrainSnapper: assign the Terrain3D node first.")
		return
	var data: Object = terrain.get("data")
	if data == null:
		push_warning("TerrainSnapper: Terrain3D has no data yet (sculpt a region first).")
		return

	var count: int = 0
	for c in containers:
		if c == null:
			continue
		for child in c.get_children():
			if child is Node3D and _snap_node(child, data):
				count += 1
	for n in nodes:
		if n != null and _snap_node(n, data):
			count += 1

	print("TerrainSnapper: snapped %d node(s) to terrain." % count)

func _snap_node(n: Node3D, data: Object) -> bool:
	var pos: Vector3 = n.global_position
	var h: float = data.call("get_height", pos)
	if is_nan(h):
		return false # outside a sculpted region — leave it alone
	n.global_position = Vector3(pos.x, h + base_offset, pos.z)
	return true
