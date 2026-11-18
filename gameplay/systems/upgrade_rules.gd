class_name UpgradeRules
extends RefCounted
## Pure rules for branch purchases and evolution: one main branch (up to tier 3 + evolution) and
## one secondary branch (up to tier 2); the third branch stays locked. (User change, 2026-11-12.)

const EVOLUTION_CAP := -1 ## max evolved towers per match: -1 = unlimited (all towers can evolve; set to 2 to rollback)
const WAVES_TO_CALIBRATE := 2 ## completed waves at T3 before evolution is allowed
const MAX_TIER := 3
## Main + secondary upgrades: at most 2 branches per tower, only one of them above tier 2.
const MAX_BRANCHES := 2
const SECONDARY_MAX_TIER := 2


## Unlock state supplied by meta progression (Phase 4). Phase 3 default: everything unlocked.
class Unlocks:
	var branch_c: Dictionary = {} ## tower_id -> bool
	var evolutions: Dictionary = {} ## tower_id -> bool
	var all: bool = false

	static func everything() -> Unlocks:
		var u := Unlocks.new()
		u.all = true
		return u

	func branch_unlocked(def: TowerDef, b: int) -> bool:
		if all or b < 0 or b >= def.branches.size() or not def.branches[b].requires_research:
			return true
		return bool(branch_c.get(def.id, false))

	func evolution_unlocked(def: TowerDef) -> bool:
		return all or bool(evolutions.get(def.id, false))


static func branches_used(t: Tower) -> int:
	var n := 0
	for v in t.tiers:
		if v > 0:
			n += 1
	return n


## True if another branch than `b` is already above the secondary cap (i.e. is the main branch).
static func other_is_main(t: Tower, b: int) -> bool:
	for i in range(t.tiers.size()):
		if i != b and t.tiers[i] > SECONDARY_MAX_TIER:
			return true
	return false


## Next tier purchasable in branch `b` (ignoring cost/research), or null if the rules forbid it.
static func next_tier(t: Tower, b: int) -> TierDef:
	if b < 0 or b >= t.def.branches.size():
		return null
	var cur := t.tiers[b]
	if cur == 0 and branches_used(t) >= MAX_BRANCHES:
		return null
	if cur >= SECONDARY_MAX_TIER and other_is_main(t, b):
		return null
	var br := t.def.branches[b]
	if cur >= br.tiers.size() or cur >= MAX_TIER:
		return null
	return br.tiers[cur]


## "" when allowed, otherwise a human-readable reason.
static func upgrade_block_reason(t: Tower, b: int, unlocks: Unlocks, currency: int) -> String:
	if b < 0 or b >= t.def.branches.size():
		return I18n.t("No such branch")
	var cur := t.tiers[b]
	if cur == 0 and branches_used(t) >= MAX_BRANCHES:
		return I18n.t("Locked: 2 branches chosen")
	if cur >= SECONDARY_MAX_TIER and cur < MAX_TIER and other_is_main(t, b):
		return I18n.t("Secondary max (tier 2)")
	if not unlocks.branch_unlocked(t.def, b):
		return I18n.t("Requires research")
	var nt := next_tier(t, b)
	if nt == null:
		return I18n.t("Max tier")
	if currency < nt.cost:
		return I18n.f("Need %d more", nt.cost - currency)
	return ""


static func evolution_block_reason(t: Tower, unlocks: Unlocks, currency: int, evolved_count: int) -> String:
	if t.evolved:
		return I18n.t("Already evolved")
	var br := t.branch_def()
	if br == null or br.evolution == null:
		return I18n.t("Choose a branch first")
	if t.tier < MAX_TIER:
		return I18n.t("Requires tier 3")
	if not unlocks.evolution_unlocked(t.def):
		return I18n.t("Requires research")
	if t.waves_since_t3 < WAVES_TO_CALIBRATE:
		return I18n.f("Calibrating (%d/%d waves)", [t.waves_since_t3, WAVES_TO_CALIBRATE])
	if EVOLUTION_CAP > 0 and evolved_count >= EVOLUTION_CAP:
		return I18n.f("Evolution limit (%d per match)", EVOLUTION_CAP)
	if currency < br.evolution.cost:
		return I18n.f("Need %d more", br.evolution.cost - currency)
	return ""
