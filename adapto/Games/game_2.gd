extends Node2D

func _unhandled_input(event):
	if event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and not event.echo:
		if $AnswerInput.has_focus() and not $Submit.disabled:
			check_answer()
## Game 2 category challenge.
##
## Tracks question correctness and money score, then reports a normalized result
## to the adaptive engine before routing to the next game.

var money = 0
var questions = {}
var answered = {}
var current_key = ""
var button_by_key = {}
var total_questions = 0
var correct_count := 0
var incorrect_count := 0
var round_started_unix := 0
var adaptive_recorded := false

func _ready() -> void:
	randomize()
	# Capture start time for normalized speed scoring.
	round_started_unix = Time.get_unix_time_from_system()
	#gather and group lesson items
	var lesson: Lesson
	if Global.selected_lesson != null:
		lesson = Global.selected_lesson
	else:
		lesson = load("res://Lessons/lesson_files/Object Oriented/oop.tres")
	var items = lesson.lesson_items
	var groups = {}
	for item in items:
		for rel in item.related_to:
			if not groups.has(rel):
				groups[rel] = []
			groups[rel].append(item)

	# pick three related groups with >=3 items
	var selected_rel = []
	#shuffle groups.keys,
	var keys = groups.keys()
	keys.shuffle()
	for rel in keys:
		if groups[rel].size() >= 3:
			selected_rel.append(rel)
			if selected_rel.size() == 3:
				break

	# sort each chosen group by difficulty
	var categories = []
	for rel in selected_rel:
		var arr = groups[rel]
		arr.sort_custom(func(a,b): return a.difficulty < b.difficulty)
		categories.append(arr)

	# set category labels (new paths)
	$Category/Category1.text = str(selected_rel[0]) if selected_rel.size() > 0 else ""
	$Category/Category2.text = str(selected_rel[1]) if selected_rel.size() > 1 else ""
	$Category/Category3.text = str(selected_rel[2]) if selected_rel.size() > 2 else ""

	# connect buttons under Cat1, Cat2, Cat3
	var cat_nodes = [$Cat1, $Cat2, $Cat3]
	for row in range(cat_nodes.size()):
		var btns = cat_nodes[row].get_children()
		for col in range(btns.size()):
			var btn = btns[col]
			var key = "%d_%d" % [row, col]
			button_by_key[key] = btn
			if row >= categories.size() or col >= categories[row].size():
				btn.visible = false
				continue
			var value = int(btn.text.lstrip("$ "))
			var item = categories[row][col]
			var qtext = item.definition
			questions[key] = {
				"question": qtext,
				"answer": item.term,
				"accepted_answers": _build_accepted_answers(item),
				"value": value
			}
			btn.connect("pressed", Callable(self, "_on_button_pressed").bind(key))

	total_questions = questions.size()
	$Submit.disabled = true

func _on_button_pressed(key: String) -> void:
	if answered.has(key):
		return
	current_key = key
	$QuestionBackground.visible = true
	$QuestionDialog.text = questions[key].question
	$AnswerInput.text = ""
	#lock other buttons while question is active
	for btn_key in button_by_key.keys():
		if btn_key != key:
			button_by_key[btn_key].disabled = true
	$Submit.disabled = false


func check_answer() -> void:
	if current_key == "":
		return
	var user_answer = _normalize_answer($AnswerInput.text)
	var accepted_answers: Array = questions[current_key].get("accepted_answers", [])
	if accepted_answers.has(user_answer):
		money += questions[current_key].value
		correct_count += 1
	else:
		money -= questions[current_key].value
		incorrect_count += 1
	answered[current_key] = true
	$TopBar/TopBarHBox/MoneyLabel.text = "Money: $" + str(money)
	$QuestionBackground.visible = false
	$QuestionDialog.text = ""
	button_by_key[current_key].disabled = true
	current_key = ""
	#re-enable buttons that haven't been answered yet
	for btn_key in button_by_key.keys():
		if not answered.has(btn_key):
			button_by_key[btn_key].disabled = false
	$AnswerInput.text = ""
	_check_game_end()


func _build_accepted_answers(item) -> Array:
	var options: Array = []
	options.append(_normalize_answer(str(item.term)))

	if item.has_method("get"):
		var extra = item.get("accepted_terms")
		if typeof(extra) == TYPE_ARRAY:
			for term in extra:
				options.append(_normalize_answer(str(term)))

	var dedup := {}
	for option in options:
		if option == "":
			continue
		dedup[option] = true
		if option.ends_with("s") and option.length() > 3:
			dedup[option.substr(0, option.length() - 1)] = true
		else:
			dedup[option + "s"] = true

	return dedup.keys()


func _normalize_answer(value: String) -> String:
	return value.strip_edges().to_lower().replace("_", " ").replace("-", " ")


func _on_answer_input_text_changed() -> void:
	$Submit.disabled = $AnswerInput.text.strip_edges().is_empty() or current_key == ""


func _check_game_end() -> void:
	if total_questions > 0 and answered.size() >= total_questions:
		# Persist normalized result before leaving the scene.
		_record_adaptive_performance()
		# Route next scene using adaptive ranking.
		get_tree().change_scene_to_file(UserStats.get_scene_after_game("game2"))


# Converts Game 2 outcomes into fair adaptive metrics.
func _record_adaptive_performance() -> void:
	if adaptive_recorded:
		return
	adaptive_recorded = true

	var answered_total := answered.size()
	var accuracy := 0.0
	if answered_total > 0:
		accuracy = (float(correct_count) / float(answered_total)) * 100.0

	var elapsed := maxi(0, Time.get_unix_time_from_system() - round_started_unix)
	var completion_ratio := 0.0
	if total_questions > 0:
		completion_ratio = clampf(float(answered_total) / float(total_questions), 0.0, 1.0)

	UserStats.record_adaptive_result("game2", float(money), accuracy, float(elapsed), completion_ratio)
