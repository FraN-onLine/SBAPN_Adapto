
# Returns the game_id with the highest diagnostic score for the current user.

## User stats and adaptive game flow manager.
##
## Responsibilities:
## - Stores per-game and overall diagnostic statistics.
## - Computes fair, normalized efficiency scores across different games.
## - Runs an adaptive flow that starts with a scaled diagnostic pass and then
##   prioritizes the game where the learner is currently most efficient.
extends Node

const GAME_SEQUENCE: Array[String] = ["game1", "game2", "game3", "game4", "game5"]
const GAME_SCENES := {
	"game1": "res://Games/game1.tscn",
	"game2": "res://Games/game2.tscn",
	"game3": "res://Games/game3.tscn",
	"game4": "res://Games/game4.tscn",
	"game5": "res://Games/game5.tscn"
}

const SCORE_REFERENCE := {
	"game1": 500.0,
	"game2": 2700.0,
	"game3": 800.0,
	"game4": 1200.0,
	"game5": 1400.0
}
const TIME_REFERENCE := {
	"game1": 150.0,
	"game2": 180.0,
	"game3": 180.0,
	"game4": 120.0,
	"game5": 150.0
}
const ADAPTIVE_HISTORY_LIMIT := 6


func _default_adaptive_history() -> Dictionary:
	return {
		"game1": [],
		"game2": [],
		"game3": [],
		"game4": [],
		"game5": []
	}

# Returns true if the current user has completed at least one full diagnostic round (all games played at least once)
func has_completed_diagnostic() -> bool:
	if Global.current_user == null:
		return false
	return diagnostic_runs_completed >= 1


func should_prompt_adaptive_first() -> bool:
	return has_completed_diagnostic() and not adaptive_started_once


func get_best_diagnostic_game() -> String:
	# For each game, check overall_stats[game]["highest_score"]
	var best_game = ""
	var best_score = -INF
	for game_id in GAME_SEQUENCE:
		if overall_stats.has(game_id) and overall_stats[game_id].has("highest_score"):
			var score = overall_stats[game_id]["highest_score"]
			if score > best_score:
				best_score = score
				best_game = game_id
	return best_game
	
var adaptive_mode_active := false
var adaptive_phase: String = "none" # none | adaptive
var adaptive_history := _default_adaptive_history()
var adaptive_last_ranked: Array[String] = []
# Tracks the current leader game during adaptive phase
var adaptive_current_leader: String = ""
var diagnostic_runs_completed := 0
var adaptive_started_once := false

var player_stats = {
	"typing": {"accuracy": 0, "time": 0},
}

var game_stats = {
	"game1" : {
		"type": ["keyword", "simple_terms", "definition", "tof"],
		"correct": [0, 0, 0, 0],
		"incorrect": [0, 0, 0, 0],
		"timeout": [0, 0, 0, 0],
		"accuracy": [0, 0, 0, 0],
		"sum_time": [0, 0, 0, 0],
		"questions": [0, 0, 0, 0],
		"item_times": [[], [], [], []], # track time per item per type
	},
	"game2": {
		"questions_answered": 0,
		"questions_correct": 0,
		"total_score": 0,
		"time_taken": 0,
		"item_times": [], # track time per item
	},
	"game3" : {
		"questions_answered": 0,
		"questions_correct": 0,
		"total_score": 0,
		"time_taken": 0,
		"item_times": [],
		"puzzles_completed": 0,
	},
	"game4": {
		"questions_answered": 0,
		"questions_correct": 0,
		"total_score": 0,
		"time_taken": 0,
		"item_times": [],
	},
	"game5": {
		"questions_answered": 0,
		"questions_correct": 0,
		"total_score": 0,
		"time_taken": 0,
		"item_times": [],
	}
}

