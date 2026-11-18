extends TestCase
## Gameplay guard: fingerprint of every campaign level (two bot configurations each) must equal the
## recorded baseline. Any visual-only change keeps this green; a gameplay change makes it fail.
## Re-recorded on 2026-11-13 for the content update (new maps, Rift, bosses); L1/L4/L7 were verified
## identical to the 0.8.0 baseline before re-recording.


func test_gameplay_matches_golden_baseline() -> void:
	var f := FileAccess.open(GoldenRun.PATH, FileAccess.READ)
	check(f != null, "golden file exists")
	if f == null:
		return
	var expected: Dictionary = JSON.parse_string(f.get_as_text())
	var actual: Dictionary = JSON.parse_string(JSON.stringify(GoldenRun.run_all(tree.root))) # same number types as the file
	eq(actual.size(), expected.size(), "same number of runs")
	for k in expected:
		var e: Dictionary = expected[k]
		var a: Dictionary = actual.get(k, {})
		for field in e:
			eq(str(a.get(field)), str(e[field]), "%s %s" % [k, field])
