extends Resource
class_name Lesson

@export var lesson_title = ""
@export var lesson_items: Array[LessonItem]

func get_random_lesson_item() -> LessonItem:
	if lesson_items.is_empty():
		return null
	return lesson_items.pick_random()

func get_items_by_difficulty(target_difficulty: int) -> Array[LessonItem]:
	return lesson_items.filter(func(item):
		return item.difficulty == target_difficulty
	)
