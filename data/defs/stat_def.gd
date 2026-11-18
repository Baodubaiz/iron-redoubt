class_name StatDef
extends Resource
## One stat key that towers / tiers / enemies / effects can use (see data/stats/catalog.tres).
## Adding a stat = add an entry to the catalog; UI labels, stacking and validation read it from here.

enum Stack { MAX, OR, ADD, MUL, OVERRIDE } ## how two branches setting the same key combine
enum Owner { TOWER, ENEMY, EFFECT }

@export var id: StringName
@export var label: String = "" ## short UI label (translated)
@export_multiline var description: String = ""
@export var owner: Owner = Owner.TOWER
@export var stack: Stack = Stack.MAX
@export var unit: String = "" ## "", "s", "%", "px", "/s"
@export var percent: bool = false ## value 0.15 shown as 15%
@export var shown: bool = true ## listed in upgrade previews / Codex
