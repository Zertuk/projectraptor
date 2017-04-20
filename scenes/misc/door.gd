
extends Area2D

export var scene = ""
var used = false
export var bubblePos = Vector2(0, 0)

func enter(body):
	print(body)
	if (body.get_name() == "player"):
		get_node("Sprite").show()
		set_process(true)

func exit(body):
	if (body.get_name() == "player"):
		get_node("Sprite").hide()
		set_process(false)

func _ready():
	connect("body_enter", self, "enter")
	connect("body_exit", self, "exit")
	pass

func _process(delta):
	var playerPos = get_tree().get_root().get_node("Node2D/player").get_global_pos()
	playerPos.y = round(playerPos.y - 16)
	get_node("Sprite").set_global_pos(playerPos)
	if (Input.is_action_pressed("move_up") and !used):
		used = true
		get_tree().get_root().get_node("Node2D").switchScene(scene)
