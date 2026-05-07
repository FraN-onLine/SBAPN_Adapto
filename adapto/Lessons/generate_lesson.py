import requests
import json
import sys
import os
import base64
import re
import random
from pathlib import Path

# Load .env from the project root (adapto/) regardless of where the script is run from
_env_path = Path(__file__).resolve().parent.parent / ".env"
try:
    from dotenv import load_dotenv
    load_dotenv(dotenv_path=_env_path)
except ImportError:
    # dotenv not installed — fall back to os.environ only (CI/CD / production)
    pass

API_KEY = os.environ.get("GEMINI_API_KEY", "")
if not API_KEY:
    print("Error: GEMINI_API_KEY is not set. Add it to adapto/.env or set it as an environment variable.")
    sys.exit(1)
MODEL = "gemini-2.5-flash-lite"
PDF_MODEL = "gemini-2.5-flash-lite"  # same model used for prompt-based generation
OUTPUT_DIR = "Lessons/lesson_files"
PREFERRED_DEFINITION_LEN = 120
MAX_DEFINITION_LEN = 240
TERM_MIN_LEN = 3
TERM_MAX_LEN = 34
TERM_ALLOWED_RE = re.compile(r"[^A-Za-z0-9 \-]")

SEED_EXAMPLES = [
    {"id": "OOP1", "term": "Encapsulation", "keyword": "hides",
     "definition": "the pillar that hides data, preventing users from accessing it",
     "simple_terms": "public = access, private = no access", "difficulty": 1, "related_to": ["pillars"]},
    {"id": "OOP2", "term": "Inheritance", "keyword": "classes",
     "definition": "makes use of class hierarchy to access functions and variables native to other classes",
     "simple_terms": "children gets parent behavior", "difficulty": 2, "related_to": ["pillars"]},
]


GEMINI_PROMPT_TEMPLATE = """Create exactly {count} x 2 lesson items about "{topic}" using this strict JSON schema and constraints.

Return ONLY valid JSON that matches the schema exactly. Do NOT include markdown, commentary, or extra fields.

SCHEMA (JSON):
{{
    "items": [
        {{
            "id": "string (format: ABC_01 where ABC = first 3 letters of topic uppercase)",
            "term": "string (3-34 chars max, no acronyms, alphanumeric+space+hyphen only)",
            "keyword": "string (3-15 chars, single concept)",
            "definition": "string (prefer 60-120 chars, single-line, plain text; allowed up to 240 chars)",
            "simple_terms": "string (20-60 chars, plain text)",
            "examples": ["string", "string", "string"],
            "accepted_terms": ["string (0-3 items; acronyms or synonyms only)"] ,
            "difficulty": 1,
            "related_to": ["string (reuse 3-5 same category tags across ALL items)"] ,
            "type_of_information": ["definition","explain","apply"],
            "tof_statement": {{"true": "string", "false": "string"}}
        }}
    ]
}}

STRICT RULES:
1. `term` MUST be between 3 and 34 characters. No all-uppercase acronyms in `term` (if a concept is commonly an acronym, place it in `accepted_terms` instead), do not append any form of acronym in the term.
2. `definition` should be concise (aim 60-120 characters). Longer definitions are allowed up to 240 characters when necessary; avoid newlines or markdown.
3. `simple_terms` 20-60 characters. do not use the term itself.
4. `examples` MUST contain exactly 3 items, each 5-25 chars.
5. `accepted_terms` OPTIONAL, max 5 items; use only for acronyms/variants/synonyms/plurals/with or withour hyphen and the like.
6. `type_of_information` MUST contain 3-5 items from: definition, explain, apply, list, defined.
7. `related_to` should reuse the same 3-5 category tags across all items in this response.
8. `id` should follow the ABC_01 numbering pattern (ABC = first 3 letters of the topic, uppercase).
9. 'keyword' does not use the term itself.
SEED STYLE EXAMPLES (follow tone/format):
{seed_json}

Return ONLY the JSON object.
"""


def _clean_term(value: str) -> str:
    t = str(value or "").strip()
    if t == "":
        return ""
    t = t.replace("_", " ")
    t = TERM_ALLOWED_RE.sub(" ", t)
    t = re.sub(r"\s+", " ", t).strip()
    return t


