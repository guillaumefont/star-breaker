class_name FortDeco
extends RefCounted
## Low poly dressing for the fortress sections, built with each terrain chunk: a trim lip,
## pipes, panels, vents and lights on the plating, props standing on the corridor floor and
## hanging from its ceiling (antennas, domes, tanks, dishes and one themed prop per world), and
## a dark back wall with ribs and lit windows behind the corridor (Guillaume's pick, 2026-11-14).
## Visual only: nothing here is solid, the plating's front face and everything behind the
## play plane stay clear of the corridor. Each chunk's dressing is merged into one mesh per
## material, so a chunk adds at most seven draw calls.

## False draws the plain plating (used by tests and review shots).
static var enabled := true

const ZF := 11.0  # front face of the plating (see Main.terrain_tris)
const BACK_Z := -31.0  # back face of the back wall, the deepest part of a chunk (Main.chunk_pad)
const PH := 126.0

var parts := {}
var c := 0
var theme := ""


static func h(n: float) -> float:
	var s := sin(n * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)


## Adds a convex shape (centred on its own origin) transformed by `t`.
func put(key: String, tris: Array, t: Transform3D) -> void:
	if not parts.has(key):
		parts[key] = []
	var arr: Array = parts[key]
	for tri in tris:
		arr.append(Geo.orient([t * (tri[0] as Vector3), t * (tri[1] as Vector3), t * (tri[2] as Vector3)], t.origin))


func box(key: String, at: Vector3, size: Vector3, rz := 0.0, base := Transform3D.IDENTITY) -> void:
	put(key, Geo.box(size.x, size.y, size.z), base * Transform3D(Basis(Vector3.BACK, rz), at))


## A round bar from a to b.
func bar(key: String, a: Vector3, b: Vector3, r: float, seg := 6, base := Transform3D.IDENTITY) -> void:
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.BACK)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	put(key, Geo.cyl(r, r, d.length(), seg), base * Transform3D(Basis(x, y, z), (a + b) / 2.0))


## One flat quad facing `dir` (open surfaces such as the back wall).
func quad(key: String, a: Vector3, b: Vector3, cc: Vector3, d: Vector3, dir: Vector3) -> void:
	if not parts.has(key):
		parts[key] = []
	var arr: Array = parts[key]
	var m := (a + b + cc + d) / 4.0 - dir
	arr.append(Geo.orient([a, b, cc], m))
	arr.append(Geo.orient([a, cc, d], m))


func build(grp: Node3D, chunk: int, top: Array, bot: Array, w: Dictionary) -> void:
	c = chunk
	theme = w.get("fdeco", "")
	for side in [1, 0]:
		var hs: Array = top if side else bot
		var sg := 1.0 if side else -1.0
		var e := []
		for i in 9:
			e.append(PH / 2.0 - hs[i] if side else -PH / 2.0 + hs[i])
		_plating(e, sg, side)
		_props(e, sg, side)
	var et := []
	var eb := []
	for i in 9:
		et.append(PH / 2.0 - top[i] + 13.0)
		eb.append(-PH / 2.0 + bot[i] - 13.0)
	_back_wall(et, eb)
	var mats := {trim = Models.M.fort_trim, dark = Models.M.fort_dark, light = Models.M.fort_light, win = Models.M.fort_win,
		back = Models.M.fort_back, acc = Models.M[w.deco_mats[0]], acc2 = Models.M[w.deco_mats[1]]}
	for k in parts:
		grp.add_child(Models.mesh(Geo.build_wound(parts[k]), mats[k]))


# ---------- the plating's front face ----------

