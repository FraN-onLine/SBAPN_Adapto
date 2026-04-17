extends Node

const USE_PROJECT_SAVE_PATH := true
const PROJECT_SAVE_PATH := "res://Database/user_data.json"
const USER_SAVE_PATH := "user://user_data.json"
var db = {}


func _get_save_path() -> String:
	if USE_PROJECT_SAVE_PATH:
		return PROJECT_SAVE_PATH
	return USER_SAVE_PATH

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


func _ensure_user_schema(username: String) -> bool:
	_ensure_schema()
	if not db["users"].has(username):
		return false

	var user_record = db["users"][username]
	if typeof(user_record) != TYPE_DICTIONARY:
		return false

	if not user_record.has("password") or typeof(user_record["password"]) != TYPE_STRING:
		user_record["password"] = ""
	if not user_record.has("performance") or typeof(user_record["performance"]) != TYPE_DICTIONARY:
		user_record["performance"] = {}
	if not user_record.has("saved_lessons") or typeof(user_record["saved_lessons"]) != TYPE_ARRAY:
		user_record["saved_lessons"] = []
	if not user_record.has("role") or typeof(user_record["role"]) != TYPE_STRING:
		user_record["role"] = "student"
	else:
		user_record["role"] = _normalize_role(str(user_record["role"]))

	db["users"][username] = user_record
	return true


func _normalize_role(role: String) -> String:
	var normalized := role.strip_edges().to_lower()
	if normalized in ["admin", "instructor", "student"]:
		return normalized
	return "student"

func _ready():
	load_db()

func load_db():
	var save_path := _get_save_path()
	var file = FileAccess.open(save_path, FileAccess.READ)
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
	_migrate_and_deduplicate_lessons()
	save_db()


func _lesson_dedupe_key(lesson_data: Dictionary) -> String:
	if lesson_data.has("lesson_path"):
		var lesson_path = str(lesson_data["lesson_path"]).strip_edges()
		if lesson_path != "":
			return "path:" + lesson_path

	return "payload:" + JSON.stringify(lesson_data, "")


func _migrate_and_deduplicate_lessons() -> void:
	_ensure_schema()

	var user_saved_map := {}
	for username in db["users"].keys():
		if not _ensure_user_schema(username):
			continue

		var unique_user_lessons := []
		var seen_user := {}
		for lesson in db["users"][username]["saved_lessons"]:
			if typeof(lesson) != TYPE_DICTIONARY:
				continue
			var dedupe_key = _lesson_dedupe_key(lesson)
			if seen_user.has(dedupe_key):
				continue
			seen_user[dedupe_key] = true
			unique_user_lessons.append(lesson)

		db["users"][username]["saved_lessons"] = unique_user_lessons
		user_saved_map[str(username)] = seen_user

	var unique_global := []
	var seen_global := {}
	for entry in db["global_saved_lessons"]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var username = str(entry.get("username", ""))
		var lesson = entry.get("lesson", null)
		if username == "" or typeof(lesson) != TYPE_DICTIONARY:
			continue

		var dedupe_key = _lesson_dedupe_key(lesson)
		var global_key = username + "|" + dedupe_key
		if seen_global.has(global_key):
			continue

		if user_saved_map.has(username) and not user_saved_map[username].has(dedupe_key):
			continue

		seen_global[global_key] = true
		unique_global.append(entry)

	db["global_saved_lessons"] = unique_global

func save_db():
	var save_path := _get_save_path()
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(db, "\t")
		file.store_string(json_string)
		file.close()

func user_exists(username):
	_ensure_schema()
	return db["users"].has(username)

func add_user(username, password, role := "student"):
	if user_exists(username):
		return false
	
	# Basic password hashing (replace with a more secure method in production)
	var hashed_password = password.sha256_text()
	
	db["users"][username] = {
		"password": hashed_password,
		"performance": {},
		"saved_lessons": [],
		"role": _normalize_role(str(role))
	}
	save_db()
	return true

func check_user_credentials(username, password):
	if not _ensure_user_schema(username):
		return false
	
	var hashed_password = password.sha256_text()
	return db["users"][username]["password"] == hashed_password

func save_user_performance(username, performance_data):
	if not _ensure_user_schema(username):
		return false

	if typeof(performance_data) != TYPE_DICTIONARY:
		performance_data = {}

	db["users"][username]["performance"] = performance_data
	save_db()
	return true

func load_user_performance(username):
	if not _ensure_user_schema(username):
		return null
	return db["users"][username]["performance"]


func get_user_role(username: String) -> String:
	if not _ensure_user_schema(username):
		return "student"
	return _normalize_role(str(db["users"][username].get("role", "student")))


func set_user_role(username: String, role: String) -> bool:
	if not _ensure_user_schema(username):
		return false
	db["users"][username]["role"] = _normalize_role(role)
	save_db()
	return true


func is_instructor(username: String) -> bool:
	var role := get_user_role(username)
	return role == "instructor" or role == "admin"

func save_user_lesson(username, lesson_data):
	if not _ensure_user_schema(username):
		return false

	if typeof(lesson_data) != TYPE_DICTIONARY:
		return false

	db["users"][username]["saved_lessons"].append(lesson_data)

	db["global_saved_lessons"].append({
		"username": username,
		"lesson": lesson_data,
		"saved_at": Time.get_unix_time_from_system()
	})

	save_db()
	return true

func load_user_lessons(username, include_all := false):
	if not _ensure_user_schema(username):
		return []

	var user_lessons = []
	if typeof(db["users"][username]["saved_lessons"]) == TYPE_ARRAY:
		user_lessons = db["users"][username]["saved_lessons"].duplicate(true)

	if include_all:
		var known_paths := {}
		for lesson in user_lessons:
			if typeof(lesson) == TYPE_DICTIONARY and lesson.has("lesson_path"):
				known_paths[str(lesson["lesson_path"])] = true

		for entry in load_all_lessons():
			if typeof(entry) == TYPE_DICTIONARY and entry.has("lesson"):
				var lesson = entry["lesson"]
				if typeof(lesson) != TYPE_DICTIONARY or not lesson.has("lesson_path"):
					user_lessons.append(lesson)
					continue

				var lesson_path = str(lesson["lesson_path"])
				if known_paths.has(lesson_path):
					continue
				known_paths[lesson_path] = true
				user_lessons.append(lesson)

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
	if not _ensure_user_schema(username):
		return false

	db["users"][username]["saved_lessons"] = lessons.duplicate(true)

	var refreshed_global := []
	for entry in db["global_saved_lessons"]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("username", "")) == str(username):
			continue
		refreshed_global.append(entry)

	for lesson in lessons:
		if typeof(lesson) != TYPE_DICTIONARY:
			continue
		refreshed_global.append({
			"username": username,
			"lesson": lesson,
			"saved_at": lesson.get("saved_at", Time.get_unix_time_from_system())
		})

	db["global_saved_lessons"] = refreshed_global
	save_db()
	return true
