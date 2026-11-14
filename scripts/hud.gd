class_name Hud
extends Control
## Glass HUD, banners, menus and the touch layer. Laid out on the 1280x720 base canvas.

signal start_pressed
signal mute_pressed
signal safe_toggled
signal title_pressed
## A mode card on the main menu was tapped or clicked ("normal" or "endless").
signal mode_chosen(mode: String)

const C_TEXT := Color("f4f2ff")
const C_MUTED := Color("bdb6e0")
const C_SPORE := Color("ff4fa3")
const C_LANCE := Color("3ff0e0")
const C_AMBER := Color("ffb547")
const C_LIME := Color("c8f560")
const C_VIOLET := Color("8c7bff")
const CHARGE_TICKS := [50 / 240.0, 100 / 240.0, 160 / 240.0]

var fonts := {}
var touch: TouchPad
var muted := false
var lives := 2

var _score: Label
var _hi: Label
var _laser: Label
var _speed: Label
var _lives_icon: Control
var _lives_txt: Label
var _boss: Control
var _boss_pct: Label
var _boss_fill: ColorRect
var _charge: Control
var _charge_lv: Label
var _charge_fill: ColorRect
var _hints: Control
var _banner: VBoxContainer
var _banner_t: Label
var _banner_glow: Label
var _banner_s: Label
var _banner_tw: Tween
var _hud: Control
var _btn_mute: Button
var _btn_pause: Button
var title_scr: Control
var over_scr: Control
var pause_scr: Control
## Main menu mode cards: mode -> {button, best label, colour}.
var _cards := {}
var selected_mode := "normal"
var _over_score: Label
var _over_best: Label
var _key_rows: Array = []
var _touch_rows: Array = []
var _cache := {}
var _small_buttons: Array = []
var _crash: PanelContainer
var _crash_txt: Label
var _crash_report := ""
var _btn_gfx: Button
var _boss_name: Label
var _fade: ColorRect
var _fade_tw: Tween
var _over_cta: Button
var _over_note: Label
var _over_title: Button
var _over_reached: Label
var end_scr: Control
var _end_score: Label
var _end_best: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for w in [500, 700, 800]:
		fonts[w] = load("res://assets/fonts/rubik-latin-%d-normal.woff2" % w)
	var th := Theme.new()
	th.default_font = fonts[500]
	th.default_font_size = 17
	theme = th

	_hud = _full(self)
	_build_hud()
	touch = TouchPad.new()
	touch.hud = self
	add_child(touch)
	title_scr = _build_title()
	over_scr = _build_over()
	pause_scr = _build_pause()
	end_scr = _build_end()
	over_scr.hide()
	pause_scr.hide()
	end_scr.hide()
	# black curtain for the cut between worlds (on top of everything, never takes input)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.01, 0.06, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade.hide()
	add_child(_fade)
	set_touch_mode(OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"))


# ---------- building blocks ----------

func _full(parent: Control) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _font(weight: int, spacing := 0.0) -> Font:
	var key := "%d_%f" % [weight, spacing]
	if not fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = fonts[weight]
		fv.spacing_glyph = int(spacing)
		fonts[key] = fv
	return fonts[key]


func _label(text: String, size: int, weight := 500, color := C_TEXT, spacing := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font(weight, spacing))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _caps(text: String, size := 11, color := C_MUTED) -> Label:
	return _label(text.to_upper(), size, 700, color, 2.0)


func _glass_style(radius := 999, pad := Vector2(16, 6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(22 / 255.0, 17 / 255.0, 50 / 255.0, 0.55)
	s.border_color = Color(1, 1, 1, 0.16)
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	s.anti_aliasing = true
	return s


func _glass(radius := 999, pad := Vector2(16, 6)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _glass_style(radius, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _pill(label: String) -> Array:
	var p := _glass()
	var h := _hbox(10)
	p.add_child(h)
	var l := _caps(label)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var n := _label("0", 22, 800)
	h.add_child(n)
	return [p, n]


func _chip(text: String, color: Color) -> Array:
	var p := _glass(999, Vector2(12, 4))
	var h := _hbox(6)
	p.add_child(h)
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.draw.connect(func():
		dot.draw_circle(Vector2(5, 5), 7.0, Color(color, 0.25))
		dot.draw_circle(Vector2(5, 5), 4.5, color))
	h.add_child(dot)
	h.add_child(_label(text, 13, 700))
	var v := _label("1", 13, 700)
	h.add_child(v)
	return [p, v]


func _bar(a: Color, b: Color, h: float, ticks := []) -> Array:
	var track := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.1)
	s.set_corner_radius_all(99)
	track.add_theme_stylebox_override("panel", s)
	track.custom_minimum_size = Vector2(0, h)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/bar.gdshader")
	mat.set_shader_parameter("col_a", a)
	mat.set_shader_parameter("col_b", b)
	fill.material = mat
	fill.resized.connect(func(): mat.set_shader_parameter("size", fill.size))
	track.add_child(fill)
	for t in ticks:
		var tk := ColorRect.new()
		tk.color = Color(5 / 255.0, 4 / 255.0, 13 / 255.0, 0.8)
		tk.anchor_left = t
		tk.anchor_right = t
		tk.anchor_bottom = 1.0
		tk.offset_right = 2
		track.add_child(tk)
	return [track, fill]


func _key(k: String, text: String) -> PanelContainer:
	var p := _glass(999, Vector2(8, 4))
	var h := _hbox(8)
	p.add_child(h)
	var cap := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(1, 1, 1, 0.15)
	cs.set_corner_radius_all(8)
	cs.content_margin_left = 8
	cs.content_margin_right = 8
	cs.content_margin_top = 3
	cs.content_margin_bottom = 3
	cap.add_theme_stylebox_override("panel", cs)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(_label(k, 13, 700))
	h.add_child(cap)
	var l := _label(text, 14, 500)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return p


func _keys(list: Array, max_w := 980.0) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.alignment = FlowContainer.ALIGNMENT_CENTER
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	f.custom_minimum_size = Vector2(max_w, 0)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for kv in list:
		f.add_child(_key(kv[0], kv[1]))
	return f


func _icon_button(kind: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(44, 44)
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		var s := _glass_style(999, Vector2.ZERO)
		if st == "hover" or st == "pressed":
			s.bg_color = Color(40 / 255.0, 32 / 255.0, 84 / 255.0, 0.7)
		b.add_theme_stylebox_override(st, s)
	b.draw.connect(func(): _draw_icon(b, kind))
	return b


func _draw_icon(b: Button, kind: String) -> void:
	var o := b.size / 2.0 - Vector2(10, 10)
	var k := 20.0 / 24.0
	var pts := func(a: Array) -> PackedVector2Array:
		var r := PackedVector2Array()
		for i in range(0, a.size(), 2):
			r.append(o + Vector2(a[i], a[i + 1]) * k)
		return r
	if kind == "pause":
		b.draw_rect(Rect2(o + Vector2(6, 5) * k, Vector2(4, 14) * k), C_TEXT)
		b.draw_rect(Rect2(o + Vector2(14, 5) * k, Vector2(4, 14) * k), C_TEXT)
		return
	b.draw_colored_polygon(pts.call([4, 9, 8, 9, 13, 5, 13, 19, 8, 15, 4, 15]), C_TEXT)
	if muted:
		b.draw_line(o + Vector2(16, 9) * k, o + Vector2(22, 15) * k, C_TEXT, 2.0, true)
		b.draw_line(o + Vector2(22, 9) * k, o + Vector2(16, 15) * k, C_TEXT, 2.0, true)
	else:
		b.draw_arc(o + Vector2(13, 12) * k, 4.5 * k, -0.9, 0.9, 8, C_TEXT, 2.0, true)
		b.draw_arc(o + Vector2(13, 12) * k, 8.0 * k, -0.95, 0.95, 12, C_TEXT, 2.0, true)


func _cta(text: String) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font(800, 3.0))
	b.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = C_LANCE.lerp(Color("9afcff"), 0.35 if st == "hover" else 0.0)
		if st == "pressed":
			s.bg_color = C_LANCE.darkened(0.12)
		s.set_corner_radius_all(999)
		s.content_margin_left = 46
		s.content_margin_right = 46
		s.content_margin_top = 13
		s.content_margin_bottom = 13
		s.shadow_color = Color(C_LANCE, 0.45)
		s.shadow_size = 18
		s.shadow_offset = Vector2(0, 8)
		s.border_width_bottom = 3
		s.border_color = Color(0, 0, 0, 0.18)
		s.anti_aliasing = true
		b.add_theme_stylebox_override(st, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color("07051a"))
	b.pressed.connect(func(): start_pressed.emit())
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func _grad_label(text: String, size: int, weight: int, mode: int, cols: Array, spacing := 0.0) -> Label:
	var l := _label(text, size, weight, Color.WHITE, spacing)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/text_grad.gdshader")
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("c1", cols[0])
	m.set_shader_parameter("c2", cols[1])
	m.set_shader_parameter("c3", cols[2] if cols.size() > 2 else cols[1])
	l.material = m
	l.resized.connect(func(): m.set_shader_parameter("box", l.size))
	return l


## A soft coloured halo label drawn behind gradient text (stands in for CSS drop-shadow).
func _halo(text: String, size: int, weight: int, color: Color, spacing := 0.0) -> Label:
	var l := _label(text, size, weight, Color(color, 0.0), spacing)
	l.add_theme_constant_override("outline_size", 22)
	l.add_theme_color_override("font_outline_color", Color(color, 0.16))
	return l


func _stack(a: Control, b: Control) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(a)
	c.add_child(b)
	b.resized.connect(func():
		c.custom_minimum_size = b.size
		a.size = b.size)
	return c


func _stat(label: String) -> Array:
	var p := _glass(16, Vector2(22, 8))
	var v := _vbox(0)
	p.add_child(v)
	var l := _caps(label)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var n := _label("0", 22, 800)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	return [p, n]


# ---------- HUD ----------

func _build_hud() -> void:
	var left := _vbox(7)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.position = Vector2(26, 25)
	_hud.add_child(left)
	var sp := _pill("Score")
	sp[0].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(sp[0])
	_score = sp[1]
	var chips := _hbox(6)
	chips.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.add_child(chips)
	var lp := _glass(999, Vector2(12, 4))
	var lh := _hbox(4)
	lp.add_child(lh)
	_lives_icon = Control.new()
	_lives_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lives_icon.draw.connect(_draw_lives)
	lh.add_child(_lives_icon)
	_lives_txt = _label("", 13, 700)
	lh.add_child(_lives_txt)
	chips.add_child(lp)
	var lc := _chip("Laser", C_LANCE)
	chips.add_child(lc[0])
	_laser = lc[1]
	var sc := _chip("Speed", C_LIME)
	chips.add_child(sc[0])
	_speed = sc[1]

	var right := _hbox(8)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_left = -26
	right.offset_right = -26
	right.offset_top = 25
	right.offset_bottom = 25
	right.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud.add_child(right)
	var hp := _pill("Best")
	right.add_child(hp[0])
	_hi = hp[1]
	_btn_mute = _icon_button("mute")
	_btn_mute.pressed.connect(func(): mute_pressed.emit())
	right.add_child(_btn_mute)
	_btn_pause = _icon_button("pause")
	_btn_pause.pressed.connect(func(): start_pressed.emit())
	right.add_child(_btn_pause)

	# boss bar
	_boss = _glass(16, Vector2(16, 8))
	_boss.anchor_left = 0.33
	_boss.anchor_right = 0.67
	_boss.offset_top = 25
	_hud.add_child(_boss)
	var bv := _vbox(6)
	_boss.add_child(bv)
	var br := _hbox()
	br.alignment = BoxContainer.ALIGNMENT_BEGIN
	bv.add_child(br)
	var bn := _caps("Bloom Mother", 11, Color("ff8cc6"))
	bn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(bn)
	_boss_name = bn
	_boss_pct = _caps("100%", 11, Color("ff8cc6"))
	br.add_child(_boss_pct)
	var bb := _bar(C_SPORE, C_AMBER, 8)
	bv.add_child(bb[0])
	_boss_fill = bb[1]
	_boss.hide()

	# charge meter
	_charge = _glass(16, Vector2(14, 7))
	_charge.anchor_left = 0.37
	_charge.anchor_right = 0.63
	_charge.anchor_top = 1.0
	_charge.anchor_bottom = 1.0
	_charge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_charge.offset_bottom = -28
	_hud.add_child(_charge)
	var cv := _vbox(5)
	_charge.add_child(cv)
	var cr := _hbox()
	cr.alignment = BoxContainer.ALIGNMENT_BEGIN
	cv.add_child(cr)
	var cn := _caps("Lance charge")
	cn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr.add_child(cn)
	_charge_lv = _caps("")
	cr.add_child(_charge_lv)
	# a notch at each charge stage (Main.CHARGE_AT over Main.CHARGE_MAX: LV 1, 2, 3, then Nova at the end)
	var cb := _bar(C_VIOLET, C_LANCE, 7, CHARGE_TICKS)
	cv.add_child(cb[0])
	_charge_fill = cb[1]

	# keyboard hints
	_hints = _keys([["WASD", "Move"], ["Z", "Fire (hold for rapid)"], ["X", "Charge (hold, release)"], ["Space", "Pod"]])
	_hints.anchor_left = 0.5
	_hints.anchor_right = 0.5
	_hints.anchor_top = 0.87
	_hints.anchor_bottom = 0.87
	_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.add_child(_hints)
	_hints.modulate.a = 0.0

	# banner
	_banner = _vbox(6)
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.3
	_banner.anchor_bottom = 0.3
	_hud.add_child(_banner)
	_banner_t = _grad_label("", 46, 800, 1, [Color.WHITE, Color("a9f6ff")])
	_banner_glow = _halo("", 46, 800, C_LANCE)
	var st := _stack(_banner_glow, _banner_t)
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner.add_child(st)
	_banner_s = _label("", 14, 500, Color(C_TEXT, 0.85), 3.0)
	_banner_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_s)
	_banner.hide()


func _draw_lives() -> void:
	var n := lives if lives <= 4 else 1
	for i in n:
		var o := Vector2(i * 22, 1)
		var k := 20.0 / 24.0
		_lives_icon.draw_colored_polygon(PackedVector2Array([o + Vector2(2, 12) * k, o + Vector2(7, 7) * k, o + Vector2(22, 12) * k, o + Vector2(7, 17) * k]), C_TEXT)


func _menu_bg(parent: Control) -> Control:
	var m := Control.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(m)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.set_color(0, Color(40 / 255.0, 24 / 255.0, 90 / 255.0, 0.3))
	g.set_color(1, Color(5 / 255.0, 4 / 255.0, 13 / 255.0, 0.86))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.15, 0.45)
	bg.texture = gt
	m.add_child(bg)
	return m


func _center_col(m: Control, sep := 16) -> VBoxContainer:
	var v := _vbox(sep)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(v)
	return v


func _build_title() -> Control:
	var m := _menu_bg(self)
	var v := _center_col(m, 22)
	v.offset_bottom = -54
	var logo := _vbox(0)
	v.add_child(logo)
	var sub := _label("SIX WORLDS · ONE STAR", 18, 700, C_TEXT, 8.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(sub)
	var star := _label("STAR", 72, 800)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.add_theme_constant_override("line_spacing", -18)
	logo.add_child(star)
	var brk := _grad_label("BREAKER", 72, 800, 0, [C_LANCE, C_VIOLET, C_SPORE])
	var st := _stack(_halo("BREAKER", 72, 800, C_VIOLET), brk)
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.add_child(st)
	var cards := _hbox(22)
	v.add_child(cards)
	cards.add_child(_mode_card("normal", "Normal", "Campaign", "Break through six worlds\nto the heart of the star.", C_LANCE))
	cards.add_child(_mode_card("endless", "Endless", "No end", "The worlds loop forever,\ntougher every lap.", C_SPORE))
	select_mode(selected_mode)
	var kr := _keys([["◀ ▶", "Choose"], ["Enter", "Play"], ["WASD", "Move"], ["Z", "Fire"], ["X", "Charge"], ["Space", "Pod"], ["Esc", "Pause"]], 1000)
	kr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(kr)
	_key_rows.append(kr)
	var tr := _keys([["Tap", "A mode to play"], ["Left", "Move"], ["Right, bottom up", "Fire · Charge · Pod"]], 1000)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tr)
	_touch_rows.append(tr)
	_build_device_row(m)
	return m


## A big glass card on the main menu that starts its mode when tapped or clicked.
func _mode_card(key: String, title: String, tag: String, desc: String, col: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(340, 0)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(func(): mode_chosen.emit(key))
	b.mouse_entered.connect(func(): select_mode(key))
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 26)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 18)
	b.add_child(pad)
	var v := _vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	pad.add_child(v)
	var top := _hbox(10)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_child(top)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(44, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func(): _draw_mode_icon(icon, key, col))
	top.add_child(icon)
	var tv := _vbox(-4)
	tv.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_child(tv)
	tv.add_child(_caps(tag, 11, col))
	tv.add_child(_label(title.to_upper(), 34, 800, C_TEXT, 3.0))
	var d := _label(desc, 15, 500, C_MUTED)
	v.add_child(d)
	var br := _hbox(8)
	br.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_child(br)
	var bl := _caps("Best", 11)
	bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	br.add_child(bl)
	var best := _label("0", 20, 800, C_TEXT)
	br.add_child(best)
	# the card's height follows its content
	pad.minimum_size_changed.connect(func(): b.custom_minimum_size.y = pad.get_combined_minimum_size().y)
	b.custom_minimum_size.y = pad.get_combined_minimum_size().y
	_cards[key] = {button = b, best = best, col = col}
	return b


func _draw_mode_icon(c: Control, key: String, col: Color) -> void:
	var h := c.size.y / 2.0
	if key == "normal":
		# worlds on a path ending at the star
		var pts := [Vector2(3, h + 6), Vector2(13, h - 2), Vector2(23, h + 4), Vector2(33, h - 5)]
		for i in 3:
			c.draw_line(pts[i], pts[i + 1], Color(col, 0.5), 2.0, true)
		for i in 3:
			c.draw_circle(pts[i], 3.5, col)
		c.draw_circle(pts[3], 7.0, Color(col, 0.25))
		c.draw_circle(pts[3], 4.5, Color.WHITE)
	else:
		# infinity loop
		var pts := PackedVector2Array()
		for i in 49:
			var t := TAU * i / 48.0
			var k := 1.0 + sin(t) * sin(t)
			pts.append(Vector2(22 + 17 * cos(t) / k, h + 17 * sin(t) * cos(t) / k))
		c.draw_polyline(pts, Color(col, 0.3), 7.0, true)
		c.draw_polyline(pts, col, 3.0, true)


## Highlights the mode card the keyboard or gamepad will start.
func select_mode(key: String) -> void:
	if not _cards.has(key):
		return
	selected_mode = key
	for k in _cards:
		var c: Dictionary = _cards[k]
		var on: bool = k == key
		for stn in ["normal", "hover", "pressed", "focus"]:
			var sb := _glass_style(24, Vector2.ZERO)
			if on:
				sb.bg_color = Color(c.col.darkened(0.72), 0.82)
				sb.border_color = c.col
				sb.set_border_width_all(2)
				sb.shadow_color = Color(c.col, 0.35)
				sb.shadow_size = 22
				sb.shadow_offset = Vector2(0, 6)
			if stn == "pressed":
				sb.bg_color = sb.bg_color.lightened(0.12)
			c.button.add_theme_stylebox_override(stn, sb)
		c.button.modulate = Color.WHITE if on else Color(1, 1, 1, 0.78)


func set_bests(normal: String, endless: String) -> void:
	if _cards.is_empty():
		return
	set_text(_cards.normal.best, "best_n", normal)
	set_text(_cards.endless.best, "best_e", endless)


## Bottom of the title screen: graphics mode toggle and, after an unexpected close, what
## the game was doing when it stopped, with a button to copy the full report.
func _build_device_row(m: Control) -> void:
	var col := _vbox(8)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.offset_bottom = -18
	m.add_child(col)
	_crash = _glass(16, Vector2(16, 10))
	_crash.custom_minimum_size.x = 760
	_crash.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_crash.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cv := _vbox(6)
	_crash.add_child(cv)
	cv.add_child(_caps("The game closed unexpectedly last time · safe graphics switched on, pick a mode to try again", 11, C_AMBER))
	_crash_txt = _label("", 12, 500, C_MUTED)
	_crash_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crash_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(_crash_txt)
	_crash.hide()
	col.add_child(_crash)
	var row := _hbox(8)
	col.add_child(row)
	var copy := _small_button("Copy crash report")
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(_crash_report)
		copy.text = "COPIED"
	)
	copy.visible = false
	_crash.visibility_changed.connect(func(): copy.visible = _crash.visible)
	row.add_child(copy)
	_btn_gfx = _small_button("")
	_btn_gfx.pressed.connect(func():
		Diag.set_safe(not Diag.safe)
		_update_gfx()
		safe_toggled.emit()
	)
	row.add_child(_btn_gfx)
	_update_gfx()
	var ver := _label("Build " + str(ProjectSettings.get_setting("application/config/version", "dev")), 11, 500, Color(C_MUTED, 0.6))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ver)


