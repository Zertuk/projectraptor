
extends Sprite

onready var anim = get_node("AnimationPlayer")

func _ready():
	set_fixed_process(true)
	pass

func _fixed_process(delta):
	if (!anim.is_playing()):
		queue_free()


