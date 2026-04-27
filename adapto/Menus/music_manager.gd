extends Node

@onready var player = $AudioStreamPlayer2D

func _ready():
	player.stream = preload("res://Assets/Walen - Gameboy (freetouse.com).mp3")
	player.play()
