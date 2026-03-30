extends Node2D

# Game 3 Stats Display
# This script displays one question type at a time (keyword, simple term, definition, TOF)
# Users can navigate between types using back/next buttons. Fun animations are included.
# All logic is documented for easy understanding.

@onready var type_label = $TypeLabel
@onready var stat_label = $StatLabel
@onready var back_btn = $BackBtn
@onready var next_btn = $NextBtn

var question_types = ["Keyword", "Simple Term", "Definition", "TOF"]
var stats = [] # Filled from user_stats
var current_type_idx = 0

func _ready():
	# Example: Fetch stats from global user_stats
	var user_stats = get_node("/root/UserStats")
	stats = user_stats.get_game3_stats_display()
	_update_display()
	back_btn.pressed.connect(_on_back)
	next_btn.pressed.connect(_on_next)
	# Animate in
	_animate_in()

func _update_display():
	type_label.text = question_types[current_type_idx]
	stat_label.text = stats[current_type_idx]
	_animate_switch()

func _on_back():
	current_type_idx = (current_type_idx - 1) % question_types.size()
	_update_display()

func _on_next():
	current_type_idx = (current_type_idx + 1) % question_types.size()
	_update_display()

func _animate_in():
	# Simple fade-in animation for the whole panel
	self.modulate = Color(1,1,1,0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1,1,1,1), 0.6)

func _animate_switch():
	# Fun scale bounce animation for stat_label
	stat_label.scale = Vector2(1,1)
	var tween = create_tween()
	tween.tween_property(stat_label, "scale", Vector2(1.2,1.2), 0.15)
	tween.tween_property(stat_label, "scale", Vector2(1,1), 0.15)

# End of script
# All functions are documented above for clarity.
