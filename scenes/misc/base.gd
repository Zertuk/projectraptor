
extends Node2D

var prevScene = ""
var currentScene = ""
onready var player = get_node("player")
var tileMin = Vector2(0, 0)
var tileMax = Vector2(0, 0)
var tileSize = 16
var spawnCoords = ""
var prevSpawnCoords
var forceSpawn = false
var oldTileMin = Vector2()
var oldTileMax = Vector2()
var initLoad = true
var sceneSwitchTimer = 0
const SCENE_SWITCH_TIME = 10
var pauseScreen = false
var prevSaveLocation = ""
var deathPause = false
onready var data = get_node("data")

func switchScene(level, extraRoomIdentifier=""):
	if (sceneSwitchTimer > 0):
		return
	sceneSwitchTimer = SCENE_SWITCH_TIME
	get_node("ui/transition/Sprite").show()
	get_node("ui/transition/Sprite").set_opacity(1)
	get_node("ui/transition/Sprite/AnimationPlayer").play("idle")
	player.set("pausePlayer", false)
	prevScene = currentScene
	currentScene = level
	get_node("level").hide()
	clearTempObjects()
	get_node("level").queue_free()
	get_node("level").set_name("levelOld")
	var scene = load("res://scenes/level/zones/" + level + ".tscn")
	var node = scene.instance()
	add_child(node, true)
#	data.checkLevelData(currentScene)
	setupScene()
	if (!initLoad): 
		var prevSceneBase = prevScene.split("/")[1]
		positionPlayer("bounds/" + prevSceneBase + extraRoomIdentifier)

func clearTempObjects():
	var tempChildren = get_node("temp").get_children()
	for child in tempChildren:
		child.queue_free()

func calculateBounds():
	oldTileMin = tileMin
	oldTileMax = tileMax
	tileMin = Vector2()
	tileMax = Vector2()
	var tilemap = get_node("level/tiles")
	tilemap.get_used_cells()
	var used_cells = tilemap.get_used_cells()
	for global_pos in used_cells:
	    if global_pos.x < tileMin.x:
	        tileMin.x = int(global_pos.x)
	    elif global_pos.x > tileMax.x:
	        tileMax.x = int(global_pos.x)
	    if global_pos.y < tileMin.y:
	        tileMin.y = int(global_pos.y)
	    elif global_pos.y > tileMax.y:
	        tileMax.y = int(global_pos.y)
	
	tileMax.x = tileMax.x + 1
	tileMax.y = tileMax.y + 1
	tileMax = tileMax*tileSize
	tileMin = tileMin *tileSize
	print(tileMax)
	print(tileMin)

func setupScene():
	var node = get_node("level")
	prevSpawnCoords = spawnCoords
	spawnCoords = node.get("coords")
	
	calculateBounds()
	setCameraBounds()

func resetBounds():
	setCameraBounds()

func setCameraBounds():
	var camera = get_node("player/Sprite/camera/Camera2D")
	var marginLeft = 0
	var marginTop = 1
	var marginRight = 2
	var marginBottom = 3
	
	camera.set_limit(marginLeft, tileMin.x)
	camera.set_limit(marginTop, tileMin.y)
	camera.set_limit(marginRight, tileMax.x)
	camera.set_limit(marginBottom, tileMax.y)

func positionPlayer(coords="", savePoint=false):
	var spawn = Vector2(0, 0)
	print(coords)
	if (coords != ""):
 		spawn = get_node("level/" + coords + "/spawn").get_global_pos()
	elif(savePoint):
		spawn = get_node("level/save").get_global_pos()
	else:
		spawn = get_node("level/spawn").get_global_pos()
	spawn.y = spawn.y - 6
	print(spawn)
	player.set_pos(spawn)

func _ready():
	randomize()
	setupScene()
	set_fixed_process(true)
	get_tree().set_debug_collisions_hint(false)
	startGame()
	pass

func startGame():
	if (true):
		switchScene("one/test")
		positionPlayer()
	elif (prevSaveLocation != ""):
		switchScene(prevSaveLocation)
		positionPlayer("", true)
	else:
		switchScene("tree/treevillage")
		positionPlayer()

func adjustPos():
	if (!initLoad):
		var pos = player.get_global_pos()
		var adjustedY = oldTileMax.y - tileMax.y
		pos.y = pos.y - adjustedY
		player.set_pos(pos)


func _fixed_process(delta):
	initLoad = false
	if (sceneSwitchTimer > 0):
		sceneSwitchTimer = sceneSwitchTimer - 1