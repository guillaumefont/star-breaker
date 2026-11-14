class_name Worlds
extends RefCounted
## The campaign: six worlds, each with its own look, terrain, enemy mix, song and boss. Every
## level alternates open terrain (caves and winding tunnels) with fortress sections (stepped
## metal corridors, towers with guns, locked barriers, gun lines and walls). All content is
## original.
##
## Terrain is a ceiling and a floor height (stage units) for every world position `wx`:
## a noisy cave that can narrow into winding tunnels or turn into a fortress. Gates, towers and
## walls are objects placed by the level script. Script entries with y < 0 spawn on the local
## corridor centre line.

const PH := 126.0
## Fortress corridors change height in steps this long (a multiple of the 8-unit terrain grid).
const STEP := 56.0

const LIST := [
	{
		name = "The Hollow Moon", sub = "World 1", boss = "bloom", boss_name = "Bloom Mother", song = "stage", boss_song = "boss",
		boss_at = 7300.0, clear = "Bloom Mother cut down",
		pal = {bg = "0c0a26", top = "1c1046", mid = "0c0a26", bot = "071225", fog = "120f26", amb = "8f8cc4", rim = "ff4fa3",
			planet = "5a3d8f", planet_e = "1a0c2e", ring = "8a74c9", far = "2c2656", star_a = "9a93c8", star_b = "e8e4f6",
			plate = "5d5a86", plate2 = "48456e", light = "4fe3d6"},
		rock = ["rock", "rock2"], deco = "cone", deco_mats = ["crystal_c", "crystal_m"], gate = "crystal_c",
		pool = ["waves", "hopper", "waves", "shell"], flyer = "waves",
		terrain = {start = 500.0, end = 7100.0, ca = 1.0, fa = 1.0, ph = 0.0, bumps = [[1800.0, 2500.0, 0.35]],
			tunnels = [{a = 2520.0, b = 3060.0, gap = 46.0, amp = 12.0, freq = 0.011, cy = 63.0}],
			forts = [{a = 3400.0, b = 4700.0, gap = 54.0, seed = 3.0}, {a = 5900.0, b = 6960.0, gap = 48.0, seed = 7.0}]},
	},
	{
		name = "Frost Rift", sub = "World 2", boss = "prism", boss_name = "Prism Warden", song = "frost", boss_song = "boss",
		boss_at = 7300.0, clear = "Prism Warden shattered",
		pal = {bg = "08162a", top = "16365a", mid = "0a1a33", bot = "050c1a", fog = "0c1c30", amb = "9cc4e8", rim = "7fe8ff",
			planet = "8fb8e0", planet_e = "1a3050", ring = "cfefff", far = "2a4060", star_a = "a8c8e8", star_b = "f0f8ff",
			plate = "7f9cc0", plate2 = "5d7aa0", light = "bff6ff"},
		rock = ["ice_rock", "ice_rock2"], deco = "spike", deco_mats = ["ice_c", "ice_b"], gate = "ice_c",
		pool = ["shards", "flake", "shards", "hulk"], flyer = "shards",
		terrain = {start = 300.0, end = 7100.0, ca = 0.75, fa = 1.0, ph = 1.7, bumps = [[900.0, 1300.0, 0.4]],
			tunnels = [{a = 1500.0, b = 2320.0, gap = 44.0, amp = 18.0, freq = 0.009, cy = 63.0},
				{a = 2860.0, b = 3360.0, gap = 40.0, amp = 12.0, freq = 0.013, cy = 61.0},
				{a = 5000.0, b = 5800.0, gap = 42.0, amp = 20.0, freq = 0.01, cy = 63.0}],
			forts = [{a = 3500.0, b = 4800.0, gap = 52.0, seed = 11.0}, {a = 5900.0, b = 6960.0, gap = 48.0, seed = 13.0}]},
	},
	{
		name = "Verdant Hive", sub = "World 3", boss = "queen", boss_name = "Hive Queen", song = "hive", boss_song = "boss",
		boss_at = 7300.0, clear = "Hive Queen brought down",
		pal = {bg = "0c1a0c", top = "1e3a14", mid = "0c1a0c", bot = "060c06", fog = "101e0c", amb = "b8d08f", rim = "c8f560",
			planet = "7aa040", planet_e = "1a2a08", ring = "d8e890", far = "263a20", star_a = "c8d8a0", star_b = "f4ffe0",
			plate = "6a6040", plate2 = "4e4630", light = "ffb547"},
		rock = ["hive_rock", "hive_rock2"], deco = "cone", deco_mats = ["amber", "moss"], gate = "amber",
		pool = ["wasps", "spitters", "wasps", "nest", "waves"], flyer = "wasps",
		terrain = {start = 200.0, end = 7100.0, ca = 1.05, fa = 1.0, ph = 5.3, bumps = [[600.0, 1200.0, 0.3]],
			tunnels = [{a = 1500.0, b = 2350.0, gap = 44.0, amp = 20.0, freq = 0.0095, cy = 63.0},
				{a = 3900.0, b = 4700.0, gap = 42.0, amp = 14.0, freq = 0.012, cy = 63.0}],
			forts = [{a = 2500.0, b = 3700.0, gap = 54.0, seed = 17.0}, {a = 5300.0, b = 6900.0, gap = 48.0, seed = 19.0}]},
	},
	{
		name = "Iron Foundry", sub = "World 4", boss = "titan", boss_name = "Furnace Titan", song = "foundry", boss_song = "boss",
		boss_at = 7300.0, clear = "Furnace Titan melted down",
		pal = {bg = "1a0f0c", top = "3a1c10", mid = "1a0f0c", bot = "0c0808", fog = "1c100c", amb = "c4a08f", rim = "ff8a3d",
			planet = "8f4a2a", planet_e = "2e120a", ring = "c99a74", far = "3a2a26", star_a = "c8a893", star_b = "fff0e0",
			plate = "6e625e", plate2 = "554a46", light = "ff7a1a"},
		rock = ["metal_rock", "metal_rock2"], deco = "strut", deco_mats = ["hot", "hazard"], gate = "hot",
		pool = ["drones", "crawler", "drones", "pistons"], flyer = "drones",
		terrain = {start = 200.0, end = 7100.0, ca = 1.05, fa = 1.05, ph = 4.1, bumps = [],
			tunnels = [{a = 700.0, b = 1520.0, gap = 48.0, amp = 10.0, freq = 0.012, cy = 63.0},
				{a = 2200.0, b = 3300.0, gap = 46.0, amp = 16.0, freq = 0.008, cy = 63.0}],
			forts = [{a = 3500.0, b = 4900.0, gap = 50.0, seed = 23.0}, {a = 5900.0, b = 6960.0, gap = 46.0, seed = 29.0}]},
	},
	{
		name = "Bastion Ring", sub = "World 5", boss = "bastion", boss_name = "Bastion Core", song = "bastion", boss_song = "boss",
		boss_at = 7300.0, clear = "Bastion Core breached",
		pal = {bg = "0a0c1e", top = "1a1e44", mid = "0a0c1e", bot = "05060f", fog = "0c0e22", amb = "a0a8e0", rim = "ff4fa3",
			planet = "4a5aa0", planet_e = "10183a", ring = "a0b0ff", far = "222848", star_a = "a0a8d8", star_b = "eef0ff",
			plate = "7078a0", plate2 = "50587e", light = "ff4fa3"},
		rock = ["plate", "plate2"], deco = "strut", deco_mats = ["neon", "neon2"], gate = "neon",
		pool = ["lancers", "drones", "lancers", "bulwark"], flyer = "drones",
		terrain = {start = 150.0, end = 7100.0, ca = 0.8, fa = 0.8, ph = 2.2, bumps = [],
			tunnels = [{a = 4900.0, b = 5700.0, gap = 40.0, amp = 14.0, freq = 0.012, cy = 63.0}],
			forts = [{a = 300.0, b = 2000.0, gap = 54.0, seed = 31.0}, {a = 3100.0, b = 4800.0, gap = 50.0, seed = 37.0},
				{a = 5800.0, b = 6960.0, gap = 46.0, seed = 41.0}]},
	},
	{
		name = "Star Core", sub = "Final world", boss = "heart", boss_name = "Star Heart", song = "core", boss_song = "final",
		boss_at = 7300.0, clear = "The star is broken",
		pal = {bg = "200808", top = "4a1408", mid = "200808", bot = "100404", fog = "260a06", amb = "e0a080", rim = "ffcc40",
			planet = "ffb040", planet_e = "ff6a00", ring = "ffd890", far = "4a1a10", star_a = "ffc890", star_b = "fff4d0",
			plate = "6a3a30", plate2 = "502a22", light = "ffcc40"},
		rock = ["magma_rock", "magma_rock2"], deco = "cone", deco_mats = ["lava", "gold"], gate = "lava",
		pool = ["embers", "seekers", "shards", "sentinel", "drones", "wasps"], flyer = "seekers",
		terrain = {start = 300.0, end = 7100.0, ca = 0.9, fa = 1.15, ph = 2.9, bumps = [[1000.0, 1500.0, 0.4]],
			tunnels = [{a = 1700.0, b = 2520.0, gap = 42.0, amp = 22.0, freq = 0.0085, cy = 63.0},
				{a = 2920.0, b = 3520.0, gap = 38.0, amp = 12.0, freq = 0.016, cy = 63.0}],
			forts = [{a = 3700.0, b = 5100.0, gap = 50.0, seed = 43.0}, {a = 5900.0, b = 6960.0, gap = 44.0, seed = 47.0}]},
	},
]


