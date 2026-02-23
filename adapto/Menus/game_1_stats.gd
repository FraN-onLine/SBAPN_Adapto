extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Definition.text = ""
	$Keyword.text = ""
	$SimpleTerm.text = ""
	$TOF.text = ""


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")
