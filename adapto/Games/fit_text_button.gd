extends Button

@export var min_font_size: int = 10
@export var max_font_size: int = 18
@export var padding: float = 8.0
var _is_adjusting := false
var _last_text: String = ""

func _ready():
	resized.connect(_queue_adjust_font_for_size)
	set_process(true)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_last_text = text
	_queue_adjust_font_for_size()

func _process(_delta: float) -> void:
	# Game 1 updates button.text directly, so also react to text changes.
	if text != _last_text:
		_last_text = text
		_queue_adjust_font_for_size()

func _notification(what):
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_queue_adjust_font_for_size()

func _queue_adjust_font_for_size() -> void:
	if _is_adjusting:
		return
	call_deferred("_adjust_font_for_size")

func _adjust_font_for_size():
	if _is_adjusting:
		return
	_is_adjusting = true

	if text.is_empty():
		_is_adjusting = false
		return
	
	var stylebox: StyleBox = get_theme_stylebox("normal")
	var content_left := 0.0
	var content_right := 0.0
	var content_top := 0.0
	var content_bottom := 0.0
	if stylebox != null:
		content_left = stylebox.content_margin_left
		content_right = stylebox.content_margin_right
		content_top = stylebox.content_margin_top
		content_bottom = stylebox.content_margin_bottom

	var available_width := maxf(8.0, size.x - (padding * 2.0) - content_left - content_right)
	var available_height := maxf(8.0, size.y - (padding * 2.0) - content_top - content_bottom)

	if icon != null:
		var icon_w := float(icon.get_width())
		var icon_h := maxf(1.0, float(icon.get_height()))
		var displayed_icon_w := icon_w
		if expand_icon:
			var max_icon_h := maxf(1.0, available_height)
			displayed_icon_w = minf(icon_w * (max_icon_h / icon_h), max_icon_h)
		available_width = maxf(8.0, available_width - displayed_icon_w - 6.0)
	var current_size = max_font_size
	var font = get_theme_font("font")
	
	if not font:
		_is_adjusting = false
		return
		
	while current_size >= min_font_size:
		add_theme_font_size_override("font_size", current_size)
		var text_size = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, available_width, current_size)
		if text_size.x <= available_width and text_size.y <= available_height:
			_is_adjusting = false
			return
		current_size -= 1
	
	add_theme_font_size_override("font_size", min_font_size)
	_is_adjusting = false

func update_text(new_text: String):
	text = new_text
	_last_text = new_text
	_queue_adjust_font_for_size()

#hmm
