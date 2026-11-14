extends SceneTree
## Self-update (scripts/boot.gd): a newer game pack for this APK shell is downloaded,
## checked and loaded; a bad download is refused; a build that needs a new shell offers
## the APK; offline starts the game as it is. update.json and the pack are served by a
## tiny HTTP server inside this test.

const Boot := preload("res://scripts/boot.gd")

var fails := 0
var server := TCPServer.new()
var files := {}   # path -> PackedByteArray
var hits := []
var pending := []   # [connection, request so far]
var closing := []


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func clean() -> void:
	for f in [Boot.PACK, Boot.META]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


## A game pack holding one new file, as CI's --export-pack would hold the whole game.
func make_pack(text: String) -> PackedByteArray:
	var src := "user://probe_src.txt"
	var f := FileAccess.open(src, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var out := "user://probe.pck"
	var p := PCKPacker.new()
	p.pck_start(out)
	p.add_file("res://update_probe.txt", src)
	p.flush()
	return FileAccess.get_file_as_bytes(out)


func manifest(build: int, shell: String, pck: PackedByteArray) -> Dictionary:
	return {"build": build, "id": "b%d test" % build, "shell": shell, "pck": "star-breaker.pck",
		"size": pck.size(), "sha256": Boot.sha256(pck), "apk": "star-breaker.apk"}


## Non-blocking: HTTPRequest runs on this same thread, so requests arrive over frames.
func serve() -> void:
	while server.is_connection_available():
		pending.append([server.take_connection(), ""])
	for p in pending.duplicate():
		var c: StreamPeerTCP = p[0]
		c.poll()
		if c.get_available_bytes() > 0:
			p[1] += c.get_utf8_string(c.get_available_bytes())
		if not p[1].contains("\r\n\r\n"):
			continue
		pending.erase(p)
		var path: String = p[1].get_slice(" ", 1).get_slice("?", 0)
		hits.append(path)
		var body: PackedByteArray = files.get(path, PackedByteArray())
		var head := "HTTP/1.1 %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [
			"200 OK" if files.has(path) else "404 Not Found", body.size()]
		c.put_data(head.to_utf8_buffer())
		c.put_data(body)
		closing.append(c)


## Runs the boot screen against `url` until it decides, without leaving for the game.
func run_boot(url: String, build: int, shell: String, fallback := "") -> Node:
	var b: Node = load("res://scenes/boot.tscn").instantiate()
	b.base_url = url
	b.fallback_url = fallback
	b.own_build = build
	b.own_shell = shell
	b.go_to_main = false
	root.add_child(b)
	for i in 600:
		serve()
		await process_frame
		if b.status != "":
			break
	return b


func _initialize() -> void:
	print("Star Breaker self-update test")
	clean()
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/boot.tscn",
		"the update check runs first (main scene)")
	var src := FileAccess.get_file_as_string("res://scripts/boot.gd")
	var game_classes := RegEx.create_from_string("\\b(Diag|Hud|Sfx|Models|Geo|TouchPad)\\.")
	check(game_classes.search(src) == null, "boot.gd uses no game class (it would keep the bundled one)")
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	check(presets.get_value("preset.0.options", "permissions/internet", false) == true, "the Android build may use the network")

	# decisions
	var m := {"build": 12, "shell": "s1", "sha256": "x"}
	check(Boot.decide(m, 10, "s1") == "pack", "newer build, same shell: download the pack")
	check(Boot.decide(m, 12, "s1") == "none", "same build: nothing to do")
	check(Boot.decide(m, 15, "s1") == "none", "never goes back to an older build")
	check(Boot.decide(m, 10, "s2") == "apk", "newer build for another shell: offer the APK")
	check(Boot.decide(m, 10, "") == "none", "local builds (no shell id) never update")

	check(server.listen(0, "127.0.0.1") == OK, "test server listening")
	var url := "http://127.0.0.1:%d/" % server.get_local_port()

	# a bad download is refused and nothing is installed
	var pck := make_pack("hello from build 12")
	var bad := pck.duplicate()
	bad[bad.size() - 1] ^= 0xff
	files["/update.json"] = JSON.stringify(manifest(12, "s1", pck)).to_utf8_buffer()
	files["/star-breaker.pck"] = bad
	var b := await run_boot(url, 10, "s1")
	check(b.status.begins_with("pack download failed"), "a corrupted pack is refused: " + b.status)
	check(Boot.installed(10, "s1").is_empty(), "nothing installed after a bad download")
	b.queue_free()

	# offline: the game starts as it is
	b = await run_boot("http://127.0.0.1:1/", 10, "s1")
	check(b.status == "offline", "offline starts the game: " + b.status)
	b.queue_free()

	# a PR build whose preview is gone follows main
	files["/star-breaker.pck"] = pck
	b = await run_boot(url + "pr/9/", 10, "s1", url)
	check(hits.has("/pr/9/update.json") and b.status.begins_with("updated to b12 test"), "falls back to main when the PR preview is gone: " + b.status)
	check(not Boot.installed(10, "s1").is_empty(), "the pack is installed")
	check(b.status.ends_with("running pack b12 test"), "and loaded at once")
	check(FileAccess.get_file_as_string("res://update_probe.txt") == "hello from build 12", "the pack's files replace the bundled game")
	check(ProjectSettings.get_setting("application/config/version") == "b12 test", "the title screen shows the pack's build id")
	b.queue_free()

	# up to date: no download
	hits.clear()
	b = await run_boot(url, 10, "s1")
	check(b.status.begins_with("up to date") and not hits.has("/star-breaker.pck"), "already installed: no download: " + b.status)
	b.queue_free()

	# a new APK that is newer than the pack drops it
	check(Boot.installed(12, "s1").is_empty() and Boot.installed(10, "s2").is_empty(),
		"an installed pack is ignored by a newer APK or another shell")

	# needs a new shell: offer the APK, with a cache-busting link
	files["/update.json"] = JSON.stringify(manifest(14, "s2", pck)).to_utf8_buffer()
	b = await run_boot(url, 10, "s1")
	check(b.status == "apk needed", "a new shell asks to install the new APK: " + b.status)
	check(b.apk_url == url + "star-breaker.apk?b=14", "APK link skips cached downloads: " + b.apk_url)
	b._skip_apk()
	check(b.status.begins_with("apk skipped"), "can still play the current version")
	b.queue_free()

	server.stop()
	clean()
	print("update test: ", "PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
