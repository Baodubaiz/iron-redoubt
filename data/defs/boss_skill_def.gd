class_name BossSkillDef
extends Resource
## One telegraphed boss skill (pure data). A boss = EnemyDef.boss_skills + boss_passives.
## Scheduler: in each phase the eligible skills take turns; a new phase opens with its newest skill.
##
## action ids (EnemyAbilities): shell, sprint, hangar, cloak, adapt, jam, bulwark, blink, static,
##   capacitor, submerge, revive, decoy, prism, effect_area, summon, heal_area
## Generic actions (no code needed for new bosses):
##   effect_area  params: effect (EffectDef path), radius, on ("allies" | "self" | "towers")
##   summon       params: enemy (EnemyDef path), count, spacing
##   heal_area    params: radius, frac (of max HP), self (bool)

@export var action: StringName
@export var min_phase: int = 1
@export var max_phase: int = 3
@export var interval: float = 8.0
@export var telegraph: float = 1.0
## phase -> interval multiplier (e.g. {3: 0.5} = twice as often in phase III)
@export var phase_interval_mult: Dictionary = {}
@export var label: String = "" ## boss-bar warning while telegraphing (translated)
@export var params: Dictionary = {}
