
extends Sprite

# member variables here, example:
# var a=2
# var b="textvar"
onready var anim = get_node("AnimationPlayer")

func _ready():
	set_fixed_process(true)
	pass

func _fixed_process(delta):
	if (!anim.is_playing()):
		queue_free()