func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font(700, 1.5))
	b.add_theme_font_size_override("font_size", 12)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := _glass_style(999, Vector2(16, 8))
		if st == "pressed":
			sb.bg_color = sb.bg_color.lightened(0.15)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", C_TEXT)
	_small_buttons.append(b)
	return b


func _update_gfx() -> void:
	_btn_gfx.text = ("Graphics: safe" if Diag.safe else "Graphics: full").to_upper()


func show_crash_notice(summary: String, report: String) -> void:
	_crash_report = report
	_crash_txt.text = summary
	_crash.show()
	_update_gfx()


## Keeps the HUD clear of notches and rounded corners on phones.
func apply_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	var win := Vector2(DisplayServer.window_get_size())
	var sa := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0 or sa.size.x <= 0:
		return
	var k := get_viewport_rect().size.x / win.x
	_hud.offset_left = maxf(0.0, sa.position.x * k)
	_hud.offset_right = -maxf(0.0, (win.x - sa.end.x) * k)
	touch.set_safe_insets(_hud.offset_left, -_hud.offset_right)


func _build_over() -> Control:
	var m := _menu_bg(self)
	var v := _center_col(m, 18)
	var h := _label("Game Over", 58, 800)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var row := _hbox(10)
	v.add_child(row)
	var a := _stat("Score")
	row.add_child(a[0])
	_over_score = a[1]
	var b := _stat("Best")
	row.add_child(b[0])
	_over_best = b[1]
	_over_reached = _caps("", 12, C_SPORE)
	_over_reached.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_over_reached)
	_over_cta = _cta("Play again")
	v.add_child(_over_cta)
	_over_note = _caps("Continuing starts the world again with the score reset", 11)
	_over_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_over_note)
	_over_title = _small_button("Menu")
	_over_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_over_title.pressed.connect(func(): title_pressed.emit())
	v.add_child(_over_title)
	return m


