extends Node2D

var money = 0
var questions = {}
var answered = {}
var current_key = ""

func _ready() -> void:
	#load 3 categories,
	$Category/Category1.text = ""
	
