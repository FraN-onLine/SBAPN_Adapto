extends PanelContainer

signal remove_requested(entry: Node)

@onready var term_edit: LineEdit = $Margin/VBox/TermEdit
@onready var keyword_edit: LineEdit = $Margin/VBox/KeywordEdit
@onready var definition_edit: LineEdit = $Margin/VBox/DefinitionEdit
@onready var simple_terms_edit: LineEdit = $Margin/VBox/SimpleTermsEdit
@onready var examples_edit: LineEdit = $Margin/VBox/ExamplesEdit
@onready var accepted_terms_edit: LineEdit = $Margin/VBox/AcceptedTermsEdit
@onready var related_to_edit: LineEdit = $Margin/VBox/RelatedToEdit
@onready var info_types_edit: LineEdit = $Margin/VBox/InfoTypesEdit
@onready var true_statement_edit: LineEdit = $Margin/VBox/TrueStatementEdit
@onready var false_statement_edit: LineEdit = $Margin/VBox/FalseStatementEdit
@onready var difficulty_spin: SpinBox = $Margin/VBox/DifficultySpin


func _on_remove_button_pressed() -> void:
	remove_requested.emit(self)


func to_lesson_item(index: int, lesson_prefix: String) -> LessonItem:
	var term_value := term_edit.text.strip_edges()
	if term_value == "":
		return null

	var definition_value := definition_edit.text.strip_edges()
	if definition_value == "":
		definition_value = "Definition for " + term_value

	var keyword_value := keyword_edit.text.strip_edges()
	if keyword_value == "":
		keyword_value = term_value.substr(0, min(12, term_value.length())).to_lower()

	var item := LessonItem.new()
	item.id = _slug(lesson_prefix) + str(index)
	item.term = term_value
	item.keyword = keyword_value
	item.definition = definition_value
	item.simple_terms = simple_terms_edit.text.strip_edges()
	item.examples = _parse_csv(examples_edit.text)
	item.accepted_terms = _parse_csv(accepted_terms_edit.text)
	item.related_to = _parse_csv(related_to_edit.text)
	if item.related_to.is_empty():
		item.related_to = ["general"]
	item.type_of_information = _parse_csv(info_types_edit.text)
	if item.type_of_information.is_empty():
		item.type_of_information = ["definition", "explain"]
	item.difficulty = int(difficulty_spin.value)

	var true_statement := true_statement_edit.text.strip_edges()
	var false_statement := false_statement_edit.text.strip_edges()
	if true_statement == "":
		true_statement = term_value + " is " + definition_value
	if false_statement == "":
		false_statement = term_value + " is unrelated to " + keyword_value
	item.tof_statement = {
		"true": true_statement,
		"false": false_statement
	}

	return item


func _parse_csv(text: String) -> Array[String]:
	var result: Array[String] = []
	for part in text.split(","):
		var value := part.strip_edges()
		if value != "":
			result.append(value)
	return result


func _slug(value: String) -> String:
	var output := ""
	for ch in value.to_lower():
		if ch.is_valid_identifier() and ch != "_":
			output += ch
	if output == "":
		return "lesson"
	return output
