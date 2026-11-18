class_name Profile
extends RefCounted
## Pure persistent-profile model (JSON-friendly Dictionary) + validation + conflict merge.
## Cores are never stored as a mutable balance: they are the sum of an idempotent ledger
## (credits positive, research spends negative). Duplicate keys can never pay twice and two
## profiles merge by ledger union without losing or duplicating currency.

const SCHEMA := 1
const MAX_PROCESSED := 200

var data: Dictionary


func _init(d: Dictionary = {}) -> void:
	data = d


static func fresh(starting_towers: Array[StringName]) -> Dictionary:
	var towers: Array = []
	for t in starting_towers:
		towers.append(String(t))
	return {
		"schema": SCHEMA, "revision": 0, "ledger": {}, "levels": {}, "towers": towers,
		"research": [], "achievements": {}, "challenges": {},
		"lifetime": {"counters": {}, "sets": {}}, "processed_matches": [],
		"shards": {}, "shard_pity": 0, "items": {}, "item_buy_seq": 0,
	}


## Coerces untrusted/old data into the current schema. Returns {data, repaired: bool}.
static func sanitize(raw: Dictionary, starting_towers: Array[StringName]) -> Dictionary:
	var d := fresh(starting_towers)
	var repaired := false
	if raw.is_empty():
		return {"data": d, "repaired": false}
	if int(raw.get("schema", -1)) != SCHEMA:
		repaired = true
	d["revision"] = maxi(int(raw.get("revision", 0)), 0)
	var ledger: Variant = raw.get("ledger", {})
	if ledger is Dictionary:
		for k in ledger:
			var v: Variant = ledger[k]
			if (v is float or v is int) and is_finite(float(v)):
				d["ledger"][String(k)] = int(v)
			else:
				repaired = true
	else:
		repaired = true
	var levels: Variant = raw.get("levels", {})
	if levels is Dictionary:
		for k in levels:
			var r: Variant = levels[k]
			if r is Dictionary:
				d["levels"][String(k)] = {
					"cleared": bool(r.get("cleared", false)), "clears": maxi(int(r.get("clears", 0)), 0),
					"best_hp": maxi(int(r.get("best_hp", 0)), 0), "flawless": bool(r.get("flawless", false)),
					"best_time": float(r.get("best_time", 0.0)),
				}
			else:
				repaired = true
	for key in ["towers", "research", "processed_matches"]:
		var arr: Variant = raw.get(key, [])
		if arr is Array:
			for v in arr:
				if v is String and not d[key].has(v):
					d[key].append(v)
		else:
			repaired = true
	for key in ["achievements", "challenges"]:
		var dict: Variant = raw.get(key, {})
		if dict is Dictionary:
			for k in dict:
				d[key][String(k)] = true
		else:
			repaired = true
	var sh: Variant = raw.get("shards", {})
	if sh is Dictionary:
		for k in sh:
			var e: Variant = sh[k]
			if e is Array and e.size() == 2 and e[0] is String and (e[1] is int or e[1] is float):
				d["shards"][String(k)] = [e[0], int(e[1])]
			else:
				repaired = true
	d["shard_pity"] = maxi(int(raw.get("shard_pity", 0)), 0)
	var it: Variant = raw.get("items", {})
	if it is Dictionary:
		for k in it:
			var e: Variant = it[k]
			if e is Array and e.size() == 2 and e[0] is String and (e[1] is int or e[1] is float):
				d["items"][String(k)] = [e[0], int(e[1])]
			else:
				repaired = true
	d["item_buy_seq"] = maxi(int(raw.get("item_buy_seq", 0)), 0)
	var lt: Variant = raw.get("lifetime", {})
	if lt is Dictionary:
		var c: Variant = lt.get("counters", {})
		if c is Dictionary:
			for k in c:
				d["lifetime"]["counters"][String(k)] = maxi(int(c[k]), 0)
		var s: Variant = lt.get("sets", {})
		if s is Dictionary:
			for k in s:
				if s[k] is Array:
					d["lifetime"]["sets"][String(k)] = (s[k] as Array).filter(func(x: Variant) -> bool: return x is String)
	return {"data": d, "repaired": repaired}


