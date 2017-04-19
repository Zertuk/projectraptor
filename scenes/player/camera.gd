
extends Camera2D

# member variables here, example:
# var a=2
# var b="textvar"

var _duration = 0.0
var _period_in_ms = 0.0
var _amplitude = 0.0
var _timer = 0.0
var _last_shook_timer = 0
var _previous_x = 0.0
var _previous_y = 0.0
var _last_offset = Vector2(0, 0)
var offsetUp = false
var offsetDown = false
var offsetAmount = 0
var originalPos = Vector2(0, 0)
onready var player = get_tree().get_root().get_node("Node2D/player")

func _ready():
	originalPos = get_pos()
	set_process(true)


#func lookFurther():
#	var grounded = player.get("grounded")
#	var pos = get_pos()
#	if (grounded):
#		if (Input.is_action_pressed("move_down") and !offsetUp):
#			if (!offsetDown):
#				originalPos = pos
#			if (offsetAmount < 16):
#				offsetAmount = offsetAmount + 1
#				pos.y = pos.y + 1
#				set_pos(pos)
#			offsetDown = true
#		elif (Input.is_action_pressed("move_up") and !offsetDown):
#			if (!offsetUp):
#				originalPos = pos
#			if (offsetAmount < 16):
#				offsetAmount = offsetAmount + 1
#				pos.y = pos.y - 1
#				set_pos(pos)
#			offsetUp = true
#		else:
#			if (offsetAmount != 0 and (offsetUp or offsetDown)):
#				if (originalPos.y < pos.y):
#					pos.y = pos.y - 1
#					offsetAmount = offsetAmount - 1
#				else:
#					pos.y = pos.y + 1
#					offsetAmount = offsetAmount - 1
#				set_pos(pos)
#			elif (offsetAmount == 0):
#				offsetUp = false
#				offsetDown = false



# Shake with decreasing intensity while there's time remaining.
func _process(delta):
#    lookFurther()
    # Only shake when there's shake time remaining.
    if _timer == 0:
        return
    # Only shake on certain frames.
    _last_shook_timer = _last_shook_timer + delta
    # Be mathematically correct in the face of lag; usually only happens once.
    while _last_shook_timer >= _period_in_ms:
        _last_shook_timer = _last_shook_timer - _period_in_ms
        # Lerp between [amplitude] and 0.0 intensity based on remaining shake time.
        var intensity = _amplitude * (1 - ((_duration - _timer) / _duration))
        # Noise calculation logic from http://jonny.morrill.me/blog/view/14
        var new_x = rand_range(-1.0, 1.0)
        var x_component = intensity * (_previous_x + (delta * (new_x - _previous_x)))
        var new_y = rand_range(-1.0, 1.0)
        var y_component = intensity * (_previous_y + (delta * (new_y - _previous_y)))
        _previous_x = new_x
        _previous_y = new_y
        # Track how much we've moved the offset, as opposed to other effects.
        var new_offset = Vector2(x_component, y_component)
        set_offset(get_offset() - _last_offset + new_offset)
        _last_offset = new_offset
    # Reset the offset when we're done shaking.
    _timer = _timer - delta
    if _timer <= 0:
        _timer = 0
        set_offset(get_offset() - _last_offset)

# Kick off a new screenshake effect.
func shake(duration, frequency, amplitude):
    # Initialize variables.
    _duration = duration
    _timer = duration
    _period_in_ms = 1.0 / frequency
    _amplitude = amplitude
    _previous_x = rand_range(-1.0, 1.0)
    _previous_y = rand_range(-1.0, 1.0)
    # Reset previous offset, if any.
    set_offset(get_offset() - _last_offset)
    _last_offset = Vector2(0, 0)