var overall_stats = {
	"game1" : {
		"type": ["keyword", "simple_terms", "definition", "tof"],
		"correct": [0, 0, 0, 0],
		"incorrect": [0, 0, 0, 0],
		"timeout": [0, 0, 0, 0],
		"accuracy": [0, 0, 0, 0],
		"total_sum_time": [0, 0, 0, 0],
		"total_questions": [0, 0, 0, 0],
		"average_score": 0.0,
	},
	"game2": {
		"total_questions_answered": 0,
		"total_questions_correct": 0,
		"average_score": 0.0,
		"total_time": 0,
		"accuracy": 0.0,
	},
	"game3" : {
		"total_questions_answered": 0,
		"total_questions_correct": 0,
		"average_score": 0.0,
		"total_time": 0,
		"total_puzzles_completed": 0,
		"accuracy": 0.0,
	},
	"game4": {
		"total_questions_answered": 0,
		"total_questions_correct": 0,
		"average_score": 0.0,
		"total_time": 0,
		"accuracy": 0.0,
	},
	"game5": {
		"total_questions_answered": 0,
		"total_questions_correct": 0,
		"average_score": 0.0,
		"total_time": 0,
		"accuracy": 0.0,
	}
}

# Save user stats to database
func save_user_stats():
	if Global.current_user != null:
		var perf = Database.load_user_performance(Global.current_user)
		if typeof(perf) != TYPE_DICTIONARY:
			perf = {}
		perf["overall_stats"] = overall_stats.duplicate(true)
		perf["game_stats"] = game_stats.duplicate(true)
		perf["adaptive_history"] = adaptive_history.duplicate(true)
		perf["diagnostic_runs_completed"] = diagnostic_runs_completed
		perf["adaptive_started_once"] = adaptive_started_once
		Database.save_user_performance(Global.current_user, perf)

# Load user stats from database
func load_user_stats():
	if Global.current_user != null:
		var perf = Database.load_user_performance(Global.current_user)
		if perf != null and typeof(perf) == TYPE_DICTIONARY:
			if perf.has("overall_stats"):
				overall_stats = perf["overall_stats"]
			if perf.has("game_stats"):
				game_stats = perf["game_stats"]
			if perf.has("adaptive_history"):
				adaptive_history = perf["adaptive_history"]
			if perf.has("diagnostic_runs_completed"):
				diagnostic_runs_completed = int(perf["diagnostic_runs_completed"])
			if perf.has("adaptive_started_once"):
				adaptive_started_once = bool(perf["adaptive_started_once"])

	for game_id in GAME_SEQUENCE:
		if not adaptive_history.has(game_id) or typeof(adaptive_history[game_id]) != TYPE_ARRAY:
			adaptive_history[game_id] = []

	# Backward-compat migration: infer unlock for older saves that already completed diagnostics.
	if diagnostic_runs_completed <= 0 and _legacy_has_completed_diagnostic_stats():
		diagnostic_runs_completed = 1


# Starts a fresh adaptive run and clears rolling efficiency history.
func start_adaptive_session() -> void:
	# Only allow adaptive if diagnostic is completed
	if not has_completed_diagnostic():
		adaptive_mode_active = false
		adaptive_phase = "none"
		adaptive_current_leader = ""
		return
	adaptive_mode_active = true
	adaptive_phase = "adaptive"
	adaptive_last_ranked = []
	adaptive_current_leader = get_leading_game()
	adaptive_started_once = true
	save_user_stats()
# Returns average score for each game for the current user
func get_average_scores_per_game() -> Dictionary:
	var result = {}
	for game_id in GAME_SEQUENCE:
		if overall_stats.has(game_id) and overall_stats[game_id].has("average_score"):
			result[game_id] = overall_stats[game_id]["average_score"]
		else:
			result[game_id] = 0.0
	return result


# Ends adaptive mode and returns routing to default game order.
func stop_adaptive_session() -> void:
	adaptive_mode_active = false
	adaptive_phase = "none"
	adaptive_current_leader = ""
	save_user_stats()


# Resolves a game id to its scene path.
func get_scene_for_game(game_id: String) -> String:
	if GAME_SCENES.has(game_id):
		return str(GAME_SCENES[game_id])
	return str(GAME_SCENES["game1"])



