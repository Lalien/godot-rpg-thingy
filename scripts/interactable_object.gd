extends Area2D
class_name InteractableObject
signal comes_into_contact
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

func _ready():
	add_to_group("interactable_objects")
	print("hello!");
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print(body)
	if body is CharacterBody2D:
		print("came into contact")
		comes_into_contact.emit()
