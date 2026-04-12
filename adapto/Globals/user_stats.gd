
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

# Returns true if the current user has completed at least one full diagnostic round (all games played at least once)
func has_completed_diagnostic() -> bool:
       if Global.current_user == null:
           return false
       for game_id in GAME_SEQUENCE:
           if not overall_stats.has(game_id):
               return false
           # For a game to be considered completed, must have at least one question answered or score > 0
           var stat = overall_stats[game_id]
           if stat.has("total_questions"):
               var total = 0
               for q in stat["total_questions"]:
                   total += q
               if total == 0:
                   return false
           elif stat.has("total_questions_answered"):
               if stat["total_questions_answered"] == 0:
                   return false
           elif stat.has("highest_score"):
               if stat["highest_score"] == 0:
                   return false
       return true


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
var adaptive_phase: String = "none" # none | diagnostic | adaptive
var adaptive_history := {
    "game1": [],
    "game2": [],
    "game3": [],
    "game4": [],
    "game5": []
}
var adaptive_last_ranked: Array[String] = []
# Tracks the current leader game during adaptive phase
var adaptive_current_leader: String = ""

var player_stats = {
    "typing": {"accuracy": 0, "time": 0},
}

var game_stats = {
    "game1" : {
        "type": ["keyword", "simple_terms", "definition", "tof"], #arr of 4
        "correct": [0, 0, 0, 0], #arr of 4
        "incorrect": [0, 0, 0, 0], #arr of 4
        "timeout": [0, 0, 0, 0], #arr of 4
        "accuracy": [0, 0, 0, 0], #arr of 4
        "sum_time": [0, 0, 0, 0], #sum of times per question type
        "questions": [0, 0, 0, 0], #number of questions per type
    },##
    "game3" : {
        "questions_answered": 0,
        "questions_correct": 0,
        "total_score": 0,
        "time_taken": 0,
        "puzzles_completed": 0,
    }
}

var overall_stats = {
    "game1" : {
        "type": ["keyword", "simple_terms", "definition", "tof"], #arr of 4
        "correct": [0, 0, 0, 0], #arr of 4
        "incorrect": [0, 0, 0, 0], #arr of 4
        "timeout": [0, 0, 0, 0], #arr of 4
        "accuracy": [0, 0, 0, 0], #arr of 4
        "total_sum_time": [0, 0, 0, 0], #total sum of times
        "total_questions": [0, 0, 0, 0], #total number of questions
    },##
    "game3" : {
        "total_questions_answered": 0,
        "total_questions_correct": 0,
        "highest_score": 0,
        "total_time": 0,
        "total_puzzles_completed": 0,
        "accuracy": 0.0,
    }
}


# Starts a fresh adaptive run and clears rolling efficiency history.
func start_adaptive_session() -> void:
       # Only allow adaptive if diagnostic is completed
       if not has_completed_diagnostic():
           adaptive_mode_active = false
           adaptive_phase = "none"
           adaptive_current_leader = ""
           return
       adaptive_mode_active = true
       adaptive_phase = "diagnostic"
       adaptive_last_ranked = []
       adaptive_current_leader = ""
       for game_id in GAME_SEQUENCE:
           adaptive_history[game_id] = []
       reset_game_stats()
# Returns average score for each game for the current user
func get_average_scores_per_game() -> Dictionary:
       var result = {}
       for game_id in GAME_SEQUENCE:
           if overall_stats.has(game_id):
               var stat = overall_stats[game_id]
               if stat.has("total_questions") and stat.has("correct") and stat["total_questions"] is Array:
                   var total = 0
                   var correct = 0
                   for i in range(stat["total_questions"].size()):
                       total += stat["total_questions"][i]
                       correct += stat["correct"][i]
                   result[game_id] = float(correct) / float(total) * 100.0 if total > 0 else 0.0
               elif stat.has("total_questions_answered") and stat.has("total_questions_correct"):
                   var total = stat["total_questions_answered"]
                   var correct = stat["total_questions_correct"]
                   result[game_id] =  float(correct) / float(total) * 100.0 if total > 0 else 0.0
               elif stat.has("highest_score"):
                   result[game_id] = float(stat["highest_score"])
               else:
                   result[game_id] = 0.0
           else:
               result[game_id] = 0.0
       return result


# Ends adaptive mode and returns routing to default game order.
func stop_adaptive_session() -> void:
    adaptive_mode_active = false
    adaptive_phase = "none"
    adaptive_current_leader = ""


# Resolves a game id to its scene path.
func get_scene_for_game(game_id: String) -> String:
    if GAME_SCENES.has(game_id):
        return str(GAME_SCENES[game_id])
    return str(GAME_SCENES["game1"])



