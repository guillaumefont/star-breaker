extends SceneTree
## Regression ("crash a few seconds after start-up" on Android): the songs used to be
## synthesised on a worker thread. They are now built a few notes per frame on the main
## thread; check that both songs finish, that no frame spends long on it, and that music plays.

var fails := 0


func check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		fails += 1


func _initialize() -> void:
	var sfx := Sfx.new()
	root.add_child(sfx)
	await process_frame
	print("Audio test")
	check(not sfx.songs_ready(), "songs are queued, not built up front")
	sfx.music("stage")
	var frames := 0
	var worst := 0
	while not sfx.songs_ready() and frames < 2000:
		var t0 := Time.get_ticks_usec()
		await process_frame
		worst = maxi(worst, Time.get_ticks_usec() - t0)
		frames += 1
	check(sfx.songs_ready(), "both songs finish building (%d frames)" % frames)
	check(worst < 60000, "no frame stalls on synthesis (worst %d us)" % worst)
	check(sfx._songs.has("stage") and sfx._songs.has("boss"), "stage and boss songs exist")
	check(sfx._music.stream == sfx._songs.get("stage"), "music asked for early starts once it is ready")
	for k in ["shot", "rapid", "beam1", "beam3", "boom", "pod", "dock", "alarm", "oneup"]:
		check(sfx._fx.has(k), "sound effect %s" % k)
	print("%d failure(s)" % fails)
	quit(1 if fails else 0)