# Chooses the next scene using default order or adaptive ranking.
func get_scene_after_game(current_game_id: String) -> String:
	if not adaptive_mode_active:
		if current_game_id == "game5":
			mark_diagnostic_completed()
		return _get_default_scene_after_game(current_game_id)

	# Adaptive phase: alternate between top 1 and top 2
	if adaptive_phase == "adaptive":
		var ranked = get_adaptive_ranked_games()
		if ranked.size() < 2:
			adaptive_current_leader = ranked[0] if ranked.size() > 0 else "game1"
		else:
			var idx = 0
			if adaptive_current_leader == ranked[0]:
				idx = 1
			adaptive_current_leader = ranked[idx]
		if adaptive_current_leader == "":
			adaptive_current_leader = "game1"
		return get_scene_for_game(adaptive_current_leader)

	return get_scene_for_game("game1")
# Returns a dictionary with analysis: best, worst, fastest, slowest game, and average times
func get_diagnostic_analysis() -> Dictionary:
	# Use normalized average score for best/worst game, not highest_score
	var result = {
		"best_game": "",
		"worst_game": "",
		"fastest_game": "",
		"slowest_game": "",
		"average_times": {},
		"average_scores": {},
	}
	var best_score = -1.0
	var worst_score = 9999.0
	var fastest_time = 999999.0
	var slowest_time = -1.0
	for game_id in GAME_SEQUENCE:
		var avg_score = 0.0
		var avg_time = 0.0
		if overall_stats.has(game_id):
			avg_score = overall_stats[game_id].get("average_score", 0.0)
			avg_time = overall_stats[game_id].get("average_time_per_item", 0.0)
		result["average_scores"][game_id] = avg_score
		result["average_times"][game_id] = avg_time
		if avg_score > best_score:
			best_score = avg_score
			result["best_game"] = game_id
		if avg_score < worst_score:
			worst_score = avg_score
			result["worst_game"] = game_id
		if avg_time < fastest_time:
			fastest_time = avg_time
			result["fastest_game"] = game_id
		if avg_time > slowest_time:
			slowest_time = avg_time
			result["slowest_game"] = game_id
	return result




# Stores normalized performance in rolling history per game.
func record_adaptive_result(
	game_id: String,
	raw_score: float,
	accuracy_percent: float,
	time_spent_sec: float,
	completion_ratio: float
) -> float:
	if not adaptive_history.has(game_id):
		return 0.0

	var fair_score := compute_fair_score(game_id, raw_score, accuracy_percent, time_spent_sec, completion_ratio)
	var game_history: Array = adaptive_history[game_id]
	game_history.append(fair_score)
	while game_history.size() > ADAPTIVE_HISTORY_LIMIT:
		game_history.remove_at(0)
	adaptive_history[game_id] = game_history

	_update_adaptive_ranking()
	save_user_stats()
	return fair_score


# Computes a fair cross-game efficiency score (0..100).
func compute_fair_score(
	game_id: String,
	raw_score: float,
	accuracy_percent: float,
	time_spent_sec: float,
	completion_ratio: float
) -> float:
	var ref_score := float(SCORE_REFERENCE.get(game_id, 1000.0))
	var ref_time := float(TIME_REFERENCE.get(game_id, 150.0))

	var score_component := clampf(_safe_ratio(raw_score, ref_score), 0.0, 1.0)
	var accuracy_component := clampf(_safe_ratio(accuracy_percent, 100.0), 0.0, 1.0)
	var speed_component := clampf(1.0 - _safe_ratio(time_spent_sec, ref_time), 0.0, 1.0)
	var completion_component := clampf(completion_ratio, 0.0, 1.0)

	# Weighted fairness model: emphasizes accuracy and completion over raw points.
	return (
		(accuracy_component * 0.45)
		+ (completion_component * 0.30)
		+ (speed_component * 0.15)
		+ (score_component * 0.10)
	) * 100.0


# Returns the current top-ranked game by average efficiency.
func get_leading_game() -> String:
	_update_adaptive_ranking()
	if adaptive_last_ranked.is_empty():
		return ""
	return adaptive_last_ranked[0]


# Returns all games sorted by adaptive efficiency.
func get_adaptive_ranked_games() -> Array[String]:
	_update_adaptive_ranking()
	return adaptive_last_ranked.duplicate()

