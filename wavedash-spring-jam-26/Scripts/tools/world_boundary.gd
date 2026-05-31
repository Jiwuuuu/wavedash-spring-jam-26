extends Node

## Keeps the player inside the Ground area and limits Terrain3D rendering
## to avoid showing endless flat terrain beyond the playable map.
##
## Assign the three nodes in the inspector, then adjust `boundary_margin`
## if you want a small buffer before the wall.

@export var player: CharacterBody3D
@export var ground: CSGBox3D
@export var terrain: Node3D   ## The Terrain3D node

## How many units inside the ground edge the player is stopped.
@export var boundary_margin: float = 1.0

## Terrain3D mesh LOD count — lower = less terrain visible beyond the map.
## Default Terrain3D is 7-8; 4 keeps nearby detail but hides far-off flat terrain.
@export_range(2, 10) var terrain_mesh_lods: int = 4

var _half_x: float
var _half_z: float
var _center: Vector3

func _ready() -> void:
	if ground:
		var s: Vector3 = ground.size
		_half_x = s.x * 0.5 - boundary_margin
		_half_z = s.z * 0.5 - boundary_margin
		_center = ground.global_position

	# Reduce the Terrain3D clipmap so it doesn't render far beyond the map.
	if terrain and terrain.has_method("set_mesh_lods"):
		terrain.set_mesh_lods(terrain_mesh_lods)
	elif terrain:
		terrain.set("mesh_lods", terrain_mesh_lods)

func _physics_process(_delta: float) -> void:
	if player == null or ground == null:
		return

	var pos: Vector3 = player.global_position
	pos.x = clampf(pos.x, _center.x - _half_x, _center.x + _half_x)
	pos.z = clampf(pos.z, _center.z - _half_z, _center.z + _half_z)
	player.global_position = pos