func _build_end() -> Control:
	var m := _menu_bg(self)
	var v := _center_col(m, 18)
	var cap := _label("ALL SIX WORLDS CLEARED", 18, 700, C_AMBER, 6.0)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	var h := _grad_label("STAR BROKEN", 72, 800, 0, [C_AMBER, C_SPORE, C_VIOLET])
	var st := _stack(_halo("STAR BROKEN", 72, 800, C_AMBER), h)
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(st)
	var t := _label("The heart has gone dark. Moon, ice and iron fall quiet behind you.", 17, 500, C_MUTED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var row := _hbox(10)
	v.add_child(row)
	var a := _stat("Final score")
	row.add_child(a[0])
	_end_score = a[1]
	var b := _stat("Best")
	row.add_child(b[0])
	_end_best = b[1]
	v.add_child(_cta("Back to menu"))
	return m


func _build_pause() -> Control:
	var m := _menu_bg(self)
	var v := _center_col(m, 18)
	var h := _label("Paused", 58, 800)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	v.add_child(_cta("Resume"))
	var quit := _small_button("Quit to menu")
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func(): title_pressed.emit())
	v.add_child(quit)
	var kr := _keys([["Z", "Fire (hold for rapid)"], ["X", "Charge"], ["Space", "Pod"], ["M", "Mute"]], 900)
	kr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(kr)
	_key_rows.append(kr)
	return m


