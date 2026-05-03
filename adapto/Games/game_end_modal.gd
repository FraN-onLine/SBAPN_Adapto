extends CanvasLayer

signal confirmed

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var continue_btn: Button = $Panel/VBox/ContinueBtn

func show_stats(title_text: String, message_text: String) -> void:
	if not is_node_ready():
		await ready
		
	title_label.text = title_text
	message_label.text = message_text

func _on_continue_btn_pressed() -> void:
	emit_signal("confirmed")
