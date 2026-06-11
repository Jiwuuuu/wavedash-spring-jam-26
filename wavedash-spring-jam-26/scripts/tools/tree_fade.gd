extends Node3D

## Attach to the "Trees" container. Each frame, any tree standing between the camera
## and the beaver fades to partially see-through so it never hides the player; trees
## that clear the view fade back to solid. Cheap maths (project tree onto the
## camera->player segment), no physics raycasts — web-safe for ~dozens of trees.
##
## Works by swapping each tree material from toon.gdshader to toon_fade.gdshader
## (same look, plus a `fade` uniform) at startup, then driving that uniform.

const TOON := preload("res://shaders/toon.gdshader")
const TOON_FADE := preload("res://shaders/toon_fade.gdshader")

## The beaver. Trees between the camera and this node fade out.
@export var target: Node3D
## Opacity a tree fades to while it blocks the view (1.0 = solid).
@export var fade_alpha: float = 0.35
## How close (metres) a tree must be to the camera->player line to count as blocking.
@export var radius: float = 1.4
## Fade in/out speed (higher = snappier).
@export var lerp_speed: float = 8.0
## Aim a bit above the beaver's feet so trunks crossing the body count.
@export var aim_height: float = 0.8
## Sample each tree around trunk/low-canopy height rather than its base.
@export var sample_height: float = 1.6

# Each entry: { "node": Node3D, "mats": Array[ShaderMaterial], "fade": float }.
var _trees: Array = []

func _ready() -> void:
	for child in get_children():
		var tree := child as Node3D
		if tree == null:
			continue
		var mats: Array = []
		_collect_mats(tree, mats)
		if not mats.is_empty():
			_trees.append({ "node": tree, "mats": mats, "fade": 1.0 })

## Swap every toon-shaded mesh under `node` to the fade shader (keeps all existing
## parameters, which share names) and start it fully solid.
func _collect_mats(node: Node, out: Array) -> void:
	for child in node.get_children():
		var gi := child as GeometryInstance3D
		if gi != null:
			var mat := gi.material_override as ShaderMaterial
			if mat != null and mat.shader == TOON:
				mat.shader = TOON_FADE
				mat.set_shader_parameter("fade", 1.0)
				out.append(mat)
		if child.get_child_count() > 0:
			_collect_mats(child, out)

func _process(delta: float) -> void:
	if target == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cam_pos := cam.global_position
	var aim := target.global_position + Vector3.UP * aim_height
	var seg := aim - cam_pos
	var seg_len_sq := seg.length_squared()
	if seg_len_sq < 0.0001:
		return
	var blend := clampf(lerp_speed * delta, 0.0, 1.0)
	for entry in _trees:
		# Check the raw (untyped) value first: a cut tree has been queue_free'd, and
		# assigning a freed instance to a typed Node3D var would error before we
		# could guard it.
		if not is_instance_valid(entry["node"]):
			continue
		var tree: Node3D = entry["node"]
		var p := tree.global_position + Vector3.UP * sample_height
		# Parametric position of the tree's closest point along the camera->player line.
		var t := seg.dot(p - cam_pos) / seg_len_sq
		var target_fade := 1.0
		if t > 0.05 and t < 0.98:
			var closest := cam_pos + seg * t
			if closest.distance_to(p) < radius:
				target_fade = fade_alpha
		var f: float = lerpf(entry["fade"], target_fade, blend)
		entry["fade"] = f
		for mat in entry["mats"]:
			mat.set_shader_parameter("fade", f)