static func smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func hash1(n: float) -> float:
	var s := sin(n * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)


## Ceiling (x) and floor (y) heights at world position `wx`.
static func heights(w: Dictionary, wx: float) -> Vector2:
	var tr: Dictionary = w.terrain
	var a := smooth(tr.start, tr.start + 200.0, wx) * (1.0 - smooth(tr.end - 200.0, tr.end, wx))
	if a <= 0.0:
		return Vector2.ZERO
	var k := 1.0
	for b in tr.bumps:
		k += b[2] * smooth(b[0], b[0] + 150.0, wx) * (1.0 - smooth(b[1] - 150.0, b[1], wx))
	var ph: float = tr.ph
	var c: float = a * k * tr.ca * (13.0 + 7.0 * sin(wx * 0.019 + ph) + 5.0 * sin(wx * 0.051 + 1.3 + ph))
	var f: float = a * k * tr.fa * (13.0 + 7.0 * sin(wx * 0.017 + 2.0 + ph) + 5.0 * sin(wx * 0.043 + 0.4 + ph))
	for tu in tr.tunnels:
		var tw := smooth(tu.a, tu.a + 140.0, wx) * (1.0 - smooth(tu.b - 140.0, tu.b, wx))
		if tw <= 0.0:
			continue
		var cy: float = tu.cy + tu.amp * sin((wx - tu.a) * tu.freq)
		c = lerpf(c, cy - tu.gap / 2.0, tw)
		f = lerpf(f, PH - (cy + tu.gap / 2.0), tw)
	for fo in tr.forts:
		if wx <= fo.a or wx >= fo.b:
			continue
		var fw := smooth(fo.a, fo.a + 64.0, wx) * (1.0 - smooth(fo.b - 64.0, fo.b, wx))
		var fh := fort_h(fo, wx)
		c = lerpf(c, fh.x, fw)
		f = lerpf(f, fh.y, fw)
	return Vector2(c, f)


