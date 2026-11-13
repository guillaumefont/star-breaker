extends SceneTree
## Writes the Android launcher icons from icon.svg.
## godot --headless --path . --script tools/gen_icons.gd

const BG := '<rect width="256" height="256" fill="url(#bg)"/>'


func _initialize() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	_save(svg, 192, "res://icons/icon-192.png")
	var defs := svg.substr(svg.find("<defs>"), svg.find("</defs>") + 7 - svg.find("<defs>"))
	var head := '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">'
	_save(head + defs + BG + "</svg>", 432, "res://icons/adaptive-background-432.png")
	# foreground: artwork without the tile, shrunk into the adaptive-icon safe zone
	var art := svg.substr(svg.find("</defs>") + 7).replace("</svg>", "")
	art = art.substr(art.find("/>") + 2)
	_save(head + defs + '<g transform="translate(128 128) scale(.62) translate(-128 -128)">' + art + "</g></svg>", 432, "res://icons/adaptive-foreground-432.png")
	quit()


func _save(svg: String, size: int, path: String) -> void:
	var img := Image.new()
	img.load_svg_from_string(svg, size / 256.0)
	img.save_png(path)
	print("wrote ", path)
