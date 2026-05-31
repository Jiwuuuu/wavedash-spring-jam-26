@tool
class_name TerrainSnap
extends Node3D

## Drop this as a CHILD of any Node3D to make that parent snap onto the Terrain3D
## surface in the editor, re-snapping live as you drag it — the same feel as the
## grass patch, but for a single placed object (tree, rock, …).
##
## Editor-only by default so it never fights runtime animations (e.g. a tree's
## topple/sink tween). Flip `snap_at_runtime` on for a one-shot snap on game start.
##
## Heights are sampled from Terrain3D's `data.get_height`, like
## Scripts/tools/terrain_snapper.gd — physics raycasts don't work in the editor.
## The static `find_terrain`/`get_height_at` helpers are reused by other tools
## (e.g. river.gd's per-point conform).

## Terrain3D to sample. Auto-found in the current scene if left empty.
@export var terrain: Node3D:
	set(value):
		terrain = value
		_snap()
## Added to the sampled height (negative sinks the object into the ground).
@export var surface_offset: float = 0.0:
	set(value):
		surface_offset = value
		_snap()
## Also snap once when the game starts. Off by default so it can't fight animations.
@export var snap_at_runtime: bool = false

# Guards against the snap we trigger re-entering through TRANSFORM_CHANGED.
var _busy: bool = false


func _ready() -> void:
	set_notify_transform(true)
	if Engine.is_editor_hint() or snap_at_runtime:
		_snap()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_snap()


func _snap() -> void:
	if _busy or not is_inside_tree():
		return
	var target_node := get_parent() as Node3D
	if target_node == null:
		return

	var terr: Node = terrain if terrain != null else find_terrain(self)
	if terr == null:
		return
	var h: float = get_height_at(terr, target_node.global_position)
	if is_nan(h):
		return # outside a sculpted region — leave it alone

	var target_y: float = h + surface_offset
	_push_sway_base(target_node, target_y)
	if absf(target_node.global_position.y - target_y) < 0.0005:
		return # already there; avoids a feedback loop

	_busy = true
	target_node.global_position.y = target_y
	_busy = false


func _push_sway_base(node: Node, by: float) -> void:
	# Keep height-based sway shaders (toon.gdshader) calm on elevated terrain by
	# telling them the object's base height. Harmless on materials without `base_y`.
	for child in node.get_children():
		var gi := child as GeometryInstance3D
		if gi == null:
			continue
		var mat := gi.material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("base_y", by)


## Find the first Terrain3D in `context`'s scene (edited scene in the editor,
## current scene at runtime). Returns null if none.
static func find_terrain(context: Node) -> Node:
	if context == null or not context.is_inside_tree():
		return null
	var root: Node = null
	if Engine.is_editor_hint():
		root = context.get_tree().get_edited_scene_root()
	if root == null:
		root = context.owner if context.owner != null else context.get_tree().current_scene
	if root == null:
		return null
	return _search_terrain(root)


## Sample the Terrain3D surface height at a world position. Returns NAN if there's
## no terrain/data or the point is outside a sculpted region.
static func get_height_at(terrain_node: Node, world_pos: Vector3) -> float:
	if terrain_node == null:
		return NAN
	var data: Object = terrain_node.get("data")
	if data == null:
		return NAN
	return data.call("get_height", world_pos)


static func _search_terrain(n: Node) -> Node:
	if n.get_class() == "Terrain3D":
		return n
	# Fallback: anything exposing a `data` object with get_height (Terrain3D does).
	var d: Variant = n.get("data")
	if d != null and typeof(d) == TYPE_OBJECT and d.has_method("get_height"):
		return n
	for c in n.get_children():
		var found := _search_terrain(c)
		if found != null:
			return found
	return null
