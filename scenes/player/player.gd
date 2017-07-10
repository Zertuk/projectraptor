extends KinematicBody2D

#CONSTANTS
const FLOOR_ANGLE_TOLERANCE = 40
const WALK_FORCE = 300
const WALK_MIN_SPEED = 10
const WALK_MAX_SPEED = 90
const STOP_FORCE = 800
const JUMP_MAX_AIRBORNE_TIME = 0.2
const SLIDE_STOP_VELOCITY = 1.0 # One pixel per second
const SLIDE_STOP_MIN_TRAVEL = 1.0 # One pixel
const GRAVITY = 600
const JUMP_SPEED = 160
const ROLL_SPEED = 90
const ATTACK_ONE_TIME = 30
const ATTACK_TWO_TIME = 24
const ATTACK_THREE_TIME = 24
const IMMUNE_TIME = 60
const IMMUNE_COOLDOWN = 20
const RECENT_ATTACK_TIME = 3
const LASER_TIME_CONST = 30

#ONREADY
onready var anim = get_node("Sprite/AnimationPlayer")
onready var playerSprite = get_node("Sprite")


#MISC
var hasShot = false
var currentItem = "potion"
var playerState = "normal"
var playerAnimation = "idle"
var prevAnimation = ""
var velocity = Vector2()
var position = Vector2()
var nextAttack = 1
var currentAttack = 0
var maxHealth = 10
var health = 9
var vineXPos = 0
var enemyPos = 0
var currentDirection = "left"
var directionModifier = -1
var dropCount = 0
var enemyAttackDamage = 0

#BOOLS
var attackedRecently = false
var cutscene = false
var reachedWalkTo = false
var pausePlayer = false
var fixAirVelocity = false
var airAttackUsed = false
var preventJump = false
var floatUp = false
var potionUsed = false
var jumping = false
var queueAttack = false
var hasFloated = false
var isFloating = true
var jumpInput = false
var attackInput = false
var ignoreVines = false
var knockbackFlip = false
var vine = false
var inEnemy = false
var deathFinished = false
var dead = false
var prev_jump_pressed = false
var grounded = true
var tongued = false
var hasLilly = false
var hasLaser = true
var inPoison = false
var secondJump = false

#TIMERS
var laserTimer = 0
var knockbackTimeLeft = 0
var floatUpTimer = 0
var timeLeft = 0
var cooldown = 20
var rollTime = 30
var on_air_time = 100
var immuneTimer = 0
var visibleCount = 0
var immuneCooldown = 0
var freshVine = 0
var recentAttackTimer = 0
var animHoldTimer = 0

func save():
	var saveData = {
		"health": health,
		"maxHealth": maxHealth,
		"hasLilly": hasLilly,
		"dropCount": dropCount
	}
	return saveData

func loadGame(data):
	if (data == null):
		return
	dropCount = data["dropCount"]
	health = data["health"]
	maxHealth = data["maxHealth"]
	hasLilly = data["hasLilly"]

func reset():
	airAttackUsed = false
	fixAirVelocity = false
	hasShot = false
	playerState = "normal"
	playerAnimation = "idle"
	anim.stop()
	anim.play("idle")
	health = maxHealth
	dropCount = 0
	currentAttack = 0
	queueAttack = false
	attackInput = false
	jumpInput = false
	isFloating = false
	velocity = Vector2(0, 0)
	timeLeft = 0
	deathFinished = false
	dead = false
	inEnemy = false
	set_pos(Vector2(30, 50))

func kill():
	if (!dead):
		timeLeft = 60
		dead = true

func stateMachine(delta):
	if (tongued):
		velocity = Vector2(0, 0)
		return
	if (playerState == "normal"):
		return doNormal(delta)
	elif (playerState == "roll"):
		return doRoll(delta)
	elif (playerState == "attack"):
		return doAttack(delta)
	elif (playerState == "climb"):
		return doClimb(delta)
	elif (playerState == "knockback"):
		return doKnockback(delta)
	elif (playerState == "death"):
		return doDeath()
	elif (playerState == "item"):
		return doUseItem()
	elif (playerState == "range"):
		return doRangeAttack(delta)
	elif (playerState == "save"):
		return doSave()
	elif (playerState == "honey" or playerState == "honeywall"):
		return doHoney()

