class_name DamageTypeDef
extends Resource
## One damage type (data/damage/catalog.tres, index = Damage.Type value). A new type = a new entry;
## towers / effects refer to it by index or id.

@export var id: StringName
@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export var vs_shield: float = 1.0 ## multiplier against shields (Energy = 2)
## Default per-enemy armor for this type is 0 (full bypass) unless EnemyDef.armor_by_type sets an
## explicit value for it (Enemy.effective_armor_for). True ignores this and the override both --
## true damage always goes through, full stop; Poison defaults the same way but CAN be resisted by
## a specific enemy via armor_by_type, for "robotic things resist poison" style diversity.
@export var ignores_armor: bool = false
@export var min_through: float = 0.25 ## fraction of a hit that always passes armor
@export var ignores_shield: bool = false ## skips the shield bar entirely, win or lose (Plasma)
@export var flat_pierce: float = 0.0 ## innate armor pierce for this type, on top of the tower's own (Explosive's shrapnel)
