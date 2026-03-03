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


func _on_topic_select_pressed() -> void:
	$ColorRect.visible = true


func _on_topic_import_pressed() -> void:
	# Show the topic import dialog
	show_topic_import_dialog()


func show_topic_import_dialog():
	# Create a simple input dialog for topic generation
	var dialog = AcceptDialog.new()
	dialog.set_title("Generate New Topic")
	dialog.set_size(Vector2(400, 300))
	
	# Create container for inputs
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	# Topic name input
	var topic_label = Label.new()
	topic_label.text = "Topic Name:"
	vbox.add_child(topic_label)
	
	var topic_input = LineEdit.new()
	topic_input.placeholder_text = "e.g., Machine Learning"
	vbox.add_child(topic_input)
	
	# Question count input
	var count_label = Label.new()
	count_label.text = "Number of Questions:"
	vbox.add_child(count_label)
	
	var count_input = SpinBox.new()
	count_input.min_value = 1
	count_input.max_value = 50
	count_input.value = 8
	vbox.add_child(count_input)
	
	# Folder name input
	var folder_label = Label.new()
	folder_label.text = "Folder Name (optional):"
	vbox.add_child(folder_label)
	
	var folder_input = LineEdit.new()
	folder_input.placeholder_text = "Leave empty to use topic name"
	vbox.add_child(folder_input)
	
	# Generate button
	var generate_btn = Button.new()
	generate_btn.text = "Generate Lesson"
	vbox.add_child(generate_btn)
	
	# Connect button to generation function
	generate_btn.pressed.connect(_on_generate_lesson_pressed.bind(topic_input, count_input, folder_input, dialog))
	
	# Add dialog to scene and show it
	add_child(dialog)
	dialog.popup_centered()


func _on_generate_lesson_pressed(topic_input: LineEdit, count_input: SpinBox, folder_input: LineEdit, dialog: AcceptDialog):
	var topic = topic_input.text.strip_edges()
	var count = int(count_input.value)
	var folder = folder_input.text.strip_edges()
	
	if topic == "":
		show_error_dialog("Please enter a topic name.")
		return
	
	# Use topic name as folder if folder is empty
	if folder == "":
		folder = topic
	
	# Close the dialog
	dialog.queue_free()
	
	# Execute the Python script
	generate_lesson_with_python(topic, count, folder)


func generate_lesson_with_python(topic: String, count: int, folder: String):
	# Show loading message
	show_info_dialog("Generating lesson...")
	
	# Get the path to the python script
	var script_path = "res://Lessons/generate_lesson.py"
	var project_path = ProjectSettings.globalize_path("res://")
	var full_script_path = project_path + "adapto/Lessons/generate_lesson.py"
	
	# Prepare the command arguments
	var args = [full_script_path, topic, str(count), folder]
	
	# Execute the Python script
	var output = []
	var result = OS.execute("python", args, output, true, true)
	
	if result == 0:
		show_success_dialog("Lesson generated successfully!\nTopic: " + topic + "\nQuestions: " + str(count))
	else:
		var error_msg = "Failed to generate lesson.\nError code: " + str(result)
		if output.size() > 0:
			error_msg += "\nOutput: " + str(output)
		show_error_dialog(error_msg)


func show_error_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.set_title("Error")
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func show_success_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.set_title("Success")
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func show_info_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.set_title("Info")
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
