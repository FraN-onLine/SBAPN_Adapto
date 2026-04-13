extends Control

signal login_successful
signal show_registration

@onready var username_edit = $Panel/VBoxContainer/UsernameEdit
@onready var password_edit = $Panel/VBoxContainer/PasswordEdit
@onready var feedback_label = $Panel/VBoxContainer/FeedbackLabel

func _on_login_button_pressed():
	var username = username_edit.text.strip_edges()
	var password = password_edit.text.strip_edges()

	if username.is_empty() or password.is_empty():
		feedback_label.text = "Please enter username and password."
		return

	# TODO: Add database check here
	# For now, we'll just simulate a successful login
	if Database.check_user_credentials(username, password):
		Global.current_user = username
		Global.current_user_role = Database.get_user_role(username)
		login_successful.emit()
	else:
		feedback_label.text = "Invalid username or password."

func _on_register_button_pressed():
	show_registration.emit()

func clear_fields():
	username_edit.text = ""
	password_edit.text = ""
	feedback_label.text = ""
