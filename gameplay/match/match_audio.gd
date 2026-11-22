class_name MatchAudio
extends Node
## Maps match events to sounds (presentation only). The Audio limiter keeps mass firing subtle.

var controller: MatchController
var _evolved: Dictionary = {}


func _ready() -> void:
	var c := controller
	c.tower_built.connect(func(_t: Tower) -> void: _play(&"build"))
	c.tower_upgraded.connect(func(t: Tower) -> void:
		if t.evolved and not _evolved.has(t.uid):
			_evolved[t.uid] = true
			_play(&"evolve")
		else:
			_play(&"upgrade"))
	c.tower_sold.connect(func(_t: Tower, _r: int) -> void: _play(&"sell"))
	c.shot_fired.connect(func(t: Tower) -> void: _play(StringName(SHOT_SFX.get(t.def.id, "shot_" + String(t.def.id)))))
	c.explosion.connect(func(_p: Vector2, _r: float) -> void: _play(&"explosion"))
	c.enemy_killed.connect(func(_e: Enemy) -> void: _play(&"enemy_death"))
	c.waves.wave_started.connect(func(i: int, _b: int) -> void:
		_play(&"wave_start")
		var boss := i >= 0 and i < c.level.waves.size() and c.level.waves[i].is_boss
		_music(&"boss" if boss else &"action"))
	c.boss_spawned.connect(func(_e: Enemy) -> void:
		_play(&"boss")
		_music(&"boss"))
	c.boss_phase_changed.connect(func(_e: Enemy, _p: int) -> void: _play(&"boss_phase"))
	c.waves.wave_cleared.connect(func(_i: int, _r: int) -> void:
		_play(&"wave_clear")
		_music(&"calm")) # emitted only once the field is empty
	c.towers_disrupted.connect(func(_p: Vector2) -> void: _play(&"emp"))
	c.match_ended.connect(func(won: bool) -> void:
		_play(&"victory" if won else &"defeat")
		_music(&"calm"))
	_music(&"calm") # build phase before wave 1 (or a resumed match between waves)


## Towers without their own shot sound can borrow one here (2026-11-22: Coil now has its own discharge).
const SHOT_SFX := {}


func _exit_tree() -> void:
	_music(&"calm") # back to menus


## Music state: calm (build / between waves), action (wave running), boss (boss wave).
func _music(state: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").set_music(state)


func _play(id: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(id)
