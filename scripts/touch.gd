class_name TouchPad
extends Control
## Touch controls with no visible buttons: the left half is a floating analog stick that
## appears where the thumb lands and follows it; the right half is split into invisible
## zones (Pod strip on top, then Fire | Rapid | Charge). A faint map of the zones shows
## for the first seconds of a run.

const ZC := {fire = Color("3ff0e0"), rapid = Color("ffb547"), charge = Color("8c7bff"), pod = Color("ff4fa3")}
const RADIUS := 65.0

var hud: Hud
var enabled := false
var playing := false            ## set by the game: false on menus and pause
var stick_id := -1
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var ax := 0.0
var ay := 0.0
var held := {}                  ## zone -> held now
var latched := {}               ## zone -> pressed since last poll (taps shorter than a tick)
var _zone_of := {}              ## touch index -> zone
var _ripples := []              ## [pos, colour, age]
var _zones: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zones = Control.new()
	_zones.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zones.modulate.a = 0.0
	add_child(_zones)
	_zone(Rect2(0.02, 0.20, 0.44, 0.76), "MOVE", "Touch anywhere here")
	_zone(Rect2(0.50, 0.20, 0.48, 0.22), "POD", "Tap to launch or recall")
	_zone(Rect2(0.50, 0.45, 0.15, 0.51), "FIRE", "Tap")
	_zone(Rect2(0.665, 0.45, 0.15, 0.51), "RAPID", "Hold")
	_zone(Rect2(0.83, 0.45, 0.15, 0.51), "CHARGE", "Hold, release")


func _zone(r: Rect2, title: String, sub: String) -> void:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.05)
	s.border_color = Color(1, 1, 1, 0.28)
	s.set_border_width_all(1)
	s.set_corner_radius_all(20)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.anchor_left = r.position.x
	p.anchor_top = r.position.y
	p.anchor_right = r.end.x
	p.anchor_bottom = r.end.y
	_zones.add_child(p)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var a := Label.new()
	a.text = title
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.add_theme_font_override("font", hud._font(700, 2.0))
	a.add_theme_font_size_override("font_size", 15)
	a.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	v.add_child(a)
	var b := Label.new()
	b.text = sub
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color("bdb6e0"))
	v.add_child(b)


func show_zones(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_zones, "modulate:a", 1.0 if on and enabled else 0.0, 0.3 if on else 1.0)


static func zone_at(fx: float, fy: float) -> String:
	if fx < 0.48:
		return "move"
	if fy < 0.43:
		return "pod"
	if fx < 0.66:
		return "fire"
	if fx < 0.825:
		return "rapid"
	return "charge"


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not enabled:
			hud.set_touch_mode(true)
		var e := event as InputEventScreenTouch
		var vs := get_viewport_rect().size
		if e.pressed:
			if hud.blocks_touch(e.position):
				return
			if not playing:
				latched["start"] = true
				return
			var z := zone_at(e.position.x / vs.x, e.position.y / vs.y)
			_zone_of[e.index] = z
			if z == "move":
				if stick_id == -1:
					stick_id = e.index
					origin = e.position
					knob = Vector2.ZERO
					ax = 0.0
					ay = 0.0
			else:
				held[z] = true
				latched[z] = true
				_ripples.append([e.position, ZC[z], 0.0])
			queue_redraw()
		else:
			var z: String = _zone_of.get(e.index, "")
			_zone_of.erase(e.index)
			if e.index == stick_id:
				release_stick()
			elif z != "" and z != "move" and not _zone_of.values().has(z):
				held[z] = false
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != stick_id:
			return
		var off := d.position - origin
		var len := off.length()
		if len > RADIUS:
			origin += off / len * (len - RADIUS)
			off = d.position - origin
		knob = off
		ax = clampf(off.x / RADIUS, -1, 1)
		ay = clampf(off.y / RADIUS, -1, 1)
		queue_redraw()


func release_stick() -> void:
	stick_id = -1
	ax = 0.0
	ay = 0.0
	queue_redraw()


## Drops every touch (focus loss, pause, game over).
func reset() -> void:
	release_stick()
	held.clear()
	latched.clear()
	_zone_of.clear()


func _process(delta: float) -> void:
	if _ripples.is_empty():
		return
	for r in _ripples:
		r[2] += delta
	_ripples = _ripples.filter(func(r): return r[2] < 0.45)
	queue_redraw()


func _draw() -> void:
	if stick_id != -1:
		draw_circle(origin, RADIUS, Color(1, 1, 1, 0.05))
		draw_arc(origin, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
		var k := origin + knob
		draw_circle(k, 34.0, Color(0.25, 0.94, 0.88, 0.12))
		draw_circle(k, 29.0, Color(0.86, 0.9, 1.0, 0.6))
		draw_circle(k - Vector2(6, 7), 13.0, Color(1, 1, 1, 0.75))
	for r in _ripples:
		var t: float = r[2] / 0.45
		var c: Color = r[1]
		draw_arc(r[0], 40.0 * lerpf(0.3, 1.4, t), 0, TAU, 40, Color(c, 0.9 * (1.0 - t)), 2.0, true)
