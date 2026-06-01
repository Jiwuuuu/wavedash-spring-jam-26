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
@export_range(0, 360) var detection_angle: float = 270.0 
@export var detection_fill_near: float = 100.0  
@export var detection_fill_far: float = 30.0  
@export var detection_decay: float = 20.0    
@export var detect_bar: Node 
@export var eye: Node3D 


@export_group("Chase")
@export var chase_speed: float = 3.0
@export var orbit_distance: float = 3.0   
@export var avoid_distance: float = 2.0   

@export_group("Orbit")
@export var orbit_speed: float = 3.0
@export var orbit_radius: float = 3.0     
@export var orbit_time: float = 2.5       

@export_group("Pounce")
@export var pounce_speed: float = 8.0
@export var pounce_time: float = 0.4
## Damage dealt to the player on a connecting pounce.
@export var pounce_damage: float = 40.0
## How close (horizontal metres) the pounce must land to bite the player.
@export var pounce_hit_range: float = 0.8

enum State { IDLE, WANDER, CHASE, ORBIT, POUNCE }

var _state: State = State.IDLE
var _home_position: Vector3              
var _idle_timer: float = 0.0
var _wander_timer: float = 0.0
var _wander_angle: float = 0.0    
var _can_see_player: bool = false     
var _orbit_dir: float = 1.0   
var _orbit_timer: float = 0.0
var _pounce_dir: Vector3 = Vector3.ZERO
var _pounce_timer: float = 0.0
var _pounce_hit: bool = false   # one bite per pounce

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
	var hidden: bool = _is_player_hidden()
	_can_see_player = _can_detect_player() and not hidden
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
	
	if _detected and (_state == State.IDLE or _state == State.WANDER):
		_start_chase()
	elif not _detected and (_state == State.CHASE or _state == State.ORBIT or _state == State.POUNCE):
		_start_idle()

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.WANDER:
			_process_wander(delta)
		State.CHASE:
			_process_chase(delta)
		State.ORBIT:
			_process_orbit(delta)
		State.POUNCE:
			_process_pounce(delta)

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
	if dist < 4:
		return true   

	
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	var angle: float = rad_to_deg(forward.angle_to(to_player))
	if angle > detection_angle / 2.0:
		return false
	return _has_line_of_sight()
	

func _has_line_of_sight() -> bool:
	var space := get_world_3d().direct_space_state
	var from: Vector3 = eye.global_position
	var to: Vector3 = player.global_position
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]   
	var hit := space.intersect_ray(query)
	return hit.is_empty() or hit.collider == player
	
	
	
#Chase functions..... scary stories
func _start_chase() -> void:
	_state = State.CHASE

func _process_chase(delta: float) -> void:
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() <= orbit_distance:
		_start_orbit()
		return
	var desired: Vector3 = _avoid_obstacles(to_player.normalized())
	velocity.x = desired.x * chase_speed
	velocity.z = desired.z * chase_speed
	_face_direction(desired, delta)

func _avoid_obstacles(desired: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var origin: Vector3 = eye.global_position
	if not _ray_blocked(space, origin, desired):
		return desired
	for angle in [30, -30, 60, -60, 90, -90]:
		var dir: Vector3 = desired.rotated(Vector3.UP, deg_to_rad(angle))
		if not _ray_blocked(space, origin, dir):
			return dir
	return desired  

func _ray_blocked(space: PhysicsDirectSpaceState3D, origin: Vector3, dir: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * avoid_distance)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	return hit.collider != player   

func _start_orbit() -> void:
	_state = State.ORBIT
	_orbit_timer = orbit_time
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0  

func _process_orbit(delta: float) -> void:
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	if dist > orbit_distance * 1.5:   
		_start_chase()
		return
	var to_dir: Vector3 = to_player.normalized()
	var tangent: Vector3 = Vector3(-to_dir.z, 0.0, to_dir.x) * _orbit_dir   
	var correction: float = clampf(dist - orbit_radius, -1.0, 1.0)          
	var move: Vector3 = (tangent + to_dir * correction).normalized()
	velocity.x = move.x * orbit_speed
	velocity.z = move.z * orbit_speed
	_face_direction(to_dir, delta) 
	if _can_see_player:
		_orbit_timer -= delta
		if _orbit_timer <= 0.0:
			_start_pounce()

func _start_pounce() -> void:
	_state = State.POUNCE
	_pounce_timer = pounce_time
	_pounce_hit = false
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	_pounce_dir = to_player.normalized()
	rotation.y = atan2(-_pounce_dir.x, -_pounce_dir.z)

func _process_pounce(delta: float) -> void:
	velocity.x = _pounce_dir.x * pounce_speed
	velocity.z = _pounce_dir.z * pounce_speed
	# Bite once if the lunge lands close enough.
	if not _pounce_hit and player != null and player.has_method("take_damage"):
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() <= pounce_hit_range:
			player.take_damage(pounce_damage)
			_pounce_hit = true
	_pounce_timer -= delta
	if _pounce_timer <= 0.0:
		_start_chase()
		
		
func _is_player_hidden() -> bool:
	return player != null and player.get_meta("hidden_count", 0) > 0
