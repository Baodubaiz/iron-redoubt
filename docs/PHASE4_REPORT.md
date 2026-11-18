# Phase 4 Report — Campaign & Progression

Status: **Implemented and tested (headless + rendered on desktop). Awaiting approval before Phase 5.**
Date: 2026-11-11 · Godot 4.7.2

## How to run / verify

- **Play:** Main menu → **Campaign** (L1 open, the rest unlock in order), **Research**, **Challenges & Achievements**. **Combat Lab (dev)** appears in debug builds only.
- **Tests:**

  ```bash
  godot --headless --path . -s res://tests/run_tests.gd
  ```

- **Balance simulation** (add `--meta` for a full-research profile):

  ```bash
  godot --headless --path . -s res://tools/sim/campaign_sim.gd -- --seeds=1,2 [--trace]
  ```

- **Screenshots** (uses a throwaway profile, not yours):

  ```bash
  godot --path . -s res://tools/capture_p4.gd -- --out=<dir> --profile=<dir>/p.json
  ```

- **Profile file:** `user://profile.json` (Windows: `%APPDATA%\Godot\app_userdata\game-test\profile.json`). Delete it to reset progress.

## Implemented

### Maps (3)

| Map | Layout | Mechanics |
|---|---|---|
| **Circuit** | Single serpentine path + authored air route | **Overload nodes:** 3 zones giving +15% range. Blocked terrain |
| **Delta** | Two entrances merging into a winding tail | **Day/Night:** night waves give −20% range unless the tower is in Beacon light; Phantoms appear at night. Prep announces Day/Night |
| **Prism** | Two alternative routes around a central island + southern air corridor | **Shifting gates:** the open route switches at authored waves, announced in prep ("Gate: route South"). Both routes stay non-buildable |

### Campaign (9 levels)

| Lvl | Map | New threats | Waves | Start | HP | Unlock / Cores |
|---|---|---|---:|---:|---:|---|
| 1 | Circuit | Drone, Dart | 8 | 350 | 20 | L2 · 10 |
| 2 | Circuit | Brute, Swarmling | 10 | 350 | 20 | **Lance** · 10 |
| 3 | Circuit | Plated, Glider | 12 | 400 | 20 | **Beacon** · 15 |
| 4 | Delta | Phantom (night) | 12 | 500 | 20 | 15 |
| 5 | Delta | Aegis | 14 | 500 | 20 | 20 |
| 6 | Delta | Mender, **Monolith (I–II)** | 15 | 550 | 25 | Prism · 30 |
| 7 | Prism | Glider-heavy, gates | 15 | 550 | 20 | 25 |
| 8 | Prism | Elite mixes, 3 switches | 18 | 600 | 20 | 30 |
| 9 | Prism | Everything, **Monolith (I–III)** | 20 | 650 | 30 | 50 |

### Waves

- **Hybrid waves:** waves are authored in a compact DSL (`tools/author_data.gd`) and saved as concrete `.tres` data.
- **Randomness:** non-special groups with 6 or more enemies vary by ±10% in count and timing, seeded per match. Special and boss waves are fixed.

### Meta progression (persistent Cores)

- **Sources:**
  - first clear;
  - replay: 25% of the first-clear reward, once per match;
  - flawless bonus: 5, once per level;
  - achievements;
  - challenges.
- **Research (13 nodes):**
  - 4 third-branch unlocks;
  - 4 evolution unlocks;
  - Reserve Funds I/II (+25 / +50 currency);
  - Reinforced Core (+3 HP);
  - Quick Deploy (+25% early bonus);
  - Field Scanner (next-wave preview).
- **Tower unlocks:** Lance on clearing L2, Beacon on clearing L3.

### Achievements (12)

All 12 come from Phase 1 §11 and are evaluated from real match results and lifetime counters.

### Challenges

- **Pools:** 12 daily and 8 weekly. Each is a level plus restrictions: banned towers, HP cap, currency multiplier, no selling, or a time limit.
- **Scheduling:** deterministic per UTC day and per week starting Monday. The reward can be claimed once per period, and challenge runs never count as campaign clears.

### Persistence

