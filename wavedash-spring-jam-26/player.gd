extends CharacterBody3D

# Movement Variables
@export_group("Movement Variables")
@export var walking_speed: float = 2.0
@export var sprinting_speed: float = 3.5
@export var acceleration: float = 5.0
@export var friction: float = 7.0

var current_speed: float = 0
var movement_direction: Vector3

func _ready() -> void:
	current_speed = walking_speed

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Getting the Input direction of the player.
	var input_dir : Vector2 = Input.get_vector("left", "right", "forward", "backward")
	# Using the Input direction and lerping it to get a movement direction, This will make for a smoother movement input.
	movement_direction = lerp(movement_direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), acceleration * delta)
	
	if Input.is_action_just_pressed("sprint"):
		current_speed = sprinting_speed
	elif Input.is_action_just_released("sprint"):
		current_speed = walking_speed
	
	if movement_direction:
		velocity.x = movement_direction.x * current_speed
		velocity.z = movement_direction.z * current_speed
	else:
		# Lerping the velocity to 0 if there is no input.
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)

	move_and_slide()
