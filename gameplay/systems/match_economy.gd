class_name MatchEconomy
extends RefCounted
## Single authority for match currency. Credits carry an idempotency key so a repeated
## event (double kill callback, double button press) can never pay twice.

signal changed(currency: int, delta: int, reason: String)

var currency: int = 0
var locked: bool = false ## true after the match ends: no further credits or spends
var config: EconomyConfig

var _paid_keys: Dictionary = {}
var _passive_timer: float = 0.0
var _passive_count: int = 0


func _init(starting: int, cfg: EconomyConfig) -> void:
	currency = starting
	config = cfg


func can_afford(amount: int) -> bool:
	return not locked and amount >= 0 and currency >= amount


## Returns true only on the first credit for `key`.
func credit(amount: int, key: String) -> bool:
	if locked or amount <= 0 or _paid_keys.has(key):
		return false
	_paid_keys[key] = true
	currency += amount
	changed.emit(currency, amount, key)
	return true


func was_paid(key: String) -> bool:
	return _paid_keys.has(key)


func try_spend(amount: int, reason: String) -> bool:
	if not can_afford(amount):
		return false
	currency -= amount
	changed.emit(currency, -amount, reason)
	return true


## Passive income only while a wave is active.
func step_passive(dt: float, wave_active: bool) -> void:
	if locked or not wave_active or config.passive_amount <= 0:
		return
	_passive_timer += dt
	while _passive_timer >= config.passive_interval:
		_passive_timer -= config.passive_interval
		_passive_count += 1
		credit(config.passive_amount, "passive:%d" % _passive_count)
