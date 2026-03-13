extends Node2D

const ROUND_TIME := 120
const TARGET_PAIRS := 8

@onready var game_timer: Timer = $GameTimer
@onready var score_label: Label = $TopBar/TopBarHBox/ScoreLabel
@onready var streak_label: Label = $TopBar/TopBarHBox/StreakLabel
@onready var timer_label: Label = $TopBar/TopBarHBox/TimerLabel
@onready var feedback_label: Label = $FeedbackLabel
@onready var board_grid: GridContainer = $BoardPanel/BoardGrid
@onready var progress_label: Label = $SidePanel/SideVBox/ProgressLabel
@onready var mistake_label: Label = $SidePanel/SideVBox/MistakeLabel
@onready var shuffle_btn: Button = $BottomBar/BottomHBox/ShuffleBtn
@onready var hint_btn: Button = $BottomBar/BottomHBox/HintBtn
@onready var submit_pair_btn: Button = $BottomBar/BottomHBox/SubmitPairBtn
@onready var end_dialog: AcceptDialog = $EndDialog

var lesson: Lesson
var cards: Array = []
var selected_card_ids: Array[int] = []
var card_buttons := {}

var score := 0
var time_remaining := ROUND_TIME
var current_streak := 0
var max_streak := 0
var matched_pairs := 0
var total_pairs := 0
var wrong_attempts := 0
var hints_used := 0
var input_locked := false
var game_finished := false


func _ready() -> void:
	_apply_main_layout()

	lesson = Global.selected_lesson if Global.selected_lesson != null else load("res://Lessons/lesson_files/Object Oriented/oop.tres")

	if lesson == null or lesson.lesson_items.is_empty():
		feedback_label.text = "No lesson available. Please select or create a lesson first."
		_disable_gameplay_buttons()
		return

	_prepare_cards()
	if cards.is_empty():
		feedback_label.text = "Not enough valid lesson entries for matching game."
		_disable_gameplay_buttons()
		return

	_build_board()
	_update_hud()
	feedback_label.text = "Pick two cards that match (term ↔ meaning)."

	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_tick)
	game_timer.start()

	shuffle_btn.pressed.connect(_on_shuffle_pressed)
	hint_btn.pressed.connect(_on_hint_pressed)
	submit_pair_btn.pressed.connect(_on_submit_pair_pressed)
	end_dialog.confirmed.connect(_on_end_dialog_confirmed)


func _apply_main_layout() -> void:
	var vp_size = get_viewport_rect().size
	if vp_size.x < 100: vp_size = Vector2(1152, 648)
	
	var bg = get_node_or_null("Background")
	if bg:
		bg.size = vp_size

	var margin := 20.0
	var top_bar = $TopBar
	var side_panel = $SidePanel
	var bottom_bar = $BottomBar
	var board_panel = $BoardPanel

	top_bar.position = Vector2(margin, margin)
	top_bar.size = Vector2(vp_size.x - margin * 2, 60)
	
	feedback_label.position = Vector2(margin, top_bar.position.y + top_bar.size.y + 10)
	feedback_label.size = Vector2(vp_size.x - margin * 2, 30)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	bottom_bar.size = Vector2(vp_size.x - margin * 2, 60)
	bottom_bar.position = Vector2(margin, vp_size.y - bottom_bar.size.y - margin)
	
	var mid_y = feedback_label.position.y + feedback_label.size.y + 10
	var mid_h = bottom_bar.position.y - mid_y - margin
	var side_width := 300.0
	
	side_panel.size = Vector2(side_width, mid_h)
	side_panel.position = Vector2(vp_size.x - side_width - margin, mid_y)
	
	board_panel.size = Vector2(vp_size.x - side_width - margin * 3, mid_h)
	board_panel.position = Vector2(margin, mid_y)


