class_name BaseCore
extends RefCounted
## Base HP. Escape damage is applied by MatchController exactly once per enemy.

signal changed(hp: int, max_hp: int)
signal destroyed

var hp: int
var max_hp: int
var damage_taken: int = 0


func _init(start_hp: int) -> void:
	hp = start_hp
	max_hp = start_hp


func is_destroyed() -> bool:
	return hp <= 0


## Heal consumable: restores HP, capped at max_hp.
func heal(amount: int) -> void:
	if hp <= 0 or amount <= 0:
		return
	hp = mini(hp + amount, max_hp)
	changed.emit(hp, max_hp)


func apply_damage(amount: int) -> void:
	if hp <= 0 or amount <= 0:
		return
	var dealt := mini(amount, hp)
	hp -= dealt
	damage_taken += dealt
	changed.emit(hp, max_hp)
	if hp <= 0:
		destroyed.emit()