#ACTIONS
func doWalk(delta):
	var force = Vector2(0, GRAVITY)
	var stop = true
	var walk_left = Input.is_action_pressed("move_left")
	var walk_right = Input.is_action_pressed("move_right")
	var jump = Input.is_action_pressed("jump")
	
	if (walk_left):
		if (velocity.x <= WALK_MIN_SPEED and velocity.x > -WALK_MAX_SPEED):
			force.x -= WALK_FORCE
			stop = false
	elif (walk_right):
		if (velocity.x >= -WALK_MIN_SPEED and velocity.x < WALK_MAX_SPEED):
			force.x += WALK_FORCE
			stop = false
	
	if (stop):
		var vsign = sign(velocity.x)
		var vlen = abs(velocity.x)
		
		vlen -= STOP_FORCE*delta
		if (vlen < 0):
			vlen = 0
		
		velocity.x = vlen*vsign
	
		# Integrate forces to velocity
	if (isFloating):
		force.y = 0
	
	velocity += force*delta
	
	# Integrate velocity into motion and move
	var motion = velocity*delta
	if (isFloating):
		motion.y = 0.4
		changeAnimation("float")
		if (floatUp):
			motion.y = -1
	# Move and consume motion
	motion = move(motion)
	
	
	var floor_velocity = Vector2()
	
	if (is_colliding()):
		# You can check which tile was collision against with this
		# print(get_collider_metadata())
		# Ran against something, is it the floor? Get normal
		var n = get_collision_normal()
		
		if (rad2deg(acos(n.dot(Vector2(0, -1)))) < FLOOR_ANGLE_TOLERANCE):
			# If angle to the "up" vectors is < angle tolerance
			# char is on floor
			if (!grounded):
				resetJump()
				grounded = true
				get_node("SamplePlayer2D").play("land")
			airAttackUsed = false
			fixAirVelocity = false
			isFloating = false
			hasFloated = true
			on_air_time = 0
			floor_velocity = get_collider_velocity()
		
		if (on_air_time == 0 and force.x == 0 and get_travel().length() < SLIDE_STOP_MIN_TRAVEL and abs(velocity.x) < SLIDE_STOP_VELOCITY and get_collider_velocity() == Vector2()):
			# Since this formula will always slide the character around, 
			# a special case must be considered to to stop it from moving 
			# if standing on an inclined floor. Conditions are:
			# 1) Standing on floor (on_air_time == 0)
			# 2) Did not move more than one pixel (get_travel().length() < SLIDE_STOP_MIN_TRAVEL)
			# 3) Not moving horizontally (abs(velocity.x) < SLIDE_STOP_VELOCITY)
			# 4) Collider is not moving
			
			revert_motion()
			velocity.y = 0.0
		else:
			# For every other case of motion, our motion was interrupted.
			# Try to complete the motion by "sliding" by the normal
			motion = n.slide(motion)
			velocity = n.slide(velocity)
			# Then move again
			move(motion)
	else:
		grounded = false
	if (floor_velocity != Vector2()):
		# If floor moves, move with floor
		move(floor_velocity*delta)
	
	if (jumping and velocity.y > 0):
		# If falling, no longer jumping
		jumping = false
	
	checkJump()
	
	if (velocity.x > 0):
		changeDirection("right")
	elif (velocity.x < 0):
		changeDirection("left")
	
	on_air_time += delta
	prev_jump_pressed = jump


func doNormal(delta):
	doWalk(delta)
	
	if (velocity.x == 0 and velocity.y == 0):
		changeAnimation("idle")
	else:
		changeAnimation("run")
	
	if (timeLeft == 0):
		checkInputs()