# Chooses the next scene using default order or adaptive ranking.
func get_scene_after_game(current_game_id: String) -> String:
    if not adaptive_mode_active:
        return _get_default_scene_after_game(current_game_id)

    # Diagnostic phase: always go in order
    if adaptive_phase == "diagnostic":
        var idx := GAME_SEQUENCE.find(current_game_id)
        if idx >= 0 and idx < GAME_SEQUENCE.size() - 1:
            return get_scene_for_game(GAME_SEQUENCE[idx + 1])
        # After last game, switch to adaptive phase
        adaptive_phase = "adaptive"
        adaptive_current_leader = get_leading_game()
        return "res://Menus/game1_stats.tscn" # or summary screen

    # Adaptive phase: always do best game
    if adaptive_phase == "adaptive":
        var new_leader = get_leading_game()
        if new_leader != "" and new_leader != adaptive_current_leader:
            adaptive_current_leader = new_leader
        if adaptive_current_leader == "":
            adaptive_current_leader = "game1"
        return get_scene_for_game(adaptive_current_leader)

    # Fallback
    return get_scene_for_game("game1")


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

func reset_game_stats():
    game_stats["game1"]["correct"] = [0, 0, 0, 0]
    game_stats["game1"]["incorrect"] = [0, 0, 0, 0]
    game_stats["game1"]["timeout"] = [0, 0, 0, 0]
    game_stats["game1"]["accuracy"] = [0, 0, 0, 0]
    game_stats["game1"]["sum_time"] = [0, 0, 0, 0]
    game_stats["game1"]["questions"] = [0, 0, 0, 0]
    ##
    game_stats["game3"]["questions_answered"] = 0
    game_stats["game3"]["questions_correct"] = 0
    game_stats["game3"]["total_score"] = 0
    game_stats["game3"]["time_taken"] = 0
    game_stats["game3"]["puzzles_completed"] = 0

func update_overall_stats():
    for i in range(4):
        overall_stats["game1"]["correct"][i] += game_stats["game1"]["correct"][i]
        overall_stats["game1"]["incorrect"][i] += game_stats["game1"]["incorrect"][i]
        overall_stats["game1"]["timeout"][i] += game_stats["game1"]["timeout"][i]
        overall_stats["game1"]["total_sum_time"][i] += game_stats["game1"]["sum_time"][i]
        overall_stats["game1"]["total_questions"][i] += game_stats["game1"]["questions"][i]
        if overall_stats["game1"]["total_questions"][i] > 0:
            overall_stats["game1"]["accuracy"][i] = (overall_stats["game1"]["correct"][i] * 100.0) / overall_stats["game1"]["total_questions"][i]
    ##
    # Update game3 overall stats
    overall_stats["game3"]["total_questions_answered"] += game_stats["game3"]["questions_answered"]
    overall_stats["game3"]["total_questions_correct"] += game_stats["game3"]["questions_correct"]
    if game_stats["game3"]["total_score"] > overall_stats["game3"]["highest_score"]:
        overall_stats["game3"]["highest_score"] = game_stats["game3"]["total_score"]
    overall_stats["game3"]["total_time"] += game_stats["game3"]["time_taken"]
    overall_stats["game3"]["total_puzzles_completed"] += game_stats["game3"]["puzzles_completed"]
    if overall_stats["game3"]["total_questions_answered"] > 0:
        overall_stats["game3"]["accuracy"] = (overall_stats["game3"]["total_questions_correct"] * 100.0) / overall_stats["game3"]["total_questions_answered"]

func get_game_stats_display():
    var stats = game_stats["game1"]
    var display = []
    for i in range(4):
        var type_name = stats["type"][i]
        var correct = stats["correct"][i]
        var incorrect = stats["incorrect"][i]
        var timeout = stats["timeout"][i]
        var questions = stats["questions"][i]
        var accuracy = 0.0
        if questions > 0:
            accuracy = (correct * 100.0) / questions
        var avg_time = 0.0
        if questions > 0:
            avg_time = stats["sum_time"][i] / questions
        display.append("%s: Correct: %d, INC: %d, TO: %d, ACC: %.1f%%, AT: %.1fs" % [type_name, correct, incorrect, timeout, accuracy, avg_time])
    return display


# Fallback next-scene routing for non-adaptive flow.
func _get_default_scene_after_game(current_game_id: String) -> String:
    var idx := GAME_SEQUENCE.find(current_game_id)
    if idx == -1:
        return get_scene_for_game("game1")
    if idx >= GAME_SEQUENCE.size() - 1:
        return "res://Menus/game1_stats.tscn"
    return get_scene_for_game(GAME_SEQUENCE[idx + 1])


# Prevents division-by-zero during normalization.
func _safe_ratio(value: float, denominator: float) -> float:
    if denominator <= 0.0:
        return 0.0
    return value / denominator


# Calculates rolling average efficiency for a game.
func _average_efficiency(game_id: String) -> float:
    if not adaptive_history.has(game_id):
        return 0.0
    var history: Array = adaptive_history[game_id]
    if history.is_empty():
        return -1.0
    var total := 0.0
    for entry in history:
        total += float(entry)
    return total / float(history.size())


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
