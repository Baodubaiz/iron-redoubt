# Combat Parameters Reference

`TierDef.stats` and `TowerDef.base_params` are dictionaries of the keys below. Within a branch, tiers are merged in order (later values overwrite earlier ones). Since 0.7.0 a tower may own a main branch (up to tier 3) and a secondary branch (up to tier 2): when both set the same key, the **stronger value** wins (numbers: max, flags: or); keys no branch sets keep the base value. The main branch's evolution is merged last. `Tower.recompute()` builds the result, and `MatchController` reads it.

## Core stats (always present)

| Key | Type | Meaning |
|---|---|---|
| `damage` | float | Damage per hit (before synergy buff) |
| `fire_rate` | float | Shots per second |
| `attack_range` | float | Targeting range in px. For Beacons, the aura radius (and reveal radius) |
| `armor_pen` | float | Ignores this much flat armor |
| `splash_radius` | float | 0 = single target |
| `can_target_air` | bool | Can target fliers (Nova Cluster III turns this on: Flak) |

## Effect keys

| Key | Used by | Meaning |
|---|---|---|
| `burst_every`, `burst_count` | Pulse Storm Array | Every Nth shot fires extra shots at enemies in range |
| `pierce` | Pulse Railspike | Total enemies hit along the shot line |
| `reveal_radius` | Pulse Sensor | Reveals stealth within the radius (non-Beacon towers) |
| `mark`, `mark_duration` | Pulse Sensor | On hit: target takes +mark damage from all sources |
| `air_damage_mult` | Pulse Sensor III | Damage multiplier vs flying targets |
| `ground_marked_fliers` | Pulse Hunter Net | Marked fliers are Grounded for N seconds (**Grounded** interaction) |
| `bomblets`, `bomblet_damage` | Nova Cluster | Extra small blasts (radius 25) around the impact |
| `echo_every`, `echo_delay` | Nova Cascade | Every Nth shell detonates again after the delay |
| `burn_dps`, `burn_duration` | Nova Incendiary | Burn (TRUE damage). Burning enemies receive −50% healing |
| `fire_patch_duration`, `fire_patch_radius` | Nova Incendiary III | Ground zone that keeps enemies burning |
| `death_explosion` | Nova Inferno | Burning enemies explode on death (secondary: never chains) |
| `shred`, `shred_cap` | Nova Siege | −armor per hit, stacking to the cap, 4 s duration |
| `stagger` | Nova Siege III | Stun for N s on hit (bosses: 15% slow instead) |
| `stun_every`, `stun_duration` | Nova Quake | Every Nth shell stuns ground enemies |
| `boss_mult` | Lance Overcharge III | Damage multiplier vs bosses |
| `crit_every`, `crit_mult` | Lance Annihilator | Every Nth shot multiplies damage |
| `chain`, `chain_falloff` | Lance Arc | Extra chain jumps; each chain hit deals damage × falloff |
| `chain_shield_mult` | Lance Arc III | Chain hits' multiplier vs shields (replaces Energy's ×2 when higher) |
| `conductive`, `conductive_bonus` | Lance Arc III / Tesla Web | Chains prefer Chilled enemies; bonus jumps between Chilled ones (**Conductive**) |
| `chain_stagger` | Lance Tesla Web | Chain hits stagger |
| `beam_dps`, `ramp_max`, `ramp_time` | Lance Focus | Continuous beam; damage ramps on the same target and resets when the target changes |
| `beam_pierce` | Lance Phase Beam | The beam damages every enemy on its line |
| `slow` | Beacon | Aura slow (recomputed every step, so it vanishes the moment the Beacon is sold or disrupted) |
| `amp_damage`, `amp_rate`, `amp_range` | Beacon Amplifier | Buffs non-Beacon towers in the aura |
| `freeze_every`, `freeze_duration` | Beacon Cryo III | Periodic freeze of non-boss enemies in the aura |
| `shatter` | Beacon Absolute Zero | Frozen enemies take +X explosive damage (**Shatter**) |
| `wave_income` | Beacon Relay | Currency per cleared wave (diminishing: 100% / 75% / 50% …) |
| `bounty_bonus` | Beacon Relay III | +N bounty for kills inside the aura (highest single value) |
| `mint_amount`, `mint_interval` | Beacon Mint | Currency every interval while a wave is active |

## Global rules (MatchController / Enemy)

- **Damage pipeline order:** Mark → Shatter → shield → armor → HP.
  - Shield: absorbs first. Energy deals ×2 to shields. Armor does not apply to shields.
  - Armor: `max(dmg − max(armor − shred − pen, 0), dmg × 0.25)`.
- **Status policy:**
  - One instance of each status per enemy. Re-applying it refreshes the duration and keeps the highest magnitude.
  - Shred is the exception: it stacks up to its cap.
- **Slow cap:** 60%, or 25% for bosses. Bosses are immune to stun and freeze and take Stagger (15% slow) instead.
- **Synergy buffs:**
  - Each stat takes only the strongest Amplifier.
  - Caps: +40% damage, +30% rate, +30% range.
  - Beacons never buff Beacons.
- **Secondary damage** (Inferno explosion) never triggers on-death effects.
- **Special interactions:** Grounded, Conductive, Shatter and Meltdown (burn ×1.5 on enemies with ≥ 4 shred). Each triggered interaction is counted in `interaction_counts`, which Phase 4 achievements will read.
- **Upgrades (0.7.0):** at most 2 branches per tower; only one may exceed tier 2 (main, up to 3); the third branch is locked.
- **Evolution:** requires the main branch at tier 3, a research unlock and 2 completed waves at T3. At most 2 evolved towers can be alive per match.
- **Sell:** `floor(total_invested × 0.70)`. It removes the tower's in-flight shots, fire patches and pending detonations, and its auras end on the next step.
