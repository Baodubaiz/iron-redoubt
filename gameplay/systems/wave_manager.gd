class_name WaveManager
extends RefCounted
## Wave flow: WAITING_FIRST -> ACTIVE -> PREP (countdown, early start) -> ACTIVE ... -> DONE.
## Waves never overlap. A wave clears when every spawn has been emitted and no enemy is alive.

enum Phase { WAITING_FIRST, ACTIVE, PREP, DONE }

signal wave_started(index: int, early_bonus: int)
signal wave_cleared(index: int, reward: int)
signal prep_started(next_index: int, seconds: float)
signal all_waves_cleared

class Spawner:
	var group: SpawnGroupDef
	var remaining := 0
	var timer := 0.0
	var interval := 1.0
	var jitter := 0.0

var level: LevelDef
var economy: MatchEconomy
var rng: RandomNumberGenerator
## Callable(group: SpawnGroupDef) supplied by MatchController; spawns one enemy of the group.
var spawn_callback: Callable

var phase: Phase = Phase.WAITING_FIRST
var index: int = -1 ## current/last started wave (0-based)
var prep_remaining: float = 0.0
var early_starts: int = 0
var early_bonus_multiplier: float = 1.0
var _spawners: Array[Spawner] = []


func _init(lvl: LevelDef, econ: MatchEconomy, random: RandomNumberGenerator) -> void:
	level = lvl
	economy = econ
	rng = random


func next_wave() -> WaveDef:
	var i := index + 1
	return level.waves[i] if i >= 0 and i < level.waves.size() else null


func wave_count() -> int:
	return level.waves.size()


func is_active() -> bool:
	return phase == Phase.ACTIVE


func current_early_bonus() -> int:
	if phase != Phase.PREP:
		return 0
	return int(floor(level.economy.early_bonus(prep_remaining) * early_bonus_multiplier))


## Player request: start the first wave, or start the next wave early. Safe to spam.
func request_start() -> bool:
	match phase:
		Phase.WAITING_FIRST:
			_begin_wave(0, 0)
			return true
		Phase.PREP:
			var next := index + 1
			var bonus := current_early_bonus()
			early_starts += 1
			if bonus > 0:
				economy.credit(bonus, "early:%d" % next)
			_begin_wave(next, bonus)
			return true
	return false


func step(dt: float) -> void:
	match phase:
		Phase.ACTIVE:
			for s in _spawners:
				if s.remaining <= 0:
					continue
				s.timer -= dt
				while s.remaining > 0 and s.timer <= 0.0:
					s.remaining -= 1
					spawn_callback.call(s.group)
					var j := rng.randf_range(-s.jitter, s.jitter) if s.jitter > 0.0 else 0.0
					s.timer += s.interval * (1.0 + j)
		Phase.PREP:
			prep_remaining -= dt
			if prep_remaining <= 0.0:
				prep_remaining = 0.0
				_begin_wave(index + 1, 0)


func spawning_finished() -> bool:
	for s in _spawners:
		if s.remaining > 0:
			return false
	return true


## Called by MatchController after each step with the alive enemy count.
func check_cleared(alive_count: int) -> void:
	if phase != Phase.ACTIVE or alive_count > 0 or not spawning_finished():
		return
	var reward := level.economy.wave_reward(index + 1)
	economy.credit(reward, "wave:%d" % index)
	wave_cleared.emit(index, reward)
	if index >= wave_count() - 1:
		phase = Phase.DONE
		all_waves_cleared.emit()
		return
	phase = Phase.PREP
	var next_def := level.waves[index + 1]
	prep_remaining = next_def.prep_time_override if next_def.prep_time_override >= 0.0 else level.prep_time
	prep_started.emit(index + 1, prep_remaining)


## Planned spawn counts for a wave (applies bounded, seeded variance; special/boss waves fixed).
func _planned_count(g: SpawnGroupDef, wave: WaveDef) -> int:
	if wave.is_special or wave.is_boss or g.count_variance <= 0.0:
		return g.count
	var v := clampf(g.count_variance, 0.0, 0.15)
	return maxi(1, int(round(g.count * (1.0 + rng.randf_range(-v, v)))))


func _begin_wave(i: int, bonus: int) -> void:
	if i < 0 or i >= wave_count():
		return
	index = i
	phase = Phase.ACTIVE
	prep_remaining = 0.0
	_spawners.clear()
	var wave := level.waves[i]
	for g in wave.groups:
		var s := Spawner.new()
		s.group = g
		s.remaining = _planned_count(g, wave)
		s.interval = maxf(g.interval, 0.05)
		s.jitter = 0.0 if (wave.is_special or wave.is_boss) else clampf(g.interval_jitter, 0.0, 0.2)
		s.timer = g.start_delay
		_spawners.append(s)
	wave_started.emit(i, bonus)
