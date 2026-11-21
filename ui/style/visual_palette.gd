class_name VisualPalette
extends RefCounted
## Iron Redoubt Reforged colour tokens and presentation-only lookup tables (Stage A §2.2).
## Gameplay data (.tres colours) is never modified: visuals map ids -> display colours here.

const BG := Color("0B1020")
const BG_DEEP := Color("070B16")
const SURFACE := Color("172238")
const SURFACE_HI := Color("22314F")
const SURFACE_LINE := Color("2C3D60")
const CYAN := Color("38D9F5")
const BLUE := Color("4D8CFF")
const VIOLET := Color("A66BFF")
const ORANGE := Color("FFAA45")
const RED := Color("FF5368")
const GREEN := Color("4DE6A1")
## Player setting "Reduce effects" (mirrored here so visuals can read it without autoloads).
static var reduce_effects := false

const TEXT := Color("E8F6FF")
const TEXT_DIM := Color("9FB0CF")
const TEXT_FAINT := Color("62738F")

const TOWER := {
	&"pulse": CYAN,
	&"nova": ORANGE,
	&"lance": VIOLET,
	&"beacon": GREEN,
	&"trap": Color("FFD84D"),
	&"venom": Color("8BE36A"),
	&"spotter": Color("FF7A9A"),
	&"sniper": Color("FF6B8A"),
	&"bastion": Color("7FB2FF"),
	&"storm": Color("FF5CE1"),
	&"chronos": Color("5CFFD8"),
	&"coil": Color("6FE3FF"),
}

## Region look (menus, thumbnails, battlefield), keyed by MapDef.region_id().
const MAP := {
	&"circuit": {"name": "Circuit", "accent": CYAN, "accent2": Color("7CEBFF"), "floor": Color("0E1830"), "path": Color("17233D"),
		"block": Color("1C2A47"), "desc": "Power facility. Overload nodes boost tower range."},
	&"delta": {"name": "Delta", "accent": BLUE, "accent2": VIOLET, "floor": Color("0F1534"), "path": Color("1A2147"),
		"block": Color("222A55"), "desc": "Test sector. Two entrances and nights that shorten tower range."},
	&"prism": {"name": "Prism", "accent": VIOLET, "accent2": ORANGE, "floor": Color("150F2E"), "path": Color("231A44"),
		"block": Color("2E2350"), "desc": "Energy complex. Gates reroute the enemy mid-battle."},
	&"rift": {"name": "Rift", "accent": ORANGE, "accent2": RED, "floor": Color("1A1020"), "path": Color("2A1A28"),
		"block": Color("3A2230"), "desc": "A tear in the grid. Every mechanic at once, and two bosses."},
}


static func tower_color(id: StringName) -> Color:
	return TOWER.get(id, CYAN)


static func map_look(id: StringName) -> Dictionary:
	return MAP.get(id, MAP[&"circuit"])
