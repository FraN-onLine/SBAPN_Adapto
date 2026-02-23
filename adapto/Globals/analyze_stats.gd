extends Node

#for each one, we check how accurate, time efficient or any other external factors affect the performance
var definition_proficiency = {"acc": "poor", "time" : "slow"}
var keyword_proficiency = {"acc": "poor", "time" : "slow"}
var redefinition_proficiency = {"acc": "poor", "time" : "slow"}
var fact_inference_proficiency = {"acc": "poor", "time" : "slow"}
var image_recognition_proficiency = {"acc": "poor", "time" : "slow"}
var application_proficiency = {"acc": "poor", "time" : "slow"}

func analyze_stats():
	for i in range(4):
		var game_type = UserStats.overall_stats["game1"]["type"][i]
		var accuracy = UserStats.overall_stats["game1"]["accuracy"][i]
		var time = UserStats.overall_stats["game1"]["time"][i]
		if game_type == "definition":
			definition_proficiency["acc"] = "good" if accuracy > 80 else "poor"
			definition_proficiency["time"] = "fast" if time < 30 else "slow"
		elif game_type == "keyword":
			keyword_proficiency["acc"] = "good" if accuracy > 80 else "poor"
			keyword_proficiency["time"] = "fast" if time < 30 else "slow"
		elif game_type == "simple_terms":
			redefinition_proficiency["acc"] = "good" if accuracy > 80 else "poor"
			redefinition_proficiency["time"] = "fast" if time < 30 else "slow"
		elif game_type == "tof":
			fact_inference_proficiency["acc"] = "good" if accuracy > 80 else "poor"
			fact_inference_proficiency["time"] = "fast" if time < 30 else "slow"
		elif game_type == "image_recognition":
			image_recognition_proficiency["acc"] = "good" if accuracy > 80 else "poor"
			image_recognition_proficiency["time"] = "fast" if time < 30 else "slow"
		elif game_type == "application":
			application_proficiency["acc"] = "good" if accuracy > 80 else "poor"
			application_proficiency["time"] = "fast" if time < 30 else "slow"
