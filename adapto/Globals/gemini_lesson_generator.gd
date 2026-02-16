extends Node
class_name GeminiLessonGenerator

signal lesson_items_generated(items: Array[LessonItem])
signal generation_failed(message: String)

@export var api_key: String = ""
@export var model: String = "gemini-1.5-flash"

var _http: HTTPRequest

func _ready() -> void:
    _http = HTTPRequest.new()
    add_child(_http)
    _http.request_completed.connect(_on_request_completed)

func generate_from_seed(seed_lesson: Lesson, count: int = 8) -> void:
    if api_key.strip_edges().is_empty():
        generation_failed.emit("Missing GEMINI API key.")
        return

    var seed_examples: Array = []
    var max_seed := mini(seed_lesson.lesson_items.size(), 6)
    for i in range(max_seed):
        var item := seed_lesson.lesson_items[i]
        seed_examples.append({
            "id": item.id,
            "term": item.term,
            "keyword": item.keyword,
            "definition": item.definition,
            "simple_terms": item.simple_terms,
            "difficulty": item.difficulty,
            "related_to": item.related_to
        })

    var prompt := """
Create %d new OOP lesson items based on this style.
Return ONLY valid JSON, no markdown fences.
Schema:
{
  "items": [
    {
      "id": "AI_OOP1",
      "term": "string",
      "keyword": "string",
      "definition": "string",
      "simple_terms": "string",
      "examples": ["string", "string"],
      "difficulty": 1,
      "related_to": ["string"],
      "type_of_information": ["definition", "apply"]
    }
  ]
}
Seed examples:
%s
""" % [count, JSON.stringify(seed_examples)]

    var body := {
        "contents": [{
            "parts": [{"text": prompt}]
        }],
        "generationConfig": {
            "temperature": 0.7,
            "response_mime_type": "application/json"
        }
    }

    var url := "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s" % [model, api_key]
    var headers := ["Content-Type: application/json"]
    var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
    if err != OK:
        generation_failed.emit("HTTPRequest failed with code: %s" % err)

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code < 200 or response_code >= 300:
        generation_failed.emit("Gemini HTTP error: %s" % response_code)
        return

    var response_text := body.get_string_from_utf8()
    var root = JSON.parse_string(response_text)
    if typeof(root) != TYPE_DICTIONARY:
        generation_failed.emit("Invalid Gemini response JSON.")
        return

    var candidates: Array = root.get("candidates", [])
    if candidates.is_empty():
        generation_failed.emit("No candidates in Gemini response.")
        return

    var text_part := str(candidates[0].get("content", {}).get("parts", [{}])[0].get("text", ""))
    var payload = JSON.parse_string(text_part)
    if typeof(payload) != TYPE_DICTIONARY:
        generation_failed.emit("Model output is not valid JSON object.")
        return

    var raw_items: Array = payload.get("items", [])
    var out: Array[LessonItem] = []
    var idx := 1
    for entry in raw_items:
        if typeof(entry) != TYPE_DICTIONARY:
            continue

        var li := LessonItem.new()
        li.id = str(entry.get("id", "AI_OOP_%d" % idx))
        li.term = str(entry.get("term", ""))
        li.keyword = str(entry.get("keyword", ""))
        li.definition = str(entry.get("definition", ""))
        li.simple_terms = str(entry.get("simple_terms", ""))
        li.examples = entry.get("examples", [])
        li.difficulty = int(entry.get("difficulty", 1))
        li.related_to = entry.get("related_to", [])
        li.type_of_information = entry.get("type_of_information", ["definition"])

        if li.term != "" and li.definition != "":
            out.append(li)
            idx += 1

    if out.is_empty():
        generation_failed.emit("No valid lesson items parsed.")
        return

    lesson_items_generated.emit(out)