def _smart_shorten_term(term_raw: str, max_len: int, examples_list: list, keyword: str) -> str:
    t = _clean_term(term_raw)
    if t == "":
        # fallback to examples
        for exv in examples_list:
            exs = _clean_term(exv)
            if TERM_MIN_LEN <= len(exs) <= max_len:
                return exs
        kw = _clean_term(keyword)
        return (kw or "term")[:max_len]

    if len(t) <= max_len:
        return t

    # Try to keep whole words from the start that fit
    words = t.split()
    for end in range(len(words), 0, -1):
        cand = " ".join(words[:end]).strip()
        if TERM_MIN_LEN <= len(cand) <= max_len:
            return cand

    # Try hyphen/underscore segments
    parts = re.split(r"[-_]", t)
    for p in parts:
        p = p.strip()
        if TERM_MIN_LEN <= len(p) <= max_len:
            return p

    # Try examples
    for exv in examples_list:
        exs = _clean_term(exv)
        if TERM_MIN_LEN <= len(exs) <= max_len:
            return exs

    # Try keyword
    kw = _clean_term(keyword)
    if TERM_MIN_LEN <= len(kw) <= max_len:
        return kw

    # Last resort: hard truncate
    return t[:max_len].rstrip()


def _gd_string(value: str) -> str:
    s = str(value or "")
    s = s.replace("\\", "\\\\")
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    s = s.replace("\n", "\\n")
    s = s.replace('"', "\\\"")
    return s


def generate_godot_uid() -> str:
    """Generates a pseudo-random Godot 4 UID string."""
    chars = '0123456789abcdefghijklmnopqrstuvwxyz'
    return "uid://" + ''.join(random.choice(chars) for _ in range(13))


def normalize_items(topic: str, items: list) -> list:
    prefix = topic.replace(" ", "")[:3].upper()
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            continue

        # Ensure required keys exist
        item.setdefault("accepted_terms", [])
        item.setdefault("examples", [])
        item.setdefault("type_of_information", ["definition"])

        term_raw = item.get("term", "")
        exs = item.get("examples", []) or []
        keyword = item.get("keyword", "") or ""

        # Detect short acronyms (letters and digits) and move to accepted_terms without title-casing
        term_candidate = _clean_term(term_raw)
        if re.fullmatch(r"[A-Z0-9]{2,5}", term_candidate):
            if term_candidate not in item["accepted_terms"]:
                item["accepted_terms"].append(term_candidate)
            # pick a better human-readable fallback (keyword or example)
            term_candidate = _clean_term(keyword or (exs[0] if exs else "term"))

        term = _smart_shorten_term(term_candidate, TERM_MAX_LEN, exs, keyword)
        if len(term) < TERM_MIN_LEN:
            fallback = _clean_term(exs[0] if exs else "")
            if len(fallback) < TERM_MIN_LEN:
                fallback = _clean_term(keyword)
            if len(fallback) < TERM_MIN_LEN:
                fallback = "Term"
            term = fallback[:TERM_MAX_LEN]

        item["term"] = term

        # Definition: prefer shorter, but allow up to MAX_DEFINITION_LEN; only truncate if it exceeds that
        def smart_shorten_definition(def_text: str, max_len: int) -> str:
            d = str(def_text or "").replace("\n", " ").strip()
            if len(d) <= max_len:
                return d
            # cut at last space before limit to avoid mid-word cuts
            cut = d.rfind(" ", 0, max_len - 3)
            if cut == -1:
                return d[:max_len - 3].rstrip() + "..."
            return d[:cut].rstrip() + "..."

        definition = str(item.get("definition", "")).replace("\n", " ").strip()
        # remove accidental trailing ellipses from generator
        if definition.endswith("..."):
            definition = definition.rstrip(".")
            definition = definition.strip()

        if len(definition) > MAX_DEFINITION_LEN:
            definition = smart_shorten_definition(definition, MAX_DEFINITION_LEN)

        item["definition"] = definition

        # Simple terms
        simple = str(item.get("simple_terms", "")).replace("\n", " ").strip()
        if len(simple) > 60:
            simple = simple[:57].rstrip() + "..."
        item["simple_terms"] = simple

        # Examples: exactly 3, avoid duplicates with term
        ex = item.get("examples", [])
        ex = [str(e).strip() for e in ex if str(e).strip() != ""]
        # Remove exact duplicates and any that equal the term (case-insensitive)
        seen = set()
        filtered = []
        for e in ex:
            key = e.lower()
            if key == item["term"].lower():
                continue
            if key in seen:
                continue
            seen.add(key)
            filtered.append(e)
            
        # Pad examples safely without duplicating the core term
        while len(filtered) < 3:
            candidate = keyword if keyword and keyword.lower() not in seen else f"{item['term']} example {len(filtered) + 1}"
            cand = str(candidate).strip()
            if cand.lower() not in seen:
                filtered.append(cand)
                seen.add(cand.lower())
            else:
                # Ultimate fallback to prevent infinite loops
                fallback = f"{item['term']} {len(filtered) + 1}"
                filtered.append(fallback)
                seen.add(fallback.lower())
                
        if len(filtered) > 3:
            filtered = filtered[:3]
        item["examples"] = filtered

        # accepted_terms: ensure list, max 3
        at = [str(a).strip() for a in item.get("accepted_terms", []) if str(a).strip() != ""]
        item["accepted_terms"] = at[:3]

        # difficulty clamp
        try:
            d = int(item.get("difficulty", 1))
        except Exception:
            d = 1
        item["difficulty"] = max(1, min(3, d))

        # related_to: ensure non-empty and limited
        rel = item.get("related_to", [])
        if not rel:
            rel = [topic]
        item["related_to"] = rel[:4]

        # type_of_information: ensure 3-5 unique items
        toi = [str(t).strip() for t in item.get("type_of_information", []) if str(t).strip() != ""]
        fallbacks = ["definition", "explain", "apply"]
        
        for f in fallbacks:
            if len(toi) >= 3:
                break
            if f not in toi:
                toi.append(f)
                
        item["type_of_information"] = toi[:5]

        # tof_statement: ensure both true/false strings
        tof = item.get("tof_statement", {}) or {}
        tof_true = str(tof.get("true", "")).replace("\n", " ").strip()
        tof_false = str(tof.get("false", "")).replace("\n", " ").strip()
        if tof_true == "":
            tof_true = f"{item['term']} relates to {', '.join(item.get('related_to', []))}."
        if tof_false == "":
            tof_false = f"{item['term']} does not relate to {', '.join(item.get('related_to', []))}."
        item["tof_statement"] = {"true": tof_true[:100], "false": tof_false[:100]}

        # id generation: ABC_01 style
        item_id = item.get("id", "")
        if not item_id or not isinstance(item_id, str):
            item_id = f"{prefix}_{idx+1:02d}"
        item["id"] = item_id

    return items

