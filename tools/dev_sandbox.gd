class_name DevSandbox
extends RefCounted
## Dev tools (captures, probes) must never touch the real player profile: this swaps the
## Progression autoload's model for an in-memory copy, so match results are not saved to disk.

static var _done := false


static func isolate(root: Node) -> void:
	if _done:
		return
	_done = true
	var prog = root.get_node("/root/Progression")
	var pm := ProgressionModel.new(prog.model.campaign, MemoryStore.new())
	pm.load_profile()
	prog.model = pm
