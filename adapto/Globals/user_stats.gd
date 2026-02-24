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
	}
}

func reset_game_stats():
	game_stats["game1"]["correct"] = [0, 0, 0, 0]
	game_stats["game1"]["incorrect"] = [0, 0, 0, 0]
	game_stats["game1"]["timeout"] = [0, 0, 0, 0]
	game_stats["game1"]["accuracy"] = [0, 0, 0, 0]
	game_stats["game1"]["sum_time"] = [0, 0, 0, 0]
	game_stats["game1"]["questions"] = [0, 0, 0, 0]

func update_overall_stats():
	for i in range(4):
		overall_stats["game1"]["correct"][i] += game_stats["game1"]["correct"][i]
		overall_stats["game1"]["incorrect"][i] += game_stats["game1"]["incorrect"][i]
		overall_stats["game1"]["timeout"][i] += game_stats["game1"]["timeout"][i]
		overall_stats["game1"]["total_sum_time"][i] += game_stats["game1"]["sum_time"][i]
		overall_stats["game1"]["total_questions"][i] += game_stats["game1"]["questions"][i]
		if overall_stats["game1"]["total_questions"][i] > 0:
			overall_stats["game1"]["accuracy"][i] = (overall_stats["game1"]["correct"][i] * 100.0) / overall_stats["game1"]["total_questions"][i]

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
