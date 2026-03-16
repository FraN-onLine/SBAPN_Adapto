extends Control

const ROUND_TIME := 150
const TARGET_WORDS := 6
const PENALTY_MISS := 20
const PENALTY_HINT := 50
const PENALTY_SKIP := 100
const REWARD_LETTER := 15
const REWARD_WORD := 150

@onready var game_timer: Timer = $GameTimer
@onready var score_label: Label = $MainVBox/TopBar/TopBarHBox/ScoreLabel
@onready var streak_label: Label = $MainVBox/TopBar/TopBarHBox/StreakLabel
@onready var timer_label: Label = $MainVBox/TopBar/TopBarHBox/TimerLabel

@onready var definition_label: Label = $MainVBox/ContentHBox/GamePanel/GameVBox/DefinitionLabel
@onready var word_label: Label = $MainVBox/ContentHBox/GamePanel/GameVBox/WordLabel
@onready var feedback_label: Label = $MainVBox/ContentHBox/GamePanel/GameVBox/FeedbackLabel

@onready var keyboard_row_1: HBoxContainer = $MainVBox/ContentHBox/GamePanel/GameVBox/KeyboardCenter/KeyboardVBox/KeyboardRow1
@onready var keyboard_row_2: HBoxContainer = $MainVBox/ContentHBox/GamePanel/GameVBox/KeyboardCenter/KeyboardVBox/KeyboardRow2
@onready var keyboard_row_3: HBoxContainer = $MainVBox/ContentHBox/GamePanel/GameVBox/KeyboardCenter/KeyboardVBox/KeyboardRow3

@onready var progress_label: Label = $MainVBox/BottomBar/BottomHBox/ProgressLabel
@onready var mistakes_label: Label = $MainVBox/BottomBar/BottomHBox/MistakesLabel

@onready var hint_btn: Button = $MainVBox/BottomBar/BottomHBox/HintBtn
@onready var skip_btn: Button = $MainVBox/BottomBar/BottomHBox/SkipBtn
@onready var end_dialog: AcceptDialog = $EndDialog

var lesson: Lesson
var game_data: Array = []
var current_word_index := 0

var current_term := ""
var current_definition := ""
var guessed_letters: Array[String] = []

var score := 0
var time_remaining := ROUND_TIME
var current_streak := 0
var max_streak := 0
var mistakes_total := 0
var hints_used := 0
var skips_used := 0
var input_locked := false
var game_finished := false

var keyboard_buttons: Dictionary = {}

const QWERTY_LAYOUT = [
	"QWERTYUIOP",
	"ASDFGHJKL",
	"ZXCVBNM"
]

func _ready() -> void:
	lesson = Global.selected_lesson if Global.selected_lesson != null else load("res://Lessons/lesson_files/Object Oriented/oop.tres")
	if lesson == null or lesson.lesson_items.is_empty():
		definition_label.text = "No lesson available. Please select or create a lesson first."
		_disable_gameplay()
		return

	_prepare_data()
	if game_data.is_empty():
		definition_label.text = "Not enough valid lesson entries for Hangman."
		_disable_gameplay()
		return

	_build_keyboard()
	_start_word(0)
	_update_hud()

	game_timer.wait_time = 1.0
	game_timer.start()

func _prepare_data() -> void:
	game_data.clear()
	var items = lesson.lesson_items.duplicate()
	items.shuffle()
	
	var valid_words = []
	# Filter terms: only alphabetical + spaces, no extreme length
	for item in items:
		var term: String = str(item.term).strip_edges().to_upper()
		var definition: String = str(item.definition).strip_edges()
		if definition == "":
			definition = str(item.simple_terms).strip_edges()
			
		if term == "" or definition == "":
			continue
			
		# simple check if valid for hangman
		var is_valid = true
		var valid_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ -_"
		for char_str in term:
			if not valid_chars.contains(char_str):
				is_valid = false
				break
		
		if is_valid and term.length() <= 20: 
			valid_words.append({"term": term, "def": definition})
		
		if valid_words.size() >= TARGET_WORDS:
			break
			
	game_data = valid_words

func _build_keyboard() -> void:
	# Clear existing
	for row in [keyboard_row_1, keyboard_row_2, keyboard_row_3]:
		for child in row.get_children():
			child.queue_free()
			
	keyboard_buttons.clear()
	
	for i in range(QWERTY_LAYOUT.size()):
		var row_str = QWERTY_LAYOUT[i]
		var target_row: HBoxContainer
		if i == 0: target_row = keyboard_row_1
		elif i == 1: target_row = keyboard_row_2
		else: target_row = keyboard_row_3
			
		for letter in row_str:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(50, 60)
			btn.text = letter
			btn.add_theme_font_size_override("font_size", 24)
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(_on_key_pressed.bind(letter))
			target_row.add_child(btn)
			keyboard_buttons[letter] = btn

func _start_word(idx: int) -> void:
	if idx >= game_data.size():
		_end_game(true)
		return
		
	current_word_index = idx
	current_term = game_data[idx]["term"]
	current_definition = game_data[idx]["def"]
	guessed_letters.clear()
	
	input_locked = false
	feedback_label.text = ""
	
	# Enable all keys
	for key in keyboard_buttons:
		var btn: Button = keyboard_buttons[key]
		btn.disabled = false
		btn.modulate = Color(1, 1, 1, 1)
		
	definition_label.text = current_definition
	_update_word_display()
	_update_hud()

