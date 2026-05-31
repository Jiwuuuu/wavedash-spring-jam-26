@tool
class_name River extends Area3D

## A curving river. Shape it by editing the child Path3D's curve; a ribbon mesh and
## collision are generated to follow it. While the player is in the water, movement
## is slowed (water_drag) and pushed downstream along the nearest curve tangent.

@export var width: float = 4.0:
	set(v):
		width = maxf(0.1, v)
		_rebuild()
## Thickness (Y) of the water collision volume.
@export var depth: float = 1.0:
	set(v):
		depth = maxf(0.1, v)
		_rebuild()
## Foam/ripple repeats per metre along the river (mesh V tiling).
@export var foam_tiling: float = 0.5:
	set(v):
		foam_tiling = maxf(0.01, v)
		_rebuild()
## Sampling resolution in metres (smaller = smoother mesh + collision).
@export_range(0.2, 4.0, 0.1) var step: float = 0.5:
	set(v):
		step = clampf(v, 0.2, 4.0)
		_rebuild()

@export_group("Flow")
## Downstream push speed, in metres/second.
@export var flow_speed: float = 1.2
## Control-speed multiplier while in the water (1.0 = normal, lower = draggier).
@export var water_drag: float = 0.55
## Flip if the current pushes opposite to the foam's visible flow.
@export var reverse_flow: bool = false

var _player: CharacterBody3D
var _path: Path3D
var _surface: MeshInstance3D

func _ready() -> void:
	_fetch_nodes()
	if _path != null and _path.curve != null and not _path.curve.changed.is_connected(_rebuild):
		_path.curve.changed.connect(_rebuild)
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

func _fetch_nodes() -> void:
	if _path == null:
		_path = get_node_or_null("Path")
	if _surface == null:
		_surface = get_node_or_null("Surface")

# --- Mesh + collision generation -------------------------------------------------

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_fetch_nodes()
	if _path == null or _surface == null or _path.curve == null:
		return
	var curve: Curve3D = _path.curve
	if curve.point_count < 2:
		return
	_build_mesh(curve)
	_build_collision(curve)

func _build_mesh(curve: Curve3D) -> void:
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return
	var count: int = maxi(2, int(ceil(length / step)) + 1)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var off: float = length * float(i) / float(count - 1)
		var pos: Vector3 = _path.transform * curve.sample_baked(off, true)
		var tan: Vector3 = _tangent_at(curve, off)
		var right: Vector3 = tan.cross(Vector3.UP).normalized() * (width * 0.5)
		var v: float = off * foam_tiling
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.0, v))
		st.add_vertex(pos - right)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1.0, v))
		st.add_vertex(pos + right)
	for i in count - 1:
		var a: int = i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	_surface.mesh = st.commit()
	# The AABB is near-flat and the shader bobs verts on the GPU; a margin avoids early cull.
	_surface.extra_cull_margin = maxf(4.0, width)

func _build_collision(curve: Curve3D) -> void:
	for c in get_children():
		if c is CollisionShape3D and String(c.name).begins_with("ColSeg"):
			remove_child(c)
			c.free()
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return
	var count: int = maxi(2, int(ceil(length / step)) + 1)
	for i in count - 1:
		var o0: float = length * float(i) / float(count - 1)
		var o1: float = length * float(i + 1) / float(count - 1)
		var p0: Vector3 = _path.transform * curve.sample_baked(o0, true)
		var p1: Vector3 = _path.transform * curve.sample_baked(o1, true)
		var seg: Vector3 = p1 - p0
		var seg_len: float = seg.length()
		if seg_len < 0.0001:
			continue
		var fwd: Vector3 = seg / seg_len
		var x: Vector3 = Vector3.UP.cross(fwd).normalized()
		if x.length() < 0.0001:
			x = Vector3.RIGHT
		var y: Vector3 = fwd.cross(x).normalized()
		var box: BoxShape3D = BoxShape3D.new()
		# Overlap segments slightly so there are no gaps between boxes.
		box.size = Vector3(width, depth, seg_len + step)
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "ColSeg%d" % i
		cs.shape = box
		cs.transform = Transform3D(Basis(x, y, fwd), (p0 + p1) * 0.5)
		add_child(cs)

func _tangent_at(curve: Curve3D, off: float) -> Vector3:
	var length: float = curve.get_baked_length()
	var eps: float = 0.1
	var a: Vector3 = _path.transform * curve.sample_baked(minf(off + eps, length), true)
	var b: Vector3 = _path.transform * curve.sample_baked(maxf(off - eps, 0.0), true)
	var tan: Vector3 = a - b
	tan.y = 0.0
	if tan.length() < 0.0001:
		return Vector3.FORWARD
	return tan.normalized()

# --- Flow / player push -----------------------------------------------------------

func _on_body_entered(body: Node3D) -> void:
	# Filter to the CharacterBody3D (the beaver); ignore the static ground/terrain.
	if body is CharacterBody3D:
		_player = body

func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_clear_player()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null:
		return
	if not is_instance_valid(_player):
		_player = null
		return
	var downstream: Vector3 = _downstream_at(_player.global_position)
	_player.set("water_current", downstream * flow_speed)
	_player.set("water_drag", water_drag)

func _downstream_at(global_point: Vector3) -> Vector3:
	var curve: Curve3D = _path.curve if _path != null else null
	var dir: Vector3
	if curve != null and curve.point_count >= 2 and curve.get_baked_length() > 0.0:
		var off: float = curve.get_closest_offset(_path.to_local(global_point))
		dir = _tangent_at(curve, off)
	else:
		dir = global_transform.basis.z
		dir.y = 0.0
		dir = dir.normalized()
	if reverse_flow:
		dir = -dir
	return dir

func _clear_player() -> void:
	if _player != null and is_instance_valid(_player):
		_player.set("water_current", Vector3.ZERO)
		_player.set("water_drag", 1.0)
	_player = null
