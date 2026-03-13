extends Node2D

const ROUND_TIME := 150
const MAX_NODE_COUNT := 12

@onready var game_timer: Timer = $GameTimer
@onready var score_label: Label = $TopBar/TopBarHBox/ScoreLabel
@onready var moves_label: Label = $TopBar/TopBarHBox/MovesLabel
@onready var timer_label: Label = $TopBar/TopBarHBox/TimerLabel
@onready var feedback_label: Label = $FeedbackLabel
@onready var start_label: Label = $PuzzlePanel/StartLabel
@onready var end_label: Label = $PuzzlePanel/EndLabel
@onready var graph_board: Control = $PuzzlePanel/GraphBoard
@onready var current_path_label: Label = $PuzzlePanel/CurrentPathLabel
@onready var goal_label: Label = $SidePanel/SideVBox/GoalLabel
@onready var optimal_label: Label = $SidePanel/SideVBox/OptimalLabel
@onready var attempts_label: Label = $SidePanel/SideVBox/AttemptsLabel
@onready var undo_btn: Button = $BottomBar/BottomHBox/UndoBtn
@onready var reset_path_btn: Button = $BottomBar/BottomHBox/ResetPathBtn
@onready var hint_btn: Button = $BottomBar/BottomHBox/HintBtn
@onready var submit_path_btn: Button = $BottomBar/BottomHBox/SubmitPathBtn
@onready var end_dialog: AcceptDialog = $EndDialog

var lesson: Lesson
var adj: Dictionary = {}
var node_positions: Dictionary = {}
var node_buttons: Dictionary = {}
var shown_terms: Array[String] = []

var start_term: String = ""
var end_term: String = ""
var optimal_path: Array[String] = []
var current_path: Array[String] = []

var score: int = 0
var moves: int = 0
var attempts: int = 0
var hints_used: int = 0
var invalid_submits: int = 0
var time_remaining: int = ROUND_TIME
var game_finished: bool = false


func _ready() -> void:
	_fix_stacked_puzzle_panel()
	_apply_main_layout()

	lesson = Global.selected_lesson if Global.selected_lesson != null else load("res://Lessons/lesson_files/Object Oriented/oop.tres")

	if lesson == null or lesson.lesson_items.is_empty():
		feedback_label.text = "No lesson available. Please select a lesson first."
		_disable_all_inputs()
		return

	_build_graph_from_lesson()
	if not _setup_puzzle():
		feedback_label.text = "Could not build a valid path puzzle from this lesson."
		_disable_all_inputs()
		return

	_spawn_graph_nodes()
	graph_board.draw.connect(_draw_graph)
	graph_board.queue_redraw()

	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_tick)
	game_timer.start()

	undo_btn.pressed.connect(_on_undo_pressed)
	reset_path_btn.pressed.connect(_on_reset_pressed)
	hint_btn.pressed.connect(_on_hint_pressed)
	submit_path_btn.pressed.connect(_on_submit_pressed)
	end_dialog.confirmed.connect(_on_end_dialog_confirmed)

	feedback_label.text = "Build a valid path from Start to End using connected terms."
	_update_hud()


func _fix_stacked_puzzle_panel() -> void:
	# PanelContainers force all direct children to stack.
	# We move them into a VBoxContainer programmatically so they arrange vertically.
	var puzzle_panel = $PuzzlePanel
	puzzle_panel.remove_child(start_label)
	puzzle_panel.remove_child(end_label)
	puzzle_panel.remove_child(graph_board)
	puzzle_panel.remove_child(current_path_label)

	var vbox = VBoxContainer.new()
	puzzle_panel.add_child(vbox)
	
	vbox.add_child(start_label)
	vbox.add_child(end_label)
	vbox.add_child(graph_board)
	vbox.add_child(current_path_label)
	
	# Ensure the graph board takes up all the available vertical space
	graph_board.size_flags_vertical = Control.SIZE_EXPAND_FILL


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
	var puzzle_panel = $PuzzlePanel

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
	
	puzzle_panel.size = Vector2(vp_size.x - side_width - margin * 3, mid_h)
	puzzle_panel.position = Vector2(margin, mid_y)


