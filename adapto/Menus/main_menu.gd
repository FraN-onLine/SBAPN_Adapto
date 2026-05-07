## Main menu controller.
##
## Handles login/menu navigation, topic management, and entry points for
## diagnostic and adaptive game sessions.
extends TextureRect

const DEFAULT_ACCESS_ALL_SAVED_LESSONS := true
const ADMIN_USERNAMES := ["admin"]

var access_all_saved_lessons := DEFAULT_ACCESS_ALL_SAVED_LESSONS
var admin_all_lessons_toggle: CheckBox
var loading_dialog: AcceptDialog
var _generation_thread: Thread
var _generation_running := false
var _loading_base_text := ""
var _loading_tick := 0.0
var _generation_context := {}


func _on_start_button_pressed() -> void:
	$Control/VBoxContainer/Button.visible = false
	$Control/VBoxContainer/Button2.visible = false
	$Control/VBoxContainer/Button3.visible = false
	$Control/VBoxContainer/Button4.visible = true
	$Control/VBoxContainer/Button5.visible = true
	$Control/VBoxContainer/Back.visible = true


func on_diagnostic_button_pressed():
	# Allow diagnostic to be repeated any time
	UserStats.stop_adaptive_session()
	get_tree().change_scene_to_file(UserStats.get_scene_for_game("game1"))


func _on_adaptive_button_pressed() -> void:
	if not UserStats.has_completed_diagnostic():
		show_error_dialog("You must complete the diagnostic test (all games at least once) before accessing adaptive mode.")
		return
	# If allowed, start adaptive session and go to the best adaptive game.
	UserStats.start_adaptive_session()
	var leader = UserStats.get_leading_game()
	if leader == "":
		leader = "game1"
	get_tree().change_scene_to_file(UserStats.get_scene_for_game(leader))
	

func _show_main_menu_for_user():
		if Global.current_user != null and str(Global.current_user).strip_edges() != "":
			login_screen.visible = false
			register_screen.visible = false
			main_menu_control.visible = true
			_setup_admin_all_lessons_toggle()
			# Ensure all main menu buttons are visible
			var vbox = main_menu_control.get_node("VBoxContainer")
			for btn_name in ["Button", "Button2", "Button3"]:
				if vbox.has_node(btn_name):
					vbox.get_node(btn_name).visible = true
			_apply_instructor_visibility()
		else:
			login_screen.visible = true
			register_screen.visible = false
			main_menu_control.visible = false
		# Add stats button if not present
		$Control/VBoxContainer/Back.visible = false
		$ImportChoicePanel.visible = false
		$PromptImportPanel.visible = false
		$UserDataModal.visible = false


func _on_button_3_pressed() -> void:
	$Control/VBoxContainer/Button.visible = false
	$Control/VBoxContainer/Button2.visible = false
	$Control/VBoxContainer/Button3.visible = false
	$Control/VBoxContainer/TopicSelect.visible = true
	$Control/VBoxContainer/TopicImport.visible = true
	$Control/VBoxContainer/TopicExport.visible = true
	$Control/VBoxContainer/Back.visible = true
	
func _on_back_button_pressed():
	$Control/VBoxContainer/Button.visible = true
	$Control/VBoxContainer/Button2.visible = true
	$Control/VBoxContainer/Button3.visible = true
	$Control/VBoxContainer/TopicSelect.visible = false
	$Control/VBoxContainer/TopicImport.visible = false
	$Control/VBoxContainer/TopicExport.visible = false
	$Control/VBoxContainer/Back.visible = false
	$Control/VBoxContainer/Button4.visible = false
	$Control/VBoxContainer/Button5.visible = false
	$UserDataModal.visible = false
	
func _on_stats_button_pressed() -> void:
	if Global.current_user == null:
		show_error_dialog("Please log in first.")
		return

	# Refresh from persistence before opening the modal.
	UserStats.load_user_stats()
	_refresh_user_data_modal()
	$UserDataModal.visible = true


