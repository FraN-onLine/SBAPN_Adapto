extends Node2D

var money = 0
var questions = {}
var answered = {}
var current_key = ""
var button_by_key = {}

func _ready() -> void:
	randomize()
	# gather and group lesson items
	var lesson = load("res://Lessons/lesson_files/Object Oriented/oop.tres")
	var items = lesson.lesson_items
	var groups = {}
	for item in items:
		for rel in item.related_to:
			if not groups.has(rel):
				groups[rel] = []
			groups[rel].append(item)

	# pick three related groups with >=3 items
	var selected_rel = []
	for rel in groups.keys():
		if groups[rel].size() >= 3:
			selected_rel.append(rel)
			if selected_rel.size() == 3:
				break
	#if selected_rel.size() < 3:
		

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
			var value = int(btn.text)
			var item = categories[row][col]
			var qtext = item.definition
			if item.tof_statement and randi() % 2 == 0:
				qtext = item.tof_statement["true"]
			questions[key] = {"question": qtext, "answer": item.term, "value": value}
			btn.connect("pressed", Callable(self, "_on_button_pressed").bind(key))

func _on_button_pressed(key: String) -> void:
	if answered.has(key):
		return
	current_key = key
	$QuestionDialog.text = questions[key].question
	$AnswerInput.text = ""

func _on_question_confirmed() -> void:
	var key = current_key
	var user_answer = $AnswerInput.text.strip_edges().to_lower()
	var correct = questions[key].answer.strip_edges().to_lower()
	if user_answer == correct or user_answer == "what is " + correct:
		money += questions[key].value
		$Label.text = "Money: $" + str(money)
		button_by_key[key].text = "✓"
	else:
		button_by_key[key].text = "✗"
	answered[key] = true
	_check_game_end()

func _check_game_end() -> void:
	if answered.size() == 9:
		$QuestionDialog.dialog_text = "Game Over! Final Money: $" + str(money)
		$QuestionDialog.ok_button_text = "OK"
		$QuestionDialog.popup_centered()
