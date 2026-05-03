## Game 3 crossword challenge.
##
## Adds in-round hints and reports normalized performance for adaptive routing.
extends Node2D

# ── Constants ────────────────────────────────────────────────────────────────
# MIN and MAX limits for grid and cell size
const MIN_CELL_SIZE  := 16
const MAX_CELL_SIZE  := 50
const MIN_GRID_SIZE  := 13
const MAX_GRID_SIZE  := 34
const TIME_LIMIT     := 180
# Score cost applied each time a hint is used.
const HINT_PENALTY := 30
const TIMEOUT_REVEAL_DELAY := 10.0
const WIN_TRANSITION_DELAY := 3.5

# ── Dynamic grid properties (calculated in _ready) ────────────────────────────
var MAX_GRID: int = 13
var CELL_SIZE: int = 42
var GRID_OX: int = 18
var GRID_OY: int = 18
var available_width: int = 0
var available_height: int = 0

# ── @onready ─────────────────────────────────────────────────────────────────
@onready var game_timer     = $GameTimer
@onready var timer_label    = $TopBar/TopBarHBox/TimerLabel
@onready var score_label    = $TopBar/TopBarHBox/ScoreLabel
@onready var feedback_label = $FeedbackLabel
@onready var across_items   = $CluesPanel/CluesScroll/CluesVBox/AcrossItems
@onready var down_items     = $CluesPanel/CluesScroll/CluesVBox/DownItems
@onready var answer_input   = $AnswerBar/AnswerVBox/AnswerHBox/AnswerInput
@onready var clue_display   = $AnswerBar/AnswerVBox/ClueLabel
@onready var submit_btn     = $AnswerBar/AnswerVBox/AnswerHBox/SubmitBtn
# UI button that reveals a partial answer pattern.
@onready var hint_btn       = $AnswerBar/AnswerVBox/AnswerHBox/HintBtn
@onready var grid_node      = $GridNode
@onready var skip = $AnswerBar/AnswerVBox/SkipButton

# ── State ─────────────────────────────────────────────────────────────────────
var lesson: Lesson
var items: Array = []
var score: int = 0
var time_remaining: int = TIME_LIMIT
var game_over: bool = false

# Grid
var grid: Array = []        # grid[row][col]: "" or uppercase letter
var placements: Array = []  # dicts: word/clue/row/col/dir(0=across 1=down)/number

# Selection / Solved state
var selected_idx: int = -1
var solved: Array = []      # bool per placement index
var wrong_attempts := 0
var hints_used := 0
var adaptive_recorded := false
var stats_recorded := false


func _ready() -> void:
	lesson = Global.selected_lesson if Global.selected_lesson != null \
		else load("res://Lessons/lesson_files/Object Oriented/oop.tres")

	for it in lesson.lesson_items:
		var t: String = it.term.strip_edges()
		# Keep longer terms; final fit is validated against computed grid size.
		if t.length() >= 3 and t.length() <= MAX_GRID_SIZE:
			items.append(it)
	items = _dedupe_crossword_items(items)
	items.shuffle()
	items = items.slice(0, min(8, items.size()))

	_calculate_grid_dimensions()

	_generate_crossword()

	if placements.is_empty():
		feedback_label.text = "Not enough terms to build a crossword. Try a different lesson."
		return

	solved.resize(placements.size())
	solved.fill(false)
	_assign_numbers()
	_build_clue_ui()

	grid_node.draw.connect(_draw_grid)
	grid_node.gui_input.connect(_on_grid_input)
	grid_node.queue_redraw()

	game_timer.timeout.connect(_on_tick)
	game_timer.start()
	submit_btn.pressed.connect(_on_submit)
	submit_btn.focus_mode = Control.FOCUS_NONE
	# Enable hint feature for crossword words.
	hint_btn.pressed.connect(_on_hint_pressed)
	hint_btn.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(_on_skip_pressed)
	skip.focus_mode = Control.FOCUS_NONE
	answer_input.gui_input.connect(_on_answer_gui_input)
	_update_hud()


# ─────────────────────────────────────────────────────────────────────────────
# Crossword Generation
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Dynamic Grid Sizing
# ─────────────────────────────────────────────────────────────────────────────

