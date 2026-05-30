@tool
extends Node

## Editor utility: drops hand-placed objects onto the sculpted Terrain3D surface.
##
## Assign the Terrain3D node and the things to snap, then tick `Snap Now` in the
## inspector. It samples terrain height at each object's X,Z and sets its Y so the
## base sits on the ground. Runs at edit time so positions BAKE into the scene
## (save afterwards) — it is not a runtime/procedural pass. Re-tick after you
## reshape the hills.
##
## `terrain` is typed as Node3D (not Terrain3D) and queried dynamically so this
## script never hard-fails to parse if the Terrain3D plugin isn't loaded yet.

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
