extends CharacterBody3D

@export var head: Node3D   

@export_group("Movement")
@export var move_speed: float = 1.5    
@export var turn_speed: float = 6.0      

@export_group("Wander")
@export var wander_radius: float = 8.0    
@export var wander_jitter: float = 3.0     
@export var wander_time_min: float = 3.0  
@export var wander_time_max: float = 6.0   
@export var idle_time_min: float = 1.0     
@export var idle_time_max: float = 3.0    

@export_group("Detection")
@export var player: Node3D                          
@export var detection_range: float = 10.0          
@export_range(0, 360) var detection_angle: float = 120.0 
@export var detection_fill_near: float = 80.0  
@export var detection_fill_far: float = 20.0  
@export var detection_decay: float = 30.0    
@export var detect_bar: Node 

enum State { IDLE, WANDER }

var _state: State = State.IDLE
var _home_position: Vector3              
var _idle_timer: float = 0.0
var _wander_timer: float = 0.0
var _wander_angle: float = 0.0    
var _can_see_player: bool = false     

signal player_detected
var _detection_level: float = 0.0
var _detected: bool = false  

func _ready() -> void:
	_home_position = global_position
	_start_idle()

func _physics_process(delta: float) -> void:
	#gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	#detection bar
	var was_seeing: bool = _can_see_player
	_can_see_player = _can_detect_player()
	if _can_see_player:
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		var dist: float = to_player.length()
		var closeness: float = 1.0 - clampf(dist / detection_range, 0.0, 1.0)
		var fill_speed: float = lerpf(detection_fill_far, detection_fill_near, closeness)
		_detection_level = minf(_detection_level + fill_speed * delta, 100.0)
		if _detection_level >= 100.0 and not _detected:
			_detected = true
			player_detected.emit()
			print("Player fully detected!")
	else:
		_detection_level = maxf(_detection_level - detection_decay * delta, 0.0)
		if _detection_level <= 0.0:
			_detected = false
	detect_bar.value = _detection_level
	#move behavior based on state
	match _state:
		State.IDLE:
			_process_idle(delta)
		State.WANDER:
			_process_wander(delta)

	move_and_slide()

func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	velocity.z = move_toward(velocity.z, 0.0, move_speed)

	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_start_wander()
	if head != null:
		head.rotation.y = sin(Time.get_ticks_msec() / 600.0) * 0.4

 
func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_start_idle()
		return

	_wander_angle += randf_range(-1.0, 1.0) * wander_jitter * delta
	var direction: Vector3 = Vector3(-sin(_wander_angle), 0.0, -cos(_wander_angle))

	var from_home: Vector3 = global_position - _home_position
	from_home.y = 0.0
	var dist: float = from_home.length()
	if dist > wander_radius:
		var home_dir: Vector3 = -from_home.normalized()
		var pull: float = clampf((dist - wander_radius) / wander_radius, 0.0, 1.0)
		direction = direction.lerp(home_dir, pull).normalized()
		_wander_angle = atan2(-direction.x, -direction.z)

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_face_direction(direction, delta)
	if head != null:
		head.rotation.y = lerp_angle(head.rotation.y, 0.0, 10.0 * delta)


func _start_wander() -> void:
	_state = State.WANDER
	_wander_timer = randf_range(wander_time_min, wander_time_max)
	_wander_angle = rotation.y   


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	
	var target_yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

func _start_idle() -> void:
	_state = State.IDLE
	_idle_timer = randf_range(idle_time_min, idle_time_max)

func _can_detect_player() -> bool:
	if player == null:
		return false

	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0  

	
	var dist: float = to_player.length()
	if dist > detection_range:
		return false
	if dist < 2:
		return true   

	
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	var angle: float = rad_to_deg(forward.angle_to(to_player))
	return angle <= detection_angle / 2.0