func _refresh_user_data_modal() -> void:
	var game_names = {
		"game1": "Multiple Choice",
		"game2": "Jeopardy",
		"game3": "Crossword",
		"game4": "Matching Game",
		"game5": "Hangman"
	}

	var username_text := str(Global.current_user)
	if username_text.strip_edges() == "":
		username_text = "Guest"
	$UserDataModal/ModalPanel/VBoxContainer/UsernameLabel.text = "User: " + username_text

	# Clear previous stats in GridContainer
	var stats_grid = $UserDataModal/ModalPanel/VBoxContainer/StatsPanel/VBox/ScrollContainer/StatsGrid
	for child in stats_grid.get_children():
		child.queue_free()

	for game_id in UserStats.GAME_SEQUENCE:
		var gname = game_names[game_id] if game_names.has(game_id) else game_id
		var avg_score = 0.0
		var avg_time = 0.0
		if UserStats.overall_stats.has(game_id):
			avg_score = UserStats.overall_stats[game_id].get("average_score", 0.0)
			avg_time = UserStats.overall_stats[game_id].get("average_time_per_play", 0.0)
		
		_add_stat_row(stats_grid, gname, str(int(round(avg_score))), str(int(round(avg_time))) + "s")

	var analysis = UserStats.get_diagnostic_analysis()
	var best = analysis.get("best_game", "")
	var worst = analysis.get("worst_game", "")
	var fastest = analysis.get("fastest_game", "")
	var slowest = analysis.get("slowest_game", "")
	var best_name = game_names[best] if game_names.has(best) else (str(best) if best != "" else "N/A")
	var worst_name = game_names[worst] if game_names.has(worst) else (str(worst) if worst != "" else "N/A")
	var fastest_name = game_names[fastest] if game_names.has(fastest) else (str(fastest) if fastest != "" else "N/A")
	var slowest_name = game_names[slowest] if game_names.has(slowest) else (str(slowest) if slowest != "" else "N/A")

	var vbox_analysis = $UserDataModal/ModalPanel/VBoxContainer/AnalysisBox/VBox
	vbox_analysis.get_node("BestLabel").text = "Best Game: " + best_name
	vbox_analysis.get_node("WorstLabel").text = "Worst Game: " + worst_name
	vbox_analysis.get_node("FastestLabel").text = "Fastest Game: " + fastest_name
	vbox_analysis.get_node("SlowestLabel").text = "Slowest Game: " + slowest_name
	vbox_analysis.get_node("DiagStatusLabel").text = "Diagnostic Completed: " + ("Yes" if UserStats.has_completed_diagnostic() else "No")


func _add_stat_row(grid: GridContainer, game: String, score: String, time: String) -> void:
	var label_game = Label.new()
	label_game.text = game
	label_game.custom_minimum_size = Vector2(200, 0)
	label_game.add_theme_font_override("font", load("res://Assets/Fonts/Silkscreen-Regular.ttf"))
	label_game.add_theme_font_size_override("font_size", 14)
	label_game.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	
	var label_score = Label.new()
	label_score.text = score
	label_score.custom_minimum_size = Vector2(100, 0)
	label_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_score.add_theme_font_override("font", load("res://Assets/Fonts/Silkscreen-Regular.ttf"))
	label_score.add_theme_font_size_override("font_size", 14)
	label_score.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	
	var label_time = Label.new()
	label_time.text = time
	label_time.custom_minimum_size = Vector2(100, 0)
	label_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_time.add_theme_font_override("font", load("res://Assets/Fonts/Silkscreen-Regular.ttf"))
	label_time.add_theme_font_size_override("font_size", 14)
	label_time.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	
	grid.add_child(label_game)
	grid.add_child(label_score)
	grid.add_child(label_time)


func _on_user_data_close_pressed() -> void:
	$UserDataModal.visible = false


func _on_topic_select_pressed() -> void:
	_populate_topic_list()
	$TopicSelectPanel.visible = true


func _on_topic_select_cancel_pressed() -> void:
	$TopicSelectPanel.visible = false


