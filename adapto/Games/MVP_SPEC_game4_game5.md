# MVP Spec — Game 4 & Game 5

This spec is designed to match the UX quality of `game3` (clear HUD, panel layout, readable typography, strong feedback states) while staying MVP-simple.

---

## Shared Design System (Both Games)

### UX Quality Targets (match `game3`)
- Top HUD with **title, score, timer, streak**.
- Main gameplay area centered and visually dominant.
- Right panel for objectives/help/progress.
- Bottom action bar for input/confirm/reset.
- Color-coded feedback states: neutral, selected, correct, incorrect, solved.
- Smooth but minimal transitions (`Tween` for scale/modulate only).

### Shared Technical Rules
- Lesson source:
  - `Global.selected_lesson` if available
  - fallback: `res://Lessons/lesson_files/Object Oriented/oop.tres`
- Save result payload through `Database.save_user_performance(...)` using per-game key.
- Keep all randomization deterministic per run when needed:
  - `seed(Time.get_unix_time_from_system())` for normal run
  - optional debug seed for QA.
- No new custom resource format needed for MVP.

### Shared Performance Payload Shape
```gdscript
{
  "score": int,
  "correct": int,
  "incorrect": int,
  "accuracy": float,
  "time_spent": int,
  "completed": bool,
  "timestamp": int,
  "lesson_title": String
}
```

---

## Game 4 — Concept Match Rush (Drag & Drop)

## 1) Core Goal
Player matches concept cards into correct pairs under time pressure.

## 2) Why this game
- Adds speed + recognition skill (different from recall-heavy game1/game2).
- Uses existing fields: `term`, `definition`, `simple_terms`.
- Highly visual and polished with moderate implementation cost.

## 3) Scene File
- `res://Games/game4.tscn`
- Script: `res://Games/game_4.gd`

## 4) Scene Tree (MVP)
```text
Game4 (Node2D)
├─ Background (TextureRect)
├─ GameTimer (Timer)
├─ TopBar (PanelContainer)
│  └─ TopBarHBox (HBoxContainer)
│     ├─ TitleLabel (Label)         # "CONCEPT MATCH RUSH"
│     ├─ ScoreLabel (Label)         # "Score: 0"
│     ├─ StreakLabel (Label)        # "Streak: x0"
│     └─ TimerLabel (Label)         # "Time: 120s"
├─ FeedbackLabel (Label)
├─ BoardPanel (PanelContainer)
│  └─ BoardGrid (GridContainer)     # 4 columns, dynamic card buttons
├─ SidePanel (PanelContainer)
│  └─ SideVBox (VBoxContainer)
│     ├─ ObjectiveLabel (Label)
│     ├─ ProgressLabel (Label)      # "Matched: 0/8"
│     └─ MistakeLabel (Label)
├─ BottomBar (PanelContainer)
│  └─ BottomHBox (HBoxContainer)
│     ├─ ShuffleBtn (Button)
│     ├─ HintBtn (Button)
│     └─ SubmitPairBtn (Button)
└─ EndDialog (AcceptDialog)
```

## 5) Data Preparation
Given `lesson.lesson_items`, generate `N` pairs (default `N=8`):
- Pair type A (primary): `term` ↔ `definition`
- Pair type B (fallback diversity): `term` ↔ `simple_terms`

Card model (Dictionary):
```gdscript
{
  "id": int,                # unique card id
  "pair_id": int,           # same for matching pair
  "text": String,
  "kind": String,           # "term" | "definition" | "simple"
  "state": String           # "idle" | "selected" | "solved"
}
```

## 6) Game Loop
1. Build shuffled card set (2N cards).
2. Player selects first card, then second card.
3. If `pair_id` matches and `kind` differs -> mark solved.
4. Else mark incorrect, apply penalty, deselect.
5. Continue until all pairs solved or time ends.

## 7) Scoring Formula (MVP)
- Correct pair: `+100`
- Time bonus on correct: `+max(0, 20 - seconds_since_last_match)`
- Wrong pair: `-35`
- Streak bonus: every 3 consecutive correct matches: `+75`
- Hint used: `-60` and reveal one valid pair for 1.5s

Suggested equation:
```text
final_score = base_correct + streak_bonus + time_bonus - penalties
```

## 8) Difficulty Controls
- Easy: 6 pairs, 150s
- Normal: 8 pairs, 120s
- Hard: 10 pairs, 100s

MVP default: Normal only (add mode selection later).

## 9) Input & State Rules
- Max selected cards = 2.
- Ignore clicks on solved cards.
- During mismatch animation (0.4s), temporarily lock board input.
- `SubmitPairBtn` optional for mobile friendliness; desktop can auto-check at second selection.

## 10) End Conditions
- Win: all pairs solved before timer -> completed true.
- Lose: timer reaches 0 -> completed false.

## 11) Saved Stats Fields
```gdscript
UserStats.game_stats["game4"] = {
  "pairs_total": int,
  "pairs_matched": int,
  "wrong_attempts": int,
  "hints_used": int,
  "max_streak": int,
  "score": int,
  "time_used": int
}
```

## 12) Implementation Steps
1. Create `game4.tscn` with `game3`-style panel structure.
2. Implement card generation + board rendering.
3. Implement selection/match resolution.
4. Add timer + score + streak updates.
5. Add result dialog + scene exit.
6. Save performance to DB.