func doRoll(delta):
	var force = Vector2(0, GRAVITY)
	var rollVelocity = Vector2(0, 0)
	changeAnimation("roll")
	if (anim.is_playing()):
		rollVelocity.x = ROLL_SPEED * delta * directionModifier
	else:
		playerState = "normal"
		timeLeft = cooldown
	jumping = false
	
	velocity += force*delta
	
	var motion = velocity*delta
	motion = move(motion)
	
	move(rollVelocity)

func doRangeAttack(delta):
#	var force = Vector2(0, GRAVITY)
#	velocity += force*delta
#	move(velocity*delta)
	var down = false
	var up = false
	if (Input.is_action_pressed("move_down")):
		changeAnimation("rangedown")
		down = true
	elif (Input.is_action_pressed("move_up")):
		changeAnimation("rangeup")
		up = true
	else:
		changeAnimation("range")
	if (!hasShot):
		addLaserShot(down, up)
		laserTimer = LASER_TIME_CONST
		print(laserTimer)
	doWalk(delta)
	
	if (laserTimer <= 0):
		hasShot = false
		if (Input.is_action_pressed("range_attack")):
			return
		playerState = "normal"
		return

func doHit(body):
	get_node("SamplePlayer2D").play("hit" + str(currentAttack))
	if (body.is_in_group("enemies")):
		if (body.get_parent().get("dead")):
			return
		body.get_parent().set("hit", true)
		body.get_parent().set("currentAttack", currentAttack)
		addAttackBurst(currentAttack)
		if (currentAttack == 3):
			get_node("Sprite/camera/Camera2D").shake(0.5, 30, 10)
			if (!body.get("interruptImmune")):
				body.get_parent().changeAnimation("hurt")
				body.get_parent().doAnimation()
			get_tree().get_root().get_node("Node2D/freezeframe").pause(14)
		if (currentAttack == 2):
			get_node("Sprite/camera/Camera2D").shake(0.5, 10, 5)
	elif (body.is_in_group("destructable")):
		body.hit()



func doAttack(delta):
	if (timeLeft <= 0):
		jumping = false
		playerState = "normal"
		queueAttack = false
		timeLeft = cooldown
		currentAttack = 0
		if (airAttackUsed):
			timeLeft = 0
		return
	recentAttackTimer = RECENT_ATTACK_TIME
	if (!grounded and !airAttackUsed):
		airAttackUsed = true
		currentAttack = 3
		changeAnimation("attackthree")
	elif (!airAttackUsed and grounded):
		jumping = false
		checkAttackInput()
		if (currentAttack == 1):
			doAttackOne(delta)
		if (currentAttack == 2):
			doAttackTwo(delta)
		if (currentAttack == 3):
			doAttackThree(delta)
	var force = Vector2(0, GRAVITY)
	if (airAttackUsed):
		if (Input.is_action_pressed("move_left")):
			force.x = -WALK_MAX_SPEED
			if (currentDirection == "right" and velocity.x > 0 and !fixAirVelocity):
				force.x = force.x * 3
				velocity.x = 0
				fixAirVelocity = true
		elif (Input.is_action_pressed("move_right")):
			force.x = WALK_MAX_SPEED
			if (currentDirection == "left" and velocity.x < 0 and !fixAirVelocity):
				force.x = force.x * 3
				velocity.x = 0
				fixAirVelocity = true
	velocity += force*delta
	if (velocity.x > WALK_MAX_SPEED):
		velocity.x = WALK_MAX_SPEED
	elif (velocity.x < -WALK_MAX_SPEED):
		velocity.x = -WALK_MAX_SPEED
	# Integrate velocity into motion and move
	var motion = velocity*delta
	# Move and consume motion
	motion = move(motion)
	
	return Vector2(0, 0)

func doAttackOne(delta):
	changeAnimation("attackone")

