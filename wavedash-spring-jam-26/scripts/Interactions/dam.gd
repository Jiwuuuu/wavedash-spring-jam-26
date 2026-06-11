@tool
class_name Shelter extends InteractableBody

## Beaver dam + shelter with a wood-funded build progression (5 stages). Stage 0 is a
## small lodge (the shelter you hide in); each later stage adds a row to a wall of logs
## laid ACROSS the river, so a finished dam spans the whole width. A translucent ghost
## of the next stage shows while the player is near (the "telegraph"). All geometry is
## built procedurally from primitives + toon.gdshader, in code (editor-visible via @tool,
## not saved into the scene).

signal shelter_upgraded(new_stage: int)
signal shelter_complete

const TOON := preload("res://shaders/toon.gdshader")
const BUILD_SFX := preload("uid://bm5kg2ku5uq08")  # dam_wood_pilling.mp3 — uid ref is case-proof for web export
const NOT_ENOUGH_SFX := preload("uid://dx2h0pi6a4rpu")  # not_enough_wood_sfx.mp3

## Wood spent to advance from each stage to the next. This array's length drives the
## number of build stages: stage 0 is the lodge, then one stage per entry, so a finished
## dam has `wood_costs.size() + 1` stages. Add or remove entries in the inspector to add
## or remove dam stages — the model, prompts and win condition all follow automatically.
@export var wood_costs: Array[int] = [3, 5, 8, 12]:
	set(value):
		wood_costs = value
		# Live-rebuild the procedural model so stage changes preview in the editor.
		if is_inside_tree():
			current_stage = clampi(current_stage, 0, max_stage())
			_build_model()
			_apply_stage_visual()


## Total dam stages = lodge (stage 0) + one stage per wood cost entry.
func stage_count() -> int:
	return wood_costs.size() + 1

## River this dam spans. The log wall auto-aligns across its flow and matches its width.
@export var river: River
## Used only when `river` is unset.
@export var barrier_width: float = 4.0

@export_group("Audio")
## Loudness of the dam-build sound, in decibels.
@export var build_volume_db: float = 0.0
## Loudness of the "not enough wood" sound, in decibels.
@export var deny_volume_db: float = 0.0

var current_stage: int = 0

var _stages: Array[Node3D] = []
var _ghosts: Array[Node3D] = []
var _mat_mud: ShaderMaterial
var _mat_log: ShaderMaterial
var _mat_ghost: StandardMaterial3D
var _build_player: AudioStreamPlayer3D
var _deny_player: AudioStreamPlayer3D


func _ready() -> void:
	super()
	_build_model()
	is_interactable = true
	_apply_stage_visual()
	if not Engine.is_editor_hint():
		_build_player = AudioStreamPlayer3D.new()
		_build_player.stream = BUILD_SFX
		_build_player.volume_db = build_volume_db
		add_child(_build_player)
		_deny_player = AudioStreamPlayer3D.new()
		_deny_player.stream = NOT_ENOUGH_SFX
		_deny_player.volume_db = deny_volume_db
		add_child(_deny_player)


# --- Gameplay --------------------------------------------------------------------

func on_interact() -> void:
	if not is_interactable:
		return
	var last_stage := stage_count() - 1
	if current_stage >= last_stage:
		return
	var cost: int = wood_costs[current_stage] if current_stage < wood_costs.size() else 0
	if GameState.wood < cost:
		_flash_not_enough_wood()
		return
	GameState.add_wood(-cost)
	current_stage += 1
	_apply_stage_visual()
	if _build_player != null:
		_build_player.play()
	shelter_upgraded.emit(current_stage)
	if current_stage >= last_stage:
		is_interactable = false
		shelter_complete.emit()
		GameState.unlock_achievement(GameState.ACH_DAM)


func set_focused(focused: bool) -> void:
	super.set_focused(focused)
	_update_ghost()


func _apply_stage_visual() -> void:
	for i in _stages.size():
		if is_instance_valid(_stages[i]):
			_stages[i].visible = (i == current_stage)
	_update_ghost()
	if is_complete():
		set_prompt_text("Dam complete!")
	else:
		set_prompt_text("Press E to build (%d wood)" % wood_needed_for_next())


func _update_ghost() -> void:
	for i in _ghosts.size():
		if is_instance_valid(_ghosts[i]):
			_ghosts[i].visible = _focused and not is_complete() and i == current_stage + 1


