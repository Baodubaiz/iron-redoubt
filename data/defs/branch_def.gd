class_name BranchDef
extends Resource
## An upgrade branch: 3 tiers + an evolution capstone. Buying tier 1 locks the other branches.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var tiers: Array[TierDef] = []
@export var evolution: TierDef
@export var requires_research: bool = false ## branch C: unlocked through meta research