func doAttackTwo(delta):
	var force = Vector2(0.05, 0)
	velocity = force
	var motion = velocity
	motion.x = motion.x * directionModifier
	move(motion)
	changeAnimation("attacktwo")

func doAttackThree(delta):
	var force = Vector2(0.2, 0)
	velocity = force
	var motion = velocity
	motion.x = motion.x * directionModifier
	move(motion)
	changeAnimation("attackthree")

func resetJump():
	jumping = false
	on_air_time = 0
	prev_jump_pressed = false
	secondJump = false
	isFloating = false

func doClimb(delta):
	if (!vine):
		playerState = "normal"
	resetJump()
	
	changeAnimation("climb")
	velocity = Vector2(0, 0)
	if (Input.is_action_pressed("move_up")):
		velocity.y = -50
	elif (Input.is_action_pressed("move_down")):
		velocity.y = 50
	
	var moveX = false
	if (Input.is_action_pressed("move_left")):
		changeDirection("right")
		velocity.x = -velocity.x
		moveX = true
	elif (Input.is_action_pressed("move_right")):
		changeDirection("left")
		moveX = true
		
#	only allow jumping if we have x movement
	if (moveX):
		if (checkJump()):
			playerState = "normal"
			vine = false
#			sprite is opposite here so need -1 to fix sign
			velocity.x = WALK_MAX_SPEED * directionModifier * -1  
	
	var motion = velocity*delta
	move(motion)

func doAnimation():
	if (prevAnimation != playerAnimation):
		anim.stop()
		anim.play(playerAnimation)
		prevAnimation = playerAnimation

func doHoney():
	on_air_time = 0
	prev_jump_pressed = false
	jumping = false
	changeAnimation(playerState)
	if (checkJump()):
		playerState = "normal"

func doDeath():
	dead = true
	changeAnimation("death")
	immuneTimer = 0
	timeLeft = timeLeft - 1
	if (timeLeft < 0):
		deathFinished = true

func doHurt(pos, damage=1, projectile=false):
	enemyPos = pos
	if (playerState != "roll" and playerState != "knockback" and immuneTimer == 0 and immuneCooldown == 0 and !dead):
		get_node("SamplePlayer2D").play("hurt1")
		get_node("Sprite/camera/Camera2D").shake(0.5, 20, 2)
		health = health - damage
		knockbackTimeLeft = 8
		immuneTimer = IMMUNE_TIME
		playerState = "knockback"
		if (enemyPos >= position.x):
			knockbackFlip = true
		else:
			knockbackFlip = false
		if (pos == -1000):
			knockbackTimeLeft = 0
	elif (!projectile):
		if (!dead):
			enemyAttackDamage = damage
			inEnemy = true

func doKnockback(delta):
	if (knockbackTimeLeft > 0):
		knockbackTimeLeft = knockbackTimeLeft - 1
		var knockback = Vector2(100, -50)
		if (knockbackFlip):
			knockback.x = - knockback.x
		var motion = knockback*delta
		move(motion)
	else:
		playerState = "normal"

func doUseItem():
	if (!anim.is_playing()):
		playerState = "normal"
		potionUsed = false
		timeLeft = cooldown
	else:
		changeAnimation("item")
		if (currentItem == "potion" and !potionUsed):
			doPotion()



func doPotion():
	potionUsed = true

func doBounce():
	velocity.y = -300

func doSave():
	if (Input.is_action_pressed("move_right") or Input.is_action_pressed("move_left")):
		playerState = "normal"
	changeAnimation("save")

func useSavePoint(savePos):
	set_pos(Vector2(savePos.x + 10, savePos.y + 6))
	changeDirection("left")
	playerState = "save"
	health = maxHealth



#UTILITY
func changeAnimation(newAnimation):
	prevAnimation = playerAnimation
	playerAnimation = newAnimation

func fixPlayerPosForClimb():
	var pos = get_pos()
	pos.x = vineXPos - 8
	set_pos(pos)

