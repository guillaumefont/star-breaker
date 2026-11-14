class_name Geo
extends RefCounted
## Low poly mesh builders. Every mesh is flat shaded (one normal per triangle).
## Shapes are returned as triangle lists ([a, b, c] arrays of Vector3) so they can be
## transformed before being baked into an ArrayMesh.

static var _cache: Dictionary = {}


## Returns a cached mesh, building it with `f` the first time `key` is asked for.
static func cached(key: String, f: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = f.call()
	return _cache[key]


## Bakes triangles into a mesh, orienting each face away from `center`
## (the centroid of the vertices when not given). Good for convex shapes.
static func build(tris: Array, center: Variant = null) -> ArrayMesh:
	var c := Vector3.ZERO
	if center == null:
		var n := 0
		for t in tris:
			for v in t:
				c += v
				n += 1
		if n > 0:
			c /= float(n)
	else:
		c = center
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var d: Vector3 = t[2]
		var nrm := (b - a).cross(d - a)
		if nrm.length_squared() < 1e-10:
			continue
		nrm = nrm.normalized()
		if nrm.dot((a + b + d) / 3.0 - c) < 0.0:
			nrm = -nrm
			var tmp := b
			b = d
			d = tmp
		# Godot treats clockwise triangles as front faces.
		verts.append(a)
		verts.append(d)
		verts.append(b)
		for i in 3:
			norms.append(nrm)
	return _mesh(verts, norms)


## Bakes triangles into a mesh with every face turned towards `dir` (for open surfaces).
static func build_facing(tris: Array, dir: Vector3) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var d: Vector3 = t[2]
		var nrm := (b - a).cross(d - a)
		if nrm.length_squared() < 1e-10:
			continue
		nrm = nrm.normalized()
		if nrm.dot(dir) < 0.0:
			nrm = -nrm
			var tmp := b
			b = d
			d = tmp
		verts.append(a)
		verts.append(d)
		verts.append(b)
		for i in 3:
			norms.append(nrm)
	return _mesh(verts, norms)


## Bakes triangles that are already wound outwards (see `orient()`), e.g. from `loft()`.
static func build_wound(tris: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var d: Vector3 = t[2]
		var nrm := (b - a).cross(d - a)
		if nrm.length_squared() < 1e-10:
			continue
		verts.append(a)
		verts.append(d)
		verts.append(b)
		nrm = nrm.normalized()
		for i in 3:
			norms.append(nrm)
	return _mesh(verts, norms)


## Returns `tri` wound so that its normal points away from `ref`.
static func orient(tri: Array, ref: Vector3) -> Array:
	var a: Vector3 = tri[0]
	var b: Vector3 = tri[1]
	var c: Vector3 = tri[2]
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - ref) < 0.0:
		return [a, c, b]
	return [a, b, c]


## Hull lofted along X through elliptical cross-sections, capped at both ends.
## Each section is [x, half height, half depth, centre y]; sections must be ordered by x.
## The first ring vertex sits half a step off the top so the hull has a flat spine.
static func loft(secs: Array, seg: int) -> Array:
	var rings := []
	for s in secs:
		var r := []
		for i in seg:
			var a := (i + 0.5) / seg * TAU
			r.append(Vector3(s[0], s[3] + s[1] * cos(a), s[2] * sin(a)))
		rings.append(r)
	var tris := []
	for k in secs.size() - 1:
		var s0: Array = secs[k]
		var s1: Array = secs[k + 1]
		var m := Vector3((s0[0] + s1[0]) * 0.5, (s0[3] + s1[3]) * 0.5, 0)
		var r0: Array = rings[k]
		var r1: Array = rings[k + 1]
		for i in seg:
			var j := (i + 1) % seg
			tris.append(orient([r0[i], r1[i], r1[j]], m))
			tris.append(orient([r0[i], r1[j], r0[j]], m))
	for e in [[0, 1.0], [secs.size() - 1, -1.0]]:
		var s: Array = secs[e[0]]
		var c := Vector3(s[0], s[3], 0)
		var r: Array = rings[e[0]]
		if s[1] <= 0.0 or s[2] <= 0.0:
			continue
		for i in seg:
			tris.append(orient([c, r[i], r[(i + 1) % seg]], c + Vector3(e[1], 0, 0)))
	return tris


static func _mesh(verts: PackedVector3Array, norms: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func xf(tris: Array, t: Transform3D) -> Array:
	var out := []
	for tri in tris:
		out.append([t * (tri[0] as Vector3), t * (tri[1] as Vector3), t * (tri[2] as Vector3)])
	return out


static func rot(axis: Vector3, angle: float) -> Transform3D:
	return Transform3D(Basis(axis, angle), Vector3.ZERO)


static func move(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


static func _faces(v: Array, idx: Array) -> Array:
	var tris := []
	for i in range(0, idx.size(), 3):
		tris.append([v[idx[i]], v[idx[i + 1]], v[idx[i + 2]]])
	return tris


static func octa(r: float) -> Array:
	var v := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r, 0), Vector3(0, -r, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	var tris := []
	for a in [0, 1]:
		for b in [2, 3]:
			for c in [4, 5]:
				tris.append([v[a], v[b], v[c]])
	return tris


static func tetra(r: float) -> Array:
	var v := []
	for p in [Vector3(1, 1, 1), Vector3(-1, -1, 1), Vector3(-1, 1, -1), Vector3(1, -1, -1)]:
		v.append(p.normalized() * r)
	return _faces(v, [0, 1, 2, 0, 1, 3, 0, 2, 3, 1, 2, 3])


static func ico(r: float, detail := 0) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := []
	for p in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
			Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		v.append(p.normalized())
	var tris := _faces(v, [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
			3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for i in detail:
		var nt := []
		for tri in tris:
			var a: Vector3 = tri[0]
			var b: Vector3 = tri[1]
			var c: Vector3 = tri[2]
			var ab := ((a + b) * 0.5).normalized()
			var bc := ((b + c) * 0.5).normalized()
			var ca := ((c + a) * 0.5).normalized()
			nt.append_array([[a, ab, ca], [ab, b, bc], [ca, bc, c], [ab, bc, ca]])
		tris = nt
	return xf(tris, Transform3D(Basis().scaled(Vector3.ONE * r), Vector3.ZERO))


static func dodeca(r: float) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var q := 1.0 / t
	var raw := [-1, -1, -1, -1, -1, 1, -1, 1, -1, -1, 1, 1, 1, -1, -1, 1, -1, 1, 1, 1, -1, 1, 1, 1,
			0, -q, -t, 0, -q, t, 0, q, -t, 0, q, t, -q, -t, 0, -q, t, 0, q, -t, 0, q, t, 0,
			-t, 0, -q, t, 0, -q, -t, 0, q, t, 0, q]
	var v := []
	for i in range(0, raw.size(), 3):
		v.append(Vector3(raw[i], raw[i + 1], raw[i + 2]).normalized() * r)
	return _faces(v, [3, 11, 7, 3, 7, 15, 3, 15, 13, 7, 19, 17, 7, 17, 6, 7, 6, 15, 17, 4, 8, 17, 8, 10, 17, 10, 6,
			8, 0, 16, 8, 16, 2, 8, 2, 10, 0, 12, 1, 0, 1, 18, 0, 18, 16, 6, 10, 2, 6, 2, 13, 6, 13, 15,
			2, 16, 18, 2, 18, 3, 2, 3, 13, 18, 1, 9, 18, 9, 11, 18, 11, 3, 4, 14, 12, 4, 12, 0, 4, 0, 8,
			11, 9, 5, 11, 5, 19, 11, 19, 7, 19, 5, 14, 19, 14, 4, 19, 4, 17, 1, 12, 14, 1, 14, 5, 1, 5, 9])


## Cylinder along Y, centred on the origin (top radius 0 gives a cone).
static func cyl(rt: float, rb: float, h: float, seg: int) -> Array:
	var tris := []
	var top := []
	var bot := []
	for i in seg:
		var a := float(i) / seg * TAU
		top.append(Vector3(rt * sin(a), h / 2.0, rt * cos(a)))
		bot.append(Vector3(rb * sin(a), -h / 2.0, rb * cos(a)))
	var ct := Vector3(0, h / 2.0, 0)
	var cb := Vector3(0, -h / 2.0, 0)
	for i in seg:
		var j := (i + 1) % seg
		if rt > 0.0:
			tris.append([top[i], bot[i], bot[j]])
			tris.append([top[i], bot[j], top[j]])
			tris.append([ct, top[i], top[j]])
		else:
			tris.append([ct, bot[i], bot[j]])
		tris.append([cb, bot[i], bot[j]])
	return tris


static func cone(r: float, h: float, seg: int) -> Array:
	return cyl(0.0, r, h, seg)


static func box(w: float, h: float, d: float) -> Array:
	var v := []
	for x in [-w / 2, w / 2]:
		for y in [-h / 2, h / 2]:
			for z in [-d / 2, d / 2]:
				v.append(Vector3(x, y, z))
	# vertex index = x*4 + y*2 + z
	return _faces(v, [0, 1, 3, 0, 3, 2, 4, 6, 7, 4, 7, 5, 0, 4, 5, 0, 5, 1, 2, 3, 7, 2, 7, 6, 0, 2, 6, 0, 6, 4, 1, 5, 7, 1, 7, 3])


## Convex polygon in XY, extruded along Z and centred on z = 0.
static func prism(pts: Array, depth: float) -> Array:
	var f := []
	var b := []
	for p in pts:
		f.append(Vector3(p[0], p[1], depth / 2.0))
		b.append(Vector3(p[0], p[1], -depth / 2.0))
	var tris := []
	var n := pts.size()
	for i in range(1, n - 1):
		tris.append([f[0], f[i], f[i + 1]])
		tris.append([b[0], b[i], b[i + 1]])
	for i in n:
		var j := (i + 1) % n
		tris.append([f[i], b[i], b[j]])
		tris.append([f[i], b[j], f[j]])
	return tris


## Upper half of a low poly sphere (open at the bottom).
static func hemi(r: float, wseg: int, hseg: int) -> Array:
	var tris := []
	for j in hseg:
		var t0 := float(j) / hseg * PI / 2.0
		var t1 := float(j + 1) / hseg * PI / 2.0
		for i in wseg:
			var p0 := float(i) / wseg * TAU
			var p1 := float(i + 1) / wseg * TAU
			var a := _sph(r, p0, t0)
			var b := _sph(r, p1, t0)
			var c := _sph(r, p1, t1)
			var d := _sph(r, p0, t1)
			if j > 0:
				tris.append([a, b, c])
			tris.append([a, c, d])
	return tris


static func _sph(r: float, phi: float, theta: float) -> Vector3:
	return Vector3(-r * cos(phi) * sin(theta), r * cos(theta), r * sin(phi) * sin(theta))


## Ring tube around the Z axis (ring radius `R`, tube radius `r`).
static func torus(R: float, r: float, seg: int, side: int) -> Array:
	var tris := []
	for i in seg:
		var a0 := float(i) / seg * TAU
		var a1 := float(i + 1) / seg * TAU
		var cm := Vector3(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5), 0) * R
		for j in side:
			var b0 := float(j) / side * TAU
			var b1 := float(j + 1) / side * TAU
			var q00 := _tor(R, r, a0, b0)
			var q10 := _tor(R, r, a1, b0)
			var q11 := _tor(R, r, a1, b1)
			var q01 := _tor(R, r, a0, b1)
			tris.append(orient([q00, q10, q11], cm))
			tris.append(orient([q00, q11, q01], cm))
	return tris


static func _tor(R: float, r: float, a: float, b: float) -> Vector3:
	return Vector3(cos(a), sin(a), 0) * (R + r * cos(b)) + Vector3(0, 0, r * sin(b))


## Flat ring in the XY plane.
static func ring(ri: float, ro: float, seg: int) -> Array:
	var tris := []
	for i in seg:
		var a0 := float(i) / seg * TAU
		var a1 := float(i + 1) / seg * TAU
		var p := Vector3(cos(a0), sin(a0), 0)
		var q := Vector3(cos(a1), sin(a1), 0)
		tris.append([p * ri, p * ro, q * ro])
		tris.append([p * ri, q * ro, q * ri])
	return tris


## Flat disc in the XY plane facing +Z.
static func disc(r: float, seg: int) -> Array:
	var tris := []
	for i in seg:
		var a0 := float(i) / seg * TAU
		var a1 := float(i + 1) / seg * TAU
		tris.append([Vector3.ZERO, Vector3(cos(a0), sin(a0), 0) * r, Vector3(cos(a1), sin(a1), 0) * r])
	return tris
