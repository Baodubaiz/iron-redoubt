class_name WaveDef
extends Resource

@export var groups: Array[SpawnGroupDef] = []
@export var is_special: bool = false
@export var is_boss: bool = false
@export var prep_time_override: float = -1.0 ## seconds of preparation before this wave; -1 = level default
@export var night: bool = false ## Day/Night maps: this wave happens at night
@export var active_route: int = -1 ## Dynamic-gate maps: open this ground route from this wave on (-1 = unchanged)