func _prepare_cards() -> void:
	cards.clear()
	var items = lesson.lesson_items.duplicate()
	items.shuffle()

	var pair_count := 0
	var card_id := 0

	for item in items:
		if pair_count >= TARGET_PAIRS:
			break

		var term: String = str(item.term).strip_edges()
		var clue: String = str(item.definition).strip_edges()
		if clue == "":
			clue = str(item.simple_terms).strip_edges()

		if term == "" or clue == "":
			continue

		var pair_id := pair_count
		cards.append({
			"id": card_id,
			"pair_id": pair_id,
			"text": term,
			"kind": "term",
			"state": "idle"
		})
		card_id += 1

		cards.append({
			"id": card_id,
			"pair_id": pair_id,
			"text": clue,
			"kind": "meaning",
			"state": "idle"
		})
		card_id += 1

		pair_count += 1

	cards.shuffle()
	total_pairs = pair_count


func _build_board() -> void:
	for child in board_grid.get_children():
		child.queue_free()

	card_buttons.clear()
	for card in cards:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 100)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.text = str(card["text"])
		btn.theme_type_variation = "FlatButton"
		btn.clip_text = true
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_card_pressed.bind(int(card["id"])))
		board_grid.add_child(btn)
		card_buttons[int(card["id"])] = btn
		_apply_card_visual(int(card["id"]))


func _on_card_pressed(card_id: int) -> void:
	if input_locked or game_finished:
		return

	var card_index := _find_card_index(card_id)
	if card_index == -1:
		return
	if cards[card_index]["state"] == "solved":
		return

	if selected_card_ids.has(card_id):
		selected_card_ids.erase(card_id)
		cards[card_index]["state"] = "idle"
		_apply_card_visual(card_id)
		return

	if selected_card_ids.size() >= 2:
		return

	selected_card_ids.append(card_id)
	cards[card_index]["state"] = "selected"
	_apply_card_visual(card_id)

	if selected_card_ids.size() == 2:
		_check_selected_pair()


func _on_submit_pair_pressed() -> void:
	if input_locked or game_finished:
		return
	if selected_card_ids.size() == 2:
		_check_selected_pair()
	else:
		feedback_label.text = "Select two cards first."


func _check_selected_pair() -> void:
	if selected_card_ids.size() != 2:
		return

	input_locked = true

	var id_a := selected_card_ids[0]
	var id_b := selected_card_ids[1]
	var idx_a := _find_card_index(id_a)
	var idx_b := _find_card_index(id_b)
	if idx_a == -1 or idx_b == -1:
		input_locked = false
		return

	var card_a: Dictionary = cards[idx_a]
	var card_b: Dictionary = cards[idx_b]
	var is_match: bool = int(card_a["pair_id"]) == int(card_b["pair_id"]) and str(card_a["kind"]) != str(card_b["kind"])

	if is_match:
		cards[idx_a]["state"] = "solved"
		cards[idx_b]["state"] = "solved"
		_apply_card_visual(id_a)
		_apply_card_visual(id_b)

		matched_pairs += 1
		current_streak += 1
		max_streak = maxi(max_streak, current_streak)

		var time_bonus := maxi(0, 20 - int((ROUND_TIME - time_remaining) / 6.0))
		score += 100 + time_bonus
		if current_streak > 0 and current_streak % 3 == 0:
			score += 75

		feedback_label.text = "✅ Match!"
	else:
		wrong_attempts += 1
		current_streak = 0
		score -= 35
		feedback_label.text = "❌ Not a match."
		await get_tree().create_timer(0.4).timeout
		if cards[idx_a]["state"] != "solved":
			cards[idx_a]["state"] = "idle"
		if cards[idx_b]["state"] != "solved":
			cards[idx_b]["state"] = "idle"
		_apply_card_visual(id_a)
		_apply_card_visual(id_b)

	selected_card_ids.clear()
	input_locked = false
	_update_hud()

	if matched_pairs >= total_pairs:
		_end_game(true)


func _on_shuffle_pressed() -> void:
	if input_locked or game_finished:
		return

	selected_card_ids.clear()
	for card in cards:
		if card["state"] != "solved":
			card["state"] = "idle"
	cards.shuffle()
	_build_board()
	feedback_label.text = "Board shuffled."


