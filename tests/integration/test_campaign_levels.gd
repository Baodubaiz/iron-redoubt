extends TestCase
## Every campaign level is completable by a scripted bot. Evidence, not balance validation.
## Circuit + Delta (1-20): NO-META profile (no research), only the towers a fresh player owns at that point.
## Prism + Rift (21-40): full research (by then a player has earned well over the 285 Cores it costs), bot
## buys a secondary branch too.

const SIM := preload("res://tools/sim/campaign_sim.gd")
## level id -> strategy that won it in tools/sim/campaign_sim.gd (campaign order: 4 regions x 10).
const WINNING := {
	"level_01": "balanced", "level_02": "balanced", "level_20": "balanced", "level_21": "heavy", "level_03": "balanced",
	"level_22": "heavy", "level_23": "heavy", "level_24": "heavy", "level_25": "heavy", "level_26": "heavy",
	"level_04": "balanced", "level_05": "heavy", "level_27": "heavy", "level_28": "balanced", "level_06": "heavy",
	"level_29": "heavy", "level_30": "balanced", "level_31": "heavy", "level_32": "heavy", "level_33": "heavy",
	"level_07": "balanced", "level_08": "balanced", "level_34": "heavy", "level_35": "heavy", "level_36": "heavy",
	"level_37": "heavy", "level_38": "heavy", "level_39": "heavy", "level_40": "balanced", "level_09": "heavy",
	"level_10": "balanced", "level_11": "balanced", "level_12": "balanced", "level_13": "heavy", "level_14": "heavy",
	"level_15": "balanced", "level_16": "balanced", "level_17": "heavy", "level_18": "balanced", "level_19": "balanced",
}
const META_FROM := 20 ## campaign index from which the full-research profile is used (Prism + Rift)


func test_every_level_completable() -> void:
	var campaign: CampaignDef = load("res://data/campaign.tres")
	eq(WINNING.size(), campaign.levels.size(), "a strategy per level")
	for i in range(campaign.levels.size()):
		var lvl := campaign.levels[i]
		var m := MatchController.new()
		m.auto_process = false
		tree.root.add_child(m)
		_nodes.append(m)
		var mods := SIM.no_meta_modifiers(campaign, i)
		var meta := i >= META_FROM
		if meta:
			mods.unlocks = UpgradeRules.Unlocks.everything()
			mods.start_currency_bonus = 50
			mods.base_hp_bonus = 3
			mods.early_bonus_multiplier = 1.25
		m.setup(lvl, 1, null, mods)
		var old_cp: bool = SIM.crosspath
		SIM.crosspath = meta
		var bot := SIM.make_bot(m, WINNING[String(lvl.id)])
		SIM.crosspath = old_cp
		var steps := int(2400.0 / DT)
		for k in range(steps):
			if m.is_over():
				break
			bot.step(DT)
			m.step(DT)
		print("    [campaign] %s %-8s %s -> %s hp=%d/%d t=%ds" % [lvl.id, WINNING[String(lvl.id)], "meta" if meta else "no-meta",
			MatchController.State.keys()[m.state], m.base.hp, m.base.max_hp, int(m.match_time)])
		eq(m.state, MatchController.State.WON, "%s completable" % lvl.id)