func _calculate_grid_dimensions() -> void:
	# Get GridNode's available space
	var grid_rect: Rect2 = grid_node.get_rect()
	available_width = int(grid_rect.size.x)
	available_height = int(grid_rect.size.y)
	
	# Find longest word in items (accounting for spaces)
	var longest_len: int = 0
	for item in items:
		var word_len = item.term.strip_edges().length()
		if word_len > longest_len:
			longest_len = word_len
	
	# MAX_GRID should be at least the longest word, but clamped to reasonable limits
	MAX_GRID = clampi(maxi(longest_len + 4, MIN_GRID_SIZE), MIN_GRID_SIZE, MAX_GRID_SIZE)
	
	# Calculate CELL_SIZE to fit the grid in available space, leaving some padding
	var width_cell_size = (available_width - 36) / MAX_GRID  # 36 = padding on both sides
	var height_cell_size = (available_height - 36) / MAX_GRID
	CELL_SIZE = clampi(mini(width_cell_size, height_cell_size), MIN_CELL_SIZE, MAX_CELL_SIZE)
	
	# Center the grid in available space
	var grid_total_width = MAX_GRID * CELL_SIZE
	var grid_total_height = MAX_GRID * CELL_SIZE
	GRID_OX = int((available_width - grid_total_width) / 2.0)
	GRID_OY = int((available_height - grid_total_height) / 2.0)


func _init_grid() -> void:
	grid.clear()
	for _i in range(MAX_GRID):
		var row: Array = []
		row.resize(MAX_GRID)
		row.fill("")
		grid.append(row)


func _cell(r: int, c: int) -> String:
	if r < 0 or r >= MAX_GRID or c < 0 or c >= MAX_GRID:
		return "#"
	return grid[r][c]


func _can_place(word: String, row: int, col: int, dir: int) -> bool:
	var dr := 1 if dir == 1 else 0
	var dc := 1 if dir == 0 else 0
	var wlen := word.length()
	var end_r := row + dr * (wlen - 1)
	var end_c := col + dc * (wlen - 1)
	if end_r >= MAX_GRID or end_c >= MAX_GRID or row < 0 or col < 0:
		return false

	var before := _cell(row - dr, col - dc)
	if before != "" and before != "#":
		return false
	var after := _cell(end_r + dr, end_c + dc)
	if after != "" and after != "#":
		return false

	var intersections := 0
	for i in range(wlen):
		var r := row + dr * i
		var c := col + dc * i
		var letter := word[i]
		var existing := _cell(r, c)
		
		# Spaces can overlap with anything
		if letter == " ":
			continue

		if existing == "":
			if dir == 0:
				if _cell(r - 1, c) != "" and _cell(r - 1, c) != "#": return false
				if _cell(r + 1, c) != "" and _cell(r + 1, c) != "#": return false
			else:
				if _cell(r, c - 1) != "" and _cell(r, c - 1) != "#": return false
				if _cell(r, c + 1) != "" and _cell(r, c + 1) != "#": return false
		elif existing == letter:
			intersections += 1
		elif existing != " " and letter != " ":
			return false

	return intersections > 0 or placements.is_empty()


func _place_word(item, row: int, col: int, dir: int) -> void:
	var word: String = item.term.to_upper()
	var dr := 1 if dir == 1 else 0
	var dc := 1 if dir == 0 else 0
	for i in range(word.length()):
		if word[i] != " ":
			grid[row + dr * i][col + dc * i] = word[i]
	placements.append({
		"word": word, "clue": item.definition,
		"row": row, "col": col, "dir": dir, "number": 0
	})


