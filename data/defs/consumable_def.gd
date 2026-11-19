class_name ConsumableDef
extends Resource
## A one-shot item bought with Cores in the Armory and carried into matches: no cooldown, each use
## consumes one from the owned stock (buy more to use more). At most one use per item per match
## (ProgressionModel.use_item_block_reason). MatchController.apply_consumable() applies the effect.

enum Kind { AIRSTRIKE, HEAL, FREEZE, HASTE }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: String = "star"
@export var cost: int = 40 ## Cores per purchase
@export var kind: Kind = Kind.AIRSTRIKE
## AIRSTRIKE: damage / radius (centred on the toughest enemy alive). HEAL: heal_amount (Base HP).
## FREEZE: freeze_duration (regular enemies stop; bosses stagger, same as a stun). HASTE: haste_mult
## (fire_rate_mult, e.g. 1.25) / haste_duration, every tower on the map.
@export var damage: float = 0.0
@export var radius: float = 0.0
@export var heal_amount: int = 0
@export var freeze_duration: float = 0.0
@export var haste_mult: float = 1.0
@export var haste_duration: float = 0.0
## The player picks where it lands (2026-11-19): tap the item, then tap the map. `radius` is the area.
@export var targeted: bool = false
