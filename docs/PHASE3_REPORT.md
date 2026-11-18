# Phase 3 Report — Advanced Combat Systems

Status: **Implemented and tested (headless and rendered on desktop). Awaiting approval before Phase 4.**
Date: 2026-11-11 · Godot 4.7.2

## How to run / verify

- **Play:** run the game and choose **Combat Lab (Phase 3 test)** from the menu. It has all 4 towers, all 10 enemies, both Monolith variants and 2500 starting currency.
- **Tests:**

  ```bash
  godot --headless --path . -s res://tests/run_tests.gd
  ```

- **Screenshots:**

  ```bash
  godot --path . -s res://tools/capture_lab.gd -- --out=<dir>
  ```

- **Tower panel:** tap a tower. The panel shows 3 branches, evolution and Sell (tap Sell twice to confirm). The panel docks at the top when the tower is in the lower part of the map.

## Implemented

| Area | Content |
|---|---|
| Towers (4) | Pulse, Nova, **Lance** (Energy, armor pen, Strongest targeting), **Beacon** (aura: 20% slow + stealth reveal) |
| Branches (12) | 3 per tower × 3 tiers, as designed in Phase 1 §6.3. Each tier changes real behaviour through parameters (`docs/COMBAT_PARAMS.md`) |
| Branch locking | The first purchase permanently commits the tower. Other branches show "Locked". No crosspathing or switching |
| Research gate | Branch C and evolutions are checked against `UpgradeRules.Unlocks`. Phase 3 default: all unlocked; Phase 4 wires it to meta progression |
| Evolutions (12) | Storm Array, Railspike, Hunter Net, Cascade, Inferno, Quake, Annihilator, Tesla Web, Phase Beam, Overclock Core, Absolute Zero, Mint. Requirements: T3 + research + 2 waves at T3 + cost. **Cap of 2 alive per match** |
| Enemies (10) | Drone, Dart, Brute, **Swarmling**, **Plated** (armor 8), **Aegis** (regenerating shield), **Glider** (flying, air route), **Phantom** (stealth), **Mender** (heals 5 allies), **Monolith** boss |
| Boss | Phase I: summons 4 (1.5 s telegraph). Phase II: EMP disrupts towers within r170 for 3 s (2 s ring telegraph). Phase III: +30% speed, then splits into 3 Shards on death. 25% slow cap, stun immune (Stagger instead). L6 variant: 4500 HP, phases I–II, no split |
| Status effects | Slow (aura), Burn, Mark, Shred, Stun, Freeze, Stagger, Reveal (+1.5 s linger), Grounded, tower Disruption |
| Synergy | Amplifier buffs (strongest-only, caps, no Beacon→Beacon); combos (Cryo + splash, Mark + Lance, Shred + Pulse, Burn vs healing); special interactions **Grounded / Conductive / Shatter / Meltdown** |
| Selling | Fixed 70%, exactly once, with the exact refund shown; frees the footprint; removes in-flight shots, fire patches and delayed detonations; disabled while paused |
| UI | Bottom/top tower panel; boss HP bar with phase and EMP warning; synergy toasts; tier pips, evolution ring, buff markers and disruption ring on towers; status pips on enemies; link lines/rings to buff sources |

## Tests executed (real output)

`78 passed, 0 failed (31.4 s)`. There were 0 `SCRIPT ERROR` lines in the run log. The game launches with no errors.

**New in Phase 3 (37 tests):**
- **Upgrades:**
  - branch lock and max tier; currency and pause gating; branch C research lock;
  - Cluster III Flak really hits air;
  - evolution requirements (branch → T3 → research → calibration → cap 2 → cost);
  - the Storm Array burst fires.
- **Enemies:**
  - armor vs Pulse/Lance;
  - shield: Energy ×2, leftover goes through armor, regenerates after 3 s, capped;
  - air route plus ground-only restriction;
  - stealth: hidden → reveal → linger → expire, and splash still hits hidden units;
  - Mender heals the 5 most damaged allies, never itself, burning allies at half;
  - status refresh/max/shred cap/expiry.
- **Boss:** summon after telegraph with no bounty; EMP hits only towers in range and they stop firing for 3 s; fracture speed, slow cap, stun immunity and 3 shards; L6 variant has 2 phases and no split.
- **Synergy:**
  - strongest-only Amplifier, no Beacon buffs, buffs removed on sell, caps;
  - aura slow vanishes on sell;
  - **Inferno never chains**;
  - Shatter; Cryo freeze skips the boss; Grounded → Nova fires; Conductive prefers Chilled (+1 bonus); Meltdown;
  - Relay diminishing income paid once per wave;
  - Focus ramp/cap.
- **Selling:** 70% including upgrades and evolution, once only; footprint freed and projectiles removed; fire patches removed; paused.

**Counter simulations** (same budget, Circuit map, scripted bot — evidence, not balance):

| Threat | Weak answer | Counter |
|---|---|---|
| 12 Plated | 4× Pulse: 1 kill, 22 HP leaked | 2× Lance: 7 kills, 10 HP leaked |
| 12 Glider | 2× Nova: 0 kills, 24 HP leaked | 4× Pulse: 12 kills, 0 HP leaked |
| 10 Phantom | 4× Pulse: 0 kills, 20 HP leaked | Beacon + 3 Pulse: 8 kills, 4 HP leaked |
| 10 Aegis | 2× Nova: 1 kill, 18 HP leaked | 2× Lance: 7 kills, 6 HP leaked |

Additional runs:
- **Monolith (12,000 HP, all 3 phases + shards) with a 9000 budget:** WON, 0 HP leaked, so the boss can be beaten through legitimate play.
- **Combat Lab with the mixed bot:** WON 20/40 HP, 214 kills.
- **L1 and L2** still win 20/20.

**Rendered screenshots:** `docs/phase3_screens/` (fliers, Lance panel, Amplifier links, boss EMP telegraph, final boss, results).

## Known issues / limitations

1. **Balance is provisional.** The Monolith test used a generous 9000 budget. Real campaign budgets are tuned in Phase 4/7, which I expect to need iteration (the boss is tanky).
2. **The bot does not exercise every evolution or interaction** in full-level runs (`interactions: {}` in the Lab run). Those mechanics are covered by unit tests, not by level-scale play.
3. **Panel layout:** the bottom panel covers part of the lower path when it docks at the bottom. Phase 5 handles layout polish and real phone sizes.
4. **The Beacon role text** still says "slows 20%" after Amplifier/Relay removes the slow. The stats line is correct; I'll fix the copy in Phase 5.
5. **Circuit has no authored air route**, so fliers cross the map diagonally. Phase 4 maps will author air routes.
6. **Design deviations to approve:**
   - **Boss-summoned Swarmlings give no bounty.** The design said "no bounty after boss death"; this is simpler and anti-farm.
   - **Shards** are generated from the Monolith's data, not as an 11th enemy type, to keep the roster at 10.
   - **The evolution cap counts alive evolved towers**, so selling one frees a slot.
7. **Still not covered:** real-device input, audio, persistence, GameHub integration and performance profiling, which belong to later phases.