## Fortress corridor: flat ceiling and floor that change height in steps of STEP units, each
## step a short 8-unit ramp (it matches the terrain mesh grid, so what you see is what hits).
static func fort_h(fo: Dictionary, wx: float) -> Vector2:
	var k := floori((wx - fo.a) / STEP)
	var t := clampf((wx - fo.a - k * STEP) / 8.0, 0.0, 1.0)
	return _fort_step(fo, k - 1).lerp(_fort_step(fo, k), t)


static func _fort_step(fo: Dictionary, k: int) -> Vector2:
	var sd: float = fo.seed
	var c := 10.0 + floorf(hash1(sd + k * 7.31) * 5.0) * 7.0
	var f := 10.0 + floorf(hash1(sd * 1.7 + k * 3.13 + 0.5) * 5.0) * 7.0
	var room: float = PH - fo.gap
	if c + f > room:
		var cut := (c + f - room) / 2.0
		c -= cut
		f -= cut
	return Vector2(c, f)


## True inside a tunnel section (used by tests and to keep script waves sensible).
static func in_tunnel(w: Dictionary, wx: float) -> bool:
	for tu in w.terrain.tunnels:
		if wx > tu.a + 140.0 and wx < tu.b - 140.0:
			return true
	return false


## True inside a fortress section (fortress terrain is drawn as metal plating).
static func in_fort(w: Dictionary, wx: float) -> bool:
	for fo in w.terrain.forts:
		if wx > fo.a + 24.0 and wx < fo.b - 24.0:
			return true
	return false


