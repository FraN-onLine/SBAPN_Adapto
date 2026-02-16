extends Resource
class_name LessonItem

#added placeholder terms to understand what each lesson item is
@export var id = "OOP1"
@export var term = "Encapsulation"
@export var keyword = "hides"
@export var definition = "the pillar that hides data, preventing users from accessing it"
@export var simple_terms = "public = access, private = no access"
@export var examples = ["public", "private"]
@export var image: Texture2D
@export var difficulty = 2
@export var related_to = ["pillars"]
@export var type_of_information = ["list", "defined", "definition", "explain", "apply"] #more or less