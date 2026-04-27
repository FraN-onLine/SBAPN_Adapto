extends Control

signal registration_successful
signal show_login

@onready var username_edit = $Panel/VBoxContainer/UsernameEdit
@onready var password_edit = $Panel/VBoxContainer/PasswordEdit
@onready var confirm_password_edit = $Panel/VBoxContainer/ConfirmPasswordEdit
@onready var feedback_label = $Panel/VBoxContainer/FeedbackLabel

# Color constants
const COLOR_ERROR = Color(0.749, 0.188, 0.188, 1)  # Red #BF3030
const COLOR_SUCCESS = Color(0.18, 0.616, 0.306, 1)  # Green #2E9D4E
const COLOR_DEFAULT = Color(0.0, 0.0, 0.0, 1)  # Black/dark gray

func _on_register_button_pressed():
	var username = username_edit.text
	var password = password_edit.text
	var confirm_password = confirm_password_edit.text

	if username.is_empty() or password.is_empty():
		_display_feedback("Please fill in all fields.", "error")
		return

	if password != confirm_password:
		_display_feedback("Passwords do not match.", "error")
		return

	if Database.user_exists(username):
		_display_feedback("Username already exists.", "error")
		return

	var normalized_username = username.strip_edges().to_lower()
	var role := "student"
	if normalized_username.begins_with("inst_") or normalized_username.ends_with("_inst"):
		role = "instructor"

	if Database.add_user(username, password, role):
		_display_feedback("Registration successful!", "success")
		registration_successful.emit()
	else:
		_display_feedback("Registration failed.", "error")


func _on_back_button_pressed():
	show_login.emit()

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
	confirm_password_edit.text = ""
	feedback_label.text = ""
	feedback_label.add_theme_color_override("font_color", COLOR_DEFAULT)