# ---------- level scripts ----------
## Worlds 1, 2, 4 and 6 open with a hand-made first half; the rest of every level (and all of
## worlds 3 and 5) is built from the world's fortress ranges and enemy pool by `_sections`,
## with a fixed seed so a level is the same every time.

static func script(i: int) -> Array:
	var s: Array = []
	var w: Dictionary = LIST[i]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + i * 77
	var open_from := 0.0
	match w.name:
		"The Hollow Moon":
			_moon(s)
			open_from = 3100.0
		"Frost Rift":
			_frost(s)
			open_from = 3420.0
		"Iron Foundry":
			_foundry(s)
			open_from = 3320.0
		"Star Core":
			_core(s)
			open_from = 3620.0
		_:
			open_from = 140.0
	_sections(s, i, open_from, w.boss_at - 260.0, rng)
	s.sort_custom(func(a, b): return a.x < b.x)
	return s


## Fills [x0, x1] with fortress rooms inside the world's fortress ranges and enemy groups from
## its pool outside them, with an item carrier every so often.
static func _sections(s: Array, i: int, x0: float, x1: float, rng: RandomNumberGenerator) -> void:
	var w: Dictionary = LIST[i]
	var drops := ["P", "L", "S"]
	var nd := 0
	var x := x0
	var since_drop := 400.0
	var since_heavy := 0.0
	while x < x1:
		var fort := _fort_at(w, x)
		var tun := in_tunnel(w, x)
		if since_drop > 520.0:
			_add(s, x, "carrier", {y = -1, drop = drops[nd % 3]})
			nd += 1
			since_drop = 0.0
			x += 60.0
			continue
		if not fort.is_empty() and x > fort.a + 90.0 and x < fort.b - 200.0:
			var room: int = rng.randi_range(0, 4)
			var used := _fort_room(s, x, room, rng)
			x += used
			since_drop += used
			continue
		# open terrain: one group from the world's pool
		var kind: String = w.pool[rng.randi_range(0, w.pool.size() - 1)]
		if kind in ["shell", "hulk", "sentinel", "bulwark", "nest"]:
			if since_heavy < 500.0 or tun:
				kind = w.pool[0]
			else:
				since_heavy = 0.0
		var step := _group(s, x, kind, tun, rng)
		x += step
		since_drop += step
		since_heavy += step


static func _fort_at(w: Dictionary, x: float) -> Dictionary:
	for fo in w.terrain.forts:
		if x >= fo.a and x < fo.b:
			return fo
	return {}


## One fortress room starting at x; returns its length.
static func _fort_room(s: Array, x: float, room: int, rng: RandomNumberGenerator) -> float:
	match room:
		0:
			# towers rising from the floor and hanging from the ceiling, each with a gun on top
			var side := rng.randi_range(0, 1)
			for k in 3:
				_add(s, x + k * 78.0, "tower", {side = (side + k) % 2})
			_add(s, x + 120.0, "flyers", {y = -1})
			return 270.0
		1:
			# a locked barrier: shoot the generator on its lip to drop the field
			_add(s, x + 30.0, "flyers", {y = -1})
			_add(s, x + 140.0, "gate", {off = rng.randf_range(-6.0, 6.0), gh = 13.0, mode = "locked"})
			return 250.0
		2:
			# gun line on both walls, then a wall to shoot through
			for k in 4:
				_add(s, x + k * 52.0, "gun", {side = k % 2})
			_add(s, x + 230.0, "wall")
			return 300.0
		3:
			# a shutter and a sliding gate in a row
			_add(s, x + 40.0, "gate", {off = 0.0, gh = 14.0, mode = "shutter", rate = rng.randf_range(0.024, 0.032)})
			_add(s, x + 110.0, "flyers", {y = -1})
			_add(s, x + 200.0, "gate", {off = 0.0, gh = 13.0, mode = "slide", amp = 8.0, rate = rng.randf_range(0.018, 0.026)})
			return 280.0
		_:
			# a tight corridor run with fliers and a tower in the middle
			_add(s, x, "flyers", {y = -1})
			_add(s, x + 90.0, "tower", {side = rng.randi_range(0, 1)})
			_add(s, x + 150.0, "flyers", {y = -1})
			return 240.0