func changeDirection(newDir):
	if (currentDirection == "right" and newDir == "left"):
		currentDirection = newDir
		playerSprite.set_scale(Vector2(1, 1))
		directionModifier = -1
		addSideCloud()
	elif (currentDirection == "left" and newDir == "right"):
		currentDirection = newDir
		playerSprite.set_scale(Vector2(-1, 1))
		directionModifier = 1
		addSideCloud()

#CHECKS
func checkResetFloatUp():
	if (floatUpTimer > 0):
		floatUpTimer = floatUpTimer - 1
		if (floatUpTimer == 0):
			floatUp = false
func resetJumpInput():
	if (jumpInput and !Input.is_action_pressed("jump")):
		jumpInput = false
		hasFloated = false

func checkQueuedAttack():
	if (queueAttack && timeLeft < 2):
		queueAttack = false
		currentAttack = nextAttack
		if (Input.is_action_pressed("move_left")):
			changeDirection("left")
		elif (Input.is_action_pressed("move_right")):
			changeDirection("right")
		if  (currentAttack == 2):
			timeLeft = ATTACK_TWO_TIME
		elif (currentAttack == 3):
			timeLeft = ATTACK_THREE_TIME

func checkAttackInput():
	if (!Input.is_action_pressed("attack")):
		attackInput = false
	if (Input.is_action_pressed("attack") and (timeLeft < 8 or timeLeft == 0) and not attackInput):
		attackInput = true
		playerState = "attack"
		if (timeLeft != 0) :
			queueAttack = true
			nextAttack = currentAttack + 1
		
		if (timeLeft < 2):
			currentAttack = nextAttack
		
		if (timeLeft == 0):
			currentAttack = 1
			timeLeft = ATTACK_ONE_TIME

func checkClimbInput():
	if (Input.is_action_pressed("move_up") 
	    or Input.is_action_pressed("move_down") 
	    or Input.is_action_pressed("jump")):
		if (vine):
			if (playerState != "climb"):
				jumpInput = true
				playerState = "climb"
				fixPlayerPosForClimb()
	elif (playerState == "climb"):
		playerState = "normal"

func checkInputs():
	if (Input.is_action_pressed("roll_button") and grounded):
		get_node("SamplePlayer2D").play("roll")
		playerState = "roll"
		timeLeft = rollTime
	if (Input.is_action_pressed("jump") and !jumpInput and !hasFloated and hasLilly):
		isFloating = true
		jumping = false
		velocity.y = 0
	elif (isFloating):
		isFloating = false
		hasFloated = true
	if (Input.is_action_pressed("use_item") and grounded):
		print('use item')
	if (Input.is_action_pressed("range_attack") and laserTimer <= 0 and hasLaser):
		playerState = "range"
	checkClimbInput()
	checkAttackInput()

func checkInPoison():
	if (inPoison):
		doHurt(-1000, 3, true)

func checkInEnemy():
	if (inEnemy):
		doHurt(enemyPos, enemyAttackDamage)

func checkImmune():
	var sprite = get_node("Sprite")
	if (immuneTimer > 0):
		immuneTimer = immuneTimer - 1
		if (sprite.is_visible() and visibleCount > 8):
			sprite.hide()
			visibleCount = 0
		elif (!sprite.is_visible() and visibleCount > 4):
			sprite.show()
			visibleCount = 0
		visibleCount = visibleCount + 1
		if (immuneTimer == 0):
			immuneCooldown = IMMUNE_COOLDOWN
	else:
		if (!sprite.is_visible()):
			sprite.show()
	
	if (immuneCooldown > 0):
		immuneCooldown = immuneCooldown - 1

func checkJump():
	var jump = Input.is_action_pressed("jump")
#	if (Input.is_action_pressed("move_down") and grounded):
#		return
	if (on_air_time < JUMP_MAX_AIRBORNE_TIME and jump and !prev_jump_pressed and !jumping and !jumpInput):
		get_node("SamplePlayer2D").play("jump")
		addJumpcloud()
		grounded = false
		jumpInput = true
		velocity.y = -JUMP_SPEED
		jumping = true
		return true
	if (prev_jump_pressed and jump and !secondJump and !jumpInput):
		get_node("SamplePlayer2D").play("jump")
		secondJump = true
		velocity.y = -JUMP_SPEED
		jumpInput = true
		jumping = true
		return true

