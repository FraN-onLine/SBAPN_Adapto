extends Node2D

var money = 0
var questions = {}
var answered = {}
var current_key = ""

func _ready():
	var lesson = load("res://Lessons/lesson_files/Object Oriented/oop.tres")
	var items = lesson.lesson_items
	
	# Group by related_to
	var groups = {}
	for item in items:
		for rel in item.related_to:
			if not groups.has(rel):
				groups[rel] = []
			groups[rel].append(item)
	
	# Pick 3 groups with at least 3 items
	var selected_groups = []
	for rel in groups.keys():
		if groups[rel].size() >= 3:
			selected_groups.append(rel)
		if selected_groups.size() == 3:
			break
	
	# For each group, pick 3 items, sorted by difficulty
	var categories = []
	for i in range(3):
		var rel = selected_groups[i]
		var group_items = groups[rel]
		group_items.sort_custom(func(a, b): return a.difficulty < b.difficulty)
		var selected_items = group_items.slice(0, 3)
		categories.append({"name": rel, "items": selected_items})
	
	# Set categories
	$Board/Categories/Category1.text = categories[0]["name"]
	$Board/Categories/Category2.text = categories[1]["name"]
	$Board/Categories/Category3.text = categories[2]["name"]
	
	# Create questions
	var idx = 0
	for cat in categories:
		for item in cat["items"]:
			var key = "%d00_%d" % [((idx / 3) + 1) * 100, (idx % 3) + 1]
			questions[key] = {
				"question": item.definition,
				"answer": "What is " + item.term + "?",
				"category": cat["name"]
			}
			idx += 1
	
	# Connect buttons
	for i in range(1, 4):
		for j in range(1, 4):
			var btn = get_node("Board/Row%d/Btn%d00_%d" % [i, (i*100), j])
			btn.connect("pressed", Callable(self, "_on_button_pressed").bind("%d00_%d" % [(i*100), j]))

func _on_button_pressed(key):
	if answered.has(key):
		return
	current_key = key
	var q = questions[key]
	$QuestionDialog.dialog_text = q["question"]
	$QuestionDialog/AnswerInput.text = ""
	$QuestionDialog.popup_centered()

func _on_question_confirmed():
	var key = current_key
	var user_answer = $QuestionDialog/AnswerInput.text.strip_edges().to_lower()
	var correct_answer = questions[key]["answer"].to_lower()
	if user_answer == correct_answer:
		var value = int(key.split("_")[0])
		money += value
		$MoneyLabel.text = "Money: $" + str(money)
		get_node("Board/Row" + str(int(key.split("_")[0])/100) + "/Btn" + key).text = "✓"
	else:
		get_node("Board/Row" + str(int(key.split("_")[0])/100) + "/Btn" + key).text = "✗"
	answered[key] = true
	check_game_end()

func check_game_end():
	if answered.size() == 9:
		$QuestionDialog.dialog_text = "Game Over! Final Money: $" + str(money)
		$QuestionDialog.ok_button_text = "OK"
		$QuestionDialog.popup_centered()
		# Perhaps go back to menu or something
