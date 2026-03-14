extends Node

const SAVE_PATH = "user://user_data.json"
var db = {}

func _default_db() -> Dictionary:
	return {
		"users": {},
		"global_saved_lessons": []
	}


func _ensure_schema() -> void:
	if typeof(db) != TYPE_DICTIONARY:
		db = _default_db()
		return

	if not db.has("users") or typeof(db["users"]) != TYPE_DICTIONARY:
		db["users"] = {}

	if not db.has("global_saved_lessons") or typeof(db["global_saved_lessons"]) != TYPE_ARRAY:
		db["global_saved_lessons"] = []

func _ready():
	load_db()

func load_db():
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.parse_string(content)
		if typeof(json) == TYPE_DICTIONARY:
			db = json
		else:
			db = _default_db()
		file.close()
	else:
		db = _default_db()

	_ensure_schema()
	save_db()

func save_db():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(db, "\t")
		file.store_string(json_string)
		file.close()

func user_exists(username):
	_ensure_schema()
	return db["users"].has(username)

func add_user(username, password):
	if user_exists(username):
		return false
	
	# Basic password hashing (replace with a more secure method in production)
	var hashed_password = password.sha256_text()
	
	db["users"][username] = {
		"password": hashed_password,
		"performance": {},
		"saved_lessons": []
	}
	save_db()
	return true

func check_user_credentials(username, password):
	if not user_exists(username):
		return false
	
	var hashed_password = password.sha256_text()
	return db["users"][username].password == hashed_password

func save_user_performance(username, performance_data):
	if user_exists(username):
		db["users"][username].performance = performance_data
		save_db()
		return true
	return false

func load_user_performance(username):
	if user_exists(username):
		return db["users"][username].performance
	return null

func save_user_lesson(username, lesson_data):
	if user_exists(username):
		if not db["users"][username].has("saved_lessons"):
			db["users"][username].saved_lessons = []

		db["users"][username].saved_lessons.append(lesson_data)

		db["global_saved_lessons"].append({
			"username": username,
			"lesson": lesson_data,
			"saved_at": Time.get_unix_time_from_system()
		})

		save_db()
		return true
	return false

func load_user_lessons(username, include_all := false):
	if not user_exists(username):
		return []

	var user_lessons = []
	if db["users"][username].has("saved_lessons") and typeof(db["users"][username].saved_lessons) == TYPE_ARRAY:
		user_lessons = db["users"][username].saved_lessons.duplicate(true)

	if include_all:
		for entry in load_all_lessons():
			if typeof(entry) == TYPE_DICTIONARY and entry.has("lesson"):
				user_lessons.append(entry["lesson"])

	return user_lessons


func load_all_lessons():
	_ensure_schema()
	return db["global_saved_lessons"].duplicate(true)


func load_all_lessons_grouped_by_user() -> Dictionary:
	_ensure_schema()
	var grouped := {}
	for entry in db["global_saved_lessons"]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not entry.has("username") or not entry.has("lesson"):
			continue
		var username = entry["username"]
		if not grouped.has(username):
			grouped[username] = []
		grouped[username].append(entry["lesson"])
	return grouped


func replace_user_lessons(username, lessons: Array) -> bool:
	if not user_exists(username):
		return false

	db["users"][username].saved_lessons = lessons.duplicate(true)
	save_db()
	return true
