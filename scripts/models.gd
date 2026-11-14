class_name Models
extends RefCounted
## Materials and low poly models. Every model is original and built from code.

static var M: Dictionary = {}
static var glow_tex: Texture2D
static var _glow_mats: Dictionary = {}
static var font_bold: Font


static func init() -> void:
	if not M.is_empty():
		return
	M = {
		hull = std("dfe8f2"), hull_dark = std("56607a"), lance = std("4fe3d6", "4fe3d6", 1.2),
		engine = add_mat("ffb547", 0.9), nozzle = basic("ffc46b", 1.8),
		pod = std("ffb547", "ff8a00", 0.6), pod_spike = std("fff1c9"), spore = std("ff4fa3", "ff4fa3", 0.35), spore_dark = std("7a1f5c"),
		flesh = std("9b3b7a"), flesh_dark = std("4d1d48"), bone = std("e8d9c4"), beetle = std("ff7a3d", "401000", 0.6),
		moth = std("d9f46a", "334000", 0.5), shell = std("3d5a66"),
		eye = basic("ff3355", 1.6), ebullet = basic("ff9a3d", 1.8), shot = basic("9ffcf2", 1.6), heavy = basic("e9fffd", 2.0),
		pod_shot = basic("ffd27a", 1.6), beam = basic("e6fffc", 2.2), beam_glow = add_mat("4fe3d6", 0.5), charge_orb = add_mat("4fe3d6", 0.85),
		nova = basic("ffe8f6", 2.6), nova_glow = add_mat("ff4fa3", 0.55), nova_orb = add_mat("ff4fa3", 0.7),
		rock = std("51458a"), rock2 = std("453b7a"),
		crystal_c = std("4fe3d6", "4fe3d6", 1.6), crystal_m = std("ff4fa3", "ff4fa3", 1.4),
		core_skin = std("7a2a6e", "2a0020", 0.6), petal = std("ff6fb5", "ff2f8f", 0.45), iris = std("f3f0ff", "553366", 0.3),
		pupil = basic("0d0b1a"), tip = std("ffb547", "ff5a00", 0.7), flash = basic("ffffff", 1.6), far_rock = std("2c2656", "160f30", 0.4),
		planet = std("5a3d8f", "1a0c2e", 0.8), ring = std("8a74c9"),
		part_o = basic("ffb547", 1.6), part_p = basic("ff4fa3", 1.6), part_w = basic("fff6e0", 1.6), part_c = basic("4fe3d6", 1.6),
		disc = basic("0d0b1a"),
		# world 2: Frost Rift
		ice_rock = std("5f7fae"), ice_rock2 = std("4d6c9c"), ice_c = std("bff6ff", "7fe8ff", 1.3), ice_b = std("8fd8ff", "3fa8ff", 0.9),
		frost = std("e6f6ff", "9fdcff", 0.25), frost_dark = std("2d4f7a"), ice_core = std("aef8ff", "5fe0ff", 1.4),
		# world 3: Iron Foundry
		metal_rock = std("5b4a44"), metal_rock2 = std("4a3d3a"), steel = std("9aa0b0"), steel_dark = std("3b3f4d"),
		rust = std("b5552a"), hot = std("ff7a1a", "ff5a00", 1.6), hazard = std("ffcc33", "805a00", 0.4),
		# world 4: Star Core
		magma_rock = std("6b2a2a", "300800", 0.5), magma_rock2 = std("552222", "300800", 0.5), lava = std("ff6a1a", "ff4000", 1.8),
		gold = std("ffd25a", "ff9a00", 0.8), corona = std("fff0b0", "ffcc40", 2.0), ash = std("3a2422"),
		gate = std("8a93ab", "202840", 0.3),
		# world 3: Verdant Hive
		hive_rock = std("4a5a2a"), hive_rock2 = std("3a4a22"), amber = std("ffb547", "ff8a00", 1.2), moss = std("c8f560", "6a9a20", 0.9),
		chitin = std("2a3a1a"), wasp_y = std("e8d040", "402800", 0.5), sac = std("c86a9a", "5a1a40", 0.6),
		# world 5: Bastion Ring
		plate = std("7078a0"), plate2 = std("50587e"), neon = std("ff4fa3", "ff2f8f", 1.6), neon2 = std("4fe3d6", "3fc0c0", 1.4),
		armor = std("c0c8e0", "202848", 0.3),
		# fortress sections of every world (recoloured per world by main.apply_world)
		fort_a = std("5d5a86"), fort_b = std("48456e"), fort_light = basic("4fe3d6", 1.8), field = add_mat("ff4fa3", 0.4),
	}
	# opaque on purpose: a lit see-through material was a suspect for the Android crash
	M.wing = std("e9f2c4")
	for k in ["rock", "rock2", "ice_rock", "ice_rock2", "metal_rock", "metal_rock2", "magma_rock", "magma_rock2", "hive_rock", "hive_rock2",
			"plate", "plate2", "fort_a", "fort_b", "ring", "wing", "core_skin"]:
		(M[k] as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in ["planet", "ring", "far_rock"]:
		(M[k] as BaseMaterial3D).disable_fog = true
	(M.disc as BaseMaterial3D).no_depth_test = true
	(M.disc as BaseMaterial3D).render_priority = 1

	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.22, Color(1, 1, 1, 0.65))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	glow_tex = gt
	font_bold = load("res://assets/fonts/rubik-latin-800-normal.woff2")