## Conflict resolution: monotonic union. Never loses progress, never duplicates currency.
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var m: Dictionary = a.duplicate(true)
	m["revision"] = maxi(int(a.get("revision", 0)), int(b.get("revision", 0)))
	for k in b["ledger"]:
		m["ledger"][k] = b["ledger"][k] # same key => same event; union is idempotent
	for k in b["levels"]:
		var rb: Dictionary = b["levels"][k]
		if not m["levels"].has(k):
			m["levels"][k] = rb.duplicate()
			continue
		var ra: Dictionary = m["levels"][k]
		ra["cleared"] = ra["cleared"] or rb["cleared"]
		ra["clears"] = maxi(ra["clears"], rb["clears"])
		ra["best_hp"] = maxi(ra["best_hp"], rb["best_hp"])
		ra["flawless"] = ra["flawless"] or rb["flawless"]
		var ta: float = ra["best_time"]
		var tb: float = rb["best_time"]
		ra["best_time"] = tb if ta <= 0.0 else (ta if tb <= 0.0 else minf(ta, tb))
	for key in ["towers", "research", "processed_matches"]:
		for v in b[key]:
			if not m[key].has(v):
				m[key].append(v)
	for key in ["achievements", "challenges"]:
		for k in b[key]:
			m[key][k] = true
	for k in b.get("shards", {}):
		m["shards"][k] = b["shards"][k] # event ledger, like Cores
	m["shard_pity"] = maxi(int(a.get("shard_pity", 0)), int(b.get("shard_pity", 0)))
	for k in b.get("items", {}):
		m["items"][k] = b["items"][k] # event ledger, like shards
	m["item_buy_seq"] = maxi(int(a.get("item_buy_seq", 0)), int(b.get("item_buy_seq", 0)))
	for k in b["lifetime"]["counters"]:
		m["lifetime"]["counters"][k] = maxi(int(m["lifetime"]["counters"].get(k, 0)), int(b["lifetime"]["counters"][k]))
	for k in b["lifetime"]["sets"]:
		var cur: Array = m["lifetime"]["sets"].get(k, [])
		for v in b["lifetime"]["sets"][k]:
			if not cur.has(v):
				cur.append(v)
		m["lifetime"]["sets"][k] = cur
	_trim(m)
	return m


static func _trim(d: Dictionary) -> void:
	var pm: Array = d["processed_matches"]
	while pm.size() > MAX_PROCESSED:
		pm.pop_front()


# ---------------------------------------------------------------- queries / mutations

func cores() -> int:
	var total := 0
	for k in data["ledger"]:
		total += int(data["ledger"][k])
	return total


func has_entry(key: String) -> bool:
	return data["ledger"].has(key)


## Idempotent credit. Returns true only the first time `key` is seen.
func credit(key: String, amount: int) -> bool:
	if amount <= 0 or data["ledger"].has(key):
		return false
	data["ledger"][key] = amount
	return true


## Idempotent spend; fails if the balance is insufficient.
func spend(key: String, amount: int) -> bool:
	if amount < 0 or data["ledger"].has(key) or cores() < amount:
		return false
	data["ledger"][key] = -amount
	return true


# Blueprint shards: an event ledger {key: [tower_id, amount]} (spends negative), so duplicate events never
# pay twice and two saves merge without losing or duplicating shards.
func shards(tower: StringName) -> int:
	var total := 0
	for k in data["shards"]:
		var e: Array = data["shards"][k]
		if e[0] == String(tower):
			total += int(e[1])
	return total


func add_shards(key: String, tower: StringName, amount: int) -> bool:
	if amount == 0 or data["shards"].has(key):
		return false
	if amount < 0 and shards(tower) < -amount:
		return false
	data["shards"][key] = [String(tower), amount]
	return true


## Ledger entries whose key starts with `prefix` (e.g. today's rewarded ads).
func shard_events(prefix: String) -> int:
	var n := 0
	for k in data["shards"]:
		if String(k).begins_with(prefix):
			n += 1
	return n


# Consumable items: an event ledger {key: [item_id, amount]}, same idempotent pattern as shards.
func item_count(item: StringName) -> int:
	var total := 0
	for k in data["items"]:
		var e: Array = data["items"][k]
		if e[0] == String(item):
			total += int(e[1])
	return total


func has_item_event(key: String) -> bool:
	return data["items"].has(key)


func add_item(key: String, item: StringName, amount: int) -> bool:
	if amount == 0 or data["items"].has(key):
		return false
	if amount < 0 and item_count(item) < -amount:
		return false
	data["items"][key] = [String(item), amount]
	return true


## Unique key for the next purchase (buying the same item twice must use two different keys).
func next_item_key() -> String:
	data["item_buy_seq"] = int(data["item_buy_seq"]) + 1
	return "buy:%d" % int(data["item_buy_seq"])


func owns_tower(id: StringName) -> bool:
	return data["towers"].has(String(id))


func unlock_tower(id: StringName) -> bool:
	if owns_tower(id):
		return false
	data["towers"].append(String(id))
	return true


func has_research(id: StringName) -> bool:
	return data["research"].has(String(id))


func level_record(id: StringName) -> Dictionary:
	return data["levels"].get(String(id), {"cleared": false, "clears": 0, "best_hp": 0, "flawless": false, "best_time": 0.0})


func is_cleared(id: StringName) -> bool:
	return bool(level_record(id)["cleared"])


func counter(name: String) -> int:
	return int(data["lifetime"]["counters"].get(name, 0))


func add_counter(name: String, amount: int) -> void:
	data["lifetime"]["counters"][name] = counter(name) + amount


func lifetime_set(name: String) -> Array:
	return data["lifetime"]["sets"].get(name, [])


func add_to_set(name: String, values: Array) -> void:
	var cur: Array = data["lifetime"]["sets"].get(name, [])
	for v in values:
		if not cur.has(String(v)):
			cur.append(String(v))
	data["lifetime"]["sets"][name] = cur


func mark_processed(match_id: String) -> bool:
	if data["processed_matches"].has(match_id):
		return false
	data["processed_matches"].append(match_id)
	_trim(data)
	return true
