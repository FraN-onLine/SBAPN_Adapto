extends TextureRect


func _on_start_button_pressed() -> void:
	$Control/VBoxContainer/Button.visible = false
	$Control/VBoxContainer/Button2.visible = false
	$Control/VBoxContainer/Button3.visible = false
	$Control/VBoxContainer/Button4.visible = true
	$Control/VBoxContainer/Button5.visible = true
	$Control/VBoxContainer/Back.visible = true


func on_diagnostic_button_pressed():
	get_tree().change_scene_to_file("res://Games/game1.tscn")


func _on_button_2_pressed() -> void:
	$Control/VBoxContainer/Button.visible = false
	$Control/VBoxContainer/Button2.visible = false
	$Control/VBoxContainer/Button3.visible = false
	$Control/VBoxContainer/TopicSelect.visible = true
	$Control/VBoxContainer/TopicImport.visible = true
	$Control/VBoxContainer/Back.visible = true


func _on_back_pressed() -> void:
	$Control/VBoxContainer/Button.visible = true
	$Control/VBoxContainer/Button2.visible = true
	$Control/VBoxContainer/Button3.visible = true
	$Control/VBoxContainer/Button4.visible = false
	$Control/VBoxContainer/Button5.visible = false
	$Control/VBoxContainer/TopicSelect.visible = false
	$Control/VBoxContainer/TopicImport.visible = false
	$Control/VBoxContainer/Back.visible = false
	$ImportChoicePanel.visible = false
	$PromptImportPanel.visible = false


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
		btn.pressed.connect(_on_topic_entry_selected.bind(path, label_text))
		vbox.add_child(btn)


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
	var output = []
	var result = OS.execute("python", args, output, true, true)
	if result == 0:
		show_success_dialog("Lesson generated from PDF!\nFile: " + pdf_path.get_file())
	else:
		var error_msg = "Failed to generate lesson from PDF.\nError code: " + str(result)
		if output.size() > 0:
			error_msg += "\n" + str(output[0])
		show_error_dialog(error_msg)


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
	var output = []
	var result = OS.execute("python", args, output, true, true)
	if result == 0:
		show_success_dialog("Lesson generated!\nTopic: " + topic + "\nQuestions: " + str(count))
	else:
		var error_msg = "Failed to generate lesson.\nError code: " + str(result)
		if output.size() > 0:
			error_msg += "\n" + str(output[0])
		show_error_dialog(error_msg)


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
