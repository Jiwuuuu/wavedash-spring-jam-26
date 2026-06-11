@tool
extends MultiMeshInstance3D

## A single-node draggable square patch of grass, baked & visible in the editor.
## Drop instances of grass.tscn into the world; the patch scatters `count` tufts
## inside a square and snaps each onto the Terrain3D surface (via get_height, like
## Scripts/tools/terrain_snapper.gd), so it follows slopes — no waiting for runtime.
## It re-snaps live as you drag the node, so it always sits on the ground.
##
## The grass TYPES are just the `variants` array: add or remove textures in the
## inspector to control how many kinds of grass appear. They're packed into a
## Texture2DArray and chosen per tuft via MultiMesh custom data, which keeps the
## grass_cartoon shader web/Compatibility-safe (one node, one MultiMesh).
##
## Layout is deterministic from `rng_seed`, so it stays put across reloads.

@export_group("Grass types")
## The kinds of grass that can appear. Add/remove entries to change how many types
## pop up; `variant_weights[i]` sets each one's relative odds (lower = rarer).
# Path is ALL-LOWERCASE on purpose. The web export is case-sensitive and stores the
# folder lowercased, so the original capital "StylizedCartoonGrass" path threw
# "Preload file does not exist" on web and dropped the whole grass script to a fallback
# plane. Lowercase resolves in both places: case-insensitive in the Windows editor,
# exact-match on web. (UIDs can't be used here — this @tool script compiles before the
# UID registry is ready, so preload("uid://…") fails to parse on editor startup.)
@export var variants: Array[Texture2D] = [
	preload("res://assets/stylizedcartoongrass/landscaper/default_grass_v0.svg"),
	preload("res://assets/stylizedcartoongrass/landscaper/default_grass_v1.svg"),
	preload("res://assets/stylizedcartoongrass/landscaper/default_grass_v2.svg"),
]:
	set(value):
		variants = value
		_rebuild()
## Relative odds per type (matched by index). Missing entries default to 1.0.
@export var variant_weights: Array[float] = [1.0, 1.0, 0.15]:
	set(value):
		variant_weights = value
		_rebuild()

@export_group("Patch")
## Side length of the square the tufts scatter within, in world units.
@export var square_size: float = 4.0:
	set(value):
		square_size = value
		_rescatter()
## How many tufts to place in the patch.
@export var count: int = 30:
	set(value):
		count = value
		_rescatter()
## Change for a different (still deterministic) layout.
@export var rng_seed: int = 0:
	set(value):
		rng_seed = value
		_rescatter()
@export var min_scale: float = 0.7:
	set(value):
		min_scale = value
		_rescatter()
@export var max_scale: float = 1.3:
	set(value):
		max_scale = value
		_rescatter()
## Lifts tufts along the surface (raise if they sink into the ground).
@export var surface_offset: float = 0.0:
	set(value):
		surface_offset = value
		_rescatter()

## Terrain3D to snap onto. Auto-found in the scene if left empty. Without one, the
## patch lays flat at this node's height (still visible).
@export var terrain: Node3D:
	set(value):
		terrain = value
		_rescatter()

## Max width/height the variant textures are packed at (keeps the array small).
const _MAX_VARIANT_TEX := 256

# Cached so dragging (which re-scatters every frame) doesn't rebuild the array.
var _array_tex: Texture2DArray
var _layer_weights: Array = []


func _ready() -> void:
	set_notify_transform(true) # re-snap live while dragging the node
	# Build a fresh MultiMesh per node. This keeps patches independent (no shared
	# resource to rewrite) AND avoids duplicating a baked, scene-saved MultiMesh,
	# which errors when instance_count > 0 (the toggle-flags-while-populated bug).
	_make_own_multimesh()
	if not Engine.is_editor_hint():
		# Terrain3D loads its height data as the scene starts; wait a frame so tufts
		# snap to the real terrain instead of scattering before it's ready.
		await get_tree().process_frame
	_rebuild()


func _make_own_multimesh() -> void:
	var mm := MultiMesh.new()
	# Flags must be set while instance_count == 0 (it is, on a fresh MultiMesh).
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var blade := QuadMesh.new()
	blade.size = Vector2(0.4, 0.45)
	blade.subdivide_depth = 3
	blade.center_offset = Vector3(0.0, 0.225, 0.0)
	mm.mesh = blade
	multimesh = mm


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_rescatter()


