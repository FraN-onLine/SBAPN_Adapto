## Game 1 diagnostic battle quiz.
##
## Collects foundational accuracy/time stats and reports normalized performance
## for adaptive routing when adaptive mode is active.
extends Node2D

@onready var question = $Question
@onready var option1_button = $Option1Button
@onready var option2_button = $Option2Button
@onready var feedback_label = $FeedbackLabel
@onready var hp_label = $TopBar/TopBarHBox/HPLabel
@onready var timer_label = $TopBar/TopBarHBox/TimerLabel
@onready var question_timer = $QuestionTimer

@onready var hp_bar = $Healthbar
@onready var end_dialog: AcceptDialog = $EndDialog

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
var adaptive_recorded := false
var stats_recorded := false
var current_streak := 0
var max_streak := 0

func _ready() -> void:
	# Load the selected lesson, fall back to OOP if none chosen
	$HPItem.size.x = hp * 32
	if Global.selected_lesson != null:
		lesson = Global.selected_lesson
	else:
		lesson = load("res://Lessons/lesson_files/Object Oriented/oop.tres")
	
	# Connect button signals
	option1_button.pressed.connect(_on_option1_pressed)
	option2_button.pressed.connect(_on_option2_pressed)
	question_timer.timeout.connect(_on_timer_tick)
	end_dialog.confirmed.connect(_on_end_dialog_confirmed)
	
	# Reset only game1 stats (preserves previous game stats for viewing)
	UserStats.reset_game_stats("game1")
	
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

	print("Current question type: " + str(question_type) + " (" + UserStats.game_stats["game1"]["type"][question_type] + ")")
	#check performance at analyze_stats.gd, if they're poor at something
	
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
	question.text = display_text
	_adjust_question_font_size()
	if option1_button.has_method("update_text"):
		option1_button.update_text(option1_value)
	else:
		option1_button.text = option1_value

	if option2_button.has_method("update_text"):
		option2_button.update_text(option2_value)
	else:
		option2_button.text = option2_value
	
	# Start timer
	time_remaining = max_time
	question_timer.start(1.0)

func _on_option1_pressed() -> void:
	selected_option = 0
	option1_button.modulate = Color.SLATE_GRAY
	option2_button.modulate = Color.WHITE
	answer_check()

func _on_option2_pressed() -> void:
	selected_option = 1
	option2_button.modulate = Color.SLATE_GRAY
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
	var time_taken = max_time - time_remaining
	
	var selected_value = option1_value if selected_option == 0 else option2_value
	var is_correct = (selected_value == current_item.term or selected_value in current_item.accepted_terms or selected_value == correct_ans)
	
	# Update stats
	UserStats.game_stats["game1"]["questions"][question_type] += 1
	UserStats.game_stats["game1"]["sum_time"][question_type] += time_taken
	
	if is_correct:
		UserStats.game_stats["game1"]["correct"][question_type] += 1
		correct_items += 1
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
		current_streak += 1
		max_streak = maxi(max_streak, current_streak)
		# Play success sfx
		if SFXManager != null:
			SFXManager.play_success(current_streak)
		if correct_items >= 5:
			# Save this run to adaptive history before showing end dialog.
			_record_adaptive_performance()
			_record_user_stats()
			UserStats.update_overall_stats()
			_show_end_dialog(true)
			return
		load_next_question()
	else:
		UserStats.game_stats["game1"]["incorrect"][question_type] += 1
		hp -= 1
		$HPItem.size.x = hp * 32
		player_sprite.modulate = Color(1, 0, 0, 0.75)
		await get_tree().create_timer(0.1).timeout
		player_sprite.modulate = Color(1, 1, 1)
		update_hp_display()
		if hp <= 0:
			player_sprite.play("death")
			await get_tree().create_timer(1).timeout
			# Save adaptive metrics on loss as well.
			_record_adaptive_performance()
			_record_user_stats()
			UserStats.update_overall_stats()
			_show_end_dialog(false)
		else:
			await get_tree().create_timer(0.3).timeout
			option1_button.disabled = false
			option2_button.disabled = false
			load_next_question()
		# incorrect answer: reset streak and play fail
		current_streak = 0
		if SFXManager != null:
			SFXManager.play_fail()

func _on_timer_tick() -> void:
	time_remaining -= 1
	timer_label.text = "Time: " + str(time_remaining) + "s"
	
	if time_remaining <= 0:
		question_timer.stop()
		#TO
		
		UserStats.game_stats["game1"]["questions"][question_type] += 1
		UserStats.game_stats["game1"]["sum_time"][question_type] += max_time
		UserStats.game_stats["game1"]["timeout"][question_type] += 1
		selected_option = 0  #wrong answer
		hp -= 1
		$HPItem.size.x = hp * 32
		update_hp_display()
		if hp <= 0:
			await get_tree().create_timer(2.0).timeout
			# Save adaptive metrics on timeout defeat.
			_record_adaptive_performance()
			_record_user_stats()
			UserStats.update_overall_stats()
			_show_end_dialog(false)
		else:
			await get_tree().create_timer(2.0).timeout
			load_next_question()

func update_hp_display() -> void:
	hp_label.text = "HP: " + str(hp) + "/" + str(max_hp)

