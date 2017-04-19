extends Node2D

func checkReady():
	if (get_tree().get_root().get_node("Node2D/level").get("ready")):
		get_node("Sprite/AnimationPlayer").play("fade")
		get_tree().get_root().get_node("Node2D/player").set("pausePlayer", false)
	else:
		get_node("Sprite/AnimationPlayer").play("idle")