extends TextureProgressBar

@onready var timer = $Timer

# Keep health as a normal field; updates go through _set_health() to avoid
# recursive setter calls.
var health = 0

func _set_health(new_health):
	var _previous_health = health
	health = min(max_value, new_health)
	value = health
	
	if health <= 0:
		value = 0


# Called when the node enters the scene tree for the first time.
func init_health(_health):
	health = _health
	max_value = health
	value = health