func _plating(e: Array, sg: float, side: int) -> void:
	var fz := ZF
	for i in 8:
		var p0 := Vector2(i * 8.0, e[i])
		var p1 := Vector2(i * 8.0 + 8.0, e[i + 1])
		var d := p1 - p0
		var mid := (p0 + p1) / 2.0
		# trim lip along the corridor edge
		# (a sheared slab offset straight up or down, so ramps never poke into the corridor)
		var o := Vector2(0, sg * 2.6)
		var cen := mid + o / 2.0
		put("trim", Geo.prism([p0 - cen, p1 - cen, p1 + o - cen, p0 + o - cen], 2.6), Transform3D(Basis(), Vector3(cen.x, cen.y, fz + 0.9)))
		# a pipe a little way into the plating, with brackets
		bar("dark", Vector3(p0.x, p0.y + sg * 5.2, fz + 1.0), Vector3(p1.x, p1.y + sg * 5.2, fz + 1.0), 0.95)
		if i % 2 == 0 and absf(d.y) < 0.01:
			box("trim", Vector3(p0.x + 1.0, p0.y + sg * 5.2, fz + 1.0), Vector3(1.4, 3.0, 2.8))
	for i in [1, 4, 7]:
		if absf(e[i - 1] - e[i]) > 0.01 or absf(e[i + 1] - e[i]) > 0.01:
			continue
		box("light", Vector3(i * 8.0, e[i] + sg * 1.3, fz + 2.3), Vector3(3.2, 0.9, 0.4))
	# panels, vents and one themed panel on flat 16-unit runs
	for i in [0, 2, 4, 6]:
		if absf(e[i] - e[i + 1]) > 0.01 or absf(e[i + 1] - e[i + 2]) > 0.01:
			continue
		var y: float = e[i] + sg * 14.5
		var x: float = i * 8.0 + 8.0
		var r := h(c * 13.7 + i * 3.1 + side * 7.7)
		if r < 0.4:
			box("trim", Vector3(x, y, fz + 0.4), Vector3(14.2, 9.0, 1.2))
			box("dark", Vector3(x, y, fz + 0.7), Vector3(10.4, 5.6, 1.2))
			for k in [-1, 1]:
				box("win", Vector3(x + k * 6.0, y + 3.3, fz + 1.1), Vector3(0.8, 0.8, 0.4))
		elif r < 0.7:
			box("dark", Vector3(x, y, fz + 0.3), Vector3(13.0, 8.0, 1.0))
			for k in 4:
				box("trim", Vector3(x, y - 3.0 + k * 2.0, fz + 0.9), Vector3(12.0, 0.9, 1.0), 0.0)
		else:
			_theme_panel(Vector3(x, y, fz), sg)


func _theme_panel(p: Vector3, sg: float) -> void:
	box("dark", p + Vector3(0, 0, 0.3), Vector3(13.0, 8.6, 1.0))
	match theme:
		"crystal", "ice":
			# a gem set in a frame
			box("trim", p + Vector3(0, 0, 0.8), Vector3(7.0, 7.0, 1.0), PI / 4.0)
			put("acc", Geo.octa(2.6), Transform3D(Basis(), p + Vector3(0, 0, 2.0)))
			for k in [-1, 1]:
				put("acc2", Geo.octa(1.2), Transform3D(Basis(), p + Vector3(k * 5.0, 0, 1.4)))
		"hive":
			# amber honeycomb cells
			var hex := []
			for k in 6:
				hex.append(Vector2(cos(k * TAU / 6.0), sin(k * TAU / 6.0)) * 2.1)
			for q in [[-3.6, -1.9], [0.0, -1.9], [3.6, -1.9], [-1.8, 1.3], [1.8, 1.3], [5.4, 1.3]]:
				var key := "acc" if h(c + q[0] * 3.3 + q[1]) > 0.35 else "acc2"
				put(key, Geo.prism(hex, 1.6), Transform3D(Basis(), p + Vector3(q[0], q[1] * sg, 1.1)))
		"neon":
			for k in [-1, 1]:
				box("acc" if k < 0 else "acc2", p + Vector3(0, k * 2.2, 1.0), Vector3(11.0, 0.8, 0.8))
			box("trim", p + Vector3(0, 0, 0.9), Vector3(4.0, 2.4, 1.0))
		_:
			# a glowing furnace grate (foundry) or lava channel (core) behind bars
			box("acc", p + Vector3(0, 0, 0.5), Vector3(11.0, 6.2, 1.0))
			for k in 5:
				box("dark", p + Vector3(-4.4 + k * 2.2, 0, 1.2), Vector3(0.8, 7.0, 1.0))


# ---------- props on the corridor floor and ceiling (behind the play plane) ----------

