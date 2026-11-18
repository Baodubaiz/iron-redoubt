extends SceneTree
## Records the gameplay fingerprint (see GoldenRun). Only re-record when gameplay is MEANT to change.

func _initialize() -> void:
	var data := GoldenRun.run_all(root)
	var f := FileAccess.open(GoldenRun.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ", true))
	f.close()
	for k in data:
		print(k, "  ", data[k])
	quit(0)