# ---------- API used by the game ----------

func set_touch_mode(on: bool) -> void:
	touch.enabled = on
	# on touch screens the touch layer starts modes itself (card_at), so the cards
	# don't also take the emulated mouse click
	for k in _cards:
		_cards[k].button.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
	for r in _key_rows:
		r.visible = not on
	for r in _touch_rows:
		r.visible = on
	_hints.visible = not on
	_charge.offset_bottom = -20 if on else -28


func set_menu(which: String) -> void:
	title_scr.visible = which == "title"
	over_scr.visible = which == "over"
	pause_scr.visible = which == "pause"
	end_scr.visible = which == "end"
	_hud.modulate.a = 0.0 if which == "title" or which == "over" or which == "end" else 1.0
	if which == "pause":
		_hud.modulate.a = 0.0


func set_text(l: Label, key: String, v: String) -> void:
	if _cache.get(key) != v:
		_cache[key] = v
		l.text = v


func update_hud(score: String, hi: String, laser: int, speed: int, n_lives: int, charge: float, lv: int) -> void:
	set_text(_score, "score", score)
	set_text(_laser, "laser", str(laser))
	set_text(_speed, "speed", str(speed))
	if n_lives != lives or not _cache.has("lives"):
		_cache["lives"] = true
		lives = n_lives
		var icons := lives if lives <= 4 else 1
		_lives_icon.custom_minimum_size = Vector2(icons * 22, 20)
		_lives_txt.text = "×%d" % lives if lives > 4 else ("Last ship" if lives == 0 else "")
		_lives_txt.visible = _lives_txt.text != ""
		_lives_icon.queue_redraw()
	# charge is 0..1 of the way to the Nova stage; violet to cyan, cyan to white at LV 3,
	# then pink to white once the Nova (stage 4) is ready
	var fm := _charge_fill.material as ShaderMaterial
	fm.set_shader_parameter("fill", charge)
	fm.set_shader_parameter("col_a", C_SPORE if lv >= 4 else (C_LANCE if lv == 3 else C_VIOLET))
	fm.set_shader_parameter("col_b", Color.WHITE if lv >= 3 else C_LANCE)
	set_text(_charge_lv, "clv", "NOVA" if lv >= 4 else ("LV %d" % lv if lv else ""))
	_charge_lv.modulate = Color(C_SPORE * 1.3, 1.0) if lv >= 4 else Color.WHITE
	set_hi(hi)