func _props(e: Array, sg: float, side: int) -> void:
	for i in range(0, 8):
		if absf(e[i] - e[i + 1]) > 0.01:
			continue
		var r := h(c * 7.3 + i * 1.9 + side * 3.3)
		if r < 0.45:
			continue
		var x := i * 8.0 + 4.0 + (h(c + i * 5.1) - 0.5) * 3.0
		var z := -15.0 - h(c * 2.1 + i) * 5.0
		# local frame: +y points into the corridor, the base sits just inside the plating
		var base := Transform3D(Basis(Vector3.BACK, PI) if side else Basis(), Vector3(x, e[i] + sg * 9.5, z))
		var kind := int(h(c * 3.9 + i * 11.3 + side) * 6.0)
		match kind:
			0:  # antenna mast
				bar("trim", Vector3(0, 0, 0), Vector3(0, 11, 0), 0.35, 4, base)
				box("trim", Vector3(0, 8.0, 0), Vector3(3.6, 0.4, 0.4), 0.0, base)
				put("light", Geo.octa(0.7), base * Transform3D(Basis(), Vector3(0, 11.2, 0)))
			1:  # dome with a lit band
				put("trim", Geo.hemi(4.0, 8, 2), base * Transform3D(Basis(), Vector3(0, 1.0, 0)))
				box("win", Vector3(0, 2.0, 3.7), Vector3(3.0, 0.6, 0.4), 0.0, base)
			2:  # tank pair
				for k in [-1, 1]:
					put("trim", Geo.cyl(1.7, 1.7, 7.0, 7), base * Transform3D(Basis(), Vector3(k * 2.0, 3.5, 0)))
					put("dark", Geo.cyl(1.9, 1.9, 0.8, 7), base * Transform3D(Basis(), Vector3(k * 2.0, 5.5, 0)))
			3:  # dish on a stub
				put("dark", Geo.cyl(0.7, 0.9, 5.0, 5), base * Transform3D(Basis(), Vector3(0, 2.5, 0)))
				put("trim", Geo.cyl(0.4, 3.6, 1.6, 8), base * Transform3D(Basis(Vector3.BACK, 0.5), Vector3(0, 6.0, 0)))
			4:  # crates
				box("dark", Vector3(-1.0, 2.0, 0), Vector3(5.0, 4.0, 4.0), 0.0, base)
				box("trim", Vector3(1.4, 5.4, 0.4), Vector3(3.2, 3.0, 3.2), 0.15, base)
			_:
				_theme_prop(base)


func _theme_prop(base: Transform3D) -> void:
	match theme:
		"crystal", "ice":
			put("dark", Geo.cyl(2.4, 3.0, 2.4, 6), base * Transform3D(Basis(), Vector3(0, 1.2, 0)))
			for k in 3:
				var a := (k - 1) * 0.45
				var ht := 8.0 - absf(k - 1) * 2.5
				put("acc" if k != 1 else "acc2", Geo.cyl(0.0, 1.2, ht, 4),
					base * Transform3D(Basis(Vector3.BACK, a), Vector3((k - 1) * 1.4, ht / 2.0 + 1.5, 0)))
		"hive":
			put("acc2", Geo.hemi(3.4, 7, 2), base * Transform3D(Basis(), Vector3(0, 1.0, 0)))
			put("acc", Geo.ico(1.6), base * Transform3D(Basis(), Vector3(0, 4.6, 0)))
		"foundry":
			put("dark", Geo.cyl(1.6, 2.2, 9.0, 6), base * Transform3D(Basis(), Vector3(0, 4.5, 0)))
			put("acc", Geo.cyl(1.7, 1.7, 1.0, 6), base * Transform3D(Basis(), Vector3(0, 9.2, 0)))
		"neon":
			put("dark", Geo.cyl(0.9, 1.4, 10.0, 4), base * Transform3D(Basis(), Vector3(0, 5.0, 0)))
			for k in 3:
				box("acc" if k % 2 else "acc2", Vector3(0, 3.0 + k * 2.6, 0), Vector3(3.2, 0.5, 0.5), 0.0, base)
		_:
			put("acc2", Geo.cyl(0.0, 2.0, 10.0, 4), base * Transform3D(Basis(), Vector3(0, 5.0, 0)))
			put("acc", Geo.octa(1.6), base * Transform3D(Basis(), Vector3(0, 2.2, 1.6)))


# ---------- back wall ----------

## A dark back wall closing the corridor, with ribs and rows of lit windows.
func _back_wall(et: Array, eb: Array) -> void:
	var z := BACK_Z + 1.0
	for i in 8:
		quad("back", Vector3(i * 8.0, eb[i], z), Vector3(i * 8.0 + 8.0, eb[i + 1], z), Vector3(i * 8.0 + 8.0, et[i + 1], z), Vector3(i * 8.0, et[i], z), Vector3.BACK)
	for i in [0, 2, 4, 6]:
		var x: float = i * 8.0
		var mid: float = (et[i] + eb[i]) / 2.0
		box("dark", Vector3(x, mid, z + 1.0), Vector3(2.6, et[i] - eb[i], 2.0))
		var y0: float = eb[i + 1]
		var y1: float = et[i + 1]
		if absf(eb[i] - eb[i + 2]) > 0.01 or absf(et[i] - et[i + 2]) > 0.01:
			continue
		# a horizontal girder and a row of windows in each bay
		box("dark", Vector3(x + 8.0, lerpf(y0, y1, 0.25), z + 0.6), Vector3(16.0, 1.4, 1.2))
		box("dark", Vector3(x + 8.0, lerpf(y0, y1, 0.75), z + 0.6), Vector3(16.0, 1.4, 1.2))
		for row in [0.12, 0.88]:
			for k in 3:
				if h(c * 5.7 + i + k * 2.3 + row) < 0.35:
					continue
				box("win", Vector3(x + 3.5 + k * 4.5, lerpf(y0, y1, row), z + 0.4), Vector3(2.0, 1.1, 0.4))