static func std(c: String, e: String = "", ei := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.roughness = 0.78
	m.metallic = 0.06
	if e != "" and ei > 0.0:
		m.emission_enabled = true
		m.emission = Color(e)
		m.emission_energy_multiplier = ei
	return m


## Unshaded colour; energy > 1 pushes it into the bloom.
static func basic(c: String, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c) * Color(energy, energy, energy, 1.0)
	return m


static func add_mat(c: String, opacity := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(c, opacity)
	return m


## Additive soft glow material (the bloom "sprites": engine trail, shots, explosions).
static func glow_mat(c: String) -> StandardMaterial3D:
	if _glow_mats.has(c):
		return _glow_mats[c]
	var m := add_mat(c)
	m.albedo_texture = glow_tex
	m.albedo_color = Color(c) * Color(1.6, 1.6, 1.6, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_mats[c] = m
	return m


static func quad() -> QuadMesh:
	return Geo._cache.get("quad") if Geo._cache.has("quad") else _make_quad()


static func _make_quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	Geo._cache["quad"] = q
	return q


static func glow(color: String, s: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = quad()
	mi.material_override = glow_mat(color)
	mi.scale = Vector3(s, s, 1)
	mi.set_meta("nf", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func mesh(m: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func geo(key: String, f: Callable) -> ArrayMesh:
	return Geo.cached(key, func(): return Geo.build(f.call()))


## Swaps every mesh under `obj` to the white hit-flash material, or back.
static func set_flash(obj: Node, on: bool) -> void:
	if obj.get_meta("fl", false) == on:
		return
	obj.set_meta("fl", on)
	_flash(obj, on)


static func _flash(n: Node, on: bool) -> void:
	if n is MeshInstance3D and not n.get_meta("nf", false):
		(n as MeshInstance3D).material_override = M.flash if on else null
	for c in n.get_children():
		_flash(c, on)


# ---------- models ----------

## Player ship: a rounded, bulky gunship. Lofted fuselage with a bubble canopy, short thick
## swept wings with a slight droop, twin side engine pods and a main thruster.
static func ship() -> Node3D:
	var g := Node3D.new()
	var body := Node3D.new()
	g.add_child(body)
	# sections are [x, half height, half depth, centre y], tail first
	body.add_child(_wound("hull", func(): return Geo.loft([
			[-7.4, 1.5, 1.7, 0.1], [-6.2, 2.0, 2.2, 0.1], [-3.6, 2.4, 2.6, 0.2], [-0.4, 2.5, 2.7, 0.2],
			[2.8, 2.2, 2.4, 0.0], [5.2, 1.6, 1.9, -0.25], [6.8, 1.0, 1.2, -0.45], [7.6, 0.45, 0.6, -0.55]], 8), M.hull))
	# chin plate and belly keel in the darker tone
	body.add_child(_wound("chin", func(): return Geo.loft([
			[-5.8, 0.9, 1.6, -1.9], [-2.0, 1.1, 1.9, -2.1], [2.6, 0.9, 1.6, -1.9], [4.6, 0.5, 1.0, -1.5]], 6), M.hull_dark))
	var canopy := mesh(Geo.cached("canopy", func(): return Geo.build(Geo.hemi(1.0, 8, 3), Vector3.ZERO)), M.lance, Vector3(2.2, 1.7, 0))
	canopy.scale = Vector3(2.8, 1.45, 1.5)
	body.add_child(canopy)
	var wing := Geo.xf(Geo.prism([[-5.6, 0], [1.2, 0], [-1.6, 5.6], [-4.4, 6.2]], 0.7), Geo.rot(Vector3.RIGHT, PI / 2))
	wing = Geo.xf(wing, Geo.rot(Vector3.RIGHT, 0.22))
	body.add_child(mesh(Geo.cached("wingA", func(): return Geo.build(wing)), M.hull_dark, Vector3(-0.6, -0.9, 2.0)))
	body.add_child(mesh(Geo.cached("wingB", func(): return Geo.build(_mirror_z(wing))), M.hull_dark, Vector3(-0.6, -0.9, -2.0)))
	body.add_child(mesh(geo("fin", func(): return Geo.prism([[-7.2, 0], [-3.2, 0], [-5.4, 2.6], [-7.0, 2.9]], 0.6)), M.hull_dark, Vector3(0, 1.9, 0)))
	# engine pods along the flanks, each with a glowing nozzle
	var nac := Geo.cached("nac", func(): return Geo.build_wound(Geo.loft([[-8.2, 0.9, 0.9, 0], [-7.4, 1.15, 1.15, 0], [-2.4, 1.15, 1.15, 0], [-0.8, 0.6, 0.6, 0]], 6)))
	var noz := geo("noz", func(): return Geo.xf(Geo.cyl(0.7, 0.7, 0.3, 6), Geo.rot(Vector3.BACK, PI / 2)))
	for z in [2.7, -2.7]:
		body.add_child(mesh(nac, M.hull, Vector3(0, -1.0, z)))
		body.add_child(mesh(noz, M.nozzle, Vector3(-8.3, -1.0, z)))
	var en := mesh(geo("eng", func(): return Geo.cyl(1.3, 1.7, 1.4, 8)), M.hull_dark, Vector3(-8.0, 0.1, 0))
	en.rotation.z = PI / 2
	body.add_child(en)
	var core := mesh(geo("engc", func(): return Geo.cyl(1.25, 1.25, 0.3, 8)), M.nozzle, Vector3(-8.75, 0.1, 0))
	core.rotation.z = PI / 2
	body.add_child(core)
	var fl := mesh(geo("flame", func(): return Geo.xf(Geo.xf(Geo.cone(1.2, 6, 8), Geo.rot(Vector3.BACK, PI / 2)), Geo.move(-3, 0, 0))), M.engine, Vector3(-8.8, 0.1, 0))
	fl.set_meta("nf", true)
	body.add_child(fl)
	g.set_meta("body", body)
	g.set_meta("flame", fl)
	return g


static func _wound(key: String, f: Callable, mat: Material) -> MeshInstance3D:
	return mesh(Geo.cached(key, func(): return Geo.build_wound(f.call())), mat)


static func _mirror_z(tris: Array) -> Array:
	return Geo.xf(tris, Transform3D(Basis().scaled(Vector3(1, 1, -1)), Vector3.ZERO))


## Pod: a long cyan crystal with a glowing band around its middle and four pink shards
## orbiting it. All opaque. The "spin" child turns around the axle (X, nose to tail);
## the root only flips to face backwards when the pod docks behind the ship.
static func pod() -> Node3D:
	var g := Node3D.new()
	var spin := Node3D.new()
	g.add_child(spin)
	var c := mesh(geo("podX", func(): return Geo.octa(2.2)), M.crystal_c)
	c.scale = Vector3(1.7, 1, 1)
	spin.add_child(c)
	var band := mesh(Geo.cached("podR", func(): return Geo.build_wound(Geo.xf(Geo.torus(2.3, 0.18, 12, 3), Geo.rot(Vector3.UP, PI / 2)))), M.shot)
	band.set_meta("nf", true)
	spin.add_child(band)
	var shard := geo("podS", func(): return Geo.xf(Geo.octa(1.0), Transform3D(Basis().scaled(Vector3(1.8, 0.7, 0.7)), Vector3(-0.4, 3.1, 0))))
	for i in 4:
		var arm := mesh(shard, M.crystal_m)
		arm.rotation.x = i * TAU / 4.0 + 0.4
		spin.add_child(arm)
	g.set_meta("spin", spin)
	return g


static func drifter() -> Node3D:
	var g := Node3D.new()
	g.add_child(mesh(geo("dr", func(): return Geo.dodeca(3.1)), M.spore))
	var tg := geo("drT", func(): return Geo.xf(Geo.tetra(1.4), Geo.move(0, 3, 0)))
	for i in 3:
		var t := mesh(tg, M.spore_dark)
		t.rotation.z = i * 2.09
		g.add_child(t)
	return g


static func turret(side: int) -> Node3D:
	var g := Node3D.new()
	var w := 1.0 if side else -1.0
	g.add_child(mesh(geo("tb", func(): return Geo.cyl(3, 4.6, 3, 6)), M.shell, Vector3(0, w * 1.6, 0)))
	g.add_child(mesh(geo("td", func(): return Geo.ico(2.6, 0)), M.flesh, Vector3(0, -w * 0.4, 0)))
	var piv := Node3D.new()
	piv.position.y = -w * 0.4
	g.add_child(piv)
	piv.add_child(mesh(geo("tbar", func(): return Geo.box(5, 1.2, 1.2)), M.bone, Vector3(3, 0, 0)))
	g.set_meta("piv", piv)
	return g


static func hopper() -> Node3D:
	var g := Node3D.new()
	var b := mesh(geo("hp", func(): return Geo.octa(3.4)), M.beetle)
	b.scale = Vector3(1.5, 0.8, 1)
	g.add_child(b)
	var lg := geo("leg", func(): return Geo.box(0.5, 2.6, 0.5))
	var legs := []
	for i in 4:
		var l := mesh(lg, M.flesh_dark, Vector3(-2.4 + i * 1.6, -2.4, 1.5 if i % 2 else -1.5))
		g.add_child(l)
		legs.append(l)
	g.add_child(mesh(geo("eyeS", func(): return Geo.ico(0.9, 0)), M.eye, Vector3(4.4, 0.6, 1)))
	g.set_meta("legs", legs)
	return g


static func item_mat(k: String) -> Material:
	return M.pod if k == "P" else (M.lance if k == "L" else M.moth)


static func carrier(kind: String) -> Node3D:
	var g := Node3D.new()
	var b := mesh(geo("mb", func(): return Geo.octa(2.8)), M.moth)
	b.scale = Vector3(1.7, 1, 1)
	g.add_child(b)
	var wt := Geo.xf(Geo.prism([[-3, 0], [3, 0], [5, 9], [-4, 7]], 0.3), Geo.rot(Vector3.RIGHT, PI / 2))
	var p1 := Node3D.new()
	var p2 := Node3D.new()
	p1.add_child(mesh(Geo.cached("mwA", func(): return Geo.build(wt)), M.wing))
	p2.add_child(mesh(Geo.cached("mwB", func(): return Geo.build(_mirror_z(wt))), M.wing))
	g.add_child(p1)
	g.add_child(p2)
	var gem := mesh(geo("gem", func(): return Geo.octa(1.4)), item_mat(kind), Vector3(0, -2.6, 0))
	gem.set_meta("nf", true)
	g.add_child(gem)
	g.set_meta("w", [p1, p2])
	return g


static func shell() -> Node3D:
	var g := Node3D.new()
	var s := mesh(geo("sh", func(): return Geo.ico(8, 0)), M.shell)
	s.scale = Vector3(1.35, 0.85, 1)
	g.add_child(s)
	var u := mesh(geo("shu", func(): return Geo.ico(6, 0)), M.flesh_dark, Vector3(0, -2.5, 0))
	u.scale = Vector3(1.4, 0.7, 0.9)
	g.add_child(u)
	var sp := geo("shs", func(): return Geo.cone(1.4, 4.5, 4))
	for i in 5:
		var c := mesh(sp, M.bone, Vector3(-6 + i * 3, 6.8 - absf(i - 2) * 0.9, 0))
		c.rotation.z = (i - 2) * -0.2
		g.add_child(c)
	g.add_child(mesh(geo("she", func(): return Geo.ico(1.7, 0)), M.eye, Vector3(-10.2, -0.5, 2.5)))
	return g


static func item(k: String) -> Node3D:
	var g := Node3D.new()
	var core := mesh(geo("it", func(): return Geo.octa(3.6)), item_mat(k))
	g.add_child(core)
	var d := mesh(Geo.cached("disc", func(): return Geo.build_facing(Geo.disc(2.1, 16), Vector3.BACK)), M.disc, Vector3(0, 0, 5))
	d.set_meta("nf", true)
	g.add_child(d)
	var l := Label3D.new()
	l.text = k
	l.font = font_bold
	l.font_size = 64
	l.pixel_size = 0.045
	l.outline_size = 0
	l.no_depth_test = true
	l.render_priority = 2
	l.shaded = false
	l.position = Vector3(0, 0.1, 5.1)
	g.add_child(l)
	g.set_meta("core", core)
	return g


static func boss(world: Node3D) -> Node3D:
	var g := Node3D.new()
	var u := {}
	var roots := geo("root", func(): return Geo.cyl(1.4, 3, 1, 5))
	for rl in [[-0.5, 1.0], [0.2, 1.2], [0.7, 0.9], [-0.9, 0.8]]:
		var a: float = rl[0]
		var l: float = rl[1]
		var r := mesh(roots, M.flesh_dark, Vector3(cos(a) * 35 * l, sin(a) * 35 * l, -6))
		r.rotation.z = PI / 2 + a
		r.scale.y = 70 * l
		g.add_child(r)
	u.core = mesh(geo("core", func(): return Geo.ico(13, 1)), M.core_skin)
	g.add_child(u.core)
	u.eye = mesh(geo("iris", func(): return Geo.ico(6.4, 1)), M.iris, Vector3(-3, 0, 8))
	g.add_child(u.eye)
	u.pupil = mesh(geo("pup", func(): return Geo.ico(2.8, 0)), M.pupil, Vector3(0, 0, 5))
	u.pupil.set_meta("nf", true)
	u.eye.add_child(u.pupil)
	var lid := Geo.cached("lid", func(): return Geo.build(Geo.hemi(7.4, 8, 4), Vector3.ZERO))
	u.lidT = mesh(lid, M.core_skin, Vector3(-3, 0, 8))
	u.lidB = mesh(lid, M.core_skin, Vector3(-3, 0, 8))
	u.lidB.rotation.x = PI
	g.add_child(u.lidT)
	g.add_child(u.lidB)
	u.petals = []
	u.stalks = []
	for i in 4:
		var st := mesh(geo("stalk", func(): return Geo.cyl(1.1, 1.6, 1, 5)), M.flesh_dark)
		world.add_child(st)
		u.stalks.append(st)
		var p := Node3D.new()
		var b := mesh(geo("pet", func(): return Geo.octa(5.2)), M.petal)
		b.scale = Vector3(1, 1.35, 1)
		p.add_child(b)
		p.add_child(mesh(geo("bud", func(): return Geo.ico(2.2, 0)), M.crystal_m, Vector3(0, 0, 3.5)))
		world.add_child(p)
		u.petals.append(p)
	u.segs = []
	for i in 13:
		var s := mesh(geo("seg", func(): return Geo.ico(1, 0)), M.flesh if i % 2 else M.flesh_dark)
		s.scale = Vector3.ONE * maxf(2.6, 4.6 - i * 0.15)
		world.add_child(s)
		u.segs.append(s)
	u.tip = Node3D.new()
	u.tip.add_child(mesh(geo("tipB", func(): return Geo.dodeca(4.6)), M.tip))
	var tsp := geo("tsp", func(): return Geo.xf(Geo.cone(1, 3.5, 4), Geo.move(0, 5.2, 0)))
	for i in 6:
		var s := mesh(tsp, M.bone)
		s.rotation.z = i * 1.047
		u.tip.add_child(s)
	world.add_child(u.tip)
	g.set_meta("u", u)
	world.add_child(g)
	return g


# ---------- world 2: Frost Rift ----------

## Crystal dart: stops, takes aim, then lunges.
static func shard() -> Node3D:
	var g := Node3D.new()
	var b := mesh(geo("shd", func(): return Geo.octa(3)), M.ice_c)
	b.scale = Vector3(2.0, 0.7, 0.7)
	g.add_child(b)
	var f := geo("shdF", func(): return Geo.prism([[-2, 0], [2, 0], [-3, 4]], 0.4))
	for sg in [1.0, -1.0]:
		var fin := mesh(f, M.frost_dark, Vector3(1, 0.6 * sg, 0))
		fin.scale.y = sg
		g.add_child(fin)
	return g


## Hangs from the ceiling and drops when the ship passes under it.
static func icicle() -> Node3D:
	var g := Node3D.new()
	var c := mesh(geo("icl", func(): return Geo.cone(2.6, 9, 5)), M.ice_b)
	c.rotation.z = PI
	g.add_child(c)
	var c2 := mesh(geo("icl2", func(): return Geo.cone(1.4, 5, 4)), M.frost, Vector3(2, 1, 1))
	c2.rotation.z = PI
	g.add_child(c2)
	return g


## Spinning snowflake that sheds bullets in a cross.
static func flake() -> Node3D:
	var g := Node3D.new()
	g.add_child(mesh(geo("flC", func(): return Geo.ico(2.4, 0)), M.ice_core))
	var arm := geo("flA", func(): return Geo.xf(Geo.octa(1.2), Transform3D(Basis().scaled(Vector3(1, 3.2, 1)), Vector3(0, 4.4, 0))))
	for i in 6:
		var a := mesh(arm, M.frost)
		a.rotation.z = i * TAU / 6.0
		g.add_child(a)
	return g


## Heavy armoured ice hulk (behaves like the moon's shell beast).
static func hulk() -> Node3D:
	var g := Node3D.new()
	var s := mesh(geo("hk", func(): return Geo.dodeca(7.5)), M.ice_rock)
	s.scale = Vector3(1.3, 0.9, 1)
	g.add_child(s)
	var sp := geo("hkS", func(): return Geo.cone(1.8, 6, 4))
	for i in 4:
		var c := mesh(sp, M.ice_c, Vector3(-5 + i * 3.6, 6.5 - absf(i - 1.5) * 0.8, 0))
		c.rotation.z = (i - 1.5) * -0.25
		g.add_child(c)
	g.add_child(mesh(geo("hkE", func(): return Geo.ico(1.8, 0)), M.eye, Vector3(-9.6, 0, 3)))
	return g


# ---------- world 3: Iron Foundry ----------

static func drone() -> Node3D:
	var g := Node3D.new()
	var b := mesh(geo("drn", func(): return Geo.octa(2.6)), M.steel)
	b.scale = Vector3(1.5, 0.7, 1.2)
	g.add_child(b)
	var w := geo("drnW", func(): return Geo.box(1.6, 0.5, 7))
	g.add_child(mesh(w, M.steel_dark, Vector3(0.5, 0, 0)))
	g.add_child(mesh(geo("drnE", func(): return Geo.ico(0.9, 0)), M.hot, Vector3(-3.6, 0, 0)))
	g.add_child(mesh(geo("eyeS", func(): return Geo.ico(0.9, 0)), M.eye, Vector3(3.2, 0.3, 1)))
	return g


## Wall piston: a rod and a hammer head that slam out of the ceiling or floor.
static func piston(side: int) -> Node3D:
	var g := Node3D.new()
	var w := 1.0 if side else -1.0
	g.add_child(mesh(geo("psB", func(): return Geo.box(9, 4, 8)), M.steel_dark, Vector3(0, w * 2, 0)))
	var rod := mesh(geo("psR", func(): return Geo.cyl(1.4, 1.4, 1, 6)), M.steel)
	g.add_child(rod)
	var head := Node3D.new()
	head.add_child(mesh(geo("psH", func(): return Geo.box(8, 4, 7)), M.rust))
	head.add_child(mesh(geo("psS", func(): return Geo.box(8.4, 1, 7.4)), M.hazard, Vector3(0, -w * 1.6, 0)))
	g.add_child(head)
	g.set_meta("rod", rod)
	g.set_meta("head", head)
	return g


## Floor crawler tank with a turret that tracks the ship.
static func crawler() -> Node3D:
	var g := Node3D.new()
	g.add_child(mesh(geo("crB", func(): return Geo.box(10, 3.4, 6)), M.rust))
	g.add_child(mesh(geo("crT", func(): return Geo.box(12, 2, 7)), M.steel_dark, Vector3(0, -2.4, 0)))
	g.add_child(mesh(geo("crD", func(): return Geo.hemi(3, 6, 2)), M.steel, Vector3(0, 1.6, 0)))
	var piv := Node3D.new()
	piv.position.y = 2.6
	g.add_child(piv)
	piv.add_child(mesh(geo("crG", func(): return Geo.box(5.5, 1, 1)), M.steel_dark, Vector3(3, 0, 0)))
	g.set_meta("piv", piv)
	return g


## Foundry gun emplacement (behaves like the moon's turret).
static func gun(side: int) -> Node3D:
	var g := Node3D.new()
	var w := 1.0 if side else -1.0
	g.add_child(mesh(geo("gnB", func(): return Geo.box(8, 3, 7)), M.steel_dark, Vector3(0, w * 1.6, 0)))
	g.add_child(mesh(geo("gnD", func(): return Geo.ico(2.6, 0)), M.steel, Vector3(0, -w * 0.4, 0)))
	var piv := Node3D.new()
	piv.position.y = -w * 0.4
	g.add_child(piv)
	piv.add_child(mesh(geo("gnBar", func(): return Geo.box(5.5, 1.3, 1.3)), M.hot, Vector3(3, 0, 0)))
	g.set_meta("piv", piv)
	return g


# ---------- world 4: Star Core ----------

static func ember() -> Node3D:
	var g := Node3D.new()
	g.add_child(mesh(geo("emb", func(): return Geo.ico(2.4, 0)), M.lava))
	var gl := glow("ff9a40", 9)
	g.add_child(gl)
	return g


static func seeker() -> Node3D:
	var g := Node3D.new()
	var b := mesh(geo("skr", func(): return Geo.cone(2.2, 6, 4)), M.gold)
	b.rotation.z = PI / 2
	g.add_child(b)
	g.add_child(mesh(geo("skrE", func(): return Geo.ico(1.1, 0)), M.eye, Vector3(2.2, 0, 1)))
	var fl := mesh(geo("skrF", func(): return Geo.ico(1.3, 0)), M.engine, Vector3(-3.4, 0, 0))
	fl.set_meta("nf", true)
	g.add_child(fl)
	return g


## Gold sentinel (behaves like the moon's shell beast).
static func sentinel() -> Node3D:
	var g := Node3D.new()
	var s := mesh(geo("snt", func(): return Geo.octa(8)), M.gold)
	s.scale = Vector3(1.3, 0.9, 0.8)
	g.add_child(s)
	var r := mesh(Geo.cached("sntR", func(): return Geo.build_facing(Geo.ring(8.5, 10.5, 12), Vector3.BACK)), M.ash)
	g.add_child(r)
	g.add_child(mesh(geo("she", func(): return Geo.ico(1.7, 0)), M.eye, Vector3(-9.4, 0, 2.5)))
	g.set_meta("ring", r)
	return g


# ---------- level geometry ----------

## A block of a breakable wall. `mat` follows the world.
static func block(mat: Material) -> Node3D:
	var g := Node3D.new()
	var b := mesh(geo("blk", func(): return Geo.box(7.4, 7.4, 9)), mat)
	b.rotation.x = 0.12
	g.add_child(b)
	var c := mesh(geo("blkC", func(): return Geo.octa(2.2)), M.gate, Vector3(0, 0, 4.6))
	g.add_child(c)
	return g


## Gate: a top and a bottom pillar with glowing lips around the opening.
static func gate(glow_mat: Material) -> Node3D:
	var g := Node3D.new()
	var col := geo("gtP", func(): return Geo.box(1, 1, 1))
	var lip := geo("gtL", func(): return Geo.box(8, 2, 12))
	var u := {}
	for k in ["top", "bot"]:
		var p := mesh(col, M.gate)
		g.add_child(p)
		u[k] = p
		var l := mesh(lip, glow_mat)
		g.add_child(l)
		u[k + "_lip"] = l
	# energy field filling the opening while a locked gate is closed
	var f := mesh(col, M.field)
	f.set_meta("nf", true)
	f.visible = false
	g.add_child(f)
	u.field = f
	g.set_meta("u", u)
	return g


# ---------- bosses of worlds 2 to 4 ----------
## Each returns a root node (added to `world`, kept at the origin) whose meta "u" maps part
## keys to the nodes main.gd moves around in stage coordinates.

static func boss_prism(world: Node3D) -> Node3D:
	var g := Node3D.new()
	var u := {}
	var core := Node3D.new()
	core.add_child(mesh(geo("pwC", func(): return Geo.octa(11)), M.ice_core))
	var rg := mesh(Geo.cached("pwR", func(): return Geo.build_facing(Geo.ring(13, 15.5, 16), Vector3.BACK)), M.frost_dark)
	core.add_child(rg)
	core.add_child(mesh(geo("pwE", func(): return Geo.ico(3.4, 1)), M.eye, Vector3(-6, 0, 6)))
	g.add_child(core)
	u.core = core
	for k in ["top", "bot"]:
		var p := Node3D.new()
		var b := mesh(geo("pwP", func(): return Geo.octa(6.5)), M.ice_c)
		b.scale = Vector3(0.8, 1.7, 0.8)
		p.add_child(b)
		p.add_child(mesh(geo("pwPs", func(): return Geo.ico(2, 0)), M.eye, Vector3(-4, 0, 3)))
		g.add_child(p)
		u[k] = p
		var beam := mesh(geo("pwB", func(): return Geo.box(1, 1, 1)), M.frost_dark)
		g.add_child(beam)
		u[k + "_beam"] = beam
	g.set_meta("u", u)
	world.add_child(g)
	return g


static func boss_titan(world: Node3D) -> Node3D:
	var g := Node3D.new()
	var u := {}
	var hull := Node3D.new()
	hull.add_child(mesh(geo("ttH", func(): return Geo.box(34, 46, 22)), M.steel_dark))
	hull.add_child(mesh(geo("ttF", func(): return Geo.box(6, 50, 24)), M.rust, Vector3(-17, 0, 0)))
	for sy in [-1.0, 1.0]:
		hull.add_child(mesh(geo("ttS", func(): return Geo.box(36, 3, 23)), M.hazard, Vector3(0, sy * 24, 0)))
		var stack := mesh(geo("ttK", func(): return Geo.cyl(3, 3.6, 16, 6)), M.steel, Vector3(8, sy * 30, -6))
		hull.add_child(stack)
	g.add_child(hull)
	u.hull = hull
	var furnace := Node3D.new()
	furnace.add_child(mesh(geo("ttC", func(): return Geo.ico(7, 1)), M.hot))
	g.add_child(furnace)
	u.core = furnace
	var lid := geo("ttL", func(): return Geo.box(4, 9, 16))
	u.lidT = mesh(lid, M.steel)
	u.lidB = mesh(lid, M.steel)
	g.add_child(u.lidT)
	g.add_child(u.lidB)
	for k in ["top", "bot"]:
		var c := Node3D.new()
		c.add_child(mesh(geo("ttG", func(): return Geo.ico(6, 0)), M.rust))
		var piv := Node3D.new()
		c.add_child(piv)
		piv.add_child(mesh(geo("ttGb", func(): return Geo.box(12, 2.6, 2.6)), M.steel, Vector3(-6, 0, 0)))
		c.set_meta("piv", piv)
		g.add_child(c)
		u[k] = c
	g.set_meta("u", u)
	world.add_child(g)
	return g


static func boss_heart(world: Node3D) -> Node3D:
	var g := Node3D.new()
	var u := {}
	var core := Node3D.new()
	core.add_child(mesh(geo("shC", func(): return Geo.ico(12, 1)), M.corona))
	var sp := geo("shS", func(): return Geo.xf(Geo.cone(2.6, 8, 4), Geo.move(0, 15, 0)))
	var spikes := Node3D.new()
	for i in 10:
		var s := mesh(sp, M.lava)
		s.rotation.z = i * TAU / 10.0
		spikes.add_child(s)
	core.add_child(spikes)
	var shell := mesh(geo("shH", func(): return Geo.dodeca(14.5)), M.ash)
	core.add_child(shell)
	g.add_child(core)
	u.core = core
	u.spikes = spikes
	u.shell = shell
	u.nodes = []
	for i in 8:
		var n := Node3D.new()
		n.add_child(mesh(geo("shN", func(): return Geo.dodeca(4.4)), M.gold))
		n.add_child(mesh(geo("shNe", func(): return Geo.ico(1.6, 0)), M.eye, Vector3(-3, 0, 2.5)))
		g.add_child(n)
		u.nodes.append(n)
	g.set_meta("u", u)
	world.add_child(g)
	return g


# ---------- world 3: Verdant Hive ----------

static func wasp() -> Node3D:
	var g := Node3D.new()
	var b := mesh(geo("wsp", func(): return Geo.octa(2.2)), M.wasp_y)
	b.scale = Vector3(1.6, 0.8, 0.8)
	g.add_child(b)
	g.add_child(mesh(geo("wspT", func(): return Geo.cone(1, 3, 4)), M.chitin, Vector3(-3.6, 0, 0)))
	var wt := geo("wspW", func(): return Geo.prism([[-1, 0], [1.5, 0], [0, 5]], 0.2))
	var wings := []
	for sg in [1.0, -1.0]:
		var w := mesh(wt, M.wing, Vector3(0, 0.8, 0.9 * sg))
		w.rotation.x = 0.5 * sg
		g.add_child(w)
		wings.append(w)
	g.add_child(mesh(geo("eyeS", func(): return Geo.ico(0.9, 0)), M.eye, Vector3(3, 0.3, 1)))
	g.set_meta("wings", wings)
	return g


## Wall pod that lobs arcing blobs.
static func spitter(side: int) -> Node3D:
	var g := Node3D.new()
	var w := 1.0 if side else -1.0
	g.add_child(mesh(geo("spB", func(): return Geo.cyl(3, 4.4, 3, 6)), M.chitin, Vector3(0, w * 1.6, 0)))
	var bulb := mesh(geo("spU", func(): return Geo.ico(3.2, 0)), M.sac, Vector3(0, -w * 1.2, 0))
	g.add_child(bulb)
	g.add_child(mesh(geo("spM", func(): return Geo.ico(1.2, 0)), M.moss, Vector3(0, -w * 3.6, 1)))
	g.set_meta("bulb", bulb)
	return g


## Floating hive nest that releases wasps (behaves like the shell beast, without the fan).
static func nest() -> Node3D:
	var g := Node3D.new()
	var s := mesh(geo("nst", func(): return Geo.dodeca(7.5)), M.amber)
	s.scale = Vector3(1.0, 1.25, 1)
	g.add_child(s)
	var hole := geo("nstH", func(): return Geo.ico(1.6, 0))
	for i in 5:
		var a := i * TAU / 5.0
		g.add_child(mesh(hole, M.chitin, Vector3(cos(a) * 5, sin(a) * 6.5, 4)))
	g.add_child(mesh(geo("she", func(): return Geo.ico(1.7, 0)), M.eye, Vector3(-7, 0, 3)))
	return g


# ---------- world 5: Bastion Ring ----------

## Arrowhead that holds at the edge of the screen, then dashes straight across.
static func lancer() -> Node3D:
	var g := Node3D.new()
	var b := mesh(geo("lnc", func(): return Geo.prism([[-5, -2.4], [6, 0], [-5, 2.4], [-3, 0]], 2.4)), M.armor)
	g.add_child(b)
	g.add_child(mesh(geo("lncE", func(): return Geo.box(2, 1, 3)), M.neon, Vector3(-4, 0, 0)))
	var fl := mesh(geo("skrF", func(): return Geo.ico(1.3, 0)), M.engine, Vector3(-5.6, 0, 0))
	fl.set_meta("nf", true)
	g.add_child(fl)
	g.set_meta("flame", fl)
	return g


## Armoured block ship (behaves like the shell beast, rings of bullets).
static func bulwark() -> Node3D:
	var g := Node3D.new()
	g.add_child(mesh(geo("bwB", func(): return Geo.box(16, 11, 9)), M.plate2))
	g.add_child(mesh(geo("bwF", func(): return Geo.box(3, 13, 10)), M.armor, Vector3(-8.5, 0, 0)))
	for sy in [-1.0, 1.0]:
		g.add_child(mesh(geo("bwN", func(): return Geo.box(14, 1, 9.4)), M.neon, Vector3(1, sy * 5.6, 0)))
	g.add_child(mesh(geo("she", func(): return Geo.ico(1.7, 0)), M.eye, Vector3(-10, 0, 3)))
	return g


# ---------- fortress pieces ----------

## Shield generator mounted on a locked gate's lip: destroy it to open the gate.
static func generator(side: int) -> Node3D:
	var g := Node3D.new()
	var w := 1.0 if side else -1.0
	g.add_child(mesh(geo("gnrB", func(): return Geo.box(6, 2.4, 6)), M.gate, Vector3(0, w * 1.6, 0)))
	var core := mesh(geo("gnrC", func(): return Geo.octa(2.6)), M.field)
	g.add_child(mesh(geo("gnrK", func(): return Geo.ico(2, 0)), M.neon, Vector3(0, -w * 0.8, 0)))
	core.position = Vector3(0, -w * 0.8, 0)
	core.set_meta("nf", true)
	g.add_child(core)
	g.set_meta("core", core)
	return g


# ---------- bosses of worlds 3 and 5 ----------

static func boss_queen(world: Node3D) -> Node3D:
	var g := Node3D.new()
	var u := {}
	var head := Node3D.new()
	var hb := mesh(geo("qH", func(): return Geo.dodeca(8)), M.wasp_y)
	hb.scale = Vector3(1.2, 1, 1)
	head.add_child(hb)
	for sy in [-1.0, 1.0]:
		head.add_child(mesh(geo("qE", func(): return Geo.ico(2.4, 0)), M.eye, Vector3(-6, sy * 3, 5)))
		var m := mesh(geo("qM", func(): return Geo.cone(1.2, 6, 4)), M.chitin, Vector3(-10, sy * 2.5, 0))
		m.rotation.z = PI / 2 + sy * 0.4
		head.add_child(m)
	g.add_child(head)
	u.core = head
	var sac := Node3D.new()
	var sb := mesh(geo("qS", func(): return Geo.ico(10, 1)), M.sac)
	sb.scale = Vector3(1.4, 1, 1)
	sac.add_child(sb)
	for i in 4:
		sac.add_child(mesh(geo("qSt", func(): return Geo.box(1.4, 18, 16)), M.chitin, Vector3(-6 + i * 5, 0, 0)))
	g.add_child(sac)
	u.sac = sac
	var wt := geo("qW", func(): return Geo.prism([[-6, 0], [8, 0], [14, 24], [-2, 20]], 0.6))
	for k in ["top", "bot"]:
		var n := Node3D.new()
		var wm := mesh(wt, M.wing)
		wm.scale = Vector3(0.8, -0.8 if k == "bot" else 0.8, 1)
		wm.rotation.y = 0.7
		n.add_child(wm)
		n.add_child(mesh(geo("qWv", func(): return Geo.ico(2.4, 0)), M.amber, Vector3(4, 10 * (-1.0 if k == "bot" else 1.0), 1)))
		g.add_child(n)
		u[k] = n
	g.set_meta("u", u)
	world.add_child(g)
	return g


static func boss_bastion(world: Node3D) -> Node3D:
	var g := Node3D.new()
	var u := {}
	var core := Node3D.new()
	core.add_child(mesh(geo("bcC", func(): return Geo.ico(9, 1)), M.neon))
	core.add_child(mesh(Geo.cached("bcR", func(): return Geo.build_facing(Geo.ring(10, 12, 16), Vector3.BACK)), M.armor))
	core.add_child(mesh(geo("bcE", func(): return Geo.ico(3, 1)), M.eye, Vector3(-4, 0, 7)))
	g.add_child(core)
	u.core = core
	var frame := mesh(geo("bcF", func(): return Geo.box(10, 90, 14)), M.plate2)
	g.add_child(frame)
	u.frame = frame
	u.plates = []
	for i in 4:
		var p := mesh(geo("bcP", func(): return Geo.box(5, 16, 10)), M.armor)
		g.add_child(p)
		u.plates.append(p)
	u.guns = []
	for i in 4:
		var n := Node3D.new()
		n.add_child(mesh(geo("bcG", func(): return Geo.octa(4)), M.plate))
		n.add_child(mesh(geo("bcGb", func(): return Geo.box(7, 1.6, 1.6)), M.neon2, Vector3(-4, 0, 0)))
		g.add_child(n)
		u.guns.append(n)
	g.set_meta("u", u)
	world.add_child(g)
	return g
