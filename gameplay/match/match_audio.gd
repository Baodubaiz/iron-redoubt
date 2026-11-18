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
	c.shot_fired.connect(func(t: Tower) -> void: _play(StringName("shot_" + String(t.def.id))))
	c.explosion.connect(func(_p: Vector2, _r: float) -> void: _play(&"explosion"))
	c.enemy_killed.connect(func(_e: Enemy) -> void: _play(&"enemy_death"))
	c.waves.wave_started.connect(func(_i: int, _b: int) -> void: _play(&"wave_start"))
	c.boss_spawned.connect(func(_e: Enemy) -> void: _play(&"boss"))
	c.boss_phase_changed.connect(func(_e: Enemy, _p: int) -> void: _play(&"boss_phase"))
	c.waves.wave_cleared.connect(func(_i: int, _r: int) -> void: _play(&"wave_clear"))
	c.towers_disrupted.connect(func(_p: Vector2) -> void: _play(&"emp"))
	c.match_ended.connect(func(won: bool) -> void: _play(&"victory" if won else &"defeat"))


func _play(id: StringName) -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").play(id)
