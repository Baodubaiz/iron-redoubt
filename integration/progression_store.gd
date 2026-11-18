class_name ProgressionStore
extends RefCounted
## Storage boundary for the player profile. Implementations:
##   LocalFileStore  — on-device JSON (offline cache / development). NOT account sync.
##   MemoryStore     — tests (failure + conflict injection).
##   (Phase 6) a GameHub-backed store behind the GameHub adapter, once a real contract exists.
## Optimistic concurrency: save_data() is rejected with `conflict` when the stored revision is
## newer than `base_revision`; the caller merges and retries.


## Returns {ok: bool, data: Dictionary (empty if none), error: String}
func load_data() -> Dictionary:
	return {"ok": false, "data": {}, "error": "not implemented"}


## Returns {ok: bool, conflict: bool, remote: Dictionary, error: String}
func save_data(_data: Dictionary, _base_revision: int) -> Dictionary:
	return {"ok": false, "conflict": false, "remote": {}, "error": "not implemented"}
