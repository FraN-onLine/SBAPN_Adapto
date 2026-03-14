extends Control

signal registration_successful
signal show_login

@onready var username_edit = $Panel/VBoxContainer/UsernameEdit
@onready var password_edit = $Panel/VBoxContainer/PasswordEdit
@onready var confirm_password_edit = $Panel/VBoxContainer/ConfirmPasswordEdit
@onready var feedback_label = $Panel/VBoxContainer/FeedbackLabel

func _on_register_button_pressed():
	var username = username_edit.text
	var password = password_edit.text
	var confirm_password = confirm_password_edit.text

	if username.is_empty() or password.is_empty():
		feedback_label.text = "Please fill in all fields."
		return

	if password != confirm_password:
		feedback_label.text = "Passwords do not match."
		return

	if Database.user_exists(username):
		feedback_label.text = "Username already exists."
		return

	if Database.add_user(username, password):
		feedback_label.text = "Registration successful!"
		emit_signal("registration_successful")
	else:
		feedback_label.text = "Registration failed."


func _on_back_button_pressed():
	emit_signal("show_login")

func clear_fields():
	username_edit.text = ""
	password_edit.text = ""
	confirm_password_edit.text = ""
	feedback_label.text = ""