def call_gemini(topic: str, count: int) -> list:
    prompt = GEMINI_PROMPT_TEMPLATE.format(count=count, topic=topic, seed_json=json.dumps(SEED_EXAMPLES, indent=2))
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
    items = json.loads(text_part)["items"]

    # Post-generation validation & normalization
    items = normalize_items(topic, items)

    return items

def sanitize_id(s: str) -> str:
    return s.replace(" ", "_").replace(":", "").replace("/", "_").lower()

def write_tres(topic: str, items: list, out_path: str):
    load_steps = 2 + len(items)
    root_uid = generate_godot_uid()
    
    lines = []
    lines.append(f'[gd_resource type="Resource" script_class="Lesson" load_steps={load_steps} format=3 uid="{root_uid}"]')
    lines.append('')
    # Fixed res:// paths to match your handmade files structure
    lines.append('[ext_resource type="Script" uid="uid://dadne10e1geqd" path="res://Lessons/lesson_item.gd" id="1_7hrog"]')
    lines.append('[ext_resource type="Script" uid="uid://7kxviye2bk4p" path="res://Lessons/lesson.gd" id="2_bkryn"]')
    lines.append('')

    resource_ids = []
    for i, item in enumerate(items):
        rid = f"Resource_{sanitize_id(item.get('id', f'item{i}'))}"
        resource_ids.append(rid)
        lines.append(f'[sub_resource type="Resource" id="{rid}"]')
        lines.append('script = ExtResource("1_7hrog")')
        lines.append(f'id = "{_gd_string(item.get("id", ""))}"')
        lines.append(f'term = "{_gd_string(item.get("term", ""))}"')
        lines.append(f'keyword = "{_gd_string(item.get("keyword", ""))}"')
        lines.append(f'definition = "{_gd_string(item.get("definition", ""))}"')
        lines.append(f'simple_terms = "{_gd_string(item.get("simple_terms", ""))}"')
        examples = item.get("examples", [])
        lines.append(f'examples = {json.dumps(examples)}')
        accepted_terms = item.get("accepted_terms", [])
        lines.append(f'accepted_terms = {json.dumps(accepted_terms)}')
        lines.append(f'difficulty = {item.get("difficulty", 1)}')
        related = item.get("related_to", [])
        lines.append(f'related_to = {json.dumps(related)}')
        tof = item.get("tof_statement", {"true": "", "false": ""})
        lines.append('tof_statement = {')
        lines.append(f'"false": "{_gd_string(tof.get("false", ""))}", ')
        lines.append(f'"true": "{_gd_string(tof.get("true", ""))}"')
        lines.append('}')
        toi = item.get("type_of_information", ["definition"])
        lines.append(f'type_of_information = {json.dumps(toi)}')
        lines.append('metadata/_custom_type_script = "uid://dadne10e1geqd"')
        lines.append('')

    sub_refs = ", ".join([f'SubResource("{rid}")' for rid in resource_ids])
    lines.append('[resource]')
    lines.append('script = ExtResource("2_bkryn")')
    lines.append(f'lesson_title = "{_gd_string(topic)}"')
    lines.append(f'lesson_items = Array[ExtResource("1_7hrog")]([{sub_refs}])')
    lines.append('metadata/_custom_type_script = "uid://7kxviye2bk4p"')

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Saved: {out_path}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--pdf":
        if len(sys.argv) < 3:
            print("Usage: generate_lesson.py --pdf <pdf_path> [count] [folder]")
            sys.exit(1)

        pdf_path = sys.argv[2]
        count = int(sys.argv[3]) if len(sys.argv) > 3 else 8
        folder_arg = sys.argv[4] if len(sys.argv) > 4 else None

        if not os.path.isfile(pdf_path):
            print(f"PDF file not found: {pdf_path}")
            sys.exit(1)

        print(f"Generating {count} items from PDF: {pdf_path}")

        # Read and base64-encode the PDF for Gemini's inline_data field
        with open(pdf_path, "rb") as f:
            pdf_b64 = base64.b64encode(f.read()).decode("utf-8")

        pdf_name = os.path.splitext(os.path.basename(pdf_path))[0]
        folder = folder_arg if folder_arg else pdf_name

        # Fixed type_of_information in prompt to request 3 distinct categories
        pdf_prompt = f"""Analyze this PDF document and create 60 or more lesson items (depending on how much possible content there is to create, create as much as possible, covering all bases) based on its content.
Return ONLY valid JSON, no markdown fences.
Schema:
{{
    "topic": "string (the main topic of the document)",
    "items": [
        {{
            "id": "string",
            "term": "string (3-34 chars max, no acronyms, alphanumeric+space+hyphen only)",
            "keyword": "string",
            "definition": "string",
            "simple_terms": "string",
            "examples": ["string", "string", "string"],
            "accepted_terms": ["string", "string"],
            "difficulty": 1,
            "related_to": ["string"],
            "type_of_information": ["definition", "explain", "apply"],
            "tof_statement": {{
                "true": "string",
                "false": "string"
            }}
        }}
    ]
}}

Rules:
- `term` must be 3-34 chars and use only letters, numbers, spaces, and hyphens.
- Return a JSON object only.
- terms must not have acronyms accompanying them or with parenthesis (acronyms), instead acronyms, plurals and other similar will be at accepted terms
"""

        body = {
            "contents": [{
                "parts": [
                    {"inline_data": {"mime_type": "application/pdf", "data": pdf_b64}},
                    {"text": pdf_prompt}
                ]
            }],
            "generationConfig": {"temperature": 0.7, "response_mime_type": "application/json"}
        }
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{PDF_MODEL}:generateContent?key={API_KEY}"
        resp = requests.post(url, json=body)
        if resp.status_code != 200:
            print(f"HTTP {resp.status_code} error:")
            print(resp.text)
        resp.raise_for_status()

        root = resp.json()
        text_part = root["candidates"][0]["content"]["parts"][0]["text"]
        parsed = json.loads(text_part)
        topic = parsed.get("topic", pdf_name.replace("_", " ").replace("-", " ").title())
        items = normalize_items(topic, parsed["items"])
        print(f"Detected topic: {topic}")
        print(f"Got {len(items)} items from Gemini")

        out_path = os.path.join(OUTPUT_DIR, folder, f"{sanitize_id(topic)}.tres")
        write_tres(topic, items, out_path)

    else:
        topic = sys.argv[1] if len(sys.argv) > 1 else "Object Oriented Programming"
        count = int(sys.argv[2]) if len(sys.argv) > 2 else 8
        folder = sys.argv[3] if len(sys.argv) > 3 else topic

        print(f"Generating {count} items for topic: {topic}")
        items = call_gemini(topic, count)
        print(f"Got {len(items)} items from Gemini")

        out_path = os.path.join(OUTPUT_DIR, folder, f"{sanitize_id(topic)}.tres")
        write_tres(topic, items, out_path)