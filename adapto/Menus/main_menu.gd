extends TextureRect


func _on_start_button_pressed() -> void:
	$Control/VBoxContainer/Button.visible = false
	$Control/VBoxContainer/Button2.visible = false
	$Control/VBoxContainer/Button3.visible = false
	$Control/VBoxContainer/Button4.visible = true
	$Control/VBoxContainer/Button5.visible = true
	$Control/VBoxContainer/Button6.visible = true

func on_diagnostic_button_pressed():
	get_tree().change_scene_to_file("res://Games/game1.tscn")
