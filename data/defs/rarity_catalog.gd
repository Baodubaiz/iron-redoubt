class_name RarityCatalog
extends Resource

const PATH := "res://data/stats/rarity.tres"

@export var ranks: Array[RarityDef] = []

static var _default: RarityCatalog


static func get_default() -> RarityCatalog:
	if _default == null:
		_default = load(PATH) if ResourceLoader.exists(PATH) else RarityCatalog.new()
	return _default


func find(id: StringName) -> RarityDef:
	for r in ranks:
		if r.id == id:
			return r
	return null
