extends Node2D

@onready var question = $Question
@onready var option1_button = $Option1Button
@onready var option2_button = $Option2Button
@onready var feedback_label = $FeedbackLabel
@onready var hp_label = $HPLabel
@onready var timer_label = $TimerLabel
@onready var question_timer = $QuestionTimer

@onready var hp_bar = $Healthbar


var lesson: Lesson
var current_item: LessonItem
var selected_option: int = -1  # 0 for option1, 1 for option2
var question_type: int = 0  # 0=keyword, 1=simple_terms, 2=definition, 3=tof
var option1_value: String = ""
var option2_value: String = ""
var hp: int = 5
var max_hp: int = 5
var time_remaining: int = 30
var max_time: int = 30
@onready var player_sprite = $Player
@onready var enemy_sprite = $Enemy
var correct_items = 0
var correct_ans

func _ready() -> void:
	# Load the OOP lesson
	$HPItem.size.x = hp * 32
	lesson = load("res://Lessons/lesson_files/Object Oriented/oop.tres")
	
	# Connect button signals
	option1_button.pressed.connect(_on_option1_pressed)
	option2_button.pressed.connect(_on_option2_pressed)
	question_timer.timeout.connect(_on_timer_tick)
	
	# Load first question
	load_next_question()
	hp_bar.init_health(5) #first enemy 5 hp?

func load_next_question() -> void:
	timer_label.text = "Time: " + str(max_time) + "s"
	feedback_label.text = ""
	selected_option = -1
	option1_button.modulate = Color.WHITE
	option2_button.modulate = Color.WHITE
	
	#Get random lesson item
	current_item = lesson.get_random_lesson_item()
	if current_item == null:
		question.text = "No lesson items available!"
		return
	
	# Randomly choose what to display (0=keyword, 1=simple_terms, 2=definition)
	question_type = randi() % 4
	
	# Set up the question text
	var display_text = ""
	match question_type:
		0:  #keyword
			display_text = "Keyword: " + current_item.keyword
		1:  #st
			display_text = "In Simple Terms: " + current_item.simple_terms
		2:  #def
			display_text = "Definition: " + current_item.definition
		3: #tof
			var to_display = randi() % 2
			if to_display == 0:
				display_text = "TOF: " + current_item.tof_statement["true"]
				correct_ans = "True"
			else:
				display_text = "TOF: " + current_item.tof_statement["false"]
				correct_ans = "False"
	
	# Find second term (either related or random)
	var second_term = find_related_or_random_term()
	
	# Create options array with terms
	var options
	if question_type != 3: #if TOF, second term is the opposite statement
		options = [current_item.term, second_term]
		options.shuffle()
	else: 
		options = ["True", "False"]
	
	
	# Store the option values for answer checking
	option1_value = options[0]
	option2_value = options[1]
	
	# Set UI text
	question.text =  display_text
	option1_button.text = option1_value
	option2_button.text = option2_value
	
	# Start timer
	time_remaining = max_time
	question_timer.start(1.0)

func _on_option1_pressed() -> void:
	selected_option = 0
	option1_button.modulate = Color.YELLOW
	option2_button.modulate = Color.WHITE
	answer_check()

func _on_option2_pressed() -> void:
	selected_option = 1
	option2_button.modulate = Color.YELLOW
	option1_button.modulate = Color.WHITE
	answer_check()

func find_related_or_random_term() -> String:
	# Try to find a term with shared related_to values
	var candidates = []
	
	for item in lesson.lesson_items:
		if item.id == current_item.id:
			continue  # Skip the current item
		
		# Check if they share any related_to values
		for related in current_item.related_to:
			if related in item.related_to:
				candidates.append(item.term)
				break
	
	#random related term
	if not candidates.is_empty():
		return candidates[randi() % candidates.size()]
	
	#random term
	var random_item = lesson.get_random_lesson_item()
	while random_item.id == current_item.id:
		random_item = lesson.get_random_lesson_item()
	return random_item.term

func answer_check() -> void:
	option1_button.disabled = true
	option2_button.disabled = true
	question_timer.stop()
	var selected_value = option1_value if selected_option == 0 else option2_value
	var is_correct = (selected_value == current_item.term or selected_value == correct_ans)
	
	if is_correct:
		player_sprite.play("attack")
		enemy_sprite.modulate = Color(1, 0, 0, 0.75)
		await get_tree().create_timer(0.1).timeout
		enemy_sprite.modulate = Color(1, 1, 1)
		hp_bar._set_health(hp_bar.health - 1)
		await player_sprite.animation_finished
		player_sprite.play("default")
		await get_tree().create_timer(0.5).timeout
		option1_button.disabled = false
		option2_button.disabled = false
		load_next_question()
	else:
		hp -= 1
		$HPItem.size.x = hp * 32
		player_sprite.modulate = Color(1, 0, 0, 0.75)
		await get_tree().create_timer(0.1).timeout
		player_sprite.modulate = Color(1, 1, 1)
		update_hp_display()
		if hp <= 0:
			player_sprite.play("death")
			await get_tree().create_timer(1).timeout
			game_over()
		else:
			await get_tree().create_timer(0.3).timeout
			option1_button.disabled = false
			option2_button.disabled = false
			load_next_question()

func _on_timer_tick() -> void:
	time_remaining -= 1
	timer_label.text = "Time: " + str(time_remaining) + "s"
	
	if time_remaining <= 0:
		question_timer.stop()
		#TO
		selected_option = 0  #wrong answer
		hp -= 1
		update_hp_display()
		if hp <= 0:
			await get_tree().create_timer(2.0).timeout
			game_over()
		else:
			await get_tree().create_timer(2.0).timeout
			load_next_question()

func update_hp_display() -> void:
	hp_label.text = "HP: " + str(hp) + "/" + str(max_hp)

func game_over() -> void:
	question.text = "GAME OVER!"
	option1_button.disabled = true
	option2_button.disabled = true
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")
