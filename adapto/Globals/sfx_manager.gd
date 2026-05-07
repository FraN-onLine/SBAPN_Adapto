extends Node

@onready var success_sound: AudioStreamPlayer = $SuccessSound
@onready var fail_sound: AudioStreamPlayer = $FailSound

# The baseline pitch multiplier
var base_pitch := 1.0
# How much the pitch increases per streak count
var pitch_step := 0.08
# Maximum pitch multiplier mapping to 2x speed/frequency
var max_pitch := 2.0

func play_success(streak: int) -> void:
	# Ensure streak starts at 0 for pitch calculation
	var multiplier = max(0, streak - 1)
	success_sound.pitch_scale = clampf(base_pitch + (multiplier * pitch_step), base_pitch, max_pitch)
	success_sound.play()

func play_fail() -> void:
	# Fail always plays at standard pitch
	fail_sound.pitch_scale = 1.0
	fail_sound.play()
