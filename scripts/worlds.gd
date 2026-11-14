class_name Worlds
extends RefCounted
## The campaign: four worlds, each with its own look, terrain (caves, tunnels, gates,
## breakable walls), enemy mix, song and boss. All content is original.
##
## Terrain is a ceiling and a floor height (stage units) for every world position `wx`:
## a noisy cave that can narrow into winding tunnels. Gates and walls are objects placed by
## the level script. Script entries with y < 0 spawn on the local corridor centre line.

const PH := 126.0

const LIST := [
	{
		name = "The Hollow Moon", sub = "World 1", boss = "bloom", boss_name = "Bloom Mother", song = "stage", boss_song = "boss",
		boss_at = 3400.0, clear = "Bloom Mother cut down",
		pal = {bg = "0c0a26", top = "1c1046", mid = "0c0a26", bot = "071225", fog = "120f26", amb = "8f8cc4", rim = "ff4fa3",
			planet = "5a3d8f", planet_e = "1a0c2e", ring = "8a74c9", far = "2c2656", star_a = "9a93c8", star_b = "e8e4f6"},
		rock = ["rock", "rock2"], deco = "cone", deco_mats = ["crystal_c", "crystal_m"], gate = "crystal_c",
		terrain = {start = 500.0, end = 3300.0, ca = 1.0, fa = 1.0, ph = 0.0, bumps = [[1800.0, 2500.0, 0.35]],
			tunnels = [{a = 2520.0, b = 3060.0, gap = 46.0, amp = 12.0, freq = 0.011, cy = 63.0}]},
	},
	{
		name = "Frost Rift", sub = "World 2", boss = "prism", boss_name = "Prism Warden", song = "frost", boss_song = "boss",
		boss_at = 3600.0, clear = "Prism Warden shattered",
		pal = {bg = "08162a", top = "16365a", mid = "0a1a33", bot = "050c1a", fog = "0c1c30", amb = "9cc4e8", rim = "7fe8ff",
			planet = "8fb8e0", planet_e = "1a3050", ring = "cfefff", far = "2a4060", star_a = "a8c8e8", star_b = "f0f8ff"},
		rock = ["ice_rock", "ice_rock2"], deco = "spike", deco_mats = ["ice_c", "ice_b"], gate = "ice_c",
		terrain = {start = 300.0, end = 3500.0, ca = 0.75, fa = 1.0, ph = 1.7, bumps = [[900.0, 1300.0, 0.4]],
			tunnels = [{a = 1500.0, b = 2320.0, gap = 44.0, amp = 18.0, freq = 0.009, cy = 63.0},
				{a = 2860.0, b = 3360.0, gap = 40.0, amp = 12.0, freq = 0.013, cy = 61.0}]},
	},
	{
		name = "Iron Foundry", sub = "World 3", boss = "titan", boss_name = "Furnace Titan", song = "foundry", boss_song = "boss",
		boss_at = 3700.0, clear = "Furnace Titan melted down",
		pal = {bg = "1a0f0c", top = "3a1c10", mid = "1a0f0c", bot = "0c0808", fog = "1c100c", amb = "c4a08f", rim = "ff8a3d",
			planet = "8f4a2a", planet_e = "2e120a", ring = "c99a74", far = "3a2a26", star_a = "c8a893", star_b = "fff0e0"},
		rock = ["metal_rock", "metal_rock2"], deco = "strut", deco_mats = ["hot", "hazard"], gate = "hot",
		terrain = {start = 200.0, end = 3600.0, ca = 1.05, fa = 1.05, ph = 4.1, bumps = [],
			tunnels = [{a = 700.0, b = 1520.0, gap = 48.0, amp = 10.0, freq = 0.012, cy = 63.0},
				{a = 2200.0, b = 3300.0, gap = 46.0, amp = 16.0, freq = 0.008, cy = 63.0}]},
	},
	{
		name = "Star Core", sub = "Final world", boss = "heart", boss_name = "Star Heart", song = "core", boss_song = "final",
		boss_at = 3800.0, clear = "The star is broken",
		pal = {bg = "200808", top = "4a1408", mid = "200808", bot = "100404", fog = "260a06", amb = "e0a080", rim = "ffcc40",
			planet = "ffb040", planet_e = "ff6a00", ring = "ffd890", far = "4a1a10", star_a = "ffc890", star_b = "fff4d0"},
		rock = ["magma_rock", "magma_rock2"], deco = "cone", deco_mats = ["lava", "gold"], gate = "lava",
		terrain = {start = 300.0, end = 3700.0, ca = 0.9, fa = 1.15, ph = 2.9, bumps = [[1000.0, 1500.0, 0.4]],
			tunnels = [{a = 1700.0, b = 2520.0, gap = 42.0, amp = 22.0, freq = 0.0085, cy = 63.0},
				{a = 2920.0, b = 3520.0, gap = 38.0, amp = 12.0, freq = 0.016, cy = 63.0}]},
	},
]


static func smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


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
	return Vector2(c, f)


## True inside a tunnel section (used by tests and to keep script waves sensible).
static func in_tunnel(w: Dictionary, wx: float) -> bool:
	for tu in w.terrain.tunnels:
		if wx > tu.a + 140.0 and wx < tu.b - 140.0:
			return true
	return false


# ---------- level scripts ----------

static func script(i: int) -> Array:
	var s: Array = []
	match i:
		0: _moon(s)
		1: _frost(s)
		2: _foundry(s)
		3: _core(s)
	s.sort_custom(func(a, b): return a.x < b.x)
	return s


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
