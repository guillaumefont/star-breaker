extends SceneTree
## The campaign after world 1: flies worlds 2, 3 and 4 start to finish (invincible, rapid
## fire, weaving), checks each world's own enemies, gates, tunnels and boss, then the ending.
## Also checks that tunnel walls and gates really kill a ship that isn't invincible.

var main: Node3D
var fails := 0

const EXPECT := [
	["shard", "icicle", "flake", "hulk", "carrier", "block"],
	["drone", "gun", "crawler", "piston", "carrier", "block"],
	["ember", "seeker", "sentinel", "shard", "drone", "flake", "carrier", "block"],
]


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func tick(n := 1, god := true) -> void:
	for i in n:
		if god and not main.P.is_empty():
			main.P.inv = maxi(main.P.inv, 2)
		main.update()
		main._process(1.0 / 60.0)


func fly_world(wi: int) -> void:
	var seen := {}
	var gates := {}
	var narrowest := 999.0
	Input.action_press("fire")
	for i in 9000:
		var up := (i / 70) % 2 == 0
		Input.action_press("up" if up else "down")
		Input.action_release("down" if up else "up")
		tick()
		for e in main.G.enemies:
			seen[e.type] = true
		for g in main.G.gates:
			gates[g.mode] = true
		var h: Vector2 = Worlds.heights(main.wdef, main.G.scroll + main.P.x)
		narrowest = minf(narrowest, main.PH - h.x - h.y)
		if main.G.boss:
			break
	Input.action_release("up")
	Input.action_release("down")
	var want: Array = EXPECT[wi - 1]
	var missing := want.filter(func(t): return not seen.has(t))
	check(missing.is_empty(), "%s: its enemies appear (missing: %s)" % [main.wdef.name, ", ".join(missing)])
	check(gates.size() >= 1, "%s: gates appear (%s)" % [main.wdef.name, ", ".join(gates.keys())])
	check(narrowest < 50.0, "%s: the cave narrows into tunnels (narrowest %.0f)" % [main.wdef.name, narrowest])
	check(main.G.boss != null and main.G.boss.kind == main.wdef.boss, "%s: %s arrives" % [main.wdef.name, main.wdef.boss_name])
	check(main.audio._want_song == main.wdef.boss_song, "%s: boss music plays" % main.wdef.name)


func beat_boss() -> void:
	var B: Dictionary = main.G.boss
	tick(300)
	check(not B.enter, "%s settles in" % main.wdef.boss_name)
	for p in B.list:
		if not p.core and p.max < 9999:
			p.hp = 0.5
	var t := 0
	while t < 3000 and not B.dying:
		t += 1
		for part in main.G.bparts:
			if part.kind == "part" or part.kind == "core":
				main.boss_damage(part, 6)
				break
		tick()
	check(B.dying > 0, "%s can be destroyed (%d ticks)" % [main.wdef.boss_name, t])
	tick(160)
	check(main.G.get("boss") == null and main.G.clear_t > 0, "%s: world clear" % main.wdef.name)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await process_frame
	print("Star Breaker campaign test")

	# tunnels and gates are solid
	main.new_game(1)
	tick(80)
	var tu: Dictionary = main.wdef.terrain.tunnels[0]
	var wx: float = (tu.a + tu.b) / 2.0
	var h: Vector2 = Worlds.heights(main.wdef, wx)
	check(absf(main.PH - h.x - h.y - tu.gap) < 1.0, "a tunnel is %.0f units high" % (main.PH - h.x - h.y))
	main.warp(wx - main.P.x)
	main.P.inv = 0
	main.P.y = h.x - 2.0
	tick(1, false)
	check(not main.P.alive, "hitting a tunnel wall destroys the ship")
	main.new_game(1)
	tick(80, true)
	main.P.inv = 0
	main.add_gate({x = main.G.scroll + main.P.x + 1.5, type = "gate", off = 0.0, gh = 12.0})
	var g: Dictionary = main.G.gates[-1]
	main.P.y = g.gy - g.gh - 4.0
	tick(1, false)
	check(not main.P.alive, "hitting a gate pillar destroys the ship")
	main.new_game(1)
	tick(80, true)
	main.P.inv = 0
	main.add_gate({x = main.G.scroll + main.P.x + 1.5, type = "gate", off = 0.0, gh = 12.0})
	g = main.G.gates[-1]
	main.P.y = g.gy
	tick(1, false)
	check(main.P.alive, "flying through a gate's opening is safe")
	var sh := {x = 0.0, wx = 0.0, base = 63.0, gh0 = 14.0, gh = 14.0, gy = 63.0, mode = "shutter", rate = 0.03, amp = 0.0, dead = false}
	var opened := false
	var closed := false
	for t in 400:
		main.G.t = t
		main.update_gate(sh)
		opened = opened or sh.gh > 13.0
		closed = closed or sh.gh < 3.0
	check(opened and closed, "shutter gates open and close")
	main.spawn({x = main.G.scroll + 200.0, type = "wall"})
	var blocks: Array = main.G.enemies.filter(func(e): return e.type == "block")
	check(blocks.size() >= 4, "a breakable wall fills the corridor (%d blocks)" % blocks.size())

	# worlds 2 to 4 back to back
	main.new_game(1)
	var bg: Color = main._env.background_color
	check(bg != Color(Worlds.LIST[0].pal.bg), "world 2 has its own colours")
	for wi in [1, 2, 3]:
		check(main.G.world == wi and main.wdef == Worlds.LIST[wi], "world %d: %s" % [wi + 1, main.wdef.name])
		check(main.audio._want_song == main.wdef.song, "%s: its own song" % main.wdef.name)
		fly_world(wi)
		beat_boss()
		var t := 0
		while t < 400 and main.mode == "play" and main.G.world == wi:
			t += 1
			tick()
	Input.action_release("fire")
	check(main.mode == "end", "beating the Star Heart shows the ending")
	check(main.hud.end_scr.visible, "ending screen is up")
	check(main.audio._want_song == "ending", "ending music")
	tick(100, false)
	main.latch["start"] = true
	tick(1, false)
	check(main.mode == "title", "the ending returns to the title")
	tick(1, false)
	main.latch["start"] = true
	tick(1, false)
	check(main.mode == "play" and main.G.world == 0, "a new run starts at world 1")

	print("%d failure(s)" % fails)
	quit(1 if fails else 0)
