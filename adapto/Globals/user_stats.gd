# game_manager.gd
extends Node

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
