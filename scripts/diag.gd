class_name Diag
extends RefCounted
## On-device crash report. Every session writes breadcrumbs to user://diag.log, flushed
## line by line. A session that ends cleanly or goes to the background writes a final
## SUSPEND or QUIT line; if the previous log ends any other way, the game closed
## unexpectedly. The title screen then shows the report (with a Copy button) and safe
## graphics are switched on.

const PATH := "user://diag.log"
const PREV := "user://diag_prev.log"
const SETTINGS := "user://settings.cfg"
## Read by the engine at start-up (application/config/project_settings_override).
const OVERRIDE := "user://override.cfg"

static var crashed := false
static var prev_lines := PackedStringArray()
static var safe := false
static var _f: FileAccess
static var _t0 := 0
static var _seen := {}


static func start() -> void:
	_t0 = Time.get_ticks_msec()
	if FileAccess.file_exists(PATH):
		var txt := FileAccess.get_file_as_string(PATH).strip_edges()
		prev_lines = txt.split("\n")
		var last := prev_lines[prev_lines.size() - 1] if prev_lines.size() > 0 else ""
		crashed = txt != "" and not (last.contains(" SUSPEND") or last.contains(" QUIT"))
		var pf := FileAccess.open(PREV, FileAccess.WRITE)
		if pf:
			pf.store_string(txt)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	safe = bool(cfg.get_value("graphics", "safe", false))
	if crashed and not safe:
		set_safe(true)
	_f = FileAccess.open(PATH, FileAccess.WRITE)
	note("START", "%s %s | %s | %s %s | %s | screen %s | safe=%s | prev_crashed=%s" % [
		OS.get_name(), OS.get_model_name(), ProjectSettings.get_setting("application/config/version", "dev"),
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_api_version(),
		RenderingServer.get_video_adapter_name(), DisplayServer.screen_get_size(), safe, crashed])


static func note(tag: String, msg := "") -> void:
	if _f == null:
		return
	_f.store_line("%7.2f %s %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, tag, msg])
	_f.flush()


## Logs `msg` only the first time `key` is seen this session.
static func once(key: String, msg := "") -> void:
	if _seen.has(key):
		return
	_seen[key] = true
	note("FIRST", key + (" " + msg if msg != "" else ""))


## Safe graphics: no bloom or MSAA now, and the Compatibility (OpenGL) renderer from the
## next launch on.
static func set_safe(on: bool) -> void:
	safe = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("graphics", "safe", on)
	cfg.save(SETTINGS)
	if on:
		var f := FileAccess.open(OVERRIDE, FileAccess.WRITE)
		if f:
			f.store_string('[rendering]\n\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n')
	elif FileAccess.file_exists(OVERRIDE):
		DirAccess.remove_absolute(OVERRIDE)


## Text to paste back to the developer: the previous session's log (last 60 lines).
static func report() -> String:
	var n := prev_lines.size()
	var tail := prev_lines.slice(maxi(0, n - 60))
	return "Star Breaker crash report\n" + "\n".join(tail)


## One line for the title screen: where the last session stopped.
static func summary() -> String:
	if prev_lines.is_empty():
		return ""
	var last := prev_lines[prev_lines.size() - 1]
	var firsts := []
	for l in prev_lines:
		if l.contains(" FIRST "):
			firsts.append(l.get_slice(" FIRST ", 1))
	var after: String = firsts[firsts.size() - 1] if firsts.size() > 0 else "start-up"
	return "Last line: %s  ·  last new thing: %s" % [last.strip_edges(), after]