func _update_word_display() -> void:
	var display_str := ""
	var is_complete := true
	
	for char_str in current_term:
		if char_str == " " or char_str == "-":
			display_str += char_str + " "
		elif guessed_letters.has(char_str):
			display_str += char_str + " "
		else:
			display_str += "_ "
			is_complete = false
			
	word_label.text = display_str.strip_edges()
	
	if is_complete and not input_locked:
		input_locked = true
		_word_completed(true)

func _on_key_pressed(letter: String) -> void:
	if input_locked or game_finished:
		return
		
	if guessed_letters.has(letter):
		return
		
	guessed_letters.append(letter)
	var btn: Button = keyboard_buttons[letter]
	btn.disabled = true
	
	if current_term.contains(letter):
		btn.modulate = Color(0.4, 1.0, 0.4) # Greenish for correct
		score += REWARD_LETTER
		current_streak += 1
		max_streak = maxi(max_streak, current_streak)
		feedback_label.text = "Correct!"
		if current_streak > 0 and current_streak % 5 == 0:
			score += 50 # Streak bonus
	else:
		btn.modulate = Color(1.0, 0.4, 0.4) # Reddish for incorrect
		score = maxi(0, score - PENALTY_MISS)
		current_streak = 0
		mistakes_total += 1
		feedback_label.text = "Miss!"
		
	_update_word_display()
	_update_hud()

func _on_hint_pressed() -> void:
	if input_locked or game_finished:
		return
		
	score = maxi(0, score - PENALTY_HINT)
	hints_used += 1
	current_streak = 0
	feedback_label.text = "Hint used!"
	
	# Find an unrevealed letter
	var unrevealed = []
	for char_str in current_term:
		if char_str != " " and char_str != "-" and not guessed_letters.has(char_str):
			unrevealed.append(char_str)
			
	if unrevealed.size() > 0:
		var target_char = unrevealed[randi() % unrevealed.size()]
		_on_key_pressed(target_char)
	
	_update_hud()

func _on_skip_pressed() -> void:
	if input_locked or game_finished:
		return
		
	score = maxi(0, score - PENALTY_SKIP)
	skips_used += 1
	current_streak = 0
	feedback_label.text = "Word skipped!"
	
	input_locked = true
	_word_completed(false)

func _word_completed(success: bool) -> void:
	if success:
		score += REWARD_WORD
		feedback_label.text = "Excellent! +%d" % REWARD_WORD
		
	_update_hud()
	await get_tree().create_timer(1.5).timeout
	_start_word(current_word_index + 1)

func _on_timer_tick() -> void:
	if game_finished:
		return
	time_remaining -= 1
	_update_hud()
	if time_remaining <= 0:
		_end_game(false)

func _update_hud() -> void:
	score_label.text = "Score: %d" % score
	streak_label.text = "Streak: x%d" % current_streak
	timer_label.text = "Time: %ds" % maxi(0, time_remaining)
	var d_size = game_data.size() if game_data != null else 0
	progress_label.text = "Words: %d/%d" % [current_word_index, d_size]
	mistakes_label.text = "Misses: %d" % mistakes_total

func _disable_gameplay() -> void:
	input_locked = true
	hint_btn.disabled = true
	skip_btn.disabled = true
	for key in keyboard_buttons:
		keyboard_buttons[key].disabled = true

func _input(event: InputEvent) -> void:
	if game_finished or input_locked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var c = OS.get_keycode_string(event.keycode).to_upper()
		if c.length() == 1 and QWERTY_LAYOUT[0].contains(c) or QWERTY_LAYOUT[1].contains(c) or QWERTY_LAYOUT[2].contains(c):
			if not guessed_letters.has(c):
				_on_key_pressed(c)

func _end_game(won: bool) -> void:
	if game_finished:
		return
	game_finished = true
	game_timer.stop()
	_disable_gameplay()

	var elapsed := ROUND_TIME - maxi(0, time_remaining)
	var accuracy := 0.0
	var total_attempts := mistakes_total + guessed_letters.size()
	if total_attempts > 0:
		accuracy = float(guessed_letters.size() - mistakes_total) / float(total_attempts) * 100.0
		accuracy = max(0.0, accuracy)
		
	_save_performance({
		"score": score,
		"mistakes": mistakes_total,
		"accuracy": accuracy,
		"time_spent": elapsed,
		"completed": won,
		"timestamp": Time.get_unix_time_from_system(),
		"lesson_title": lesson.lesson_title if lesson != null else "",
		"max_streak": max_streak,
		"hints_used": hints_used,
		"skips_used": skips_used,
		"words_total": game_data.size()
	})

	if won:
		end_dialog.title = "Round Complete"
		end_dialog.dialog_text = "Amazing!\nScore: %d\nCompleted all words." % score
	else:
		end_dialog.title = "Time Up"
		end_dialog.dialog_text = "Time's up!\nScore: %d\nWords: %d/%d" % [score, current_word_index, game_data.size()]
	end_dialog.popup_centered()

func _save_performance(payload: Dictionary) -> void:
	if Global.current_user == null:
		return
	var existing = Database.load_user_performance(Global.current_user)
	if typeof(existing) != TYPE_DICTIONARY:
		existing = {}
	existing["game5"] = payload
	Database.save_user_performance(Global.current_user, existing)

func _on_end_dialog_confirmed() -> void:
	# After game 5, usually redirect to stats, main menu, or back to game selection
	get_tree().change_scene_to_file("res://Menus/game1_stats.tscn")