func _build_graph_from_lesson() -> void:
	adj.clear()

	var terms: Array[String] = []
	var term_to_related: Dictionary = {}
	var term_lookup: Dictionary = {}

	for item in lesson.lesson_items:
		var term: String = str(item.term).strip_edges()
		if term == "":
			continue
		if not adj.has(term):
			adj[term] = []
			terms.append(term)
		term_lookup[term.to_lower()] = term

	for item in lesson.lesson_items:
		var term: String = str(item.term).strip_edges()
		if term == "" or not adj.has(term):
			continue
		var related_norm: Array[String] = []
		if item.related_to != null:
			for rel in item.related_to:
				related_norm.append(str(rel).strip_edges().to_lower())
		term_to_related[term] = related_norm

	for i in range(terms.size()):
		for j in range(i + 1, terms.size()):
			var term_a: String = terms[i]
			var term_b: String = terms[j]

			var rel_a: Array = term_to_related.get(term_a, [])
			var rel_b: Array = term_to_related.get(term_b, [])

			var overlap := false
			for rel in rel_a:
				if rel_b.has(rel):
					overlap = true
					break

			var mentions_term := rel_a.has(term_b.to_lower()) or rel_b.has(term_a.to_lower())
			if overlap or mentions_term:
				_add_edge(term_a, term_b)


func _add_edge(a: String, b: String) -> void:
	if not adj.has(a):
		adj[a] = []
	if not adj.has(b):
		adj[b] = []
	if not adj[a].has(b):
		adj[a].append(b)
	if not adj[b].has(a):
		adj[b].append(a)


func _setup_puzzle() -> bool:
	var terms: Array[String] = []
	for key in adj.keys():
		if (adj[key] as Array).size() >= 1:
			terms.append(str(key))

	if terms.size() < 2:
		return false

	terms.shuffle()

	for i in range(terms.size()):
		for j in range(i + 1, terms.size()):
			var a: String = terms[i]
			var b: String = terms[j]
			var path: Array[String] = _bfs_shortest_path(a, b)
			if path.is_empty():
				continue
			var edges: int = path.size() - 1
			if edges >= 3 and edges <= 6:
				start_term = a
				end_term = b
				optimal_path = path
				current_path = [start_term]
				return true

	# Fallback: any connected pair with at least 2 edges
	for i in range(terms.size()):
		for j in range(i + 1, terms.size()):
			var a: String = terms[i]
			var b: String = terms[j]
			var path: Array[String] = _bfs_shortest_path(a, b)
			if path.size() >= 3:
				start_term = a
				end_term = b
				optimal_path = path
				current_path = [start_term]
				return true

	return false


func _bfs_shortest_path(start_node: String, end_node: String) -> Array[String]:
	if start_node == end_node:
		return [start_node]
	if not adj.has(start_node) or not adj.has(end_node):
		return []

	var queue: Array[String] = [start_node]
	var visited := {}
	var parent := {}
	visited[start_node] = true
	parent[start_node] = ""

	var found := false
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == end_node:
			found = true
			break

		for next_node in adj[current]:
			var neighbor: String = str(next_node)
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			parent[neighbor] = current
			queue.append(neighbor)

	if not found:
		return []

	var path: Array[String] = []
	var node: String = end_node
	while node != "":
		path.append(node)
		node = str(parent.get(node, ""))
	path.reverse()
	return path


func _spawn_graph_nodes() -> void:
	for child in graph_board.get_children():
		child.queue_free()

	node_positions.clear()
	node_buttons.clear()
	shown_terms.clear()

	var all_terms: Array[String] = []
	for key in adj.keys():
		all_terms.append(str(key))

	var include := {}
	for term in optimal_path:
		include[term] = true

	all_terms.shuffle()
	for term in all_terms:
		if include.size() >= MAX_NODE_COUNT:
			break
		include[term] = true

	for term in include.keys():
		shown_terms.append(str(term))

	var width: float = graph_board.size.x
	var height: float = graph_board.size.y
	if width < 200:
		width = 660
	if height < 200:
		height = 370

	var center: Vector2 = Vector2(width * 0.5, height * 0.52)
	var radius: float = minf(width, height) * 0.36
	if radius < 120:
		radius = 120

	var count: int = shown_terms.size()
	for i in range(count):
		var term: String = shown_terms[i]
		var angle: float = (TAU * float(i) / float(maxi(1, count))) - PI * 0.5
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		node_positions[term] = pos

		var btn := Button.new()
		btn.text = term
		btn.custom_minimum_size = Vector2(140, 44)
		btn.size = Vector2(140, 44)
		btn.position = pos - btn.size * 0.5
		btn.clip_text = true
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_node_pressed.bind(term))
		graph_board.add_child(btn)
		node_buttons[term] = btn

	_update_node_visuals()


