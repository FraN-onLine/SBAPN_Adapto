extends Control

signal login_successful
signal show_registration

@onready var username_edit = $Panel/VBoxContainer/UsernameEdit
@onready var password_edit = $Panel/VBoxContainer/PasswordEdit
@onready var feedback_label = $Panel/VBoxContainer/FeedbackLabel

# Color constants
const COLOR_ERROR = Color(0.749, 0.188, 0.188, 1)  # Red #BF3030
const COLOR_SUCCESS = Color(0.18, 0.616, 0.306, 1)  # Green #2E9D4E
const COLOR_DEFAULT = Color(0.0, 0.0, 0.0, 1)  # Black/dark gray

func _on_login_button_pressed():
	var username = username_edit.text.strip_edges()
	var password = password_edit.text.strip_edges()

	if username.is_empty() or password.is_empty():
		_display_feedback("Please enter username and password.", "error")
		return

	# TODO: Add database check here
	# For now, we'll just simulate a successful login
	if Database.check_user_credentials(username, password):
		Global.current_user = username
		Global.current_user_role = Database.get_user_role(username)
		_display_feedback("Login successful!", "success")
		login_successful.emit()
	else:
		_display_feedback("Invalid username or password.", "error")

func _on_register_button_pressed():
	show_registration.emit()

func _display_feedback(message: String, feedback_type: String = "default"):
	"""Display feedback message with color coding based on type.
	
	Args:
		message: The feedback message to display
		feedback_type: "error" (red), "success" (green), or "default" (black)
	"""
	feedback_label.text = message
	
	match feedback_type:
		"error":
			feedback_label.add_theme_color_override("font_color", COLOR_ERROR)
		"success":
			feedback_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		_:
			feedback_label.add_theme_color_override("font_color", COLOR_DEFAULT)

func clear_fields():
	username_edit.text = ""
	password_edit.text = ""
	feedback_label.text = ""
	feedback_label.add_theme_color_override("font_color", COLOR_DEFAULT)
