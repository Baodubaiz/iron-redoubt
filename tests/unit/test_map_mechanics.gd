extends TestCase
## Overload nodes, Day/Night with Beacon light, dynamic gate routes, placement on real maps.


func _level_on(map_path: String, waves: Array[WaveDef]) -> LevelDef:
	var l := make_level(waves, all_real_towers(), 100000, 50)
	l.map = load(map_path)
	return l


func test_overload_node_range_bonus() -> void:
	var waves: Array[WaveDef] = [make_wave(make_enemy_def(), 1), make_wave(make_enemy_def(), 1)]
	var m := make_match(_level_on("res://data/maps/circuit.tres", waves))
	var on := m.try_build(real_tower("pulse"), Vector2(760, 240))
	var off := m.try_build(real_tower("pulse"), Vector2(300, 240))
	check(on != null and off != null, "built")
	near(on.eff_range(), 150 * 1.15, 0.01, "+15% inside node")
	near(off.eff_range(), 150, 0.01)


func test_night_dims_unlit_towers_only() -> void:
	var w1 := make_wave(make_enemy_def(1.0e6, 0), 1)
	w1.night = true
	var waves: Array[WaveDef] = [w1, make_wave(make_enemy_def(), 1)]
	var m := make_match(_level_on("res://data/maps/delta.tres", waves))
	var lit := m.try_build(real_tower("pulse"), Vector2(560, 300))
	var dark := m.try_build(real_tower("pulse"), Vector2(860, 470))
	var b := m.try_build(real_tower("beacon"), Vector2(600, 260))
	check(lit != null and dark != null and b != null, "built")
	m.request_next_wave()
	m.step(DT)
	check(m.is_night, "night wave")
	check(not lit.night_dimmed, "inside Beacon light")
	check(dark.night_dimmed, "outside light")
	near(dark.eff_range(), 150 * 0.8, 0.01, "-20% range at night")
	near(b.attack_range, 130, 0.01, "Beacons are not dimmed")
	m.try_sell(b)
	m.step(DT)
	check(lit.night_dimmed, "selling the Beacon removes its light")


func test_day_waves_not_dimmed() -> void:
	var waves: Array[WaveDef] = [make_wave(make_enemy_def(1.0e6, 0), 1), make_wave(make_enemy_def(), 1)]
	var m := make_match(_level_on("res://data/maps/delta.tres", waves))
	var t := m.try_build(real_tower("pulse"), Vector2(860, 470))
	m.request_next_wave()
	m.step(DT)
	check(not m.is_night and not t.night_dimmed, "day")


func test_gate_switches_route_for_new_spawns() -> void:
	var g := SpawnGroupDef.new()
	g.enemy = make_enemy_def(100, 10)
	g.count = 1
	g.route_index = -1
	var w1 := WaveDef.new()
	var gs: Array[SpawnGroupDef] = [g]
	w1.groups = gs
	w1.active_route = 0
	var w2 := WaveDef.new()
	w2.groups = gs
	w2.active_route = 1
	var waves: Array[WaveDef] = [w1, w2, make_wave(make_enemy_def(), 1)]
	var m := make_match(_level_on("res://data/maps/prism.tres", waves))
	m.request_next_wave()
	m.step(DT)
	check(m.enemies[0].route == m.routes[0], "wave 1 uses route A")
	for e in m.enemies:
		m.damage_enemy(e, 1e9, Damage.Type.TRUE, 0)
	m.step(DT)
	m.request_next_wave()
	m.step(DT)
	eq(m.active_route, 1)
	check(m.enemies[0].route == m.routes[1], "wave 2 uses route B")


func test_closed_gate_route_stays_unbuildable() -> void:
	var waves: Array[WaveDef] = [make_wave(make_enemy_def(), 1)]
	var m := make_match(_level_on("res://data/maps/prism.tres", waves))
	eq(m.validate_placement(real_tower("pulse"), Vector2(600, 580)), PlacementRules.Result.ON_PATH, "route B blocked even while closed")
	eq(m.validate_placement(real_tower("pulse"), Vector2(600, 140)), PlacementRules.Result.ON_PATH)
	eq(m.validate_placement(real_tower("pulse"), Vector2(400, 470)), PlacementRules.Result.OK, "island between routes is buildable")