func _draw_graph() -> void:
	for term in shown_terms:
		if not adj.has(term):
			continue
		for n in adj[term]:
			var other: String = str(n)
			if not node_positions.has(other):
				continue
			if term > other:
				continue
			graph_board.draw_line(
				node_positions[term],
				node_positions[other],
				Color(0.45, 0.45, 0.55, 0.65),
				2.0,
				true
			)

	if current_path.size() >= 2:
		for i in range(current_path.size() - 1):
			var a: String = current_path[i]
			var b: String = current_path[i + 1]
			if node_positions.has(a) and node_positions.has(b):
				graph_board.draw_line(
					node_positions[a],
					node_positions[b],
					Color(0.2, 0.85, 1.0, 0.95),
					4.0,
					true
				)


func _on_node_pressed(term: String) -> void:
	if game_finished:
		return

	if current_path.is_empty():
		current_path.append(start_term)

	var last_term: String = current_path[current_path.size() - 1]
	if term == last_term:
		return

	if current_path.has(term):
		feedback_label.text = "Loops are disabled in MVP."
		return

	if not _are_connected(last_term, term):
		feedback_label.text = "That term is not directly connected to your current node."
		return

	current_path.append(term)
	moves += 1
	feedback_label.text = "Path extended to: " + term
	_update_hud()
	_update_node_visuals()
	graph_board.queue_redraw()


func _are_connected(a: String, b: String) -> bool:
	if not adj.has(a):
		return false
	return (adj[a] as Array).has(b)


func _on_undo_pressed() -> void:
	if game_finished:
		return
	if current_path.size() <= 1:
		return
	current_path.remove_at(current_path.size() - 1)
	moves = maxi(0, moves - 1)
	feedback_label.text = "Last node removed."
	_update_hud()
	_update_node_visuals()
	graph_board.queue_redraw()


func _on_reset_pressed() -> void:
	if game_finished:
		return
	current_path = [start_term]
	moves = 0
	feedback_label.text = "Path reset to start."
	_update_hud()
	_update_node_visuals()
	graph_board.queue_redraw()


func _on_hint_pressed() -> void:
	if game_finished:
		return
	if optimal_path.size() < 2:
		feedback_label.text = "No hint available for this puzzle."
		return

	hints_used += 1
	score -= 100

	var next_hint: String = ""
	var prefix_ok := true
	if current_path.size() > optimal_path.size():
		prefix_ok = false
	else:
		for i in range(current_path.size()):
			if current_path[i] != optimal_path[i]:
				prefix_ok = false
				break

	if prefix_ok and current_path.size() < optimal_path.size():
		next_hint = optimal_path[current_path.size()]
	else:
		next_hint = optimal_path[1]

	feedback_label.text = "Hint: Try stepping to \"%s\" next." % next_hint
	optimal_label.visible = true
	optimal_label.text = "Optimal length: %d edges" % (optimal_path.size() - 1)
	_update_hud()


func _on_submit_pressed() -> void:
	if game_finished:
		return

	attempts += 1

	var valid := _validate_current_path()
	if not valid:
		invalid_submits += 1
		score -= 40
		feedback_label.text = "Invalid path. Start/end or adjacency rules failed."
		_update_hud()
		return

	var player_len := current_path.size() - 1
	var optimal_len := optimal_path.size() - 1
	var extra_steps := maxi(0, player_len - optimal_len)
	var elapsed := ROUND_TIME - maxi(0, time_remaining)
	var efficiency_bonus := maxi(0, (optimal_len * 80) - (extra_steps * 60))
	var time_bonus := maxi(0, 120 - elapsed)

	score += 300 + efficiency_bonus + time_bonus
	_end_game(true)


