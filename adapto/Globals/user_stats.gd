# game_manager.gd
extends Node

var player_stats = {
	"typing": {"accuracy": 0, "time": 0},
}

func update_stats(game_type, accuracy, time):
	player_stats[game_type]["accuracy"] = accuracy
	player_stats[game_type]["time"] = time