- **Store boundary:** `ProgressionStore` with `LocalFileStore` (atomic temp+rename, `.bak` backup) and `MemoryStore` (tests). This is **local only — not account sync** (Phase 6).
- **Integrity:**
  - **Cores** are the sum of an idempotent ledger, so a duplicate reward key never pays twice.
  - **Match results** carry a match id, and duplicate submissions are ignored.
  - **Saves** use optimistic revisions. On conflict the client does a monotonic merge (union and max), so progress is never lost or duplicated.
  - **Corrupted or invalid data** is sanitized, and the menu shows a warning.
  - **A failed save** stays pending and retries on the next save or when the app is backgrounded.

### UI

- Main menu, campaign select (lock state, best HP, flawless star, objective, rewards), research, and challenges & achievements.
- Results show Cores earned, unlocks and achievements, plus **Next level**.
- The HUD shows Day/Night, gate, BOSS and scanner info during prep.

## Tests executed (real output)

`101 passed, 0 failed (99.4 s)`. There were 0 `SCRIPT ERROR` lines in the run log. The game launches with no errors.

New in Phase 4 (23 tests):

- **Persistence:**
  - fresh unlocks; clear unlocks the next level and tower once; replay reward;
  - **duplicate submission ignored**; **replay never regresses** (a later loss never un-clears);
  - flawless bonus once;
  - research rules (cost, prerequisite, tower requirement, no double buy) and research applied to the match (currency, HP, early bonus, branch C, tower ownership);
  - ledger merge is idempotent;
  - **interrupted save → pending → retry**;
  - **stale save → merge**: two devices, nothing lost, nothing duplicated;
  - corrupted/invalid data sanitized;
  - file store roundtrip with backup recovery.
- **Achievements:** unlock once from real events, lifetime counters, boss timer.
- **Challenges:** deterministic schedule and week boundaries; claimed once per period and not a campaign clear; modifiers enforced (ban, HP cap, currency, no selling).
- **Map mechanics:** Overload +15%; night dims only unlit towers, and selling the Beacon removes its light; day not dimmed; gate switches the route for new spawns; closed route stays unbuildable; campaign data consistency (9 levels, 3 per map, 2 boss levels, catalogue sizes).
- **Integration:** **all 9 levels completed by a scripted bot with NO meta** (no research, only the towers owned at that point).

**Balance simulation** (no meta, adaptive bot, seeds 1 and 2):

| Level | Strategies that won (of 3) | Typical HP left |
|---|---|---|
| L1–L3 | 3/3 | 18–20 / 20 (tutorial curve, intentionally easy) |
| L4 | 2/3 | 12–16 / 20 |
| L5 | 3/3 | 6–20 / 20 |
| L6 | 2/3 | 1–7 / 25 (boss level, tight) |
| L7 | 3/3 (balanced won only seed 1) | 2–20 / 20 |
| L8 | 3/3 | 4–20 / 20 |
| L9 | **1/3** (heavy, both seeds) | 2–8 / 30 |

With full research (`--meta`), L6 is easier (24/28 HP). L9 is still won only by the heavy strategy.

## Known issues / limitations

1. **L9 is hard for splash-oriented play:** only 1 of 3 bot strategies wins without meta. I left it as the culmination; Phase 7 should re-tune it with human playtests.
2. **The bot "knows" upcoming waves** (an experienced player). First-time players without Field Scanner face more uncertainty. Human playtesting is still needed.
3. **Challenge feasibility is not simulated** (e.g. "L3 without Pulse"). Some may be too hard or impossible and need checking in Phase 7.
4. **Profile and schedule are local:**
   - The device clock drives challenges (spoofable).
   - `user://profile.json` can be edited by the player.
   - The backend must be authoritative (Phase 6).
5. **The Delta night tint is subtle.** The text indicator is clear, but the visual will get polish in Phase 5.
6. **Map and route changes from Phase 3:**
   - Circuit got an authored air route.
   - Delta and Prism were lengthened or reshaped after simulations showed paths that were too short.
   - Level wave counts were scaled by tuning factors (documented in `author_data.gd`).
7. **Layout is not yet adapted to real phone aspect ratios or safe areas** (Phase 5).
