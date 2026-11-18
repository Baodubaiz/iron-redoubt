class_name ResearchDef
extends Resource
## One node of the meta research tree, bought with persistent Cores.

enum Kind { BRANCH_C, EVOLUTION, START_CURRENCY, BASE_HP, EARLY_BONUS, WAVE_PREVIEW }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.START_CURRENCY
@export var cost: int = 10
@export var tower_id: StringName = &"" ## BRANCH_C / EVOLUTION target
@export var value: float = 0.0 ## START_CURRENCY: +amount, BASE_HP: +amount, EARLY_BONUS: +fraction
@export var requires: Array[StringName] = [] ## research ids that must be owned first
@export var requires_tower: StringName = &"" ## tower that must be unlocked first
## UI grouping on the Research screen (ResearchCatalog in research_screen.gd): "tower" (branch /
## evolution unlocks, grouped per tower) or "support" (economy / utility, not tower-specific).
@export var category: StringName = &"support"