## Rebuild the variant texture array (types changed), then re-scatter.
func _rebuild() -> void:
	if not is_inside_tree():
		return

	var textures: Array[Texture2D] = []
	_layer_weights = []
	for i in variants.size():
		if variants[i] == null:
			continue
		textures.append(variants[i])
		var w: float = variant_weights[i] if i < variant_weights.size() else 1.0
		_layer_weights.append(maxf(w, 0.0))

	_array_tex = _build_variant_array(textures)
	var mat := material_override as ShaderMaterial
	if mat != null and _array_tex != null:
		mat.set_shader_parameter("variants", _array_tex)

	_rescatter()


## Re-place the tufts (position/seed/transform changed), reusing the cached array.
func _rescatter() -> void:
	if not is_inside_tree() or multimesh == null:
		return

	var total_weight: float = 0.0
	for w in _layer_weights:
		total_weight += w

	var transforms: Array[Transform3D] = []
	var layers: Array[float] = []

	if total_weight > 0.0 and count > 0 and _array_tex != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = rng_seed

		var terr: Node = terrain if terrain != null else _find_terrain()
		var data: Object = terr.get("data") if terr != null else null
		var inv := global_transform.affine_inverse()
		var half: float = square_size * 0.5

		for i in count:
			var lx: float = rng.randf_range(-half, half)
			var lz: float = rng.randf_range(-half, half)
			var world_pos: Vector3 = global_transform * Vector3(lx, 0.0, lz)

			if data != null:
				var h: float = data.call("get_height", world_pos)
				if is_nan(h):
					# Height unavailable here — on web the Terrain3D region may not be
					# resolved yet at scatter time, which left whole patches empty (just
					# bare ground). Fall back to the patch's own height so the tuft still
					# shows, snapped roughly to where the node was placed on the surface.
					world_pos.y += surface_offset
				else:
					world_pos.y = h + surface_offset
			else:
				world_pos.y += surface_offset

			var local_pos: Vector3 = inv * world_pos
			var s: float = rng.randf_range(min_scale, max_scale)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
			transforms.append(Transform3D(basis, local_pos))
			layers.append(float(_pick_variant(rng, total_weight)))

	# Flags are already set on our own MultiMesh; just resize and fill. (Setting
	# instance_count to 0 first is required before changing it to the new size.)
	multimesh.instance_count = 0
	multimesh.instance_count = transforms.size()
	for j in transforms.size():
		multimesh.set_instance_transform(j, transforms[j])
		multimesh.set_instance_custom_data(j, Color(layers[j], 0.0, 0.0, 0.0))


func _pick_variant(rng: RandomNumberGenerator, total_weight: float) -> int:
	var r: float = rng.randf() * total_weight
	var acc: float = 0.0
	for i in _layer_weights.size():
		acc += _layer_weights[i]
		if r < acc:
			return i
	return _layer_weights.size() - 1


func _build_variant_array(textures: Array[Texture2D]) -> Texture2DArray:
	var images: Array[Image] = []
	var target_size := Vector2i.ZERO
	for tex in textures:
		var img := tex.get_image()
		if img == null:
			continue
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		img.clear_mipmaps()
		if target_size == Vector2i.ZERO:
			# Cap the array resolution so the (editor-baked) texture stays small.
			var sz := img.get_size()
			var m: int = maxi(sz.x, sz.y)
			if m > _MAX_VARIANT_TEX:
				var scl: float = float(_MAX_VARIANT_TEX) / float(m)
				target_size = Vector2i(roundi(sz.x * scl), roundi(sz.y * scl))
			else:
				target_size = sz
		if img.get_size() != target_size:
			img.resize(target_size.x, target_size.y)
		images.append(img)

	if images.is_empty():
		return null
	var array_tex := Texture2DArray.new()
	array_tex.create_from_images(images)
	return array_tex


func _find_terrain() -> Node:
	var root: Node = null
	if Engine.is_editor_hint():
		root = get_tree().get_edited_scene_root()
	if root == null:
		root = owner if owner != null else get_tree().current_scene
	if root == null:
		return null
	return _search_terrain(root)


func _search_terrain(n: Node) -> Node:
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
