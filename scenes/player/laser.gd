
extends Sprite
var directionModifier = 1
var timeLeft = 500
var down = false
var up = false
var speed = 3

func _ready():
	changeDirection()
	set_fixed_process(true)
	get_node("Area2D").connect("body_enter", self, "doHit")
	get_node("Area2D").connect("area_enter", self, "tilemapHit")
	pass

func tilemapHit(area):
	if (area.get_parent().get_name() == "tilemap"):
		queue_free()

func changeDirection():
	if (down):
		set_rot(1.5708)
	elif (up):
		set_rot(1.5708)
	else:
		set_rot(0)

func doHit(body):
	if (body.is_in_group("enemies")):
		get_tree().get_root().get_node("Node2D/player/SamplePlayer2D").play("laserhit")
		if (body.get_parent().get("dead")):
			return
		body.get_parent().set("hit", true)
		get_tree().get_root().get_node("Node2D/player").get_node("Sprite/camera/Camera2D").shake(0.3, 20, 2)
		queue_free()
	elif (body.is_in_group("destructable") and !body.get("dead")):
		get_tree().get_root().get_node("Node2D/player/SamplePlayer2D").play("laserhit")
		body.hit()
		get_tree().get_root().get_node("Node2D/player").get_node("Sprite/camera/Camera2D").shake(0.3, 20, 2)
		queue_free()
	elif (body.get_parent().is_in_group("battery")):
		body.get_parent().turnOn()
		queue_free()

func _fixed_process(delta):
	var pos = get_pos()
	var movement = Vector2()
	if (!down && !up):
		movement = Vector2(speed * directionModifier, 0)
	elif(down):
		movement = Vector2(0, speed)
	elif(up):
		movement = Vector2(0, -speed)
	set_pos(Vector2(pos.x + movement.x, pos.y + movement.y))
	if (timeLeft <= 0):
		queue_free()
	timeLeft = timeLeft -1





