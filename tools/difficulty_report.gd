extends SceneTree
## Dev tool: calibrated formula difficulty of every campaign level (DifficultyModel.level_score).
## 1.0 = narrow win. Hint: < 0.7 probably too easy, > 1.5 probably too hard. No bots needed.
##   godot --headless --path . -s res://tools/difficulty_report.gd
func _initialize() -> void:
	var c: CampaignDef = load("res://data/campaign.tres")
	for i in range(c.levels.size()):
		var l := c.levels[i]
		var s := DifficultyModel.level_score(c, i)
		var hint := "  <- too easy?" if s < 0.7 else ("  <- too hard?" if s > 1.5 else "")
		print("%2d %-9s score=%.2f%s" % [l.level_number, l.id, s, hint])
	quit(0)
