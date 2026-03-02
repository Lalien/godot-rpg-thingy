extends CharacterBody2D

@export var speed = 100
@export var detection_radius = 200.0
@export var stop_distance = 50.0
@export var max_distance_from_start = 100.0
@export var return_distance = 100.0
@export var vision_angle_degrees = 90.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var starting_position: Vector2
var player_target: CharacterBody2D = null
var is_following = false
var is_returning = false
var _last_direction := Vector2.DOWN

func _ready():
	starting_position = global_position
	
	# Create detection zone
	var area = Area2D.new()
	area.name = "DetectionZone"
	add_child(area)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	collision.shape = shape
	area.add_child(collision)
	
	area.body_entered.connect(_on_detection_zone_entered)
	area.body_exited.connect(_on_detection_zone_exited)
	
	# Create contact zone for damage detection
	var contact_area = Area2D.new()
	contact_area.name = "ContactZone"
	add_child(contact_area)
	
	var contact_collision = CollisionShape2D.new()
	var contact_shape = CircleShape2D.new()
	contact_shape.radius = 20.0  # Small radius for actual contact
	contact_collision.shape = contact_shape
	contact_area.add_child(contact_collision)
	
	contact_area.body_entered.connect(_on_contact_zone_entered)

func _on_detection_zone_entered(body):
	if body is CharacterBody2D and body.get("playerCharacter") and body.playerCharacter:
		player_target = body
		if not is_returning:
			is_following = _can_see_target(body)

func _on_detection_zone_exited(body):
	if body == player_target and not is_returning:
		is_following = false
		player_target = null

func _can_see_target(target: CharacterBody2D) -> bool:
	if target == null:
		return false
	var to_target := target.global_position - global_position
	if to_target.length() > detection_radius:
		return false
	if to_target == Vector2.ZERO:
		return true
	var facing := _last_direction
	if facing == Vector2.ZERO:
		facing = Vector2.DOWN
	var facing_dir := facing.normalized()
	var target_dir := to_target.normalized()
	var threshold := cos(deg_to_rad(vision_angle_degrees * 0.5))
	return facing_dir.dot(target_dir) >= threshold

func _on_contact_zone_entered(body):
	if body is CharacterBody2D and body.get("playerCharacter") and body.playerCharacter and body.health > 0:
		if body.has_method("take_damage"):
			var damage_direction = (body.global_position - global_position).normalized()
			body.take_damage(damage_direction, 5)

func _physics_process(_delta: float) -> void:
	# Check if player is too far and we should return home
	print("Is Following? ", is_following)
	print("Is Returning? ", is_returning)
	print(player_target)
	if player_target and not is_returning:
		is_following = _can_see_target(player_target)
	if player_target and global_position.distance_to(player_target.global_position) > return_distance:
		is_following = false
		is_returning = true
	
	if is_returning:
		var direction = (starting_position - global_position)
		var distance_to_start = direction.length()
		
		if distance_to_start > 5.0:  # Small threshold to avoid jittering
			direction = direction.normalized()
			velocity = direction * speed
			_last_direction = direction
			_update_animation(direction)
		else:
			velocity = Vector2.ZERO
			is_returning = false
			global_position = starting_position  # Snap to exact position
			_play_idle()
			# Check if player is still in detection zone to resume following
			if player_target and global_position.distance_to(player_target.global_position) <= detection_radius:
				is_following = true
	elif is_following and player_target:
		var direction = (player_target.global_position - global_position)
		var distance_to_player = direction.length()
		var distance_from_start = global_position.distance_to(starting_position)
		print("following")
		print(direction)
		print(distance_to_player)
		print(distance_from_start)
		# Check if moving toward player would exceed max distance from start
		if distance_to_player > stop_distance:
			print("exceeded max distance")
			direction = direction.normalized()
			var next_position = global_position + direction * speed * _delta
			
			# Only move if we won't exceed the boundary
			if next_position.distance_to(starting_position) <= max_distance_from_start:
				velocity = direction * speed
				_last_direction = direction
				_update_animation(direction)
			else:
				velocity = Vector2.ZERO
				_play_idle()
		elif distance_from_start > max_distance_from_start:
			print("exceeded max distance from starting point")
			is_returning = true
		else:
			velocity = Vector2.ZERO
			_play_idle()
	else:
		velocity = Vector2.ZERO
		_play_idle()
	
	move_and_slide()

func _update_animation(direction: Vector2):
	var anim_name := _get_walk_animation(direction)
	_play_if_exists(anim_name)

func _get_walk_animation(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "walk_right" if direction.x > 0 else "walk_left"
	return "walk_down" if direction.y > 0 else "walk_up"

func _play_idle():
	var idle_name := _get_idle_animation(_last_direction)
	if _play_if_exists(idle_name):
		return
	if animated_sprite:
		animated_sprite.stop()

func _get_idle_animation(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "idle_right" if direction.x > 0 else "idle_left"
	return "idle_down" if direction.y > 0 else "idle_up"

func _play_if_exists(anim_name: String) -> bool:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
			animated_sprite.play(anim_name)
		return true
	return false
