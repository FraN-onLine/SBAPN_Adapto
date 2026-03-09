extends Node2D

# ── Constants ────────────────────────────────────────────────────────────────
const MAX_GRID   := 13
const CELL_SIZE  := 42
const GRID_OX    := 18
const GRID_OY    := 18
const TIME_LIMIT := 180

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
@onready var grid_node      = $GridNode

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


func _ready() -> void:
	lesson = Global.selected_lesson if Global.selected_lesson != null \
		else load("res://Lessons/lesson_files/Object Oriented/oop.tres")

	for it in lesson.lesson_items:
		var t: String = it.term.strip_edges()
		# Only single-word terms that fit in the grid are valid for crossword
		if t.length() >= 3 and t.length() <= MAX_GRID and not " " in t:
			items.append(it)
	items.shuffle()
	items = items.slice(0, min(8, items.size()))

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
	answer_input.text_submitted.connect(func(_t): _on_submit())
	_update_hud()


# ─────────────────────────────────────────────────────────────────────────────
# Crossword Generation
# ─────────────────────────────────────────────────────────────────────────────

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
		if existing == "":
			if dir == 0:
				if _cell(r - 1, c) != "" and _cell(r - 1, c) != "#": return false
				if _cell(r + 1, c) != "" and _cell(r + 1, c) != "#": return false
			else:
				if _cell(r, c - 1) != "" and _cell(r, c - 1) != "#": return false
				if _cell(r, c + 1) != "" and _cell(r, c + 1) != "#": return false
		elif existing == letter:
			intersections += 1
		else:
			return false

	return intersections > 0 or placements.is_empty()


func _place_word(item, row: int, col: int, dir: int) -> void:
	var word: String = item.term.to_upper()
	var dr := 1 if dir == 1 else 0
	var dc := 1 if dir == 0 else 0
	for i in range(word.length()):
		grid[row + dr * i][col + dc * i] = word[i]
	placements.append({
		"word": word, "clue": item.definition,
		"row": row, "col": col, "dir": dir, "number": 0
	})


func _generate_crossword() -> void:
	_init_grid()
	if items.is_empty():
		return

	var sorted_items := items.duplicate()
	sorted_items.sort_custom(func(a, b): return a.term.length() > b.term.length())

	var w0: String = sorted_items[0].term.to_upper()
	if w0.length() > MAX_GRID:
		return
	var r0: int = int(MAX_GRID / 2.0)
	var c0: int = clampi(int((MAX_GRID - w0.length()) / 2.0), 0, MAX_GRID - int(w0.length()))
	_place_word(sorted_items[0], r0, c0, 0)

	for i in range(1, sorted_items.size()):
		_try_place_item(sorted_items[i])


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
		btn.text = "%d. %s" % [p["number"], p["clue"]]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 38)
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
	answer_input.grab_focus()
	grid_node.queue_redraw()


# ─────────────────────────────────────────────────────────────────────────────
# Grid Drawing
# ─────────────────────────────────────────────────────────────────────────────

func _draw_grid() -> void:
	var font := ThemeDB.fallback_font
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
				grid_node.draw_rect(rect, Color(0.06, 0.06, 0.09, 1.0))
			else:
				var bg := Color.WHITE
				if sel_cells.has(key):
					bg = Color(0.65, 0.85, 1.0, 1.0)
				grid_node.draw_rect(rect, bg)
				grid_node.draw_rect(rect, Color(0.35, 0.35, 0.42, 1.0), false, 1.5)
				if solved_cells.has(key):
					grid_node.draw_string(font,
						Vector2(x + 14, y + CELL_SIZE - 10),
						solved_cells[key],
						HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.BLACK)

	for p in placements:
		var x: int = GRID_OX + (p["col"] as int) * CELL_SIZE
		var y: int = GRID_OY + (p["row"] as int) * CELL_SIZE
		grid_node.draw_string(font, Vector2(x + 2, y + 11),
			str(p["number"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.15, 0.2, 1.0))


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
		if solved.all(func(s): return s):
			_end_game(true)
	else:
		feedback_label.text = "❌  Wrong — try again!"
		answer_input.text = ""


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


func _end_game(won: bool) -> void:
	game_over = true
	game_timer.stop()
	submit_btn.disabled   = true
	answer_input.editable = false
	solved.fill(true)
	grid_node.queue_redraw()
	if won:
		feedback_label.text = "🎉  Excellent!  Crossword complete!  Final score: %d" % score
	else:
		feedback_label.text = "⏰  Time's up!  Score: %d  (answers revealed)" % score
	await get_tree().create_timer(3.5).timeout
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")
