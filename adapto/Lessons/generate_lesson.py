import requests
import json
import sys
import os

API_KEY = os.environ.get("GEMINI_API_KEY", "AIzaSyCTZeL8hcbWw8Gjof0RqmR6h2wmG0E3cT8")
MODEL = "gemini-2.5-flash-lite"
OUTPUT_DIR = "Lessons/lesson_files"

SEED_EXAMPLES = [
    {"id": "OOP1", "term": "Encapsulation", "keyword": "hides",
     "definition": "the pillar that hides data, preventing users from accessing it",
     "simple_terms": "public = access, private = no access", "difficulty": 1, "related_to": ["pillars"]},
    {"id": "OOP2", "term": "Inheritance", "keyword": "classes",
     "definition": "makes use of class hierarchy to access functions and variables native to other classes",
     "simple_terms": "children gets parent behavior", "difficulty": 2, "related_to": ["pillars"]},
]

def call_gemini(topic: str, count: int) -> list:
    prompt = f"""
Create {count} new lesson items about "{topic}" based on this style.
Return ONLY valid JSON, no markdown fences.
Schema:
{{
  "items": [
    {{
      "id": "AI_{topic[:3].upper()}1",
      "term": "string",
      "keyword": "string",
      "definition": "string",
      "simple_terms": "string",
      "examples": ["string", "string"],
      "difficulty": 1,
      "related_to": ["string"],
      "type_of_information": ["definition", "apply"],
      "tof_statement": {{
        "true": "string",
        "false": "string"
      }}
    }}
  ]
}}
Seed style examples:
{json.dumps(SEED_EXAMPLES, indent=2)}
"""
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.7, "response_mime_type": "application/json"}
    }
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"
    resp = requests.post(url, json=body)
    if resp.status_code != 200:
        print(f"HTTP {resp.status_code} error. Response body:")
        print(resp.text)
    resp.raise_for_status()
    root = resp.json()
    text_part = root["candidates"][0]["content"]["parts"][0]["text"]
    return json.loads(text_part)["items"]

def sanitize_id(s: str) -> str:
    return s.replace(" ", "_").replace(":", "").replace("/", "_").lower()

def write_tres(topic: str, items: list, out_path: str):
    load_steps = 2 + len(items)
    lines = []
    lines.append(f'[gd_resource type="Resource" script_class="Lesson" load_steps={load_steps} format=3]')
    lines.append('')
    lines.append('[ext_resource type="Script" uid="uid://dadne10e1geqd" path="res://Lessons/lesson_item.gd" id="1_7hrog"]')
    lines.append('[ext_resource type="Script" uid="uid://7kxviye2bk4p" path="res://Lessons/lesson.gd" id="2_bkryn"]')
    lines.append('')

    resource_ids = []
    for i, item in enumerate(items):
        rid = f"Resource_{sanitize_id(item.get('id', f'item{i}'))}"
        resource_ids.append(rid)
        lines.append(f'[sub_resource type="Resource" id="{rid}"]')
        lines.append('script = ExtResource("1_7hrog")')
        lines.append(f'id = "{item.get("id", "")}"')
        lines.append(f'term = "{item.get("term", "")}"')
        lines.append(f'keyword = "{item.get("keyword", "")}"')
        lines.append(f'definition = "{item.get("definition", "")}"')
        lines.append(f'simple_terms = "{item.get("simple_terms", "")}"')
        examples = item.get("examples", [])
        lines.append(f'examples = {json.dumps(examples)}')
        lines.append(f'difficulty = {item.get("difficulty", 1)}')
        related = item.get("related_to", [])
        lines.append(f'related_to = {json.dumps(related)}')
        tof = item.get("tof_statement", {"true": "", "false": ""})
        lines.append('tof_statement = {')
        lines.append(f'"false": "{tof.get("false", "")}", ')
        lines.append(f'"true": "{tof.get("true", "")}"')
        lines.append('}')
        toi = item.get("type_of_information", ["definition"])
        lines.append(f'type_of_information = {json.dumps(toi)}')
        lines.append('metadata/_custom_type_script = "uid://dadne10e1geqd"')
        lines.append('')

    sub_refs = ", ".join([f'SubResource("{rid}")' for rid in resource_ids])
    lines.append('[resource]')
    lines.append('script = ExtResource("2_bkryn")')
    lines.append(f'lesson_title = "{topic}"')
    lines.append(f'lesson_items = Array[ExtResource("1_7hrog")]([{sub_refs}])')
    lines.append('metadata/_custom_type_script = "uid://7kxviye2bk4p"')

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Saved: {out_path}")

if __name__ == "__main__":
    topic = sys.argv[1] if len(sys.argv) > 1 else "Object Oriented Programming"
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 8
    folder = sys.argv[3] if len(sys.argv) > 3 else topic

    print(f"Generating {count} items for topic: {topic}")
    items = call_gemini(topic, count)
    print(f"Got {len(items)} items from Gemini")

    out_path = os.path.join(OUTPUT_DIR, folder, f"{sanitize_id(topic)}.tres")
    write_tres(topic, items, out_path)