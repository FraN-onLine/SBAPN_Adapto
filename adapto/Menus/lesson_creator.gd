extends Control

const QUESTION_ENTRY_SCENE := preload("res://Menus/question_entry.tscn")

@onready var lesson_title_edit: LineEdit = $Panel/VBoxContainer/HBoxContainer/LessonTitleEdit
@onready var questions_vbox: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/QuestionsVBox
@onready var file_dialog: FileDialog = $FileDialog


func _ready() -> void:
	if questions_vbox.get_child_count() == 0:
		_on_add_question_button_pressed()
	file_dialog.current_dir = "res://Lessons/lesson_files"


func _on_add_question_button_pressed() -> void:
	var entry = QUESTION_ENTRY_SCENE.instantiate()
	entry.remove_requested.connect(_on_question_remove_requested)
	questions_vbox.add_child(entry)


func _on_question_remove_requested(entry: Node) -> void:
	entry.queue_free()
	await get_tree().process_frame
	if questions_vbox.get_child_count() == 0:
		_on_add_question_button_pressed()


func _on_save_button_pressed() -> void:
	var title := lesson_title_edit.text.strip_edges()
	if title == "":
		show_error_dialog("Please enter a lesson title.")
		return

	if _count_valid_entries() == 0:
		show_error_dialog("Add at least one lesson item with a term.")
		return

	file_dialog.current_file = _slug(title) + ".tres"
	file_dialog.popup_centered_ratio(0.7)


func _on_file_dialog_file_selected(path: String) -> void:
	var lesson := _build_lesson()
	if lesson == null:
		return

	var save_path := path
	if not save_path.ends_with(".tres"):
		save_path += ".tres"

	_ensure_directory_exists(save_path.get_base_dir())

	var err := ResourceSaver.save(lesson, save_path)
	if err == OK:
		if Global.current_user != null:
			Database.save_user_lesson(Global.current_user, _serialize_lesson_metadata(lesson, save_path))
		show_success_dialog("Lesson saved successfully:\n" + save_path)
		Global.selected_lesson = lesson
	else:
		show_error_dialog("Failed to save lesson.\nError code: " + str(err))


func _serialize_lesson_metadata(lesson: Lesson, save_path: String) -> Dictionary:
	return {
		"lesson_title": lesson.lesson_title,
		"lesson_path": save_path,
		"item_count": lesson.lesson_items.size(),
		"saved_at": Time.get_unix_time_from_system()
	}


func _build_lesson() -> Lesson:
	var title := lesson_title_edit.text.strip_edges()
	if title == "":
		show_error_dialog("Lesson title is required.")
		return null

	var items: Array[LessonItem] = []
	for child in questions_vbox.get_children():
		if child.has_method("to_lesson_item"):
			var item: LessonItem = child.to_lesson_item(items.size() + 1, title)
			if item != null:
				items.append(item)

	if items.is_empty():
		show_error_dialog("No valid lesson items to save.")
		return null

	var lesson := Lesson.new()
	lesson.lesson_title = title
	lesson.lesson_items = items
	return lesson


func _count_valid_entries() -> int:
	var count := 0
	for child in questions_vbox.get_children():
		if child.has_method("to_lesson_item"):
			var candidate: LessonItem = child.to_lesson_item(1, "tmp")
			if candidate != null:
				count += 1
	return count


func _ensure_directory_exists(dir_path: String) -> void:
	if dir_path == "":
		return
	if dir_path.begins_with("res://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	elif dir_path.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	else:
		DirAccess.make_dir_recursive_absolute(dir_path)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")


func show_error_dialog(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func show_success_dialog(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Success"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func _slug(value: String) -> String:
	var output := ""
	for ch in value.to_lower():
		if ch.is_valid_identifier() and ch != "_":
			output += ch
		elif ch == " ":
			output += "_"
	output = output.strip_edges()
	if output == "":
		return "lesson"
	return output
