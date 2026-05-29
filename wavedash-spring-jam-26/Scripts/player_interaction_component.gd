extends Node

@export var can_interact: bool = true

@onready var interaction_area: Area3D = $"../InteractionArea"

var player: CharacterBody3D
var area_bodies: Array

func _ready() -> void:
	player = get_parent()

func _process(delta: float) -> void:
	area_bodies = _get_area_bodies()
	_handle_world_interaction()

func _handle_world_interaction():
	if Input.is_action_just_pressed("interact") and can_interact:
		if !area_bodies: return # If the area is empty dont do anything
		var body: InteractableBody = _get_closest_interactable()
		
		# If the body is not interactable, Then dont continue.
		if !body.is_interactable: return
		
		body.on_interact() # Call the interact function on the body
		print("Interacted with %s" % body.name)


func _get_area_bodies() -> Array:
	if !interaction_area.has_overlapping_bodies(): return []
	return interaction_area.get_overlapping_bodies()


func _get_closest_interactable() -> InteractableBody:
	var closest_body: Node3D
	var closest_distance: float = INF
	
	# Looping through all the bodies inside the Interaction Area
	for body in area_bodies:
		if !body is InteractableBody: continue # If the body is not an Interactable Body dont calculate the distance.
		
		# Getting the distance to the player
		var distance_to_body: float = player.global_position.distance_to(body.global_position)
		# Checking if the distance to the body is less than the last closest distance
		if distance_to_body < closest_distance:
			# If a new closest body is found, Set it below.
			closest_distance = distance_to_body
			closest_body = body
	
	return closest_body
