extends SceneTree
## Main menu and game modes: picking Normal or Endless by keyboard, gamepad or click, Endless
## looping the four worlds with rising difficulty, its own best score, game over and quitting
## from pause back to the menu.

var main: Node3D
var fails := 0


func check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		fails += 1


func tick(n := 1, god := true) -> void:
	for i in n:
		if god and not main.P.is_empty():
			main.P.inv = maxi(main.P.inv, 2)
		main.update()
		main._process(1.0 / 60.0)


func press(a: String) -> void:
	main.latch[a] = true


## Beats the current world's boss straight away and waits for the next world to start.
func clear_world() -> void:
	main.G.clear_t = 1
	var t := 0
	var w: int = main.G.world
	var lap: int = main.G.lap
	while t < 500 and main.mode == "play" and main.G.world == w and main.G.lap == lap:
		t += 1
		tick()


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.cfg"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await process_frame
	print("Menu and modes test")
	var hud: Hud = main.hud
	check(main.mode == "title" and hud.title_scr.visible, "starts on the main menu")
	check(hud._cards.has("normal") and hud._cards.has("endless"), "menu offers Normal and Endless")
	check(hud.selected_mode == "normal", "Normal is picked by default")
	check(hud._btn_gfx.is_visible_in_tree() and hud._crash != null, "graphics toggle and crash notice stay on the menu")

	# keyboard / gamepad: right picks Endless, left back to Normal
	press("right")
	tick(1, false)
	check(hud.selected_mode == "endless", "Right picks Endless")
	tick(1, false)
	press("left")
	tick(1, false)
	check(hud.selected_mode == "normal", "Left picks Normal")
	tick(1, false)
	press("down")
	tick(1, false)
	check(hud.selected_mode == "endless", "Down picks Endless (gamepad stick)")
	tick(1, false)
	press("fire")
	tick(1, false)
	check(main.mode == "play" and main.endless() and main.G.world == 0 and main.G.lap == 0, "Fire starts the picked mode (Endless)")
	check(main.hud._banner_s.text.contains("LAP 1"), "Endless banner shows the lap (%s)" % main.hud._banner_s.text)

	# Endless loops the worlds and gets harder
	var d0: float = main.diff()
	for wi in 4:
		clear_world()
	check(main.mode == "play" and main.G.world == 0 and main.G.lap == 1, "after world 4 Endless loops back to world 1, lap 2 (no ending)")
	check(main.diff() > d0 + 1.5 and main.bm() > 1.1, "lap 2 is tougher (diff %.1f)" % main.diff())
	check(main.hud._banner_s.text.contains("LAP 2"), "banner announces lap 2")
	var probe: Dictionary = main.E("drifter", 100, 60)
	var hp: float = probe.hp
	main.G.enemies.erase(probe)
	probe.m.queue_free()
	check(hp >= 2, "enemies have more hit points on lap 2 (%d)" % hp)
	main.G.lap = 20
	check(main.bm() <= 1.7, "bullet speed is capped on late laps")
	main.G.lap = 1

	# its own best score
	main.add_score(50000)
	main.G.lives = 0
	main.P.inv = 0
	main.kill_player()
	tick(130, false)
	check(main.mode == "over", "losing the last ship ends the Endless run")
	check(hud._over_reached.visible and hud._over_reached.text.contains("LAP 2"), "game over shows the lap reached")
	check(hud._over_cta.text == "PLAY AGAIN", "Endless offers Play again, not Continue")
	check(main.bests.endless >= 50000 and main.bests.normal == 0, "Endless keeps its own best score")
	var cfg := ConfigFile.new()
	cfg.load("user://save.cfg")
	check(int(cfg.get_value("game", "best_endless", 0)) >= 50000 and str(cfg.get_value("game", "mode", "")) == "endless", "best and last mode are saved")
	tick(60, false)
	press("start")
	tick(1, false)
	check(main.mode == "play" and main.endless() and main.G.world == 0 and main.G.lap == 0 and main.G.score == 0, "Play again restarts Endless from lap 1")

	# pause -> quit to menu
	tick(10)
	press("start")
	tick(1)
	check(main.paused and hud.pause_scr.visible, "Esc pauses")
	hud.title_pressed.emit()
	tick(1)
	check(main.mode == "title" and hud.title_scr.visible and not main.paused, "Quit to menu from pause")
	check(hud.selected_mode == "endless", "the menu remembers the last mode")
	check(hud._cards.endless.best.text != "0", "Endless card shows its best")

	# clicking a card starts that mode
	hud._cards.normal.button.pressed.emit()
	tick(1)
	check(main.mode == "play" and not main.endless(), "clicking Normal starts a campaign run")
	check(main.hiscore == main.bests.normal, "HUD best follows the mode played")

	# Normal game over in world 1: Play again and a Menu button
	main.G.lives = 0
	main.P.inv = 0
	main.kill_player()
	tick(190, false)
	check(hud._over_title.visible and not hud._over_reached.visible, "Normal game over has a Menu button")
	hud.title_pressed.emit()
	tick(1, false)
	check(main.mode == "title", "Menu goes back to the main menu")

	# a fresh launch preselects the last mode played
	var m2: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(m2)
	await process_frame
	check(m2.hud.selected_mode == "normal" and m2.bests.endless >= 50000, "a new launch reads bests and last mode")
	m2.queue_free()

	print("%d failure(s)" % fails)
	quit(1 if fails else 0)
