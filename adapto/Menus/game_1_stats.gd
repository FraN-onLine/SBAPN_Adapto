extends Node2D

@onready var type = $Type #label for keyword etc.
@onready var corr = $Correct #label for correct for each game type etc.
@onready var accuracy = $Accuracy #label for acc for each etc.
@onready var at = $"Average Time" #label for AT etc.
@onready var back = $Back #prev type
@onready var next = $Next #next type

# Index of currently displayed question type
var current_index := 0

# Store stats display for all types
var stats_display := []

# Animation duration in seconds
const ANIMATION_TIME := 0.4

# ---
# Documentation:
# This script displays stats for Game 1, one question type at a time.
# Use Back/Next buttons to navigate between types.
# Fun animations are applied to label transitions.
# Labels:
#   Type: Shows question type name
#   Correct: Shows stats summary for current type
#   Accuracy: Shows accuracy info
#   Average Time: Shows average time info
#
# All logic is contained in show_stats(), navigation handlers, and animation function.

func _ready() -> void:
	var user_stats = get_node("/root/UserStats")
	stats_display = user_stats.get_game_stats_display()
	show_stats(current_index)
	back.connect("pressed", Callable(self, "_on_back_pressed"))
	next.connect("pressed", Callable(self, "_on_next_pressed"))

func show_stats(index: int) -> void:
	var type_names = ["Keyword", "SimpleTerm", "Definition", "TOF"]
	type.text = type_names[index]
	corr.text = stats_display[index]
	var parts = stats_display[index].split(", ")
	for part in parts:
		if part.find("ACC") != -1:
			accuracy.text = part
		elif part.find("AT") != -1:
			at.text = part
		elif part.find("Correct") != -1:
			corr.text = part 
	animate_labels()

func animate_labels() -> void:
	for label in [type, corr, accuracy, at]:
		label.modulate = Color(1,1,1,0)
		label.scale = Vector2(0.8,0.8)
		label.create_tween().tween_property(label, "modulate", Color(1,1,1,1), ANIMATION_TIME)
		label.create_tween().tween_property(label, "scale", Vector2(1,1), ANIMATION_TIME)

func _on_back_pressed() -> void:
	current_index = (current_index - 1) % stats_display.size()
	show_stats(current_index)

func _on_next_pressed() -> void:
	current_index = (current_index + 1) % stats_display.size()
	show_stats(current_index)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")

func _on_proceed_pressed() -> void:
	get_tree().change_scene_to_file("res://Games/game2.tscn")