## One group of the world's enemies at x (y follows the corridor in tunnels); returns spacing.
static func _group(s: Array, x: float, kind: String, tun: bool, rng: RandomNumberGenerator) -> float:
	var y := -1.0 if tun else rng.randf_range(36.0, 90.0)
	match kind:
		"waves":
			_wave(s, x, y, rng.randi_range(5, 7), 8.0 if tun else 16.0)
		"hopper":
			_add(s, x, "hopper", {n = 3})
		"shards":
			_add(s, x, "shards", {y = y, n = rng.randi_range(3, 5)})
		"flake":
			_add(s, x, "flake", {y = y})
		"drones":
			_add(s, x, "drones", {y = y, n = rng.randi_range(4, 6)})
		"crawler":
			_add(s, x, "crawler")
			_add(s, x + 40.0, "drones", {y = y, n = 4})
		"pistons":
			for k in 3:
				_add(s, x + k * 64.0, "piston", {side = k % 2})
			return 220.0
		"embers":
			_add(s, x, "embers", {n = rng.randi_range(3, 5)})
		"seekers":
			_add(s, x, "seekers", {y = y, n = rng.randi_range(2, 3)})
		"wasps":
			_add(s, x, "wasps", {y = y, n = rng.randi_range(5, 7)})
		"lancers":
			_add(s, x, "lancers", {n = rng.randi_range(2, 3)})
		"spitters":
			for k in 3:
				_add(s, x + k * 60.0, "spitter", {side = k % 2})
			return 200.0
		_:
			# heavies: shell, hulk, sentinel, bulwark, nest
			_add(s, x, kind, {y = rng.randf_range(50.0, 76.0)})
			return 170.0
	return rng.randf_range(80.0, 115.0)


static func _add(s: Array, x: float, type: String, o := {}) -> void:
	var d := {x = x, type = type}
	d.merge(o)
	s.append(d)


static func _wave(s: Array, x: float, y: float, n := 5, amp := 14.0) -> void:
	_add(s, x, "wave", {y = y, n = n, amp = amp})


## World 1: the original cave, now ending in a winding tunnel with two gates.
static func _moon(s: Array) -> void:
	_wave(s, 150, 40); _wave(s, 250, 86); _add(s, 340, "carrier", {y = 62, drop = "P"}); _wave(s, 430, 30); _wave(s, 500, 96, 6, 18)
	var k := 0
	var x := 650
	while x < 3080:
		_add(s, x, "turret", {side = k % 2})
		x += 88
		k += 1
	_wave(s, 620, 63, 5, 24); _add(s, 760, "carrier", {y = 50, drop = "L"}); _wave(s, 840, 44); _wave(s, 900, 82)
	_add(s, 990, "shell", {y = 63}); _add(s, 1120, "hopper", {n = 3}); _wave(s, 1200, 42, 6); _wave(s, 1260, 86, 6)
	_add(s, 1380, "carrier", {y = 70, drop = "S"}); _wave(s, 1460, 63, 7, 24); _add(s, 1570, "hopper", {n = 3}); _add(s, 1650, "shell", {y = 46}); _add(s, 1720, "shell", {y = 82})
	_wave(s, 1830, 52); _wave(s, 1890, 76); _add(s, 1970, "carrier", {y = 63, drop = "L"}); _add(s, 2070, "hopper", {n = 4}); _wave(s, 2150, 46, 6, 14); _wave(s, 2210, 80, 6, 14)
	_add(s, 2310, "shell", {y = 63}); _wave(s, 2430, 63, 8, 22); _add(s, 2530, "carrier", {y = 58, drop = "S"})
	# the tunnel: gates first fixed, then a sliding one
	_wave(s, 2640, -1, 6, 8); _add(s, 2730, "gate", {off = -7.0, gh = 14.0})
	_wave(s, 2800, -1, 5, 8); _add(s, 2900, "gate", {off = 7.0, gh = 14.0, mode = "slide", amp = 7.0, rate = 0.02})
	_add(s, 2960, "carrier", {y = -1, drop = "P"})