func _flash_not_enough_wood() -> void:
	if _deny_player != null:
		_deny_player.play()
	if current_stage >= _stages.size() or not is_instance_valid(_stages[current_stage]):
		return
	var node := _stages[current_stage]
	var base := node.scale
	var tween := create_tween()
	tween.tween_property(node, "scale", base * 1.1, 0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", base, 0.12).set_trans(Tween.TRANS_BOUNCE)


func wood_needed_for_next() -> int:
	if current_stage >= wood_costs.size():
		return 0
	return wood_costs[current_stage]


func is_complete() -> bool:
	return current_stage >= stage_count() - 1


func max_stage() -> int:
	return stage_count() - 1


# --- Procedural model ------------------------------------------------------------

func _build_model() -> void:
	for child in get_children():
		if child.name.begins_with("Stage") or child.name.begins_with("Ghost"):
			child.free()
	_stages.clear()
	_ghosts.clear()

	_mat_mud = _make_mat(Color(0.30, 0.22, 0.15))
	_mat_log = _make_mat(Color(0.45, 0.31, 0.20))
	_mat_ghost = StandardMaterial3D.new()
	_mat_ghost.albedo_color = Color(0.55, 0.8, 1.0, 0.35)
	_mat_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_ghost.cull_mode = BaseMaterial3D.CULL_DISABLED

	for stage in stage_count():
		var s := _build_stage(stage, false)
		add_child(s)
		_stages.append(s)
	for stage in stage_count():
		var g := _build_stage(stage, true)
		g.visible = false
		add_child(g)
		_ghosts.append(g)


func _make_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("bands", 3)
	m.set_shader_parameter("band_softness", 0.03)
	m.set_shader_parameter("ambient_tint", Color(0.35, 0.4, 0.45))
	m.set_shader_parameter("wind_strength", 0.0)
	return m


func _build_stage(stage: int, ghost: bool) -> Node3D:
	var root := Node3D.new()
	root.name = ("Ghost%d" if ghost else "Stage%d") % stage
	var mat_m: Material = _mat_ghost if ghost else _mat_mud
	var mat_l: Material = _mat_ghost if ghost else _mat_log

	# Lodge / shelter — present at every stage.
	_add_mound(root, 0.75, 0.5, mat_m)
	for i in 4:
		var yaw: float = float(i) * (PI / 4.0)
		var pos := Vector3(cos(yaw) * 0.25, 0.08 + 0.04 * float(i % 2), sin(yaw) * 0.25)
		_add_log(root, 1.1, pos, yaw, 0.0, mat_l)

	# Wood wall across the river — one more row per stage (stage 0 = none).
	_build_barrier(root, stage, mat_l)
	return root


func _build_barrier(parent: Node3D, rows: int, mat: Material) -> void:
	if rows <= 0:
		return
	var axes := _barrier_axes()
	var lateral: Vector3 = axes[0]
	var forward: Vector3 = axes[1]
	var width: float = axes[2]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	for r in rows:
		var y: float = 0.12 + float(r) * 0.17
		# A log spanning most of the river width.
		var span_pos := forward * rng.randf_range(-0.1, 0.1) + Vector3(0.0, y, 0.0)
		_add_log_dir(parent, width * 0.95, span_pos, lateral, mat)
		# A couple of shorter woven sticks for a messy beaver-dam look.
		for k in 2:
			var pos := lateral * (rng.randf_range(-0.35, 0.35) * width) \
				+ forward * rng.randf_range(-0.25, 0.25) \
				+ Vector3(0.0, y + 0.05, 0.0)
			var dir := lateral.lerp(forward, rng.randf_range(0.3, 0.7)).normalized()
			_add_log_dir(parent, width * 0.35, pos, dir, mat)


## Returns [lateral_local, forward_local, width]. Lateral runs across the river (the
## dam wall direction); forward is downstream. Computed in this node's local space so
## the wall aligns to the river regardless of how the dam node is rotated.
func _barrier_axes() -> Array:
	if river == null:
		return [Vector3.RIGHT, Vector3.BACK, barrier_width]
	var flow_world: Vector3 = river.flow_direction_at(global_position)
	if flow_world.length() < 0.001:
		return [Vector3.RIGHT, Vector3.BACK, river.width]
	var inv := global_transform.basis.inverse()
	var lat: Vector3 = inv * flow_world.cross(Vector3.UP).normalized()
	var fwd: Vector3 = inv * flow_world
	lat.y = 0.0
	fwd.y = 0.0
	if lat.length() < 0.001:
		lat = Vector3.RIGHT
	if fwd.length() < 0.001:
		fwd = Vector3.BACK
	return [lat.normalized(), fwd.normalized(), river.width]


func _add_mound(parent: Node3D, radius: float, flatten: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	mi.scale = Vector3(1.0, flatten, 1.0)
	mi.position = Vector3(0.0, radius * flatten, 0.0)
	parent.add_child(mi)


func _add_log(parent: Node3D, length: float, pos: Vector3, yaw: float, tilt_deg: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _log_mesh(length)
	mi.material_override = mat
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(90.0 - tilt_deg))
	mi.transform = Transform3D(b, pos)
	parent.add_child(mi)


## Lay a log so its long axis points along `dir` (a horizontal direction).
func _add_log_dir(parent: Node3D, length: float, pos: Vector3, dir: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _log_mesh(length)
	mi.material_override = mat
	var axis := dir.normalized()
	if axis.length() < 0.001:
		axis = Vector3.RIGHT
	var x := Vector3.UP.cross(axis)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := axis.cross(x).normalized()
	mi.transform = Transform3D(Basis(x, axis, z), pos)
	parent.add_child(mi)


func _log_mesh(length: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.08
	cm.height = length
	cm.radial_segments = 6
	return cm
