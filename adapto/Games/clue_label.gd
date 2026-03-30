extends Label

@export var min_font_size: int = 10
@export var max_font_size: int = 16
@export var padding: float = 2.0
var _is_adjusting := false

func _ready():
	resized.connect(_queue_adjust_font_size)
	_queue_adjust_font_size()

func _notification(what):
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_queue_adjust_font_size()

func _queue_adjust_font_size() -> void:
	if _is_adjusting:
		return
	call_deferred("_adjust_font_size")

func _adjust_font_size():
	if _is_adjusting:
		return
	_is_adjusting = true

	if text.is_empty():
		_is_adjusting = false
		return
		
	var available_height = size.y - (padding * 2)
	var current_size = max_font_size
	
	while current_size >= min_font_size:
		add_theme_font_size_override("font_size", current_size)
		if get_line_count() * get_line_height() <= available_height:
			_is_adjusting = false
			return
		current_size -= 1
	
	add_theme_font_size_override("font_size", min_font_size)
	_is_adjusting = false

func update_text(new_text: String):
	text = new_text
	_queue_adjust_font_size()