func addAttackBurst(num):
	var pos = get_pos()
	pos.y = pos.y + 2
	var scene = load("res://scenes/player/attackBurst.tscn")
	var node = scene.instance()
	node.setAnimation(num)
	if (directionModifier > 0):
		node.set_flip_h(true)
		pos.x = pos.x + 40
	else:
		node.set_flip_h(false)
		pos.x = pos.x - 30
	get_tree().get_root().get_node("Node2D/temp").add_child(node, true)
	node.set_pos(pos)

func addSideCloud():
	if (grounded and !vine):
		var pos = get_pos()
		pos.y = pos.y + 2
		var scene = load("res://scenes/player/sidecloud.tscn")
		var node = scene.instance()
		if (directionModifier > 0):
			node.set_flip_h(true)
			pos.x = pos.x - 5
		else:
			node.set_flip_h(false)
			pos.x = pos.x + 5
		get_tree().get_root().get_node("Node2D/temp").add_child(node, true)
		node.set_pos(pos)


func addJumpcloud():
	if (!vine):
		var pos = get_pos()
		pos.y = pos.y + 2
		var scene = load("res://scenes/player/jumpcloud.tscn")
		var node = scene.instance()
		get_tree().get_root().get_node("Node2D/temp").add_child(node, true)
		node.set_pos(pos)

func addLaserShot(down, up):
	get_node("SamplePlayer2D").play("laser")
	hasShot = true
	var pos = get_pos()
	pos.y = pos.y + 4
	var scene = load("res://scenes/player/laser.tscn")
	var node = scene.instance()
	node.set("down", down)
	node.set("up", up)
	if (directionModifier > 0):
		node.set_flip_h(true)
		pos.x = pos.x + 40
	else:
		node.set_flip_h(false)
		pos.x = pos.x  - 40
	if (down):
		pos.x = get_pos().x
		pos.y = pos.y + 36
	if (up):
		if (directionModifier > 0):
			pos.x = get_pos().x - 2
		else:
			pos.x = get_pos().x + 2
		pos.y = pos.y - 41
	node.set("directionModifier", directionModifier)
	get_tree().get_root().get_node("Node2D/temp").add_child(node, true)
	node.set_pos(pos)

func checkRecentAttack():
	if (recentAttackTimer > 0):
		recentAttackTimer = recentAttackTimer - 1
		attackedRecently = true
	else:
		attackedRecently = false

#MISC
func boostJump():
	velocity.y = -200
func _ready():
	set_fixed_process(true)
	changeAnimation("idle")
	pass

func doCutScene(delta):
	var walkTo = get_tree().get_root().get_node("Node2D/level/walkTo")
	var pos = walkTo.get_global_pos()
	var playerPos = get_global_pos()
	var distance = abs(pos.x - playerPos.x)
	if (distance > 10):
		changeAnimation("run")
		move(Vector2((WALK_MAX_SPEED - 20) * directionModifier * delta, 0))
	else:
		velocity = Vector2(0, 0)
		reachedWalkTo = true
		changeAnimation("idle")
	doAnimation()

func _fixed_process(delta):
	if (cutscene):
		doCutScene(delta)
	elif (!pausePlayer):
		reachedWalkTo = false
		var force = stateMachine(delta)
		
		position = get_pos()
		
		if (timeLeft > 0):
			timeLeft = timeLeft - 1
		
		if (laserTimer > 0):
			laserTimer = laserTimer - 1
		
		resetJumpInput()
		checkQueuedAttack()
		doAnimation()
		checkImmune()
		checkInEnemy()
		checkResetFloatUp()
		checkRecentAttack()
		checkInPoison()

