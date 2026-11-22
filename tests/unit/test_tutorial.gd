extends TestCase
## Level-1 tutorial (2026-11-21): runs once (lifetime counter "tutorial_done"), steps follow the player's actions,
## Skip / finish marks it done so it never shows again.

var _saved: ProgressionModel
var _saved_level: LevelDef


func before_each() -> void:
	super.before_each()
	_saved = Progression.model
	var pm := ProgressionModel.new(_saved.campaign, MemoryStore.new())
	pm.load_profile()
	Progression.model = pm
	_saved_level = SceneRouter.pending_level
	SceneRouter.pending_challenge = null
	SceneRouter.pending_is_lab = false


func after_each() -> void:
	super.after_each()
	Progression.model = _saved
	SceneRouter.pending_level = _saved_level


func _scene(level_index: int) -> Node:
	SceneRouter.pending_level = Progression.model.campaign.levels[level_index]
	var scene: Node = load("res://gameplay/match/match_scene.tscn").instantiate()
	tree.root.add_child(scene)
	_nodes.append(scene)
	(scene.get("controller") as MatchController).auto_process = false
	return scene


func _tutorial(scene: Node) -> Tutorial:
	return (scene.get("hud") as Hud).find_child("Tutorial", true, false) as Tutorial


func test_runs_only_on_level_1_until_done() -> void:
	var levels := Progression.model.campaign.levels
	check(Tutorial.should_run(levels[0], false, false), "level 1, fresh profile")
	check(not Tutorial.should_run(levels[1], false, false), "not on level 2")
	check(not Tutorial.should_run(levels[0], true, false), "not in the lab")
	check(not Tutorial.should_run(levels[0], false, true), "not in a challenge")
	check(_tutorial(_scene(1)) == null, "no tutorial node on level 2")
	var tut := _tutorial(_scene(0))
	check(tut != null, "tutorial shown on level 1")
	eq(tut.step, Tutorial.Step.BUILD)
	check(tut.get("_spot") != Vector2.INF, "a build spot beside the path was found")


func test_steps_follow_the_player_and_finish_once() -> void:
	var scene := _scene(0)
	var c: MatchController = scene.get("controller")
	var tut := _tutorial(scene)
	for i in range(Tutorial.FIRST_TOWERS):
		eq(tut.step, Tutorial.Step.BUILD, "still asking for towers (%d built)" % i)
		var spot: Vector2 = tut.get("_spot")
		check(c.try_build(real_tower("pulse"), spot) != null, "suggested spot %d is buildable" % i)
	eq(tut.step, Tutorial.Step.START, "3 built -> start the wave")
	c.request_next_wave()
	eq(tut.step, Tutorial.Step.COIL, "wave started -> Coil step (waits for the wave to clear)")
	check(tut.get("_waiting"), "Coil hint waits for wave 1 to be cleared")
	c.tower_upgraded.emit(c.towers[0]) # (shortcut) upgrade step done -> counted as done, keeps hinting
	eq(tut.step, Tutorial.Step.COIL, "upgrade only counts in the upgrade step")
	tut.call("_go", Tutorial.Step.UPGRADE)
	c.tower_upgraded.emit(c.towers[0])
	eq(tut.step, Tutorial.Step.MORE, "after the upgrade: spare-money hints until the match ends")
	eq(Progression.model.profile.counter(Tutorial.COUNTER), 1, "already marked done")
	tut.finish() # Skip button
	eq(tut.step, Tutorial.Step.DONE)
	eq(Progression.model.profile.counter(Tutorial.COUNTER), 1, "marked done")
	tut.finish()
	eq(Progression.model.profile.counter(Tutorial.COUNTER), 1, "only counted once")
	check(not Tutorial.should_run(Progression.model.campaign.levels[0], false, false), "never shown again")
