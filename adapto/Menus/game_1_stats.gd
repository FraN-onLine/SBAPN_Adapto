## Game 1 results screen.
##
## Displays per-type diagnostic results and routes to the next game according
## to the active flow (default sequence or adaptive sequence).
extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var user_stats = get_node("/root/UserStats")
	var display = user_stats.get_game_stats_display()
	$Keyword.text = display[0]  # keyword
	$SimpleTerm.text = display[1]  # simple_terms
	$Definition.text = display[2]  # definition
	$TOF.text = display[3]  # tof


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")


func _on_proceed_pressed() -> void:
	# Continue using adaptive router (or default sequence when adaptive is off).
	get_tree().change_scene_to_file(UserStats.get_scene_after_game("game1"))