func set_hi(hi: String) -> void:
	set_text(_hi, "hi", hi)


func show_boss(on: bool, name := "") -> void:
	_boss.visible = on
	if name != "":
		_boss_name.text = name.to_upper()


func set_boss(pct: float) -> void:
	(_boss_fill.material as ShaderMaterial).set_shader_parameter("fill", pct / 100.0)
	set_text(_boss_pct, "bpct", "%d%%" % ceili(pct))


## `world` is the index of the world the run ended in: in Normal, past world 1 the main
## button continues from there. `lap` is the Endless lap reached (-1 in Normal), where the
## main button always starts a new run.
func set_over(score: String, best: String, world := 0, lap := -1) -> void:
	_over_score.text = score
	_over_best.text = best
	var cont := world > 0 and lap < 0
	_over_cta.text = ("Continue · World %d" % (world + 1) if cont else "Play again").to_upper()
	_over_note.visible = cont
	_over_reached.text = ("Endless · reached lap %d, world %d" % [lap + 1, world + 1]).to_upper() if lap >= 0 else ""
	_over_reached.visible = lap >= 0


func set_ending(score: String, best: String) -> void:
	_end_score.text = score
	_end_best.text = best


## Fades the screen to black (on) or back in (off).
func fade(on: bool) -> void:
	if _fade_tw:
		_fade_tw.kill()
	if not on and not _fade.visible:
		return
	_fade.show()
	_fade_tw = create_tween()
	_fade_tw.tween_property(_fade, "modulate:a", 1.0 if on else 0.0, 0.8 if on else 0.6)
	if not on:
		_fade_tw.tween_callback(_fade.hide)


