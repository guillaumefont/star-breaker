extends SceneTree
## App icons (made by tools/icon.py): the project icon (also the web favicon) and every
## Android launcher icon in export_presets.cfg exist at the right size, the adaptive
## foreground keeps its corners clear (the emblem sits in the safe zone), the background
## is opaque and the monochrome layer is a plain white silhouette.

var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func _png(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _initialize() -> void:
	print("Star Breaker icon test")
	var icon_path: String = ProjectSettings.get_setting("application/config/icon")
	check(icon_path == "res://icon.png", "project icon is icon.png")
	var icon := _png(icon_path)
	check(icon != null and icon.get_size() == Vector2i(256, 256), "project icon is 256 px")
	if icon:
		check(icon.get_pixel(0, 0).a < 0.1, "project icon has rounded corners")
		check(icon.get_pixel(128, 128).a > 0.99, "project icon is opaque in the middle")

	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export presets load")
	var want := {
		"launcher_icons/main_192x192": 192,
		"launcher_icons/adaptive_foreground_432x432": 432,
		"launcher_icons/adaptive_background_432x432": 432,
		"launcher_icons/adaptive_monochrome_432x432": 432,
	}
	var imgs := {}
	for key: String in want:
		var path: String = cfg.get_value("preset.0.options", key, "")
		var img := _png(path) if path != "" else null
		var size: int = want[key]
		check(img != null and img.get_size() == Vector2i(size, size), "%s is a %d px image (%s)" % [key, size, path])
		imgs[key] = img

	var fg: Image = imgs["launcher_icons/adaptive_foreground_432x432"]
	if fg:
		var clear := true
		for p: Vector2i in [Vector2i(10, 10), Vector2i(421, 10), Vector2i(10, 421), Vector2i(421, 421), Vector2i(216, 20), Vector2i(216, 412)]:
			clear = clear and fg.get_pixelv(p).a < 0.05
		check(clear, "adaptive foreground leaves the outer edge clear")
		check(fg.get_pixel(216, 216).a > 0.99, "adaptive foreground has the emblem in the middle")
	var bg: Image = imgs["launcher_icons/adaptive_background_432x432"]
	if bg:
		check(not bg.detect_alpha(), "adaptive background is fully opaque")
	var mono: Image = imgs["launcher_icons/adaptive_monochrome_432x432"]
	if mono:
		var white := true
		for y in range(0, 432, 8):
			for x in range(0, 432, 8):
				var c := mono.get_pixel(x, y)
				if c.a > 0.5 and (c.r < 0.95 or c.g < 0.95 or c.b < 0.95):
					white = false
		check(white, "monochrome layer is a white silhouette")
		check(mono.get_pixel(216, 216).a > 0.99, "monochrome layer covers the emblem")
	print("FAILED %d" % fails if fails else "ALL PASSED")
	quit(1 if fails else 0)