# Reset stats for a specific game. If game_id is empty, reset all games.
func reset_game_stats(game_id: String = "") -> void:
	if game_id == "":
		# Reset all games
		game_stats["game1"] = {
			"type": ["keyword", "simple_terms", "definition", "tof"],
			"correct": [0, 0, 0, 0],
			"incorrect": [0, 0, 0, 0],
			"timeout": [0, 0, 0, 0],
			"accuracy": [0, 0, 0, 0],
			"sum_time": [0, 0, 0, 0],
			"questions": [0, 0, 0, 0],
			"item_times": [[], [], [], []],
		}
		game_stats["game2"] = {
			"questions_answered": 0,
			"questions_correct": 0,
			"total_score": 0,
			"time_taken": 0,
			"item_times": [],
		}
		game_stats["game3"] = {
			"questions_answered": 0,
			"questions_correct": 0,
			"total_score": 0,
			"time_taken": 0,
			"item_times": [],
			"puzzles_completed": 0,
		}
		game_stats["game4"] = {
			"questions_answered": 0,
			"questions_correct": 0,
			"total_score": 0,
			"time_taken": 0,
			"item_times": [],
		}
		game_stats["game5"] = {
			"questions_answered": 0,
			"questions_correct": 0,
			"total_score": 0,
			"time_taken": 0,
			"item_times": [],
		}
	elif game_id == "game1":
		game_stats["game1"] = {
			"type": ["keyword", "simple_terms", "definition", "tof"],
			"correct": [0, 0, 0, 0],
			"incorrect": [0, 0, 0, 0],
			"timeout": [0, 0, 0, 0],
			"accuracy": [0, 0, 0, 0],
			"sum_time": [0, 0, 0, 0],
			"questions": [0, 0, 0, 0],
			"item_times": [[], [], [], []],
		}
	elif game_id in ["game2", "game3", "game4", "game5"]:
		var puzzle_completed = 0 if game_id != "game3" else 0
		game_stats[game_id] = {
			"questions_answered": 0,
			"questions_correct": 0,
			"total_score": 0,
			"time_taken": 0,
			"item_times": [],
		}
		if game_id == "game3":
			game_stats[game_id]["puzzles_completed"] = 0

