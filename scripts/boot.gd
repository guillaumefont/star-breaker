extends Control
## Self-update, run before anything else on Android (the project's main scene).
##
## The APK is a shell: engine, manifest and project settings. Everything else (scripts,
## scenes, sounds) is a game pack that CI also publishes next to the APK, with update.json:
##   {"build": 130, "id": "b130 abc1234", "shell": "<hash>", "pck": "star-breaker.pck",
##    "size": 202644, "sha256": "...", "apk": "star-breaker.apk"}
## At launch we fetch update.json. A newer pack built for this same shell is downloaded,
## checked and loaded over the bundled game (no reinstall). A newer build that needs a new
## shell (engine, manifest or project settings changed) offers to download the new APK.
## Offline or on any error the game starts as it is: the last good pack, or the bundled one.
##
## Must not reference any game class (Diag, Hud, ...): loading one here would keep the
## bundled version of it instead of the updated one.

const DIR := "user://update/"
const PACK := DIR + "game.pck"
const META := DIR + "current.json"
const MAIN := "res://scenes/main.tscn"
const CHECK_TIMEOUT := 5.0
const PACK_TIMEOUT := 60.0

## Overridden by tests.
var base_url: String = ProjectSettings.get_setting("star_breaker/update_url", "")
var fallback_url: String = ProjectSettings.get_setting("star_breaker/update_fallback_url", "")
var own_build: int = ProjectSettings.get_setting("star_breaker/build", 0)
var own_shell: String = ProjectSettings.get_setting("star_breaker/shell", "")
var go_to_main := true

var apk_url := ""
var status := ""            # what happened, for tests and the crash report
var _label: Label
var _http: HTTPRequest


## What to do with a remote update.json: "pack" (download the game pack), "apk" (a new
## APK is needed) or "none". `have` is the newest build already running or installed.
static func decide(remote: Dictionary, have: int, shell: String) -> String:
	var b := int(remote.get("build", 0))
	if b <= have or shell == "":
		return "none"
	if str(remote.get("shell", "")) == shell and str(remote.get("sha256", "")) != "":
		return "pack"
	return "apk"


## The installed pack's metadata if it is usable by this APK, else {}.
static func installed(build: int, shell: String) -> Dictionary:
	if not FileAccess.file_exists(META) or not FileAccess.file_exists(PACK):
		return {}
	var m = JSON.parse_string(FileAccess.get_file_as_string(META))
	if not (m is Dictionary) or str(m.get("shell", "")) != shell or int(m.get("build", 0)) <= build:
		return {}
	return m


static func sha256(data: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(data)
	return h.finish().hex_encode()


## Checks and stores a downloaded pack; returns false (and keeps the old one) if it is bad.
static func install(remote: Dictionary, data: PackedByteArray) -> bool:
	if data.size() != int(remote.get("size", -1)) or sha256(data) != str(remote.get("sha256", "")):
		return false
	DirAccess.make_dir_recursive_absolute(DIR)
	var tmp := PACK + ".part"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(data)
	f.close()
	if DirAccess.rename_absolute(tmp, PACK) != OK:
		return false
	var m := FileAccess.open(META, FileAccess.WRITE)
	if m == null:
		return false
	m.store_string(JSON.stringify(remote))
	m.close()
	return true


## Loads the installed pack over the bundled game. Returns the build id it brings, or "".
static func apply(build: int, shell: String) -> String:
	var m := installed(build, shell)
	if m.is_empty():
		return ""
	var data := FileAccess.get_file_as_bytes(PACK)
	if sha256(data) != str(m.get("sha256", "")) or not ProjectSettings.load_resource_pack(PACK):
		DirAccess.remove_absolute(META)
		return ""
	var id := str(m.get("id", "b%d" % int(m.get("build", 0))))
	ProjectSettings.set_setting("application/config/version", id)
	return id


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 28)
	add_child(_label)
	_http = HTTPRequest.new()
	add_child(_http)
	if base_url == "" or OS.has_feature("web"):
		_start("no update url")
		return
	# say something only if the check is slow
	get_tree().create_timer(0.6).timeout.connect(_slow_check)
	var remote := await _fetch_json(base_url)
	if remote.is_empty() and fallback_url != "" and fallback_url != base_url:
		remote = await _fetch_json(fallback_url)  # a PR build whose preview is gone follows main
	if remote.is_empty():
		_start("offline")
		return
	var have: int = maxi(own_build, int(installed(own_build, own_shell).get("build", 0)))
	match decide(remote, have, own_shell):
		"pack":
			_label.text = "Updating to build %d…" % int(remote.build)
			var data := await _fetch(str(remote._base) + str(remote.pck) + "?sha=" + str(remote.sha256).left(12), PACK_TIMEOUT)
			_start("updated to %s" % remote.get("id", "") if install(remote, data) else "pack download failed")
		"apk":
			_offer_apk(remote)
		_:
			_start("up to date")


func _start(why: String) -> void:
	var id := apply(own_build, own_shell)
	status = why + (" | running pack " + id if id != "" else "")
	ProjectSettings.set_setting("star_breaker/update_status", status)
	print("update: ", status)
	if go_to_main:
		get_tree().change_scene_to_file.call_deferred(MAIN)


func _offer_apk(remote: Dictionary) -> void:
	status = "apk needed"
	_label.text = "Build %d needs a new install of the app.\n" % int(remote.build)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 220
	_label.offset_bottom = 320
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 40)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 360
	box.offset_bottom = -180
	add_child(box)
	apk_url = str(remote._base) + str(remote.get("apk", "star-breaker.apk")) + "?b=" + str(int(remote.build))
	for b in [["Download update", _download_apk], ["Play this version", _skip_apk]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(320, 90)
		btn.add_theme_font_size_override("font_size", 28)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.35, 0.8, 1.0, 0.35 if st == "pressed" else 0.18)
			sb.border_color = Color(0.35, 0.8, 1.0, 0.6)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(24)
			btn.add_theme_stylebox_override(st, sb)
		btn.pressed.connect(b[1])
		box.add_child(btn)


func _slow_check() -> void:
	if _label.text == "":
		_label.text = "Checking for updates…"


## Opens the browser on the new APK; the cache-busting ?b= stops a stale download.
func _download_apk() -> void:
	OS.shell_open(apk_url)


func _skip_apk() -> void:
	for c in get_children():
		if c is HBoxContainer:
			c.queue_free()
	_label.text = ""
	_start("apk skipped")


func _fetch(url: String, timeout: float) -> PackedByteArray:
	_http.timeout = timeout
	if _http.request(url) != OK:
		return PackedByteArray()
	var r: Array = await _http.request_completed
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		return PackedByteArray()
	return r[3]


## update.json from `base` (cache-busted), with `_base` added; {} on any failure.
func _fetch_json(base: String) -> Dictionary:
	var body := await _fetch(base + "update.json?t=%d" % int(Time.get_unix_time_from_system()), CHECK_TIMEOUT)
	var d = JSON.parse_string(body.get_string_from_utf8()) if body.size() > 0 else null
	if not (d is Dictionary) or not d.has("build"):
		return {}
	d["_base"] = base
	return d
