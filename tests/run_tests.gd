extends SceneTree
## Minimal headless test runner (no third-party addon).
##   godot --headless --path . -s res://tests/run_tests.gd [-- --filter=substring]
## Every method named test_* in tests/unit/*.gd and tests/integration/*.gd is executed.
## A test with zero assertions is reported as failed (guards against silently aborted tests).
## Also check stderr for "SCRIPT ERROR" — GDScript runtime errors abort a test without an exception.

const DIRS := ["res://tests/unit", "res://tests/integration"]


var _ran := false


## Tests run on the first frame (not in _initialize) so that nodes added to the root are inside the
## tree and receive _ready — needed for scene-level tests (match scene, lifecycle).
func _process(_delta: float) -> bool:
	if not _ran:
		_ran = true
		_run_all()
	return false


func _run_all() -> void:
	TranslationServer.set_locale("en") # assertions use the English source strings
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.substr(9)
	var passed := 0
	var failed := 0
	var failures: Array[String] = []
	var t0 := Time.get_ticks_msec()
	for dir in DIRS:
		for file in _list(dir):
			var script: GDScript = load(dir + "/" + file)
			if script == null or not script.can_instantiate():
				failed += 1
				failures.append("%s -> script failed to load/compile" % file)
				print("  FAIL  ", file, "  script failed to load/compile")
				continue
			for m in script.get_script_method_list():
				var name: String = m["name"]
				if not name.begins_with("test_"):
					continue
				var full := "%s::%s" % [file.get_basename(), name]
				if filter != "" and not full.contains(filter):
					continue
				var tc: TestCase = script.new()
				tc.tree = self
				tc.before_each()
				tc.call(name)
				tc.after_each()
				if tc.failures.is_empty() and tc.assert_count > 0:
					passed += 1
					print("  PASS  ", full)
				else:
					failed += 1
					var why := "no assertions ran (test aborted?)" if tc.failures.is_empty() else "; ".join(tc.failures)
					failures.append("%s -> %s" % [full, why])
					print("  FAIL  ", full, "  ", why)
	print("")
	print("==== %d passed, %d failed (%.1fs) ====" % [passed, failed, (Time.get_ticks_msec() - t0) / 1000.0])
	for f in failures:
		print("FAILED: ", f)
	quit(1 if failed > 0 else 0)


func _list(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(f)
	out.sort()
	return out