func _validate_current_path() -> bool:
	if current_path.is_empty():
		return false
	if current_path[0] != start_term:
		return false
	if current_path[current_path.size() - 1] != end_term:
		return false
	for i in range(current_path.size() - 1):
		if not _are_connected(current_path[i], current_path[i + 1]):
			return false
	return true


func _on_timer_tick() -> void:
	if game_finished:
		return
	time_remaining -= 1
	_update_hud()
	if time_remaining <= 0:
		_end_game(false)


func _end_game(won: bool) -> void:
	if game_finished:
		return
	game_finished = true
	game_timer.stop()
	_disable_all_inputs()

	var elapsed := ROUND_TIME - maxi(0, time_remaining)
	var player_len := maxi(0, current_path.size() - 1)
	var optimal_len := maxi(0, optimal_path.size() - 1)
	var extra_steps := maxi(0, player_len - optimal_len)
	var payload := {
		"score": score,
		"correct": 1 if won else 0,
		"incorrect": invalid_submits,
		"accuracy": 100.0 if won else 0.0,
		"time_spent": elapsed,
		"completed": won,
		"timestamp": Time.get_unix_time_from_system(),
		"lesson_title": lesson.lesson_title if lesson != null else "",
		"optimal_len": optimal_len,
		"player_len": player_len,
		"extra_steps": extra_steps,
		"invalid_submits": invalid_submits,
		"hints_used": hints_used,
		"attempts": attempts,
		"moves": moves
	}
	_save_performance(payload)

	optimal_label.visible = true
	optimal_label.text = "Optimal path (%d): %s" % [optimal_len, " → ".join(optimal_path)]

	if won:
		end_dialog.title = "Path Complete"
		end_dialog.dialog_text = "Nice solve!\nScore: %d\nYour path length: %d\nOptimal: %d" % [score, player_len, optimal_len]
	else:
		end_dialog.title = "Time Up"
		end_dialog.dialog_text = "Time expired.\nScore: %d\nOptimal path: %s" % [score, " → ".join(optimal_path)]
	end_dialog.popup_centered()


func _save_performance(payload: Dictionary) -> void:
	if Global.current_user == null:
		return
	var existing = Database.load_user_performance(Global.current_user)
	if typeof(existing) != TYPE_DICTIONARY:
		existing = {}
	existing["game5"] = payload
	Database.save_user_performance(Global.current_user, existing)


func _update_hud() -> void:
	score_label.text = "Score: %d" % score
	moves_label.text = "Moves: %d" % moves
	timer_label.text = "Time: %ds" % maxi(0, time_remaining)
	start_label.text = "Start: " + start_term
	end_label.text = "End: " + end_term
	current_path_label.text = "Current Path: " + " → ".join(current_path)
	goal_label.text = "Goal:\nBuild a valid connected path from Start to End."
	attempts_label.text = "Attempts: %d | Invalid: %d | Hints: %d" % [attempts, invalid_submits, hints_used]


func _update_node_visuals() -> void:
	for term in node_buttons.keys():
		var btn: Button = node_buttons[term]
		btn.modulate = Color(1, 1, 1, 1)

	if node_buttons.has(start_term):
		(node_buttons[start_term] as Button).modulate = Color(0.65, 1.0, 0.72, 1)
	if node_buttons.has(end_term):
		(node_buttons[end_term] as Button).modulate = Color(1.0, 0.76, 0.65, 1)

	for term in current_path:
		if node_buttons.has(term):
			(node_buttons[term] as Button).modulate = Color(0.68, 0.88, 1.0, 1)

	if current_path.size() > 0:
		var current_term: String = current_path[current_path.size() - 1]
		if node_buttons.has(current_term):
			(node_buttons[current_term] as Button).modulate = Color(0.35, 0.8, 1.0, 1)


func _disable_all_inputs() -> void:
	undo_btn.disabled = true
	reset_path_btn.disabled = true
	hint_btn.disabled = true
	submit_path_btn.disabled = true
	for term in node_buttons.keys():
		(node_buttons[term] as Button).disabled = true


func _on_end_dialog_confirmed() -> void:
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")