func _generate_crossword() -> void:
	_init_grid()
	if items.is_empty():
		return

	# Keep only entries that can fit in the computed grid dimensions.
	var placeable_items: Array = []
	for item in items:
		var word := str(item.term).strip_edges().to_upper()
		if word.length() <= MAX_GRID:
			placeable_items.append(item)

	if placeable_items.is_empty():
		return

	var sorted_items := placeable_items.duplicate()
	sorted_items.sort_custom(func(a, b): return a.term.length() > b.term.length())

	# Select the first valid anchor word instead of aborting generation.
	var anchor_index := -1
	for i in range(sorted_items.size()):
		var w0: String = str(sorted_items[i].term).strip_edges().to_upper()
		if w0.is_empty() or w0.length() > MAX_GRID:
			continue
		var r0: int = int(MAX_GRID / 2.0)
		var c0: int = clampi(int((MAX_GRID - w0.length()) / 2.0), 0, MAX_GRID - int(w0.length()))
		_place_word(sorted_items[i], r0, c0, 0)
		anchor_index = i
		break

	if anchor_index == -1:
		return

	for i in range(sorted_items.size()):
		if i == anchor_index:
			continue
		_try_place_item(sorted_items[i])


func _dedupe_crossword_items(source: Array) -> Array:
	var filtered: Array = []
	var seen_terms := {}
	var seen_definitions := {}

	for item in source:
		var canonical_term := _canonical_crossword_term(str(item.term))
		if canonical_term == "":
			continue
		if seen_terms.has(canonical_term):
			continue

		var definition_key := str(item.definition).strip_edges().to_lower()
		if definition_key != "" and seen_definitions.has(definition_key):
			continue

		seen_terms[canonical_term] = true
		if definition_key != "":
			seen_definitions[definition_key] = true
		filtered.append(item)

	return filtered


func _canonical_crossword_term(raw_term: String) -> String:
	var t := raw_term.strip_edges().to_upper().replace("-", " ")
	while t.find("  ") != -1:
		t = t.replace("  ", " ")
	if t.length() >= 5 and t.ends_with("ES"):
		t = t.substr(0, t.length() - 2)
	elif t.length() >= 4 and t.ends_with("S"):
		t = t.substr(0, t.length() - 1)
	return t


func _try_place_item(item) -> void:
	var word: String = item.term.to_upper()
	for existing in placements:
		var ew: String = existing["word"]
		for ei in range(ew.length()):
			for wi in range(word.length()):
				if ew[ei] == word[wi]:
					var new_dir: int = 1 - (existing["dir"] as int)
					var nr: int
					var nc: int
					if existing["dir"] == 0:
						nr = existing["row"] - wi
						nc = existing["col"] + ei
					else:
						nr = existing["row"] + ei
						nc = existing["col"] - wi
					if _can_place(word, nr, nc, new_dir):
						_place_word(item, nr, nc, new_dir)
						return


func _assign_numbers() -> void:
	placements.sort_custom(func(a, b):
		if a["row"] != b["row"]: return a["row"] < b["row"]
		return a["col"] < b["col"])
	var n := 1
	var numbered: Dictionary = {}
	for p in placements:
		var key := Vector2i(p["row"], p["col"])
		if not numbered.has(key):
			numbered[key] = n
			n += 1
		p["number"] = numbered[key]


# ─────────────────────────────────────────────────────────────────────────────
# Clue UI
# ─────────────────────────────────────────────────────────────────────────────

func _build_clue_ui() -> void:
	for ch in across_items.get_children(): ch.queue_free()
	for ch in down_items.get_children():   ch.queue_free()
	for idx in range(placements.size()):
		var p: Dictionary = placements[idx]
		var btn := Button.new()
		btn.add_theme_font_override("font", preload("res://Assets/Fonts/Silkscreen-Regular.ttf"))
		btn.text = "%d. %s" % [p["number"], p["clue"]]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_text = false
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_clue_selected.bind(idx))
		if p["dir"] == 0:
			across_items.add_child(btn)
		else:
			down_items.add_child(btn)


func _on_clue_selected(idx: int) -> void:
	selected_idx = idx
	var p: Dictionary = placements[idx]
	clue_display.text = "→  %d %s:   %s" % [
		p["number"], "Across" if p["dir"] == 0 else "Down", p["clue"]]
	answer_input.text = ""
	answer_input.call_deferred("grab_focus")
	grid_node.queue_redraw()


# ─────────────────────────────────────────────────────────────────────────────
# Grid Drawing
# ─────────────────────────────────────────────────────────────────────────────

