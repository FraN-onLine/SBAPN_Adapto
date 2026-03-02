extends TextureRect


func _on_start_button_pressed() -> void:
	$Control/VBoxContainer/Button.visible = false
	$Control/VBoxContainer/Button2.visible = false
	$Control/VBoxContainer/Button3.visible = false
	$Control/VBoxContainer/Button4.visible = true
	$Control/VBoxContainer/Button5.visible = true
	$Control/VBoxContainer/Back.visible = true

func on_diagnostic_button_pressed():
	get_tree().change_scene_to_file("res://Games/game1.tscn")


func _on_button_2_pressed() -> void:
	$Control/VBoxContainer/Button.visible = false
	$Control/VBoxContainer/Button2.visible = false
	$Control/VBoxContainer/Button3.visible = false
	$Control/VBoxContainer/TopicSelect.visible = true
	$Control/VBoxContainer/TopicImport.visible = true
	$Control/VBoxContainer/Back.visible = true
	
func _on_back_pressed() -> void:
	$Control/VBoxContainer/Button.visible = true
	$Control/VBoxContainer/Button2.visible = true
	$Control/VBoxContainer/Button3.visible = true
	$Control/VBoxContainer/Button4.visible = false
	$Control/VBoxContainer/Button5.visible = false
	$Control/VBoxContainer/TopicSelect.visible = false
	$Control/VBoxContainer/TopicImport.visible = false
	$Control/VBoxContainer/Back.visible = false


func _on_topic_select_pressed() -> void:
	$ColorRect.visible = true
