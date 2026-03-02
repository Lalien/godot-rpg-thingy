extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@export var health = 5
@export var speed = 100
@export var playerCharacter = false;
@export var wander_interval = 1.5
@export var wander_speed_multiplier = 0.6
@export var wander_idle_chance = 0.3
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var _last_direction := Vector2.DOWN
var is_hurt := false
var starting_position: Vector2
var max_health: int
const HURT_DURATION := 0.4
@onready var hurt_timer: Timer = Timer.new()
@onready var wander_timer: Timer = Timer.new()
var wander_direction := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _ready():
	starting_position = global_position
	max_health = health
	_connect_existing_interactables()
	get_tree().node_added.connect(_on_node_added)
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
	_hurt_timer_setup()
	_wander_setup()

func _hurt_timer_setup():
	hurt_timer.one_shot = true
	hurt_timer.wait_time = HURT_DURATION
	hurt_timer.timeout.connect(_on_hurt_timeout)
	add_child(hurt_timer)

func _wander_setup():
	rng.randomize()
	wander_timer.one_shot = false
	wander_timer.wait_time = wander_interval
	wander_timer.timeout.connect(_on_wander_timeout)
	add_child(wander_timer)
	wander_timer.start()
	_pick_wander_direction()

func _on_wander_timeout():
	_pick_wander_direction()

func _pick_wander_direction():
	if rng.randf() < wander_idle_chance:
		wander_direction = Vector2.ZERO
		return
	var angle = rng.randf_range(0.0, TAU)
	wander_direction = Vector2(cos(angle), sin(angle)).normalized()

func _connect_existing_interactables():
	for node in get_tree().get_nodes_in_group("interactable_objects"):
		print(node)
		_connect_interactable(node)

func _on_node_added(node: Node):
	if node is InteractableObject:
		_connect_interactable(node)

func _connect_interactable(node: InteractableObject):
	if not node.comes_into_contact.is_connected(_on_interactable_contact.bind(node)):
		node.comes_into_contact.connect(_on_interactable_contact.bind(node))

func _on_interactable_contact(interactable: InteractableObject):
	print("hello there!")
	pass

func _on_animation_finished():
	if is_hurt:
		return
	_play_idle()

func _on_hurt_timeout():
	is_hurt = false
	_play_idle()

func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed
	_update_animation(input_direction)

func _update_animation(input_direction: Vector2):
	if is_hurt:
		return  # Don't update animation while hurt
	
	if input_direction == Vector2.ZERO:
		_play_idle()
		return

	_last_direction = input_direction
	var anim_name := _get_walk_animation(input_direction)
	if (!_play_if_exists(anim_name)):
		print("Animation not found: ", anim_name)

func _get_walk_animation(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "walk_right" if direction.x > 0 else "walk_left"
	return "walk_down" if direction.y > 0 else "walk_up"

func _play_idle():
	var idle_name := _get_idle_animation(_last_direction)
	if _play_if_exists(idle_name):
		return
	animated_sprite.stop()

func _get_idle_animation(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "idle_right" if direction.x > 0 else "idle_left"
	return "idle_down" if direction.y > 0 else "idle_up"

func _play_if_exists(anim_name: String) -> bool:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		return true
	return false
	
func die():
	health = max_health
	global_position = starting_position
	velocity = Vector2.ZERO
	is_hurt = false
	hurt_timer.stop()
	_play_idle()

func take_damage(damage_direction: Vector2, hp):
	is_hurt = true
	hurt_timer.start()
	var hurt_direction := -damage_direction
	if hurt_direction == Vector2.ZERO:
		hurt_direction = _last_direction
	var hurt_anim := _get_hurt_animation(hurt_direction)
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(hurt_anim):
		# Force the hurt animation to play only once
		health -= hp
		if health <= 0:
			die()
		else:
			animated_sprite.stop()
			animated_sprite.play(hurt_anim)
			print("Player hurt from direction: ", hurt_anim)
	else:
		print("Hurt animation not found: ", hurt_anim)
		is_hurt = false  # Clear flag if animation doesn't exist
		hurt_timer.stop()

func _get_hurt_animation(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "hurt_right" if direction.x > 0 else "hurt_left"
	return "hurt_down" if direction.y > 0 else "hurt_up"
	
func act_robotic():
	if is_hurt:
		return
	velocity = wander_direction * speed * wander_speed_multiplier
	_update_animation(wander_direction)

func _physics_process(_delta):
	if (playerCharacter):
		get_input()
	else:
		act_robotic()
	move_and_slide()