func update_overall_stats():
	# Defensive: ensure all overall_stats keys exist
	for gid in ["game1", "game2", "game3", "game4", "game5"]:
		if not overall_stats.has(gid):
			if gid == "game1":
				overall_stats[gid] = {
					"type": ["keyword", "simple_terms", "definition", "tof"],
					"correct": [0, 0, 0, 0],
					"incorrect": [0, 0, 0, 0],
					"timeout": [0, 0, 0, 0],
					"accuracy": [0, 0, 0, 0],
					"total_sum_time": [0, 0, 0, 0],
					"total_questions": [0, 0, 0, 0],
				}
			else:
				overall_stats[gid] = {
					"total_questions_answered": 0,
					"total_questions_correct": 0,
					"highest_score": 0,
					"total_time": 0,
					"accuracy": 0.0,
				}

	# Track average time and average score per play session for all games
	for gid in ["game2", "game3", "game4", "game5"]:
		# Store all session times and scores
		if not overall_stats[gid].has("all_session_times"):
			overall_stats[gid]["all_session_times"] = []
		if not overall_stats[gid].has("all_session_scores"):
			overall_stats[gid]["all_session_scores"] = []
		# Add this session's time and normalized score if a new session was played
		if game_stats[gid].has("time_taken") and game_stats[gid]["time_taken"] > 0:
			overall_stats[gid]["all_session_times"].append(game_stats[gid]["time_taken"])
			var ref_score = float(SCORE_REFERENCE.get(gid, 1000.0))
			var norm_score = clampf(_safe_ratio(game_stats[gid]["total_score"], ref_score), 0.0, 1.0) * 1000.0
			overall_stats[gid]["all_session_scores"].append(norm_score)
		# Compute average time and average score per play session
		var total_time = 0.0
		var total_score = 0.0
		var session_count = overall_stats[gid]["all_session_times"].size()
		for t in overall_stats[gid]["all_session_times"]:
			total_time += t
		for s in overall_stats[gid]["all_session_scores"]:
			total_score += s
		overall_stats[gid]["average_time_per_play"] = total_time / session_count if session_count > 0 else 0.0
		overall_stats[gid]["average_score"] = total_score / session_count if session_count > 0 else 0.0

	# Game 1 (per-type)
	var game1_total_score = 0.0
	var game1_total_questions = 0
	for i in range(4):
		overall_stats["game1"]["correct"][i] += game_stats["game1"]["correct"][i] if game_stats["game1"].has("correct") and game_stats["game1"]["correct"].size() > i else 0
		overall_stats["game1"]["incorrect"][i] += game_stats["game1"]["incorrect"][i] if game_stats["game1"].has("incorrect") and game_stats["game1"]["incorrect"].size() > i else 0
		overall_stats["game1"]["timeout"][i] += game_stats["game1"]["timeout"][i] if game_stats["game1"].has("timeout") and game_stats["game1"]["timeout"].size() > i else 0
		overall_stats["game1"]["total_sum_time"][i] += game_stats["game1"]["sum_time"][i] if game_stats["game1"].has("sum_time") and game_stats["game1"]["sum_time"].size() > i else 0
		overall_stats["game1"]["total_questions"][i] += game_stats["game1"]["questions"][i] if game_stats["game1"].has("questions") and game_stats["game1"]["questions"].size() > i else 0
		if overall_stats["game1"]["total_questions"][i] > 0:
			overall_stats["game1"]["accuracy"][i] = (overall_stats["game1"]["correct"][i] * 100.0) / overall_stats["game1"]["total_questions"][i]
		# For normalized average score (game1):
		var ref_score = float(SCORE_REFERENCE.get("game1", 1000.0))
		var type_score = float(game_stats["game1"]["correct"][i]) * 100.0 - float(game_stats["game1"]["incorrect"][i]) * 25.0 - float(game_stats["game1"]["timeout"][i]) * 20.0
		game1_total_score += type_score
		game1_total_questions += game_stats["game1"]["questions"][i]
	var norm_score1 = clampf(_safe_ratio(game1_total_score, float(SCORE_REFERENCE.get("game1", 1000.0))), 0.0, 1.0) * 100.0 if game1_total_questions > 0 else 0.0
	overall_stats["game1"]["average_score"] = norm_score1

	# Games 2, 3, 4, 5 (aggregate)
	for gid in ["game2", "game3", "game4", "game5"]:
		if not game_stats.has(gid):
			continue
		overall_stats[gid]["total_questions_answered"] += game_stats[gid].get("questions_answered", 0)
		overall_stats[gid]["total_questions_correct"] += game_stats[gid].get("questions_correct", 0)
		# Remove highest_score logic, will use average_score instead
		overall_stats[gid]["total_time"] += game_stats[gid].get("time_taken", 0)
		if overall_stats[gid]["total_questions_answered"] > 0:
			overall_stats[gid]["accuracy"] = (overall_stats[gid]["total_questions_correct"] * 100.0) / overall_stats[gid]["total_questions_answered"]
	save_user_stats()

func get_game_stats_display():
	var display = []
	for game_id in GAME_SEQUENCE:
		if not game_stats.has(game_id):
			display.append("%s: No data" % game_id)
			continue
		var stats = game_stats[game_id]
		if game_id == "game1":
			for i in range(4):
				var type_name = stats["type"][i] if stats.has("type") and stats["type"].size() > i else str(i)
				var correct = stats["correct"][i] if stats.has("correct") and stats["correct"].size() > i else 0
				var incorrect = stats["incorrect"][i] if stats.has("incorrect") and stats["incorrect"].size() > i else 0
				var timeout = stats["timeout"][i] if stats.has("timeout") and stats["timeout"].size() > i else 0
				var questions = stats["questions"][i] if stats.has("questions") and stats["questions"].size() > i else 0
				var avg_time = 0.0
				if questions > 0:
					avg_time = stats["sum_time"][i] / questions if stats.has("sum_time") and stats["sum_time"].size() > i else 0.0
				var norm_score = 0.0
				if questions > 0:
					norm_score = compute_fair_score(game_id, correct, (correct * 100.0) / questions, avg_time, float(questions) / float(questions))
				display.append("%s (%s): Score: %.1f, Correct: %d, INC: %d, TO: %d, AT: %.1fs | [score=%.2f, acc=%.2f, avg_time=%.2f, comp=%.2f]" % [game_id, type_name, norm_score, correct, incorrect, timeout, avg_time, norm_score, (correct * 100.0) / questions if questions > 0 else 0.0, avg_time, float(questions) / float(questions) if questions > 0 else 0.0])
		else:
			var correct = stats["questions_correct"] if stats.has("questions_correct") else 0
			var total = stats["questions_answered"] if stats.has("questions_answered") else 0
			var avg_time = 0.0
			var item_times = stats["item_times"] if stats.has("item_times") else []
			if total > 0:
				avg_time = 0.0
				for t in item_times:
					avg_time += t
				avg_time = avg_time / total if total > 0 else 0.0
			var norm_score = compute_fair_score(game_id, correct, (correct * 100.0) / total if total > 0 else 0.0, avg_time, float(total) / float(total) if total > 0 else 0.0)
			display.append("%s: Score: %.1f, Correct: %d, Total: %d, AT: %.1fs | [score=%.2f, acc=%.2f, avg_time=%.2f, comp=%.2f]" % [game_id, norm_score, correct, total, avg_time, norm_score, (correct * 100.0) / total if total > 0 else 0.0, avg_time, float(total) / float(total) if total > 0 else 0.0])
	return display