## World 2: icicles under a low ceiling, crystal darts, then a tunnel of sliding gates and
## ice walls to shoot through.
static func _frost(s: Array) -> void:
	_add(s, 150, "flake", {y = 40}); _add(s, 230, "flake", {y = 86}); _add(s, 300, "shards", {y = 63, n = 3})
	_add(s, 380, "carrier", {y = 62, drop = "P"}); _add(s, 460, "shards", {y = 40, n = 4}); _add(s, 540, "flake", {y = 63})
	var x := 600.0
	while x < 1460:
		_add(s, x, "icicle")
		x += 64
	_add(s, 700, "hulk", {y = 72}); _add(s, 820, "shards", {y = 86, n = 4}); _add(s, 900, "carrier", {y = 70, drop = "L"})
	_add(s, 1000, "flake", {y = 54}); _add(s, 1060, "flake", {y = 84}); _add(s, 1150, "shards", {y = 63, n = 5})
	_add(s, 1250, "hulk", {y = 66}); _add(s, 1360, "carrier", {y = 70, drop = "S"})
	# tunnel one
	_add(s, 1560, "carrier", {y = -1, drop = "P"}); _add(s, 1630, "shards", {y = -1, n = 3})
	_add(s, 1720, "gate", {off = 0.0, gh = 13.0, mode = "slide", amp = 8.0, rate = 0.018})
	_add(s, 1820, "shards", {y = -1, n = 3}); _add(s, 1900, "flake", {y = -1})
	_add(s, 1980, "gate", {off = 0.0, gh = 12.0, mode = "slide", amp = 10.0, rate = 0.022})
	_add(s, 2100, "wall"); _add(s, 2190, "shards", {y = -1, n = 4})
	x = 2400.0
	while x < 2820:
		_add(s, x, "icicle")
		x += 56
	_add(s, 2420, "hulk", {y = 56}); _add(s, 2500, "shards", {y = 86, n = 4}); _add(s, 2580, "carrier", {y = 64, drop = "L"})
	_add(s, 2660, "flake", {y = 44}); _add(s, 2700, "flake", {y = 86}); _add(s, 2760, "shards", {y = 63, n = 5})
	# tunnel two
	_add(s, 2900, "carrier", {y = -1, drop = "S"}); _add(s, 2990, "wall")
	_add(s, 3060, "shards", {y = -1, n = 3}); _add(s, 3140, "gate", {off = 0.0, gh = 12.0, mode = "slide", amp = 9.0, rate = 0.025})
	_add(s, 3230, "wall"); _add(s, 3300, "flake", {y = -1})


