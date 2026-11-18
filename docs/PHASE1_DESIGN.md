# Tower Defense for GameHub — Phase 1: Technical Design & Implementation Plan

Status: **PROPOSAL — awaiting approval. No gameplay code has been written.**
Date: 2026-11-11

All numbers in this document are **provisional starting values** for implementation. They are not validated balance. Phase 7 validates them with simulation and playtesting.

---

## 1. Repository Inspection — Findings (verified)

| Item | Finding |
|---|---|
| Project path | `C:\linhtinh\game defence test\game-test` |
| Contents | `project.godot`, `icon.svg`, `.editorconfig`, `.gitattributes`, `.gitignore`, `.godot/` cache. **No scenes, scripts, resources, addons or docs.** |
| Godot | Project created with **4.7** (`config/features = "4.7"`). Local editor found at `C:\code\godot\Godot_v4.7.2-stable_win64.exe\` → `4.7.2.stable.official.ed1daf0bf`. Headless launch works ("no main scene defined", as expected). |
| Renderer | `gl_compatibility` for desktop and mobile. This is a good choice for broad Android/iOS support, so we keep it. |
| Stretch | `canvas_items` + `expand`. We keep it and add a landscape orientation and a base resolution. |
| Physics | Jolt (3D) is configured. It is irrelevant to a 2D game, and leaving it in is harmless. |
| GameHub | **No GameHub files, SDK, API docs, contracts, host app or backend references exist in this workspace.** The parent folder holds only this project. |
| Version control | **Not a git repository.** (`.gitignore` / `.gitattributes` exist but no `.git`.) |
| Android toolchain | JDK found (`C:\code\java`, Temurin 21.0.12). **No Android SDK** (`ANDROID_HOME` unset) and **no Godot export templates installed**. |
| iOS toolchain | Not possible on this Windows machine. iOS export requires macOS + Xcode. |

**Conclusion:** this is a greenfield Godot project. Nothing exists that needs replacing. Every GameHub integration detail is **unknown**, and Section 11 covers it.

---

## 2. Technical Foundations

- **Engine:** Godot 4.7.2, GDScript with static typing (`var x: int`) throughout, for safety and performance.
- **Base resolution:** 1280×720 logical, landscape (`display/window/handheld/orientation = landscape`), stretch `canvas_items`/`expand`. All gameplay maps are authored in a 1280×720 world space. **No camera scrolling or zoom in V1.** The whole map fits on screen, which avoids pinch/drag gesture conflicts with drag-placement.
- **Simulation tick:** all gameplay runs in `_physics_process` at a fixed 60 Hz, using our own accumulators instead of `SceneTreeTimer`. Pause therefore becomes one switch (`get_tree().paused`), and the combat core can run headless for tests and balance simulation.
- **Pause model:** gameplay nodes use `PROCESS_MODE_PAUSABLE`. The pause menu, HUD pause button and settings use `PROCESS_MODE_ALWAYS`. All build/upgrade/sell commands go through one `MatchController.can_issue_commands()` gate that returns false while paused or after the match ends.
- **Seeded randomness:** each match attempt has a seed (`RandomNumberGenerator`). Wave variance draws only from the match RNG, so a run is reproducible in tests and bug reports.

---

## 3. Architecture

### 3.1 Folder structure

```
res://
  core/                  # Autoloads + shared utilities
    event_bus.gd         # global signals (match_won, level_completed, achievement_progress...)
    scene_router.gd      # scene transitions, passes LevelDef into Match
    settings.gd          # audio/UI settings, persisted to user://settings.cfg
    audio_manager.gd     # music + pooled SFX players, voice limiting
    rng_util.gd, geometry.gd
  data/
    defs/                # Resource class scripts (schemas)
      tower_def.gd  branch_def.gd  tier_def.gd  evolution_def.gd
      enemy_def.gd  wave_def.gd  spawn_group_def.gd  level_def.gd  map_def.gd
      economy_config.gd  research_def.gd  achievement_def.gd  challenge_def.gd
    towers/*.tres  enemies/*.tres  levels/*.tres  maps/*.tres
    meta/research/*.tres  meta/achievements/*.tres  meta/challenges/*.tres
    economy.tres
  gameplay/
    match/      match.tscn, match_controller.gd, match_state.gd (state machine)
    combat/     tower.gd/.tscn, enemy.gd/.tscn, projectile.gd, damage.gd (DamageInfo + resolver),
                status_effects.gd, targeting.gd, enemy_registry.gd (spatial hash)
    systems/    placement_system.gd, wave_manager.gd, match_economy.gd, upgrade_system.gd,
                synergy_system.gd, base_core.gd, projectile_pool.gd
    maps/       map_circuit.tscn, map_delta.tscn, map_prism.tscn, mechanics/*.gd
  campaign/     progression_service.gd (autoload "Progression"), research.gd, unlocks.gd,
                achievements.gd, challenges.gd
  ui/           main_menu, campaign_select, research, achievements_challenges, hud,
                tower_palette, tower_panel (bottom), placement_overlay, pause_menu, results,
                settings, theme/td_theme.tres
  integration/  gamehub_adapter.gd (interface), mock_gamehub_adapter.gd (DEV ONLY),
                launch_context.gd, progression_repository.gd, sync_queue.gd
  audio/        sfx/*.wav  music/*.ogg  LICENSES.md
  tests/        run_tests.gd (headless runner), unit/, integration/
  tools/        sim/ (headless balance simulator), audio_gen/ (original SFX synthesis)
  docs/
```

### 3.2 Autoloads (kept minimal)
`EventBus`, `Settings`, `AudioManager`, `SceneRouter`, `GameHub` (holds the active adapter), `Progression`.

### 3.3 Match scene composition
```
Match (MatchController)            — owns MatchState: PREP → WAVE_ACTIVE → PREP ... → WON | LOST
 ├─ Map (MapDef instance: routes, blocked areas, mechanics)
 ├─ EnemyRegistry                  — spatial hash (64px cells), alive list, path-progress
 ├─ WaveManager                    — reads WaveDefs, spawns, prep countdown, early start
 ├─ MatchEconomy                   — single authority for currency; every change is a ledger entry
 ├─ BaseCore                       — Base HP, escape damage, defeat trigger
 ├─ PlacementSystem                — footprint validation, ghost preview, commit
 ├─ UpgradeSystem / SynergySystem  — branch locking, evolution, aura bookkeeping
 ├─ Towers (Node2D)  Enemies (Node2D)  Projectiles (pooled)
 └─ UI layer (HUD, palette, bottom panel, pause) — talks to systems through commands/signals only
```

### 3.4 Key design rules
- **Logic vs presentation:** `tower.gd` / `enemy.gd` hold state and rules. A child `*_visual.gd` draws geometry with `_draw()` and reacts to signals. Tests instantiate the logic without the visuals.
- **Data-driven:** towers, branches, tiers, enemies, waves, levels, maps, economy, research, achievements and challenges are `.tres` Resources. Combat scripts contain no level content.
- **Single currency authority:** only `MatchEconomy.try_spend(amount, reason) -> bool` and `credit(amount, reason, idempotency_key)` touch currency. The key (e.g. `kill:<enemy_uid>`, `wave:<n>`, `early:<n>`, `sell:<tower_uid>`) is recorded, so a duplicate event cannot pay twice.
- **Entity lifecycle:** enemies and towers get a monotonic `uid`. Death, escape and sale are each terminal state transitions guarded by `if state != ALIVE: return`, so each happens exactly once. Towers keep `uid` and weakref targets, never raw references to freed nodes.
- **Avoided on purpose:** a DI framework, an ECS rewrite, and generic "ability graph" systems. These add complexity without a concrete V1 benefit.

### 3.5 Paths & placement geometry
- Each route is a `Path2D`/`Curve2D`. Enemies store `progress` (distance along the baked curve), and "furthest along" is a float compare.
- Ground paths are non-buildable bands (half-width 26 px). Air routes are polylines that **are buildable** (fliers pass over towers).
- **Tower footprint:** a circle of radius 22 px (the same for all four towers, so the rule is easy to learn).
- **Placement is valid iff:** inside the playable rect (minus HUD safe margins) AND distance to every ground-route segment ≥ 26 + 22 AND outside all blocked polygons (inflated by 22) AND distance to every other tower centre ≥ 44 AND the map mechanics allow it. Dynamic routes: **all alternate routes stay non-buildable at all times**, so towers can never block a route.
- Validation is pure geometry (no physics bodies), unit-testable, and runs only when the finger moves.

### 3.6 Performance approach
- **Targeting:** towers re-acquire targets every 0.1 s (not every frame) using `EnemyRegistry.query_circle()` over spatial-hash cells. They keep the current target while it stays valid.
- **Pooling:** projectiles and hit-flash effects are pooled. Enemies are pooled per type (swarms spawn in bursts).
- **Rendering:** cached `_draw()` geometry with no per-frame redraw unless state changes. Rotation goes through the transform. There are no particles and no custom shaders except an optional single cheap glow.
- **Audio:** max 2 concurrent voices per SFX id, max 12 total, 40 ms retrigger cooldown per id.
- **Lifecycle:** `NOTIFICATION_APPLICATION_PAUSED` / focus-out auto-pauses the match and flushes the save/sync queue.

**Proposed targets (to be measured, not assumed):**

| Metric | Target |
|---|---|
| Frame rate, mid-range Android (e.g. Snapdragon 7-series / Helio G9x class, 2021+) | 60 FPS sustained in the heaviest wave (≈150 enemies, 40 towers, 200 projectiles) |
| Low-end Android (≈2019, 3 GB RAM) | ≥ 30 FPS floor |
| iPhone (A13 or newer) | 60 FPS |
| Frame time spikes | < 33 ms, at most 1 per 10 s in heavy waves |
| Touch-to-ghost latency | ≤ 1 frame |
| RAM | < 250 MB |
| Export size | APK < 60 MB |

I need to know which physical test devices you have available.

---

## 4. Combat Model

### 4.1 Damage & defence
- **Damage types:** `KINETIC` (Pulse), `EXPLOSIVE` (Nova), `ENERGY` (Lance), `TRUE` (burn/DoT, ignores armor).
- **Armor (flat per hit):** `dealt = max(dmg − max(armor − pen, 0), dmg × 0.25)`. Even a mismatched attack therefore deals 25% damage. Many small hits are weak against armor, and big or piercing hits are strong.
- **Shield (Aegis):** a separate pool that absorbs damage first. Armor does not apply to the shield. ENERGY deals ×2 to shields. It regenerates after 3 s without taking damage.
- **Mark:** the target takes +X% damage from all sources.
- **Detection:** `STEALTH` enemies can only be **targeted** while *Revealed* (inside a reveal aura, plus a 1.5 s linger). **Area damage still hurts unrevealed stealth enemies** inside the blast. This is a soft counter.
- **Flying:** each tower has `can_target_air`. Fliers follow the map's air route, ignore ground slows from terrain, and are affected by Beacon slow.

### 4.2 Status effect policy (anti-stacking / anti-loop)
- One instance per status per enemy. Re-application **refreshes the duration and keeps the highest magnitude**; same-type magnitudes are never summed.
- Exception: **Shred** stacks up to a defined cap (−6 armor).
- **Caps:** slow ≤ 60% (bosses ≤ 25%). Bosses are immune to Stun/Freeze but take a short "Staggered" 15% slow instead.
- **Secondary damage** (explosions caused by deaths, chain hits, burn ticks) is tagged `is_secondary = true`. It **never triggers on-hit or on-death effects**, which prevents recursion (e.g. Inferno explosions cannot chain into more Inferno explosions).

### 4.3 Automatic targeting
There are no player-facing priority controls. Each tower type has a fixed rule:

| Tower | Rule |
|---|---|
| Pulse | First: furthest along the path |
| Nova | Densest: picks the target among the first 3 that has the most enemies within splash radius |
| Lance | Strongest: highest current HP + shield. Fliers are tie-broken first |
| Beacon | Aura (no target) |

---

## 5. Tower Roster (4)

All towers use a 22 px footprint. Silhouettes and colours are distinct, and shapes never rely on colour alone.

| Tower | Shape / colour | Role | Cost | Damage | Rate | Range | Air | Sees stealth | Strengths | Weaknesses |
|---|---|---|---:|---|---:|---:|:-:|:-:|---|---|
| **Pulse** | Triangle, cyan | Cheap single-target DPS | 100 | 12 Kinetic | 2.0/s | 150 | ✔ | ✘ | Fast, hits air, cheap early defence | Very weak vs armor |
| **Nova** | Square, orange | Splash crowd control | 175 | 30 Explosive, r 55 | 0.6/s | 170 | ✘ | splash only | Swarms, clumps, hurts hidden stealth | Can't hit air (base), slow fire |
| **Lance** | Diamond, magenta | Long-range armor-piercing | 225 | 80 Energy, pen 6 | 0.4/s | 240 | ✔ | ✘ | Armor, shields, boss | Overkill on swarms, slow |
| **Beacon** | Circle with ring, green | Support / control aura | 150 | — | aura | 130 | ✔ | ✔ reveals | Slow 20% + stealth reveal in aura | No damage; useless alone |

**Threat → counter coverage check:**

| Threat | Primary counter | Secondary counter |
|---|---|---|
| Armor (Plated) | Lance | Nova Shred branch, Pulse Penetrator branch |
| Shields (Aegis) | Lance (×2 vs shield) | Sustained Pulse Rapid fire |
| Flying (Glider) | Pulse | Lance, Nova Cluster T3 (flak), Pulse Hunter Net grounding |
| Stealth (Phantom) | Beacon reveal + any tower | Pulse Sensor branch, Nova splash |
| Healing (Mender) | Burst (Lance) / focus | Nova Incendiary (−50% healing on burning targets) |
| Swarms | Nova | Lance Arc branch, Pulse Rapid |
| Boss | Lance Overcharge/Focus, Amplifier | Nova Shred, Cryo, spread placement vs EMP |

**Unlock order:** Pulse and Nova from the start. Lance unlocks on clearing L2 (before Plated appears in L3). Beacon unlocks on clearing L3 (before Phantom appears in L4). The counter to each new threat is therefore always available before that threat appears.

---

## 6. Upgrade Branches, Evolution & Synergy

### 6.1 Structure
- **3 branches per tower × 3 tiers each**, plus **1 Evolution per branch** (the capstone). Buying a branch's Tier 1 **permanently locks the other two branches** for that tower instance. There is no crosspathing.
- **Costs** relative to the tower's base cost: T1 ≈ 0.7×, T2 ≈ 1.3×, T3 ≈ 2.4×, Evolution ≈ 4.0×.
- The UI shows the stat deltas, the new behaviour text and the cost for every option before purchase. Unaffordable options are greyed out with the exact shortfall.
- **Branch C of each tower** is unlocked via research (meta-progression option unlock). Branches A and B are available as soon as the tower is unlocked.

### 6.2 Evolution rules
- **Requirements:** branch at T3, Evolution unlocked in research for that tower, the cost paid, and the tower has existed through **≥ 2 completed waves since reaching T3** (a "Calibrating" progress pip shows this).
- **Limit:** at most **2 evolved towers per match** across all types. This prevents a single mass-evolution setup and keeps base/T3 towers relevant.
- An evolution changes mechanics, not just numbers (see the tables).

### 6.3 Branch definitions (provisional values)

**Pulse (base cost 100)** — upgrade costs 70 / 130 / 240, Evolution 400

| Branch | T1 | T2 | T3 | Evolution | Trade-off |
|---|---|---|---|---|---|
| **A Rapid** | rate 2.6 | rate 3.4 | rate 4.5, dmg 14 | **Storm Array:** every 20th shot fires a 6-way burst | Highest DPS, still terrible vs armor |
| **B Penetrator** | dmg 20, pen 2 | dmg 30, pen 4, rate 1.6 | dmg 45, pen 6, range 180 | **Railspike:** shots pierce up to 3 enemies in a line | Good vs armor, lower rate, weak vs swarms |
| **C Sensor** *(research)* | reveal aura r 90 | shots Mark +15% (3 s) | Mark +25%, +50% dmg vs air | **Hunter Net:** marked fliers are *Grounded* for 3 s (become hittable by ground-only towers) | Low raw damage, enables the team |

**Nova (175)** — 120 / 230 / 420, Evolution 700

| Branch | T1 | T2 | T3 | Evolution | Trade-off |
|---|---|---|---|---|---|
| **A Cluster** | radius 70 | +3 bomblets (10 dmg each) | radius 85, dmg 45, **Flak: can target air** | **Cascade:** every 3rd shell detonates a second time after 0.5 s | Best wave clear, no control |
| **B Incendiary** | Burn 6/s TRUE (3 s), burning targets get −50% healing | Burn 10/s | leaves a fire patch (2 s, r 40) | **Inferno:** burning enemies explode on death (30 splash, secondary) | DoT is slow to kill fast enemies |
| **C Siege** *(research)* | Shred −2 armor/hit (stacks, cap −6) | range 220 | dmg 60, Stagger 0.3 s | **Quake:** every 4th shell stuns non-boss ground enemies for 0.8 s | Slowest fire rate, small radius |

**Lance (225)** — 160 / 300 / 540, Evolution 900

| Branch | T1 | T2 | T3 | Evolution | Trade-off |
|---|---|---|---|---|---|
| **A Overcharge** | dmg 120 | dmg 170, pen 8 | dmg 240, +25% vs boss | **Annihilator:** every 4th shot deals ×3 damage | Massive overkill on small enemies |
| **B Arc** | chains to 2 more (60% falloff) | chains to 3 | chains to 4, ×3 vs shields on chain hits | **Tesla Web:** chains jump +2 between *Chilled* enemies and Stagger | Lower single-target DPS |
| **C Focus** *(research)* | continuous beam, dmg ramps up to ×3 over 3 s on the same target | range 280 | ramp up to ×4 | **Phase Beam:** the beam pierces everything along its line | Ramp resets on target switch, bad vs swarms |

**Beacon (150)** — 100 / 190 / 350, Evolution 600

| Branch | T1 | T2 | T3 | Evolution | Trade-off |
|---|---|---|---|---|---|
| **A Amplifier** | nearby towers +10% dmg *(slow removed)* | +15% dmg | +20% dmg, +10% range | **Overclock Core:** also +15% attack rate | Pure support, no control |
| **B Cryo** | slow 30% | slow 40% | slow 50%; Chill builds → Freeze 1 s every 6 s (non-boss) | **Absolute Zero:** Frozen enemies take +50% explosive (*Shatter*) | No buffs |
| **C Relay** *(research)* | +10 currency per completed wave *(slow removed, reveal kept)* | +16/wave, reveal r 160 | +24/wave, kills in aura +1 bounty | **Mint:** +4 currency every 10 s during waves | Economy only, diminishing (see §8) |

Every Beacon keeps **stealth reveal** in every branch, so committing to a branch never removes the stealth counter.

### 6.4 Synergy network (compact, explicit)

**1) Stat buff synergy — Amplifier aura**
- Beacons never buff Beacons (no recursive auras).
- A tower takes only the **strongest** Amplifier aura of each stat; multiple Amplifiers do not stack.
- Damage and rate buffs from different stats multiply once.
- Hard caps: +40% damage and +30% rate over base, whatever the sources.

**2) Effect-combination synergy (status interplay)**

| Combo | Effect |
|---|---|
| Cryo slow + Nova splash | Slowed clumps stay in blast radius longer (emergent, no special code) |
| Mark (Pulse Sensor) + Lance | Mark multiplies big hits, the natural boss setup |
| Shred (Nova Siege) + Pulse | Restores Pulse viability vs armor |
| Burn + Mender | −50% healing on burning targets |

**3) Special interactions** (named, shown as a badge on the combo)

| Name | Requirement | Effect |
|---|---|---|
| **Grounded** | Pulse Hunter Net evolution | Marked fliers become ground → Nova can hit them |
| **Conductive** | Lance Arc T3+ (Tesla Web evolution strengthens it) | Chains prefer Chilled enemies and get +1 jump between them |
| **Shatter** | Cryo Absolute Zero evolution | Frozen enemies take +50% Explosive |
| **Meltdown** | Nova Siege Shred + Nova Incendiary Burn on the same enemy | Burn ticks +50% vs enemies with ≥4 Shred |

**UI:** a selected tower shows link lines to the towers buffing it or buffed by it, plus small icons (▲ dmg, ⟳ rate, ◎ range) under buffed towers. Enemies show status pips (slow ❄, burn, mark ◆, shred, revealed eye).

**Tests:** cap enforcement, non-stacking of two Amplifiers, Beacon-on-Beacon exclusion, secondary damage not proccing on-death, and removing all auras/effects on sell.

---

## 7. Enemy Roster (10)

Speeds are in px/s on a 1280×720 map. Base dmg is the Base HP lost on escape.

| # | Enemy | Category | Shape (indicator) | HP | Speed | Armor | Special | Bounty | Base dmg |
|---|---|---|---|---:|---:|---:|---|---:|---:|
| 1 | **Drone** | Basic | small circle | 60 | 70 | 0 | baseline | 4 | 1 |
| 2 | **Dart** | Basic | thin arrow | 35 | 130 | 0 | fast | 3 | 1 |
| 3 | **Brute** | Basic | large circle, thick outline | 300 | 45 | 0 | high HP | 12 | 3 |
| 4 | **Swarmling** | Basic | tiny dot, groups of 8–15 | 18 | 90 | 0 | quantity | 1 | 1 |
| 5 | **Plated** | Defensive | square with corner brackets | 220 | 55 | 8 | heavy armor | 14 | 2 |
| 6 | **Aegis** | Defensive | pentagon with outer ring | 160 + 150 shield | 60 | 2 | regenerating shield (3 s delay, 40/s); Energy ×2 vs shield | 15 | 2 |
| 7 | **Glider** | Special | chevron with shadow offset | 90 | 85 | 0 | **Flying**, uses the air route | 8 | 2 |
| 8 | **Phantom** | Special | dashed-outline triangle, 35% alpha when hidden | 110 | 80 | 0 | **Stealth**: only targetable when Revealed | 10 | 2 |
| 9 | **Mender** | Special | plus-cross inside a circle | 180 | 55 | 1 | **Heals** 30 HP to up to 5 allies within 120 every 2.5 s (not self; bosses healed 1% max) | 14 | 2 |
| 10 | **Monolith** | Boss | large rotating hexagon + phase ring | 4,500 (L6) / 12,000 (L9) | 32 | 4 | 3 phases, see below | 250 | 15 (L6) / 20 (L9) |

**Mechanics covered:** HP and speed variation (1–4), armor (5), shield/damage reduction (6), flying (7), stealth (8), healing (9), summoning and splitting (Boss), and status effects on both enemies and towers (boss EMP). `EnemyDef` has an extensible `abilities: Array[EnemyAbilityDef]`, so later enemies (e.g. a standalone splitter) can reuse the summon/split code without engine changes.

### 7.1 Monolith (boss)

The boss is announced with a banner and its own music sting. A boss HP bar with phase notches appears at the top of the screen.

| Phase | HP | Mechanic | Telegraph | Counterplay |
|---|---|---|---|---|
| **I — Summon** | 100–66% | Every 8 s spawns 4 Swarmlings at its position | Glows 1.5 s before | Splash towers along the late path |
| **II — EMP** | 66–33% | Every 12 s *Disrupts* all towers within r 170 for 3 s (no attacks) | Expanding ring, 2 s warning | Spread placement; long-range Lances outside the radius |
| **III — Fracture** | 33–0% | +30% speed. On death splits into 3 **Shards** (400 HP, armor 2, speed 60, base dmg 3 each) | Cracks appear at threshold | Keep DPS in the final third of the path |

- Slow cap 25%. Immune to stun/freeze; Stagger becomes a 15% slow instead.
- L6 uses phases I–II only and does not split.
- Escape damage is heavy but not instantly fatal at the designed Base HP, except at L9 if the player has already leaked a lot.

---

## 8. Economy (provisional)

| Source | Rule |
|---|---|
| Kill bounty | Per enemy (see table). Paid once per enemy uid. **No bounty for escaped enemies** or for Swarmlings summoned by the boss after the boss dies. |
| Wave reward | `20 + 4 × wave_number`, paid once when the wave is cleared (all spawned enemies dead or escaped). |
| Passive income | +5 every 10 s **only while a wave is active**, so stalling cannot farm it (prep auto-ends anyway). |
| Early start bonus | `floor(remaining_prep_seconds × 1.5)`, capped at 30. Paid once per wave index. The button is disabled the instant it is pressed. |
| Relay Beacon | Per-wave payout as in §6.3. Each additional Relay pays 75%/50%/50%… of its listed amount (diminishing). Mint evolution counts toward the 2-evolution cap. |
| Selling | `floor(total_invested × 0.70)`, where total_invested = build + upgrades + evolution. Shown on the Sell button. Confirm dialog. Credited once (tower state → SOLD before credit). Removes the tower's auras/effects and frees its footprint. Disabled while paused. |

**Wave flow:**
1. First wave: the player taps **Start** (no timer pressure while learning).
2. After each cleared wave: a 20 s prep countdown (15 s from L7 on), shown with the early-start bonus amount.
3. When the countdown ends, the next wave starts automatically. **Waves never overlap.**

---

## 9. Maps & Campaign

### 9.1 Maps

| Map | Layout | Defining mechanics | Strategic problem |
|---|---|---|---|
| **Circuit** | Single long serpentine path | **Terrain restrictions** (blocked circuit blocks). **Overload nodes:** 3 glowing zones where towers whose centre lies inside get +15% range | Learning coverage; contested premium spots |
| **Delta** | Two entrances, routes merge midway | **Day/Night cycle:** waves alternate. At night, tower range is −20% unless the tower is in a Beacon aura, and Phantoms appear only at night. Night is announced during prep | Split vs merge-point defence; Beacon value |
| **Prism** | Two alternative routes plus a separate air corridor | **Dynamic gates:** the active route switches at authored waves, announced in prep with an arrow preview, and both routes are always non-buildable. **Air corridor:** fliers bypass the ground maze | Hedging coverage across routes; dedicated anti-air |

Every mechanic can be answered with the roster: night → Beacon or longer-range Lance; gates → central placements or Lance range; air corridor → Pulse, Lance or Flak.

### 9.2 Campaign (9 levels, one fixed difficulty each)

| Lvl | Map | Objective | Enemies (new in **bold**) | Waves | Start $ | Base HP | Towers | Special encounters | Boss | Est. time | Reward / unlock |
|---|---|---|---|---:|---:|---:|---|---|:-:|---|---|
| 1 | Circuit | Survive (tutorial) | **Drone, Dart** | 8 | 350 | 20 | Pulse, Nova | W8 Dart rush | – | 6 min | L2 · 10 Cores |
| 2 | Circuit | Survive | +**Brute, Swarmling** | 10 | 350 | 20 | Pulse, Nova | W10 swarm flood | – | 8 min | L3 · **Lance** · 10 Cores |
| 3 | Circuit | Survive | +**Plated, Glider** | 12 | 400 | 20 | + Lance | W6 first fliers, W12 armored convoy | – | 10 min | L4 · **Beacon** · 15 Cores |
| 4 | Delta | Survive | +**Phantom** | 12 | 450 | 20 | all 4 | Night waves 4/8/12 | – | 10 min | L5 · 15 Cores |
| 5 | Delta | Survive | +**Aegis** | 14 | 450 | 20 | all | W14 shield wall from both entries | – | 12 min | L6 · 20 Cores |
| 6 | Delta | Defeat the Monolith | +**Mender** | 15 | 500 | 25 | all | W10 healer escort | **W15 Monolith (I–II)** | 13 min | Map Prism · 30 Cores |
| 7 | Prism | Survive | all, glider-heavy | 15 | 500 | 20 | all | Gate switch at W6, W11 | – | 13 min | L8 · 25 Cores |
| 8 | Prism | Survive | all, elite mixes | 18 | 550 | 20 | all | 3 gate switches; W18 stealth-air hybrid | – | 15 min | L9 · 30 Cores |
| 9 | Prism | Defeat the Monolith | everything | 20 | 600 | 30 | all | W10 mini-boss Brute pack | **W20 Monolith (I–III) + escort** | 18 min | Campaign complete · 50 Cores |

**Rewards:**
- **Replay:** 25% of the Cores reward, never regressing progress.
- **First flawless clear** (no Base HP lost): +5 Cores, one time per level.
- Levels are locked until the previous one is cleared, and the lock is shown with the requirement.

### 9.3 Hybrid wave data
```
WaveDef { groups: Array[SpawnGroupDef], is_special, is_boss, prep_override, night (Delta), active_route (Prism) }
SpawnGroupDef { enemy, count, count_variance (≤ ±15%), interval, interval_jitter (≤ ±20%),
                start_delay, route_id, variant_pool: Array[EnemyDef] (same threat tier only) }
```
- Randomness only perturbs counts and timing within those bounds, or swaps in an approved equal-tier variant.
- **Special/boss waves are never randomized.**
- A per-wave **threat budget** (Σ HP × speed factor) is checked in tests so that variance cannot exceed +10% of the authored value.

---

## 10. Meta Progression (modest)

**Persistent currency: Cores.** It is separate from match currency and earned from level clears, achievements and challenges. The total available from the first campaign clear plus achievements is ≈ 250 Cores.

| Category | Nodes | Cost (Cores) |
|---|---|---|
| Tower unlocks | Lance (L2 clear), Beacon (L3 clear). Campaign-gated, free | – |
| Branch unlocks | Third branch (C) for each tower ×4 | 15 each |
| Evolution unlocks | Evolution for Pulse / Nova / Lance / Beacon (all branches of that tower) | 30 each |
| Technology | **Reserve Funds I/II:** +25 / +50 starting currency | 20 / 35 |
| Technology | **Reinforced Core:** +3 Base HP | 25 |
| Technology | **Quick Deploy:** early-start bonus +25% | 15 |
| Technology | **Field Scanner:** shows the next wave's composition preview *(information, not power)* | 10 |
| Campaign content | Prism map unlocks via L6 | – |

**Principles:**
- Stat tech totals at most ≈ +15% starting resources and +3 HP.
- **Every level is designed to be beatable with zero research purchases.** Phase 7 verifies this with a no-meta simulation profile plus a manual playthrough.
- Costs live in `ResearchDef` resources.

---

## 11. Achievements & Challenges

**Achievements (12, event-driven via `EventBus`):**
1. Flawless L1–L3
2. Flawless any Delta level
3. Defeat a Monolith within 90 s of its spawn
4. Win a level using only 2 tower types
5. Win L5+ without building Nova
6. Evolve every tower type (lifetime)
7. Trigger every special interaction (lifetime)
8. Kill 1,000 Swarmlings (lifetime)
9. Win with 1 Base HP left
10. Start 10 waves early in one level
11. Clear L9
12. Clear the campaign without Reserve Funds research

Each achievement has an id, a condition evaluator, a lifetime counter where relevant, a Cores reward and a `claimed` flag (idempotent).

**Challenges:**
- **Daily:** 1 per day from a pool of ≈12. **Weekly:** 1 per week from a pool of ≈8. Both are `ChallengeDef` resources: target level, restriction (tower ban, Base HP cap, start-currency modifier, "no selling"), objective, reward.
- The schedule is a deterministic pick by `hash(period_id)`, where `period_id` = UTC date or ISO week.
- **Time source:** `GameHubAdapter.get_server_time()` when available. Otherwise the **device clock**, which is documented as manipulable and not secure. Claims record `challenge_id + period_id` so a reward cannot be claimed twice locally. Server-side dedupe is required for real security.
- No leaderboards.

---

## 12. Visual, UI & Audio Direction

**Visuals:**
- Dark navy/near-black background (#0E1117) with a faint grid. Paths are lighter bands with chevrons showing direction.
- Towers are thin-line geometric shapes, filled at low alpha. Tier is shown by pips on the tower (1–3 dots); evolution adds an outer rotating ring. Selection is a white outline plus the range circle.
- The ghost is green and solid when valid, red and dashed with an ✕ when invalid, so validity does not depend on colour alone.
- **VFX:** short line or dot projectiles, a 1-frame hit flash, a shrink-and-fade death over 0.2 s, and a ring pulse on build or upgrade. No screen shake.

**Layout (1280×720, safe-area aware via `DisplayServer.get_display_safe_area()`):**
- **Top bar:** Base HP, currency, wave X/Y, prep countdown + "Start early +N", pause.
- **Tower palette:** a vertical column of 4 large buttons (≥ 72 px) on the right edge, each showing its cost.
- **Bottom panel** (≈ 30% height, slides up on tower select): name/role, stats, special text, 3 branch cards (locked or unaffordable states, cost, preview), evolution card with its requirements, and the Sell button showing the refund. If the selected tower would be covered, the map view nudges up instead of hiding it.

**Placement (both paths share one `PlacementSession`):**
- **Drag:** drag from the palette. The ghost sits 64 px above the finger so the finger doesn't hide it, with the range circle shown. Release on a valid spot to build; release on an invalid spot or the palette to cancel.
- **Tap:** tap the palette, then tap the map → a ghost appears with ✔ / ✕ buttons. Tapping elsewhere repositions it.
- **Guards:** the commit is one-shot (session closes before the build call), and currency is deducted only after the tower is successfully instantiated (`try_spend` is atomic with build).

**Audio:**
- **SFX** are original and synthesized by a script in `tools/audio_gen` (sfxr-style), so licensing is clear.
- **Music** is one or two original ambient loops generated or composed for this project.
- The alternative is CC0 packs (e.g. Kenney), which requires your approval to download.
- Settings: music/SFX volume and on/off, persisted.
- **Licenses:** `audio/LICENSES.md`.

---

## 13. GameHub Integration Design

### 13.1 What is unknown (blockers)
I found **nothing** about GameHub in this workspace:
- the host app technology (native Kotlin/Swift, Flutter, React Native, Unity, or a web/WebView shell);
- the auth model, the backend API, and whether challenge definitions or server time are available.

**I will not invent any of it.**

### 13.2 Embedding options (to decide once the host is known)

| Option | Android | iOS | Notes / risks |
|---|---|---|---|
| **A. Godot Android library embedded in host app** (`godot-lib` AAR, GodotFragment) | Supported pattern | **No equivalent mature path.** LibGodot ("Godot as a library") must be verified for 4.7 on iOS | Native-to-game bridge through a Godot Android plugin (JNI). iOS is the main risk |
| **B. Web export shown in host WebView** | Works | WKWebView works with a **single-threaded** web export (no SharedArrayBuffer requirement) | One build for both platforms and a simple JS bridge (`JavaScriptBridge`). Costs: performance, load size, audio unlock quirks. Must be profiled |
| **C. Standalone app launched by GameHub** (deep link / intent with a launch token) | Works | Works | Simplest and most robust. Weakest "minigame inside hub" UX, with two store listings |

My recommendation depends on your host technology. I'll architect the game so that **any of A/B/C only changes the adapter implementation**.

### 13.3 Adapter boundary
```gdscript
class_name GameHubAdapter extends RefCounted   # interface; all methods async-style via signals/await
func get_launch_context() -> LaunchContext      # player_id, display_name, locale, opaque session token (never logged/persisted)
func load_progression() -> ProgressionResult    # {ok, data, revision, error}
func submit_progression(delta: ProgressionDelta) -> SubmitResult   # carries idempotency_key + base_revision
func report_match_result(result: MatchResult) -> SubmitResult      # match_id (UUID), level, outcome, duration, stats
func claim_reward(claim: RewardClaim) -> SubmitResult              # achievement/challenge id + period id
func fetch_challenges() -> ChallengeResult      # optional; returns NOT_SUPPORTED → local defs
func get_server_time() -> TimeResult            # optional; NOT_SUPPORTED → device clock
```
- **`MockGameHubAdapter` (DEV ONLY):** stores data in `user://mock_gamehub/*.json`, simulates latency, failure and token-expiry modes for tests, and prints a visible "MOCK GAMEHUB" badge in debug builds.
- **`ProgressionRepository`:**
  - keeps a local cache and an offline **SyncQueue** of deltas with idempotency keys;
  - retries with backoff;
  - resolves conflicts **server-wins**, with monotonic merges (unlocked levels / achievements = union, best results = max);
  - treats Cores balances as **server ledger only** (the client never overwrites them).
- **Gameplay never blocks on the network.** The game is fully playable offline with the cache, and sync happens on results screens and app pause.
- **Trust statement:** client-reported match results are **not** trustworthy. The backend must validate them (plausibility checks: duration vs wave count, reward caps per level per period, idempotency). I will document the exact checks recommended for the backend team.

---

## 14. Balancing Approach

1. **Spreadsheet-in-data:** all numbers live in `.tres` files. `tools/sim/report.gd` prints derived metrics: DPS per cost per tower/tier, effective DPS vs each enemy (armor/shield/air/stealth), time-to-kill, path exposure time per map, and the threat budget per wave.
2. **Headless simulator:** runs the real combat code at accelerated tick in `--headless` mode with scripted bot strategies (e.g. "Pulse spam", "Nova+Lance", "Beacon-Amplifier stack", "economy-first Relay", "no-meta"). Outputs: win/loss, Base HP lost, and the currency curve per level.
3. **Targets:**
   - every level is winnable by ≥ 2 distinct bot strategies and by the no-meta profile;
   - no single strategy wins all 9 levels with ≥ 90% HP;
   - each branch is picked by at least one winning strategy somewhere.
4. **Human playtest pass** (you, and me via the browser/desktop build) for feel. Results are documented in `docs/BALANCE.md` with sim output attached. Numbers are not called "balanced" without that evidence.

---

## 15. Testing Strategy

- **Runner:** a small in-repo headless runner (`godot --headless --path . -s res://tests/run_tests.gd`) with assert helpers. It has no third-party dependency, so there is no addon/4.7 compatibility risk. It can switch to GUT later if you prefer.
- **Unit:**
  - placement geometry, economy ledger/idempotency, armor/shield formulas;
  - status refresh/caps, targeting rules, branch locking, evolution requirements, synergy caps;
  - sell refund, escape damage once, defeat at 0, early-start once, wave state machine, pause gating.
- **Integration (scene-level, headless):** spawn wave → towers kill → rewards; full scripted level run; save/load; repeated completion; mock adapter failure / dupe / stale / expired-token cases. These are **labeled as mock integration tests**.
- **Manual/visual:** layouts at 16:9, 19.5:9, 20:9 and 4:3 (tablet), plus a simulated safe area. Done via a desktop run and screenshots, and on real devices when available.
- **Report discipline:** every phase report lists exactly which tests ran, with their output. Unexecuted tests are listed as such.

---

## 16. Platform & Project Risks

| Risk | Impact | Mitigation |
|---|---|---|
| GameHub host tech, API and auth unknown | Blocks Phase 6 real integration | Adapter boundary + mock. Need docs from you |
| iOS embedding of Godot in a native host is not a mature path | Could force option B or C | Decide early. Prototype option B (web export) cheaply if the host is hybrid |
| No Android SDK / export templates here | Can't produce an APK yet | Install Android SDK + Godot 4.7.2 export templates (I can guide; downloads need your OK) |
| No macOS available | iOS export can't be validated here | Needs a Mac + Xcode (or CI such as a macOS runner) |
| Not a git repo | No history or rollback between phases | Recommend `git init` now (I'll do it on your OK) |
| Device clock for challenges | Spoofable | Server time via adapter. Documented limitation |
| Balance of 36 tiers + 12 evolutions | Large tuning surface | Simulator + caps (2 evolutions/match, synergy caps) |
| Mobile web performance (if option B) | Lower FPS | Profile in Phase 5/6 before committing |

---

## 17. Phase-by-Phase Plan

| Phase | Scope | Exit evidence |
|---|---|---|
| **1 (this)** | Inspection + design | This document, approved |
| **2 Core prototype** | project settings (landscape, main scene), data schemas, Circuit map (1 route), Drone/Dart/Brute, Pulse + Nova base, free placement with footprint validation (tap + drag basic), auto-targeting via spatial hash, wave manager with prep / auto-start / early bonus, economy ledger, Base HP, win/lose, pause gating, test runner | Headless unit tests passing (output shown); scripted headless level run; playable desktop build with screenshots |
| **3 Advanced combat** | all 4 towers, all 10 enemies (incl. boss phases), 12 branches × 3 tiers, branch lock, 12 evolutions + cap, synergy system + caps, status effects, selling | Unit tests for every rule in §4–§8; sim smoke tests per enemy counter |
| **4 Campaign & progression** | 3 maps + mechanics, 9 levels of wave data, hybrid randomness + threat budget test, unlocks, research, achievements, daily/weekly challenges, local persistence via mock repository | Persistence tests (unlock, replay, dupes, stale); all 9 levels pass a bot run |
| **5 Mobile UI, art & audio** | final HUD, palette, bottom panel, drag + tap polish, safe areas, menus / campaign / research / settings / results, geometric visuals, VFX, synthesized SFX + music, audio settings | Screenshots at 4 aspect ratios; manual checklist; settings persistence tests |
| **6 Standalone mobile game & playtesting release** *(replaces "GameHub integration", per user update 2026-11-11)* | standalone Android app from the existing Godot project; installable APK for external testers; runs with no GameHub, login or backend; local save/load of campaign, achievements, unlocks, research and settings; fully offline; all 9 levels playable; landscape orientation, app icon, package id and version configured; touch controls/UI checked on device; pause/resume/reopen handling; APK install instructions + basic playtest checklist; architecture kept compatible with future GameHub integration (existing `ProgressionStore` boundary, no GameHub code required) | Signed APK built from an export preset (build log), install + launch evidence, lifecycle/persistence tests, install guide and playtest checklist |
| **7 Balance, perf, QA** | simulator sweeps, tuning, profiling on devices, Android export (and iOS on a Mac), regression run, README / architecture / QA / license docs | Balance report, perf numbers per device, export logs, known-limitations list |

---

## 18. Decisions Needed From You

1. **GameHub host technology** and any SDK/API/auth documentation (or confirmation that none exists yet → Phase 6 delivers an integration-ready module plus a spec).
2. **Embedding preference** (A/B/C, §13.2), if you already know it.
3. **Approve the roster and numbers** in §5–§10 (or request changes) — especially the 3 tiers + evolution, the 2-evolution cap, and branch C via research.
4. **Audio source:** original synthesized assets (default) or CC0 packs (needs download approval).
5. **`git init`** this project now? (recommended)
6. **UI language(s)** for V1 (English only, or also others?).
7. **Test devices** available for profiling.


---

## Requirement changes approved by the user (2026-11-12, build 0.7.0)

These replace the matching earlier constraints; everything else stays as designed.

| Earlier rule | New rule |
|---|---|
| Fixed 1× speed; no 2×/3× | **x1 / x2 speed toggle** in the match HUD. x2 runs two identical fixed simulation steps per frame, so outcomes match 1×. No 3×. |
| One branch per tower; the first purchase locks the other two (no crosspathing) | **Main + secondary branch:** at most 2 branches per tower; only one may go above tier 2 (the main branch, up to tier 3 + evolution); the other is capped at tier 2; the third branch stays locked. When two branches set the same stat, the stronger value applies. |
| English UI (open question) | **English + Vietnamese** UI and content, selectable in Settings (Device language / English / Tiếng Việt). |