func test_all_campaign_data_is_consistent() -> void:
	var c: CampaignDef = load("res://data/campaign.tres")
	eq(c.levels.size(), 40, "40 levels")
	var per_region := {}
	var maps := {}
	var boss_levels: Array[int] = []
	var kits := {}
	for l in c.levels:
		var rg := l.map.region_id()
		per_region[rg] = int(per_region.get(rg, 0)) + 1
		check(not maps.has(l.map.id), "%s has its own map" % l.id)
		maps[l.map.id] = true
		check(not l.waves.is_empty(), "%s has waves" % l.id)
		for wi in range(l.waves.size()):
			var w := l.waves[wi]
			if w.is_boss:
				boss_levels.append(l.level_number)
				eq(wi, l.waves.size() - 1, "%s boss is the final wave" % l.id)
			for g in w.groups:
				check(g.enemy != null, "%s group enemy set" % l.id)
				if g.enemy.is_boss:
					check(w.is_boss, "%s boss only in a boss wave" % l.id)
					kits[g.enemy.boss_kit] = int(kits.get(g.enemy.boss_kit, 0)) + 1
				if g.route_index >= 0 and not g.enemy.flying:
					check(g.route_index < l.map.routes.size(), "%s route index valid" % l.id)
	for rg in [&"circuit", &"delta", &"prism", &"rift"]:
		eq(per_region.get(rg), 10, "%s has 10 levels" % rg)
	eq(str(boss_levels), str([5, 10, 15, 20, 25, 30, 35, 40]), "every region: a boss on its 5th and 10th level")
	eq(kits.size(), 8, "eight different boss kits")
	for k in kits:
		eq(kits[k], 1, "boss kit %s used once" % k)
	eq(c.research.size(), 27) # 22 tower (branch/evolution, 1-2 per tower; Coil added 2026-11-21) + 5 support
	eq(c.achievements.size(), 13)
	check(c.daily_pool.size() >= 7 and c.weekly_pool.size() >= 4, "challenge pools")


## Geometry sanity for every campaign map: lanes end at the base, nodes / terrain stay off the lanes,
## the base is inside the playfield, and there is plenty of room to build.
func test_campaign_map_geometry() -> void:
	var c: CampaignDef = load("res://data/campaign.tres")
	for l in c.levels:
		var m := l.map
		var base := m.base_position()
		check(m.build_area.grow(-20).has_point(base), "%s base inside the build area" % m.id)
		for r in m.routes:
			check(r.size() >= 2, "%s route has points" % m.id)
			check(r[r.size() - 1].distance_to(base) < 0.5, "%s every lane ends at the base" % m.id)
		for z in m.range_bonus_zones:
			var zc := Vector2(z.x, z.y)
			for r in m.routes:
				check(GeoUtil.dist_point_polyline(zc, r) >= m.path_half_width + 22.0, "%s overload node %s off the lane" % [m.id, zc])
			for b in m.blocked_rects:
				check(not GeoUtil.circle_intersects_rect(zc, z.z, b), "%s overload node clear of terrain" % m.id)
			check(m.build_area.has_point(zc), "%s overload node in the build area" % m.id)
		for b in m.blocked_rects:
			for r in m.routes:
				var hit := false
				for k in range(r.size() - 1):
					var a := r[k]
					var e := r[k + 1]
					var steps := int(a.distance_to(e) / 4.0) + 1
					for s in range(steps + 1):
						if GeoUtil.circle_intersects_rect(a.lerp(e, float(s) / steps), m.path_half_width, b):
							hit = true
				check(not hit, "%s terrain %s off the lanes" % [m.id, b])
		var rules := PlacementRules.new(m)
		var spots := 0
		var x := 30.0
		while x < 1160.0:
			var y := 90.0
			while y < 720.0:
				if rules.validate(Vector2(x, y), 22.0, []) == PlacementRules.Result.OK:
					spots += 1
				y += 40.0
			x += 40.0
		check(spots >= 120, "%s has room to build (%d spots)" % [m.id, spots])