## World 3: drones and floor crawlers, pistons that slam out of the walls and furnace
## shutters that open and close.
static func _foundry(s: Array) -> void:
	_add(s, 150, "drones", {y = 40, n = 5}); _add(s, 260, "drones", {y = 86, n = 5}); _add(s, 340, "carrier", {y = 63, drop = "P"})
	var x := 420.0
	var k := 0
	while x < 700:
		_add(s, x, "gun", {side = k % 2})
		x += 90
		k += 1
	_add(s, 470, "crawler"); _add(s, 600, "drones", {y = 63, n = 6})
	# tunnel one: pistons, then two shutters with a wall between
	x = 820.0
	k = 0
	while x < 1080:
		_add(s, x, "piston", {side = k % 2})
		x += 70
		k += 1
	_add(s, 900, "carrier", {y = -1, drop = "L"})
	_add(s, 1140, "gate", {off = 0.0, gh = 15.0, mode = "shutter", rate = 0.03})
	_add(s, 1240, "drones", {y = -1, n = 4}); _add(s, 1300, "wall")
	_add(s, 1400, "gate", {off = 0.0, gh = 15.0, mode = "shutter", rate = 0.026})
	x = 1560.0
	k = 1
	while x < 2160:
		_add(s, x, "gun", {side = k % 2})
		x += 96
		k += 1
	_add(s, 1600, "crawler"); _add(s, 1660, "drones", {y = 40, n = 5}); _add(s, 1720, "carrier", {y = 70, drop = "S"})
	_add(s, 1800, "crawler"); _add(s, 1880, "drones", {y = 86, n = 5}); _add(s, 1960, "crawler"); _add(s, 2050, "drones", {y = 60, n = 6})
	# tunnel two: long and winding, everything at once
	_add(s, 2260, "carrier", {y = -1, drop = "L"})
	x = 2380.0
	k = 0
	while x < 2560:
		_add(s, x, "piston", {side = k % 2})
		x += 64
		k += 1
	_add(s, 2640, "gate", {off = 0.0, gh = 15.0, mode = "shutter", rate = 0.03})
	_add(s, 2720, "drones", {y = -1, n = 4}); _add(s, 2800, "wall")
	_add(s, 2900, "gate", {off = -3.0, gh = 13.0, mode = "slide", amp = 8.0, rate = 0.02})
	_add(s, 2980, "carrier", {y = -1, drop = "P"}); _add(s, 3020, "crawler")
	x = 3060.0
	k = 1
	while x < 3220:
		_add(s, x, "piston", {side = k % 2})
		x += 64
		k += 1
	_add(s, 3260, "wall")


## World 4: inside the star. Embers arc up from below, seekers hunt the ship, and the
## tunnels mix every kind of gate. The other worlds' creatures turn up here too.
static func _core(s: Array) -> void:
	_add(s, 140, "embers", {n = 3}); _add(s, 220, "seekers", {y = 40, n = 2}); _add(s, 300, "carrier", {y = 63, drop = "P"})
	_add(s, 380, "embers", {n = 4}); _add(s, 450, "shards", {y = 86, n = 4}); _add(s, 520, "sentinel", {y = 60})
	_add(s, 640, "drones", {y = 40, n = 5}); _add(s, 720, "embers", {n = 3}); _add(s, 780, "carrier", {y = 70, drop = "L"})
	_add(s, 860, "seekers", {y = 86, n = 3}); _add(s, 940, "flake", {y = 50}); _add(s, 1000, "flake", {y = 80})
	_add(s, 1080, "embers", {n = 5}); _add(s, 1160, "sentinel", {y = 70}); _add(s, 1260, "drones", {y = 86, n = 6})
	_add(s, 1340, "carrier", {y = 60, drop = "S"}); _add(s, 1420, "seekers", {y = 63, n = 3}); _add(s, 1500, "embers", {n = 4})
	_add(s, 1600, "shards", {y = 63, n = 5})
	# tunnel one: sliding gates and a wall, seekers inside
	_add(s, 1760, "carrier", {y = -1, drop = "P"})
	_add(s, 1880, "gate", {off = 0.0, gh = 13.0, mode = "slide", amp = 9.0, rate = 0.024})
	_add(s, 1960, "seekers", {y = -1, n = 2}); _add(s, 2060, "wall")
	_add(s, 2160, "gate", {off = 0.0, gh = 14.0, mode = "shutter", rate = 0.032}); _add(s, 2240, "shards", {y = -1, n = 3})
	_add(s, 2340, "gate", {off = 4.0, gh = 12.0, mode = "slide", amp = 6.0, rate = 0.03})
	_add(s, 2560, "embers", {n = 4}); _add(s, 2620, "sentinel", {y = 56}); _add(s, 2700, "drones", {y = 40, n = 6})
	_add(s, 2780, "carrier", {y = 72, drop = "L"}); _add(s, 2840, "seekers", {y = 86, n = 3})
	# tunnel two: the narrow way to the heart
	_add(s, 2980, "carrier", {y = -1, drop = "S"}); _add(s, 3060, "wall")
	_add(s, 3140, "gate", {off = 0.0, gh = 13.0, mode = "shutter", rate = 0.03})
	_add(s, 3220, "seekers", {y = -1, n = 2}); _add(s, 3300, "wall")
	_add(s, 3400, "gate", {off = 0.0, gh = 12.0, mode = "slide", amp = 8.0, rate = 0.026})
	_add(s, 3560, "embers", {n = 5})