# Fallback next-scene routing for non-adaptive flow.
func _get_default_scene_after_game(current_game_id: String) -> String:
	var idx := GAME_SEQUENCE.find(current_game_id)
	if idx == -1:
		return get_scene_for_game("game1")
	if idx + 1 == 5:
		return "res://Menus/main_menu.tscn"
	return get_scene_for_game(GAME_SEQUENCE[idx + 1])


# Prevents division-by-zero during normalization.
func _safe_ratio(value: float, denominator: float) -> float:
	if denominator <= 0.0:
		return 0.0
	return value / denominator


# Calculates rolling average efficiency for a game.
func _average_efficiency(game_id: String) -> float:
	if not overall_stats.has(game_id):
		return -1.0
	var avg_score = overall_stats[game_id].get("average_score", 0.0)
	var avg_time = overall_stats[game_id].get("average_time_per_play", 999999.0)
	# Combine: prioritize higher score, then lower time. Use a weighted formula.
	var score_component = clampf(avg_score / 1000.0, 0.0, 1.0)
	var time_component = 1.0 - clampf(avg_time / float(TIME_REFERENCE.get(game_id, 150.0)), 0.0, 1.0)
	return (score_component * 0.7) + (time_component * 0.3)


# Rebuilds ranking from highest to lowest average efficiency.
func _update_adaptive_ranking() -> void:
	var ranked_with_score := []
	for game_id in GAME_SEQUENCE:
		ranked_with_score.append({
			"game_id": game_id,
			"avg": _average_efficiency(game_id)
		})

	ranked_with_score.sort_custom(func(a, b):
		if a["avg"] == b["avg"]:
			return GAME_SEQUENCE.find(a["game_id"]) < GAME_SEQUENCE.find(b["game_id"])
		return float(a["avg"]) > float(b["avg"])
	)

	adaptive_last_ranked.clear()
	for entry in ranked_with_score:
		if float(entry["avg"]) >= 0.0:
			adaptive_last_ranked.append(str(entry["game_id"]))

	if adaptive_last_ranked.is_empty():
		adaptive_last_ranked = GAME_SEQUENCE.duplicate()


func mark_diagnostic_completed() -> void:
	diagnostic_runs_completed = maxi(1, diagnostic_runs_completed)
	save_user_stats()


func _legacy_has_completed_diagnostic_stats() -> bool:
	for game_id in GAME_SEQUENCE:
		if not overall_stats.has(game_id):
			return false
		var stat = overall_stats[game_id]
		if typeof(stat) != TYPE_DICTIONARY:
			return false
		if stat.has("total_questions"):
			var total := 0
			for q in stat["total_questions"]:
				total += int(q)
			if total <= 0:
				return false
		elif stat.has("total_questions_answered"):
			if int(stat["total_questions_answered"]) <= 0:
				return false
		elif stat.has("highest_score"):
			if float(stat["highest_score"]) <= 0.0:
				return false
	return true