func _draw_grid() -> void:
	var font := preload("res://Assets/Fonts/Silkscreen-Regular.ttf")
	var word_cells  := {}   # Vector2i → true
	var sel_cells   := {}   # Vector2i → true
	var solved_cells := {}  # Vector2i → letter

	for pi in range(placements.size()):
		var p: Dictionary = placements[pi]
		var dr := 1 if p["dir"] == 1 else 0
		var dc := 1 if p["dir"] == 0 else 0
		for i in range(p["word"].length()):
			var key := Vector2i(p["row"] + dr * i, p["col"] + dc * i)
			word_cells[key] = true
			if solved[pi]:
				solved_cells[key] = p["word"][i]

	if selected_idx >= 0 and selected_idx < placements.size():
		var sp: Dictionary = placements[selected_idx]
		var dr := 1 if sp["dir"] == 1 else 0
		var dc := 1 if sp["dir"] == 0 else 0
		for i in range(sp["word"].length()):
			sel_cells[Vector2i(sp["row"] + dr * i, sp["col"] + dc * i)] = true

	for r in range(MAX_GRID):
		for c in range(MAX_GRID):
			var x   := GRID_OX + c * CELL_SIZE
			var y   := GRID_OY + r * CELL_SIZE
			var key := Vector2i(r, c)
			var rect := Rect2(x, y, CELL_SIZE - 1, CELL_SIZE - 1)
			if not word_cells.has(key):
				grid_node.draw_rect(rect, Color(0.14, 0.2, 0.28, 0.55))
			else:
				var bg := Color.WHITE
				if sel_cells.has(key):
					bg = Color(0.65, 0.85, 1.0, 1.0)
				grid_node.draw_rect(rect, bg)
				grid_node.draw_rect(rect, Color(0.35, 0.35, 0.42, 1.0), false, 1.5)
				if solved_cells.has(key):
					# Scale letter spacing and size based on CELL_SIZE
					var font_size = int(CELL_SIZE * 0.7)
					grid_node.draw_string(font,
						Vector2(x + (CELL_SIZE * 0.25), y + CELL_SIZE - (CELL_SIZE * 0.2)),
						solved_cells[key],
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)

	for p in placements:
		var x: int = GRID_OX + (p["col"] as int) * CELL_SIZE
		var y: int = GRID_OY + (p["row"] as int) * CELL_SIZE
		# Calculate number font size relative to cell size
		var num_size = maxi(10, int(CELL_SIZE * 0.3))
		grid_node.draw_string(font, Vector2(x + 2, y + num_size + 1),
			str(p["number"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, num_size, Color(0.15, 0.15, 0.2, 1.0))


func _on_grid_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var gx := int((event.position.x - GRID_OX) / CELL_SIZE)
	var gy := int((event.position.y - GRID_OY) / CELL_SIZE)
	if gx < 0 or gx >= MAX_GRID or gy < 0 or gy >= MAX_GRID:
		return
	var matches: Array = []
	for pi in range(placements.size()):
		var p: Dictionary = placements[pi]
		var dr := 1 if p["dir"] == 1 else 0
		var dc := 1 if p["dir"] == 0 else 0
		for i in range(p["word"].length()):
			if p["row"] + dr * i == gy and p["col"] + dc * i == gx:
				matches.append(pi)
				break
	if matches.is_empty():
		return
	var next_sel: int = matches[0]
	if selected_idx in matches and matches.size() > 1:
		next_sel = matches[(matches.find(selected_idx) + 1) % matches.size()]
	_on_clue_selected(next_sel)


# ─────────────────────────────────────────────────────────────────────────────
# Answer Submission
# ─────────────────────────────────────────────────────────────────────────────

func _on_answer_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		_on_submit()
		answer_input.accept_event() # This swallows the Enter key! Godot's native unfocus won't run.

func _on_submit() -> void:
	if game_over:
		return
	if selected_idx < 0:
		feedback_label.text = "Click a clue or grid cell to select a word!"
		return
	if solved[selected_idx]:
		feedback_label.text = "Already solved!"
		return
	var p: Dictionary = placements[selected_idx]
	var ans: String = answer_input.text.strip_edges().to_upper()

	if ans == p["word"]:
		solved[selected_idx] = true
		score += 100
		feedback_label.text = "✅  Correct!  \"%s\"" % p["word"].to_lower().capitalize()
		_mark_clue_solved(selected_idx)
		grid_node.queue_redraw()
		_update_hud()

		answer_input.text = ""
		answer_input.grab_focus()

		if solved.all(func(s): return s):
			_end_game(true)
	else:
			# Count failed attempts for adaptive accuracy metrics.
		wrong_attempts += 1
		feedback_label.text = "❌  Wrong — try again!"

		answer_input.text = ""
		answer_input.grab_focus()
		answer_input.select_all()


	# Reveals partial letters for the selected word and applies penalty.
func _on_hint_pressed() -> void:
	if game_over:
		return
	if selected_idx < 0 or selected_idx >= placements.size():
		feedback_label.text = "Select a clue first to get a hint."
		answer_input.call_deferred("grab_focus")
		return
	if solved[selected_idx]:
		feedback_label.text = "That word is already solved."
		answer_input.call_deferred("grab_focus")
		return

	# Pass the index instead of the string so we can check the grid
	var hint_text := _build_hint(selected_idx)
	hints_used += 1
	score = maxi(0, score - HINT_PENALTY)
	feedback_label.text = "💡  Hint: %s" % hint_text
	_update_hud()
	answer_input.call_deferred("grab_focus")


func _on_skip_pressed() -> void:
	if game_over:
		return
	# End game as a loss with skip reason displayed
	_end_game(false, true)


func _mark_clue_solved(idx: int) -> void:
	var dir: int = placements[idx]["dir"]
	var list: VBoxContainer = across_items if dir == 0 else down_items
	var cnt  := 0
	for pi in range(placements.size()):
		if placements[pi]["dir"] == dir:
			if pi == idx:
				var btn := list.get_child(cnt)
				if btn:
					btn.disabled = true
					btn.modulate = Color(0.45, 1.0, 0.55, 1.0)
				return
			cnt += 1


# ─────────────────────────────────────────────────────────────────────────────
# Timer / HUD
# ─────────────────────────────────────────────────────────────────────────────

func _on_tick() -> void:
	time_remaining -= 1
	_update_hud()
	if time_remaining <= 0:
		_end_game(false)


func _update_hud() -> void:
	timer_label.text = "Time: %ds" % time_remaining
	score_label.text = "Score: %d"  % score


func _end_game(won: bool, skipped: bool = false) -> void:
	game_over = true
	game_timer.stop()
	submit_btn.disabled   = true
	answer_input.editable = false
	solved.fill(true)
	grid_node.queue_redraw()
	var dialog_title = ""
	var dialog_text = ""
	if won:
		feedback_label.text = "🎉  Excellent!  Crossword complete!  Final score: %d" % score
		dialog_title = "Victory!"
		dialog_text = "Excellent!\nCrossword complete!\nFinal score: %d\nAccuracy: %.1f%%" % [score, _calculate_accuracy()]
	elif skipped:
		feedback_label.text = "⏭️  Skipped!  Score: %d  (answers revealed)" % score
		dialog_title = "Skipped"
		dialog_text = "Skipped!\nFinal score: %d\nAccuracy: %.1f%%" % [score, _calculate_accuracy()]
	else:
		feedback_label.text = "⏰  Time's up!  Score: %d  (answers revealed)" % score
		dialog_title = "Time's up!"
		dialog_text = "Time's up!\nFinal score: %d\nAccuracy: %.1f%%" % [score, _calculate_accuracy()]
	_record_user_stats(won)
	# Save normalized performance before adaptive routing.
	_record_adaptive_performance()
	
	var end_modal = preload("res://Games/game_end_modal.tscn").instantiate()
	add_child(end_modal)
	end_modal.show_stats(dialog_title, dialog_text)
	end_modal.confirmed.connect(func():
		get_tree().change_scene_to_file(UserStats.get_scene_after_game("game3"))
	)


func _record_user_stats(won: bool) -> void:
	if stats_recorded:
		return
	stats_recorded = true

	var solved_count := 0
	for state in solved:
		if bool(state):
			solved_count += 1

	var question_count := placements.size()
	var elapsed = (TIME_LIMIT - maxi(0, time_remaining)) if won else TIME_LIMIT
	var avg_time_per_item := float(elapsed) / float(question_count)

	UserStats.game_stats["game3"]["questions_answered"] = question_count
	UserStats.game_stats["game3"]["questions_correct"] = solved_count
	UserStats.game_stats["game3"]["total_score"] = score
	UserStats.game_stats["game3"]["time_taken"] = elapsed
	UserStats.game_stats["game3"]["item_times"] = [avg_time_per_item]
	UserStats.game_stats["game3"]["puzzles_completed"] = solved_count
	UserStats.update_overall_stats()


func _calculate_accuracy() -> float:
	var solved_count := 0
	for state in solved:
		if bool(state):
			solved_count += 1
	var attempts := solved_count + wrong_attempts
	if attempts > 0:
		return (float(solved_count) / float(attempts)) * 100.0
	return 0.0


# Returns a masked hint with first/last + one random internal letter.
func _build_hint(idx: int) -> String:
	var p: Dictionary = placements[idx]
	var word: String = str(p["word"])

	# If the word is 3 letters or shorter, just reveal the whole thing
	if word.length() <= 3:
		return "%s (%d letters)" % [" ".join(word.split("")), word.length()]

	# 1. Identify which cells are already solved by other intersecting words
	var solved_cells := {}
	for pi in range(placements.size()):
		if solved[pi]:
			var sp: Dictionary = placements[pi]
			var sdr := 1 if sp["dir"] == 1 else 0
			var sdc := 1 if sp["dir"] == 0 else 0
			for i in range(sp["word"].length()):
				solved_cells[Vector2i(sp["row"] + sdr * i, sp["col"] + sdc * i)] = true

	# 2. Sort indices into 'unrevealed' and a general fallback pool
	var dr := 1 if p["dir"] == 1 else 0
	var dc := 1 if p["dir"] == 0 else 0
	var unrevealed_indices := []
	var fallback_indices := [] 

	for i in range(1, word.length()): # Start at 1 to skip the constant first letter
		if word[i] == " ":
			continue
			
		var key := Vector2i(p["row"] + dr * i, p["col"] + dc * i)
		if not solved_cells.has(key):
			unrevealed_indices.append(i)
		else:
			fallback_indices.append(i)

	# 3. Pick exactly 2 characters to reveal
	var chosen_reveals := []
	
	# Shuffle pools so the hints are random
	unrevealed_indices.shuffle()
	fallback_indices.shuffle()

	# Try to grab from the hidden letters first
	while chosen_reveals.size() < 2 and unrevealed_indices.size() > 0:
		chosen_reveals.append(unrevealed_indices.pop_back())

	# If there weren't enough hidden letters (due to intersections), grab from the fallback
	while chosen_reveals.size() < 2 and fallback_indices.size() > 0:
		chosen_reveals.append(fallback_indices.pop_back())

	# 4. Construct the hint string
	var tokens := []
	for i in range(word.length()):
		if i == 0 or chosen_reveals.has(i):
			tokens.append(word[i])
		elif word[i] == " ":
			tokens.append(" ") # Preserve any spaces between words
		else:
			tokens.append("_")

	return "%s (%d letters)" % [" ".join(tokens), word.length()]


# Converts crossword outcomes into fair adaptive metrics.
func _record_adaptive_performance() -> void:
	if adaptive_recorded:
		return
	adaptive_recorded = true

	var solved_count := 0
	for state in solved:
		if bool(state):
			solved_count += 1

	var attempts := solved_count + wrong_attempts
	var accuracy := 0.0
	if attempts > 0:
		accuracy = (float(solved_count) / float(attempts)) * 100.0

	var completion_ratio := 0.0
	if placements.size() > 0:
		completion_ratio = clampf(float(solved_count) / float(placements.size()), 0.0, 1.0)

	var elapsed := float(TIME_LIMIT - maxi(0, time_remaining))
	UserStats.record_adaptive_result("game3", float(score), accuracy, elapsed, completion_ratio)