---

## Game 5 — Relationship Path Builder (Concept Chain)

## 1) Core Goal
Player builds a valid shortest path from Start concept to End concept using concept nodes linked by `related_to`.

## 2) Why this game
- Adds systems-thinking and conceptual reasoning.
- Strongly uses your data model’s `related_to` graph.
- Feels premium with clean node-link board UI.

## 3) Scene File
- `res://Games/game5.tscn`
- Script: `res://Games/game_5.gd`

## 4) Scene Tree (MVP)
```text
Game5 (Node2D)
├─ Background (TextureRect)
├─ GameTimer (Timer)
├─ TopBar (PanelContainer)
│  └─ TopBarHBox (HBoxContainer)
│     ├─ TitleLabel (Label)         # "RELATIONSHIP PATH BUILDER"
│     ├─ ScoreLabel (Label)
│     ├─ MovesLabel (Label)         # "Moves: 0"
│     └─ TimerLabel (Label)
├─ FeedbackLabel (Label)
├─ PuzzlePanel (PanelContainer)
│  ├─ StartLabel (Label)
│  ├─ EndLabel (Label)
│  ├─ GraphBoard (Control)          # draws links + node pills
│  └─ CurrentPathLabel (Label)      # shows selected chain text
├─ SidePanel (PanelContainer)
│  └─ SideVBox (VBoxContainer)
│     ├─ GoalLabel (Label)
│     ├─ OptimalLabel (Label)       # hidden until end or hint
│     └─ AttemptsLabel (Label)
├─ BottomBar (PanelContainer)
│  └─ BottomHBox (HBoxContainer)
│     ├─ UndoBtn (Button)
│     ├─ ResetPathBtn (Button)
│     ├─ HintBtn (Button)
│     └─ SubmitPathBtn (Button)
└─ EndDialog (AcceptDialog)
```

## 5) Data Preparation (Graph)
Construct a graph from lesson items:
- Node = `item.term`
- Edge if:
  - direct overlap in `related_to`, OR
  - one term appears in another’s `related_to`.

Graph structure:
```gdscript
adj: Dictionary[String, Array[String]]
```

Pick puzzle:
1. Choose candidate terms with degree >= 2.
2. Randomly pick start/end that are connected.
3. Compute shortest path length via BFS (`optimal_len`).
4. Accept puzzle if `optimal_len` between 3 and 6 edges.

## 6) Gameplay Loop
1. Show start + end and clickable graph nodes.
2. Player builds path by selecting adjacent nodes.
3. `SubmitPath` validates:
   - starts with start term
   - ends with end term
   - every consecutive step is connected
4. Score based on optimality and time.
5. Repeat for 3 rounds (MVP can start with 1 round).

## 7) Scoring Formula (MVP)
For one round:
- Base clear: `+300`
- Efficiency bonus:
  - let `player_len` = edges used
  - let `optimal_len` = BFS shortest
  - `efficiency_bonus = max(0, (optimal_len * 80) - ((player_len - optimal_len) * 60))`
- Time bonus: `+max(0, 120 - seconds_used)`
- Hint penalty: `-100` each
- Invalid submit penalty: `-40`

Equation:
```text
round_score = 300 + efficiency_bonus + time_bonus - penalties
```

## 8) Hint Behavior (MVP)
- Reveal one valid next node from current node toward shortest path.
- Consume hint count and apply score penalty.

## 9) Input/Validation Rules
- Node selection allowed only if adjacent to last selected node.
- `Undo` removes last node in current path.
- `Reset` keeps start node, clears rest.
- Prevent duplicate loops in path for MVP simplicity.

## 10) End Conditions
- Win: valid completed path submitted before timer.
- Lose: timer ends.

## 11) Saved Stats Fields
```gdscript
UserStats.game_stats["game5"] = {
  "optimal_len": int,
  "player_len": int,
  "extra_steps": int,
  "invalid_submits": int,
  "hints_used": int,
  "score": int,
  "time_used": int,
  "completed": bool
}
```

## 12) Implementation Steps
1. Create `game5.tscn` with same panel quality/structure as `game3`.
2. Implement graph build from lesson items.
3. Implement BFS shortest path utility.
4. Implement node click path builder + validation.
5. Add scoring/timer/end dialog.
6. Persist performance.

---

## Minimal Integration Tasks (Menu + Flow)

1. Add two buttons in main menu:
- `Game4Button` -> `res://Games/game4.tscn`
- `Game5Button` -> `res://Games/game5.tscn`

2. Ensure `Global.selected_lesson` is respected in both scripts.

3. Add basic post-game return flow:
- Either go back to `main_menu.tscn`
- Or optional shared stats scene later.

---

## MVP Definition of Done

- Both games playable end-to-end with selected lesson.
- No hard crash when lesson has sparse `related_to`; graceful fallback message.
- Timer, score, feedback, and end dialog functional.
- Save performance payload for current user.
- Visual quality is consistent with `game3` (panel hierarchy, readability, responsive feedback).

---

## Post-MVP Upgrades (Later)
- Daily challenge seed.
- Difficulty presets UI.
- Combo VFX / audio polish.
- Multi-round tournament mode combining game4 + game5.