func _show_end_dialog(won: bool) -> void:
	question.text = ""
	option1_button.disabled = true
	option2_button.disabled = true
	
	var rating := _get_performance_rating()
	var score := _calculate_score()
	var avg_time := _calculate_average_time()
	
	var dialog_title = ""
	var dialog_text = ""
	
	if won:
		dialog_title = "Victory!"
		dialog_text = "Great job!\nCorrect: %d/5\nScore: %.0f\nAverage Time: %.1fs\nAccuracy: %.1f%%\nRating: %s" % [correct_items, score, avg_time, _calculate_accuracy(), rating]
	else:
		dialog_title = "Defeat"
		dialog_text = "Game Over\nCorrect: %d/5\nScore: %.0f\nAverage Time: %.1fs\nAccuracy: %.1f%%\nRating: %s" % [correct_items, score, avg_time, _calculate_accuracy(), rating]
	
	var end_modal = preload("res://Games/game_end_modal.tscn").instantiate()
	add_child(end_modal)
	end_modal.show_stats(dialog_title, dialog_text)
	end_modal.confirmed.connect(_on_end_dialog_confirmed)


func _on_end_dialog_confirmed() -> void:
	# Route via adaptive selector to the next game.
	get_tree().change_scene_to_file(UserStats.get_scene_after_game("game1"))


func _get_performance_rating() -> String:
	var accuracy := _calculate_accuracy()
	if accuracy >= 80:
		return "Excellent"
	elif accuracy >= 60:
		return "Good"
	elif accuracy >= 40:
		return "Fair"
	else:
		return "Try Again"


func _calculate_accuracy() -> float:
	var total_questions := 0
	var total_correct := 0
	for i in range(4):
		total_questions += int(UserStats.game_stats["game1"]["questions"][i])
		total_correct += int(UserStats.game_stats["game1"]["correct"][i])
	if total_questions > 0:
		return (float(total_correct) / float(total_questions)) * 100.0
	return 0.0


func _calculate_score() -> float:
	var total_correct := 0
	var total_incorrect := 0
	var total_timeout := 0
	for i in range(4):
		total_correct += int(UserStats.game_stats["game1"]["correct"][i])
		total_incorrect += int(UserStats.game_stats["game1"]["incorrect"][i])
		total_timeout += int(UserStats.game_stats["game1"]["timeout"][i])
	return (float(total_correct) * 100.0) - (float(total_incorrect) * 25.0) - (float(total_timeout) * 20.0)


func _calculate_average_time() -> float:
	var total_questions := 0
	var total_time := 0.0
	for i in range(4):
		total_questions += int(UserStats.game_stats["game1"]["questions"][i])
		total_time += float(UserStats.game_stats["game1"]["sum_time"][i])
	if total_questions > 0:
		return total_time / float(total_questions)
	return 0.0


func _adjust_question_font_size() -> void:
	# Get the text size at current font size
	var font_size = 28
	var max_font_size = 28
	var min_font_size = 12
	
	# Keep trying smaller font sizes until text fits
	while font_size >= min_font_size:
		question.add_theme_font_size_override("font_size", font_size)
		await get_tree().process_frame
		
		# Check if text fits within the boundaries
		var text_size = question.get_minimum_size()
		if text_size.y <= 121:  # 595 - 474 = 121 pixels available
			break
		
		font_size -= 2
	
	# Ensure font size is at least min_font_size
	question.add_theme_font_size_override("font_size", maxi(font_size, min_font_size))


func _record_user_stats() -> void:
	if stats_recorded:
		return
	stats_recorded = true
	
	var total_questions := 0
	var total_time := 0.0
	for i in range(4):
		total_questions += int(UserStats.game_stats["game1"]["questions"][i])
		total_time += float(UserStats.game_stats["game1"]["sum_time"][i])
	
	var avg_time_per_item = float(total_time) / float(total_questions) if total_questions > 0 else 0.0
	UserStats.game_stats["game1"]["questions_answered"] = total_questions
	UserStats.game_stats["game1"]["questions_correct"] = correct_items
	UserStats.game_stats["game1"]["total_score"] = correct_items * 100
	UserStats.game_stats["game1"]["time_taken"] = int(total_time)
	UserStats.game_stats["game1"]["item_times"] = [avg_time_per_item]


# Builds game1 fairness inputs and stores normalized adaptive score.
func _record_adaptive_performance() -> void:
	if adaptive_recorded:
		return
	adaptive_recorded = true

	var total_questions := 0
	var total_correct := 0
	var total_incorrect := 0
	var total_timeout := 0
	var total_time := 0.0

	for i in range(4):
		total_questions += int(UserStats.game_stats["game1"]["questions"][i])
		total_correct += int(UserStats.game_stats["game1"]["correct"][i])
		total_incorrect += int(UserStats.game_stats["game1"]["incorrect"][i])
		total_timeout += int(UserStats.game_stats["game1"]["timeout"][i])
		total_time += float(UserStats.game_stats["game1"]["sum_time"][i])

	var accuracy := 0.0
	if total_questions > 0:
		accuracy = (float(total_correct) / float(total_questions)) * 100.0

	var completion_ratio := clampf(float(correct_items) / 5.0, 0.0, 1.0)
	var raw_score := (float(total_correct) * 100.0) - (float(total_incorrect) * 25.0) - (float(total_timeout) * 20.0)
	UserStats.record_adaptive_result("game1", raw_score, accuracy, total_time, completion_ratio)