func _populate_topic_list() -> void:
	var vbox = $TopicSelectPanel/TopicBox/VBox/Scroll/TopicListVBox
	var current_label = $TopicSelectPanel/TopicBox/VBox/CurrentLabel

	# Update current selection label
	if Global.selected_lesson != null:
		current_label.text = "Current: " + Global.selected_lesson.lesson_title
	else:
		current_label.text = "No topic selected"

	# Clear old buttons
	for child in vbox.get_children():
		child.queue_free()

	# Scan lesson_files for every .tres file, one button per file
	var base_path = "res://Lessons/lesson_files"
	var dir = DirAccess.open(base_path)
	if dir == null:
		var lbl = Label.new()
		lbl.text = "No lesson files found."
		vbox.add_child(lbl)
		return

	var tres_paths: Array[String] = []
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var sub_dir = DirAccess.open(base_path + "/" + folder_name)
			if sub_dir:
				sub_dir.list_dir_begin()
				var file_name = sub_dir.get_next()
				while file_name != "":
					if file_name.ends_with(".tres"):
						var full = base_path + "/" + folder_name + "/" + file_name
						var fa = FileAccess.open(full, FileAccess.READ)
						if fa != null and fa.get_length() > 0:
							tres_paths.append(full)
					file_name = sub_dir.get_next()
				sub_dir.list_dir_end()
		folder_name = dir.get_next()
	dir.list_dir_end()

	_append_saved_lesson_paths_from_database(tres_paths)

	if tres_paths.is_empty():
		var lbl = Label.new()
		lbl.text = "No lesson files found."
		vbox.add_child(lbl)
		return

	for path in tres_paths:
		# Derive a display name from folder + file
		var parts = path.split("/")
		var folder_display = parts[-2]
		var file_display = parts[-1].get_basename().replace("_", " ").capitalize()
		var label_text = folder_display + "  –  " + file_display

		var btn = Button.new()
		btn.text = label_text
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_override("font", load("res://Assets/Fonts/Silkscreen-Regular.ttf"))
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
		btn.add_theme_stylebox_override("normal", SubResource_white_rounded())
		btn.set_text_alignment(HORIZONTAL_ALIGNMENT_LEFT)
		btn.pressed.connect(_on_topic_entry_selected.bind(path, label_text))
		vbox.add_child(btn)


func _append_saved_lesson_paths_from_database(tres_paths: Array[String]) -> void:
	if Global.current_user == null:
		return

	var saved_lessons = Database.load_user_lessons(Global.current_user, _can_access_all_saved_lessons())
	var known_paths := {}
	for existing_path in tres_paths:
		known_paths[existing_path] = true

	for entry in saved_lessons:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not entry.has("lesson_path"):
			continue
		var lesson_path = str(entry["lesson_path"])
		if lesson_path == "" or known_paths.has(lesson_path):
			continue
		var file_access = FileAccess.open(lesson_path, FileAccess.READ)
		if file_access != null and file_access.get_length() > 0:
			tres_paths.append(lesson_path)
			known_paths[lesson_path] = true


func SubResource_white_rounded() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 1)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.corner_radius_bottom_left = 12
	return sb


func _on_topic_entry_selected(path: String, _display_name: String) -> void:
	var lesson = load(path) as Lesson
	if lesson == null:
		show_error_dialog("Failed to load lesson:\n" + path)
		return
	Global.selected_lesson = lesson
	$TopicSelectPanel/TopicBox/VBox/CurrentLabel.text = "Current: " + lesson.lesson_title
	$TopicSelectPanel.visible = false
	show_success_dialog("Topic selected!\n" + lesson.lesson_title)


# ── Import Topic entry point ──────────────────────────────────────────────────

func _on_topic_import_pressed() -> void:
	#if not _is_current_user_instructor():
	#	show_error_dialog("Only instructors can import topics.")
	#	return
	$ImportChoicePanel.visible = true


func _on_import_choice_cancel_pressed() -> void:
	$ImportChoicePanel.visible = false


# ── Import by PDF ─────────────────────────────────────────────────────────────

func _on_import_by_pdf_pressed() -> void:
	$ImportChoicePanel.visible = false
	$PDFFileDialog.popup_centered_ratio(0.7)


func _on_pdf_file_selected(path: String) -> void:
	generate_lesson_from_pdf(path)


func generate_lesson_from_pdf(pdf_path: String) -> void:
	var project_path = ProjectSettings.globalize_path("res://")
	var script_path = project_path + "Lessons/generate_lesson.py"
	var args = [script_path, "--pdf", pdf_path]
	_start_python_generation_job(args, "Generating lesson from PDF...", "Lesson generated from PDF!\nFile: " + pdf_path.get_file(), "Failed to generate lesson from PDF.")


# ── Import by Prompt ──────────────────────────────────────────────────────────

func _on_import_by_prompt_pressed() -> void:
	$ImportChoicePanel.visible = false
	$PromptImportPanel/PromptBox/VBox/TopicInput.text = ""
	$PromptImportPanel/PromptBox/VBox/FolderInput.text = ""
	$PromptImportPanel/PromptBox/VBox/CountInput.value = 8
	$PromptImportPanel.visible = true


func _on_prompt_back_pressed() -> void:
	$PromptImportPanel.visible = false
	$ImportChoicePanel.visible = true


	

