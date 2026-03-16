extends Node2D

var money = 0
var questions = {}
var answered = {}
var current_key = ""
var button_by_key = {}
var total_questions = 0

func _ready() -> void:
	randomize()
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
			questions[key] = {"question": qtext, "answer": item.term, "value": value}
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
	var user_answer = $AnswerInput.text.strip_edges().to_lower()
	var correct_answer = questions[current_key].answer.strip_edges().to_lower()
	if user_answer == correct_answer:
		money += questions[current_key].value
	else:
		money -= questions[current_key].value
	answered[current_key] = true
	$MoneyLabel.text = "Money: $" + str(money)
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


func _on_answer_input_text_changed() -> void:
	$Submit.disabled = $AnswerInput.text.strip_edges().is_empty() or current_key == ""


func _check_game_end() -> void:
	if total_questions > 0 and answered.size() >= total_questions:
		get_tree().change_scene_to_file("res://Games/game3.tscn")
