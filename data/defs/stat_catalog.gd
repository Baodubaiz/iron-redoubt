class_name StatCatalog
extends Resource
## Registry of every stat key. Loaded once (StatCatalog.get_default()).

const PATH := "res://data/stats/catalog.tres"

@export var stats: Array[StatDef] = []

static var _default: StatCatalog
var _by_id: Dictionary = {}


static func get_default() -> StatCatalog:
	if _default == null:
		_default = load(PATH) if ResourceLoader.exists(PATH) else StatCatalog.new()
	return _default


func find(id: StringName) -> StatDef:
	if _by_id.is_empty():
		for s in stats:
			_by_id[s.id] = s
	return _by_id.get(id)


func has(id: StringName) -> bool:
	return find(id) != null