func _on_prompt_generate_pressed() -> void:
	var topic: String = $PromptImportPanel/PromptBox/VBox/TopicInput.text.strip_edges()
	var count: int = int($PromptImportPanel/PromptBox/VBox/CountInput.value)
	var folder: String = $PromptImportPanel/PromptBox/VBox/FolderInput.text.strip_edges()

	if topic == "":
		show_error_dialog("Please enter a topic name.")
		return

	if folder == "":
		folder = topic

	$PromptImportPanel.visible = false
	generate_lesson_with_python(topic, count, folder)


func generate_lesson_with_python(topic: String, count: int, folder: String) -> void:
	var project_path = ProjectSettings.globalize_path("res://")
	var script_path = project_path + "Lessons/generate_lesson.py"
	var args = [script_path, topic, str(count), folder]
	_start_python_generation_job(args, "Generating lesson by prompt...", "Lesson generated!\nTopic: " + topic + "\nQuestions: " + str(count), "Failed to generate lesson.")


# ── Manual Import/Export ──────────────────────────────────────────────────────

func _on_topic_export_pressed() -> void:
	#if not _is_current_user_instructor():
	#	show_error_dialog("Only instructors can export topics.")
	#	return
	if Global.selected_lesson == null:
		show_error_dialog("Please select a topic to export first.")
		return
	$TresExportDialog.popup_centered_ratio(0.7)

func _on_tres_export_file_selected(path: String) -> void:
	var lesson = Global.selected_lesson
	if lesson:
		var error = ResourceSaver.save(lesson, path)
		if error == OK:
			show_success_dialog("Lesson exported successfully to:\n" + path)
		else:
			show_error_dialog("Failed to export lesson.\nError code: " + str(error))

func _on_import_from_file_pressed() -> void:
	$ImportChoicePanel.visible = false
	$TresImportDialog.popup_centered_ratio(0.7)

func _on_tres_import_file_selected(path: String) -> void:
	var lesson = load(path) as Lesson
	if lesson:
		Global.selected_lesson = lesson
		if Global.current_user != null:
			Database.save_user_lesson(Global.current_user, {
				"lesson_title": lesson.lesson_title,
				"lesson_path": path,
				"item_count": lesson.lesson_items.size(),
				"saved_at": Time.get_unix_time_from_system()
			})
		_populate_topic_list()
		show_success_dialog("Lesson imported successfully!\n" + lesson.lesson_title)
	else:
		show_error_dialog("Failed to load lesson from file:\n" + path)


# ── Utility dialogs ───────────────────────────────────────────────────────────

func show_error_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.set_title("Error")
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func show_success_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.set_title("Success")
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


@onready var login_screen = $LoginScreen
@onready var register_screen = $RegisterScreen
@onready var main_menu_control = $Control

func _ready():
	if not login_screen.login_successful.is_connected(_on_login_successful):
		login_screen.login_successful.connect(_on_login_successful)
	if not login_screen.show_registration.is_connected(_on_show_registration):
		login_screen.show_registration.connect(_on_show_registration)
	if not register_screen.registration_successful.is_connected(_on_registration_successful):
		register_screen.registration_successful.connect(_on_registration_successful)
	if not register_screen.show_login.is_connected(_on_show_login):
		register_screen.show_login.connect(_on_show_login)

	if Global.current_user != null and str(Global.current_user).strip_edges() != "":
		UserStats.load_user_stats()
		login_screen.visible = false
		register_screen.visible = false
		main_menu_control.visible = true
		_setup_admin_all_lessons_toggle()
		_apply_instructor_visibility()
	else:
		login_screen.visible = true
		register_screen.visible = false
		main_menu_control.visible = false

	_show_main_menu_for_user()

func _on_login_successful():
	login_screen.visible = false
	UserStats.load_user_stats()
	main_menu_control.visible = true
	_setup_admin_all_lessons_toggle()
	_apply_instructor_visibility()

func _on_show_registration():
	login_screen.visible = false
	register_screen.visible = true
	register_screen.clear_fields()

func _on_registration_successful():
	register_screen.visible = false
	login_screen.visible = true
	login_screen.clear_fields()

func _on_show_login():
	register_screen.visible = false
	login_screen.visible = true
	login_screen.clear_fields()


func _is_current_user_admin() -> bool:
	if Global.current_user == null:
		return false
	return ADMIN_USERNAMES.has(str(Global.current_user).to_lower())