func set_muted_icon(m: bool) -> void:
	muted = m
	_btn_mute.queue_redraw()


func banner(t: String, sub: String, warn := false) -> void:
	_banner_t.text = t.to_upper() if warn else t
	_banner_glow.text = _banner_t.text
	var col := C_SPORE if warn else C_LANCE
	_banner_glow.add_theme_color_override("font_outline_color", Color(col, 0.2))
	(_banner_t.material as ShaderMaterial).set_shader_parameter("c2", Color("ff8cc6") if warn else Color("a9f6ff"))
	_banner_s.text = sub.to_upper()
	_banner_s.visible = sub != ""
	_banner.show()
	if _banner_tw:
		_banner_tw.kill()
	_banner.modulate.a = 1.0
	_banner.pivot_offset = Vector2(640, 40)
	_banner_tw = create_tween()
	if warn:
		_banner.scale = Vector2.ONE
		_banner_tw.set_loops()
		_banner_tw.tween_property(_banner, "modulate:a", 0.4, 0.5).set_trans(Tween.TRANS_SINE)
		_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		_banner.scale = Vector2(0.6, 0.6)
		_banner.modulate.a = 0.0
		_banner_tw.set_parallel()
		_banner_tw.tween_property(_banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.25)


func hide_banner() -> void:
	if _banner_tw:
		_banner_tw.kill()
	_banner.hide()


func show_hints(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_hints, "modulate:a", 1.0 if on else 0.0, 0.8 if not on else 0.2)
	touch.show_zones(on)


## The mode card under a touch at `p` on the main menu, or "".
func card_at(p: Vector2) -> String:
	if not title_scr.visible:
		return ""
	for k in _cards:
		if _cards[k].button.get_global_rect().has_point(p):
			return k
	return ""


## True when a touch at `p` lands on one of the HUD buttons (so it must not fire the ship).
func blocks_touch(p: Vector2) -> bool:
	for b in [_btn_mute, _btn_pause] + _small_buttons:
		if b.is_visible_in_tree() and b.get_global_rect().grow(8).has_point(p):
			return true
	return false