func _on_hint_pressed() -> void:
	if input_locked or game_finished:
		return

	var unsolved_by_pair := {}
	for card in cards:
		if card["state"] == "solved":
			continue
		var pair_id = card["pair_id"]
		if not unsolved_by_pair.has(pair_id):
			unsolved_by_pair[pair_id] = []
		unsolved_by_pair[pair_id].append(card["id"])

	for pair_id in unsolved_by_pair.keys():
		var ids = unsolved_by_pair[pair_id]
		if ids.size() >= 2:
			hints_used += 1
			score -= 60
			feedback_label.text = "Hint used: highlighted one pair."

			for card_id in ids:
				var idx := _find_card_index(int(card_id))
				if idx != -1 and cards[idx]["state"] != "solved":
					cards[idx]["state"] = "selected"
					_apply_card_visual(int(card_id))

			await get_tree().create_timer(1.2).timeout

			for card_id in ids:
				var idx := _find_card_index(int(card_id))
				if idx != -1 and cards[idx]["state"] == "selected":
					cards[idx]["state"] = "idle"
					_apply_card_visual(int(card_id))

			_update_hud()
			return

	feedback_label.text = "No available hint."


func _on_timer_tick() -> void:
	if game_finished:
		return
	time_remaining -= 1
	_update_hud()
	if time_remaining <= 0:
		_end_game(false)


func _apply_card_visual(card_id: int) -> void:
	if not card_buttons.has(card_id):
		return
	var btn: Button = card_buttons[card_id]
	var idx := _find_card_index(card_id)
	if idx == -1:
		return

	var state = cards[idx]["state"]
	match state:
		"solved":
			btn.disabled = true
			btn.modulate = Color(0.55, 1.0, 0.62, 1.0)
		"selected":
			btn.disabled = false
			btn.modulate = Color(0.7, 0.88, 1.0, 1.0)
		_:
			btn.disabled = false
			btn.modulate = Color(1, 1, 1, 1)


func _find_card_index(card_id: int) -> int:
	for i in range(cards.size()):
		if int(cards[i]["id"]) == card_id:
			return i
	return -1


func _update_hud() -> void:
	score_label.text = "Score: %d" % score
	streak_label.text = "Streak: x%d" % current_streak
	timer_label.text = "Time: %ds" % maxi(0, time_remaining)
	progress_label.text = "Matched: %d/%d" % [matched_pairs, total_pairs]
	mistake_label.text = "Mistakes: %d | Hints: %d" % [wrong_attempts, hints_used]


func _end_game(won: bool) -> void:
	if game_finished:
		return
	game_finished = true
	game_timer.stop()
	input_locked = true
	_disable_gameplay_buttons()

	var elapsed := ROUND_TIME - maxi(0, time_remaining)
	var total_attempts := matched_pairs + wrong_attempts
	var accuracy := 0.0
	if total_attempts > 0:
		accuracy = (float(matched_pairs) / float(total_attempts)) * 100.0

	_save_performance({
		"score": score,
		"correct": matched_pairs,
		"incorrect": wrong_attempts,
		"accuracy": accuracy,
		"time_spent": elapsed,
		"completed": won,
		"timestamp": Time.get_unix_time_from_system(),
		"lesson_title": lesson.lesson_title if lesson != null else "",
		"max_streak": max_streak,
		"hints_used": hints_used,
		"pairs_total": total_pairs
	})

	if won:
		end_dialog.title = "Round Complete"
		end_dialog.dialog_text = "Great job!\nScore: %d\nMatched all %d pairs." % [score, total_pairs]
	else:
		end_dialog.title = "Time Up"
		end_dialog.dialog_text = "Time's up!\nScore: %d\nMatched %d/%d pairs." % [score, matched_pairs, total_pairs]
	end_dialog.popup_centered()


func _save_performance(payload: Dictionary) -> void:
	if Global.current_user == null:
		return
	var existing = Database.load_user_performance(Global.current_user)
	if typeof(existing) != TYPE_DICTIONARY:
		existing = {}
	existing["game4"] = payload
	Database.save_user_performance(Global.current_user, existing)


func _disable_gameplay_buttons() -> void:
	shuffle_btn.disabled = true
	hint_btn.disabled = true
	submit_pair_btn.disabled = true


func _on_end_dialog_confirmed() -> void:
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")