func _is_current_user_instructor() -> bool:
	if _is_current_user_admin():
		return true
	if Global.current_user == null:
		return false
	return str(Global.current_user_role).to_lower() == "instructor"


func _apply_instructor_visibility() -> void:
	if not main_menu_control or not main_menu_control.has_node("VBoxContainer"):
		return
	var vbox = main_menu_control.get_node("VBoxContainer")
	if vbox.has_node("Button3"):
		vbox.get_node("Button3").visible = true


func _can_access_all_saved_lessons() -> bool:
	return _is_current_user_admin() and access_all_saved_lessons


func _start_python_generation_job(args: Array, loading_text: String, success_text: String, error_prefix: String) -> void:
	if _generation_running:
		show_error_dialog("A lesson generation task is already running.")
		return

	_show_loading_dialog(loading_text)
	_generation_context = {
		"success_text": success_text,
		"error_prefix": error_prefix
	}
	_generation_thread = Thread.new()
	_generation_running = true
	set_process(true)

	var err := _generation_thread.start(_run_python_generation.bind(args))
	if err != OK:
		_generation_running = false
		set_process(false)
		_hide_loading_dialog()
		show_error_dialog("Unable to start background generation task. Error code: " + str(err))


func _run_python_generation(args: Array) -> Dictionary:
	var output: Array = []
	var code := OS.execute("python", args, output, true, false)
	return {
		"code": code,
		"output": output
	}


func _process(delta: float) -> void:
	if not _generation_running:
		return

	_loading_tick += delta
	if loading_dialog != null:
		var dots = ".".repeat((int(_loading_tick * 2.0) % 3) + 1)
		loading_dialog.dialog_text = _loading_base_text + "\nPlease wait" + dots

	if _generation_thread != null and not _generation_thread.is_alive():
		var result = _generation_thread.wait_to_finish()
		_generation_running = false
		set_process(false)
		_hide_loading_dialog()
		_handle_generation_result(result)


func _show_loading_dialog(message: String) -> void:
	if loading_dialog == null:
		loading_dialog = AcceptDialog.new()
		loading_dialog.title = "Working"
		loading_dialog.exclusive = true
		loading_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
		add_child(loading_dialog)

	_loading_base_text = message
	_loading_tick = 0.0
	loading_dialog.dialog_text = message + "\nPlease wait..."
	loading_dialog.get_ok_button().visible = false
	loading_dialog.popup_centered(Vector2i(500, 150))


func _hide_loading_dialog() -> void:
	if loading_dialog != null:
		loading_dialog.hide()


func _handle_generation_result(result) -> void:
	var data: Dictionary = {}
	if typeof(result) == TYPE_DICTIONARY:
		data = result

	var code := int(data.get("code", -1))
	var output = data.get("output", [])
	if code == 0:
		show_success_dialog(str(_generation_context.get("success_text", "Lesson generated successfully.")))
		return

	var error_msg := str(_generation_context.get("error_prefix", "Lesson generation failed."))
	error_msg += "\nError code: " + str(code)
	if typeof(output) == TYPE_ARRAY and output.size() > 0:
		error_msg += "\n" + str(output[0])
	show_error_dialog(error_msg)


# ========================= TEMP ADMIN TOGGLE START =========================
# Remove this whole block if you want to disable the production admin toggle.
func _setup_admin_all_lessons_toggle() -> void:
	if not _is_current_user_admin():
		access_all_saved_lessons = false
		if admin_all_lessons_toggle != null:
			admin_all_lessons_toggle.queue_free()
			admin_all_lessons_toggle = null
		return

	if admin_all_lessons_toggle == null:
		admin_all_lessons_toggle = CheckBox.new()
		admin_all_lessons_toggle.name = "AdminAllLessonsToggle"
		admin_all_lessons_toggle.text = "ADMIN: View all users' saved lessons"
		admin_all_lessons_toggle.position = Vector2(20, 20)
		admin_all_lessons_toggle.button_pressed = access_all_saved_lessons
		admin_all_lessons_toggle.z_index = 50
		main_menu_control.add_child(admin_all_lessons_toggle)
		admin_all_lessons_toggle.toggled.connect(_on_admin_all_lessons_toggled)

	admin_all_lessons_toggle.visible = true


func _on_admin_all_lessons_toggled(enabled: bool) -> void:
	access_all_saved_lessons = enabled
	if $TopicSelectPanel.visible:
		_populate_topic_list()
# ========================== TEMP ADMIN TOGGLE END ==========================
