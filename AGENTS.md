# Notes for coding agents

Star Breaker is an original low poly 3D side-scrolling shooter in Godot 4.7, in the genre of
R-Type II but with all-original content: never use R-Type names, art, enemies or levels.
Guillaume wants a modern mobile-game look (glass HUD, bloom, Rubik font), not retro.
Controls (2026-11-13): one Fire action (tap = heavy shot, hold = rapid fire) and Charge; on touch
the right side is one vertical stack, bottom up: Fire, Charge, Pod (2026-11-14).

## Pull requests

- **Merging (rule from Guillaume, 2026-11-13):** agents may merge their own PRs into `main` as
  soon as CI is green (the **Headless test** and **Builds** workflows). Don't merge on red, and
  never skip or disable a test to get green.
- Every PR body lists its preview builds near the top, under a `## Preview` heading:

  ```
  ## Preview
  - Play in the browser: https://guillaumefont.github.io/star-breaker/pr/<N>/
  - Android APK: https://guillaumefont.github.io/star-breaker/pr/<N>/star-breaker.apk
  ```

  The **Builds** workflow publishes them on every push to the PR and deletes them when it
  closes. `main` is at https://guillaumefont.github.io/star-breaker/ (needs Settings > Pages >
  Source = GitHub Actions).
- All APKs share one app id (`io.github.guillaumefont.starbreaker`) and one test keystore
  (`.github/android/debug.keystore`), so a PR build installs over the `main` build.

## Keeping this file up to date

- When you learn something a future agent would need (a convention, a gotcha, a check to run),
  add it here in your PR. Keep entries short and lasting. Say what you added under an
  `## AGENTS.md` heading in the PR body and mention it in your reply to Guillaume.

## Tests

- Every change comes with a test of what it should do; a bug fix gets a regression test.
- A new test file gets a step in `.github/workflows/test.yml` and a line below.
- Test logic headlessly by calling `main.update()` / `main._process()` directly with physics and
  process turned off (see `tests/play_test.gd`); `main.warp(x)` jumps the stage forward.

## Checks to run before pushing

```
godot --headless --path . --import
godot --headless --path . --script tests/play_test.gd    # world 1: weapons, pod, enemies, gates, boss, world 2 starts, continue
godot --headless --path . --script tests/campaign_test.gd # worlds 2-4: enemies, tunnels, gates, walls, bosses, ending
godot --headless --path . --script tests/menu_test.gd     # main menu, Normal and Endless modes, bests, quit to menu
godot --headless --path . --script tests/touch_test.gd   # floating stick and invisible touch zones
godot --headless --path . --script tests/audio_test.gd   # songs build on the main thread, sound effects exist
godot --headless --path . --script tests/screen_test.gd  # crash report, safe graphics, wide and narrow screens
godot --headless --path . --script tests/update_test.gd  # self-update: pack download, checks, APK offer
godot --headless --path . --script tests/icon_test.gd    # project icon and Android launcher icon layers
```

Screenshots (needs a display, e.g. `xvfb-run -a`):
`godot --path . --rendering-method gl_compatibility --script tools/screenshots.gd -- /tmp/shots`
Close-ups of the player ship and pod (side, three-quarter, top, rear, pod launched):
`godot --path . --rendering-method gl_compatibility --script tools/ship_shots.gd -- /tmp/ship`
Hulls are lofted with `Geo.loft()` (cross-sections along X) and baked with `Geo.build_wound()`;
the pod model spins on its `spin` child around X, the root only turns it to face backwards.

## App icon

- Icon (Guillaume, 2026-11-14): same family as his Tether Rally and Aurite Front icons, a round
  cream-rimmed medal with a dark inside on a dusk scene (light beams from the top, planet rim and
  low poly ridges, sparks). Here the gunship flies out of the medal with its crystal pod.
- One source, `tools/icon.py` (Pillow): `python3 tools/icon.py` rewrites `icon.png` (project
  icon and web favicon), `icons/` (launcher icon and the adaptive background, foreground and
  monochrome layers) and `store/icon-512.png`. Commit the PNGs; CI doesn't run it.
- A launcher icon lives in the APK, not the game pack: a new icon only shows after installing
  a new APK.

## Self-update (Android)

- The main scene is `scenes/boot.tscn` (`scripts/boot.gd`): at launch it fetches `update.json`
  from Pages and, if a newer build was made for the same **shell**, downloads
  `star-breaker.pck` (the whole game, ~200 KB), checks its SHA-256 and loads it over the bundled
  game with `ProjectSettings.load_resource_pack()`. No reinstall needed.
- The shell id (set by CI) hashes what a pack can't change: Godot version, `project.godot`,
  `export_presets.cfg` and the updater (`boot.gd`, `boot.tscn`). Editing any of those makes
  the app offer a new APK download instead, so avoid needless changes to them.
- `boot.gd` must not use any game class (`Diag`, `Hud`, ...): touching one before the pack
  loads would keep the bundled version. Tests and tools load `scenes/main.tscn` directly.
- PR APKs follow `pr/N/update.json`, then main once the preview is gone.

## Main menu and modes

- The title screen is the main menu: two mode cards, **Normal** (the campaign, ends on the
  ending screen) and **Endless** (`G.mode == "endless"`: after world 4 it loops to world 1
  with `G.lap += 1`, never shows the ending). `diff()` adds 2 per lap; `bm()` is capped at 1.7.
- Each mode has its own best (`bests`, saved as `best` and `best_endless`); `hiscore` mirrors
  the mode being played. The last mode played is saved and preselected.
- Keyboard/gamepad move the selection (`hud.select_mode`), Enter/Fire plays it; on touch only a
  tap on a card starts (`hud.card_at`), other menus still take a tap anywhere.
- Menu screenshots: `xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 2400x1080 --script tools/menu_shots.gd -- /tmp/menu`

## Campaign (worlds)

- `scripts/worlds.gd` holds the four worlds: palette, terrain (cave noise plus tunnel sections),
  level script, boss and songs. Terrain heights come from `Worlds.heights(world, wx)`; a level
  script entry with `y < 0` spawns on the corridor centre line, so waves fit inside tunnels.
- Gates (`G.gates`) and breakable walls (`block` enemies) are solid: `in_wall()` covers rock and
  gate pillars. Free fliers (`FLYERS` in `main.gd`) are clamped inside the corridor.
- Bosses of worlds 2-4 share one parts system (`spawn_gboss` / `update_gboss`): each part has
  hp and a hit radius, `armour` parts deflect shots, the `core` part kills the boss. The Bloom
  Mother keeps its own code.
- Switching worlds only recolours shared materials and the environment (`apply_world`), so it
  builds no new GPU pipelines. New world materials go in `Models.M`; `_warm_up()` draws every
  entry of `Models.M` plus every model, so add new models there too.
- `Sfx.music()` always stops the player before swapping songs and logs a `MUSIC` breadcrumb, so
  a crash report shows which song change it died on.

## Gotchas

- Don't run GDScript on worker threads (`WorkerThreadPool`, `Thread`): song synthesis on a
  worker thread was the suspected cause of the Android build crashing seconds after start-up.
  Spread heavy work over frames on the main thread instead (see `scripts/audio.gd`).
- The Android build still crashed a few seconds into a run after that. It runs fine on desktop
  (debug and release templates, Mobile renderer), so the next suspects were Android-only paths:
  sounds now use a pool of `AudioStreamPlayer`s (no `AudioStreamPolyphonic`) and stars are
  MultiMesh quads (no GL point sprites). Keep it that way unless a phone test proves otherwise.
- Crash reports from phones: `scripts/diag.gd` writes breadcrumbs to `user://diag.log` (a TICK
  line every second, FIRST line for each new enemy/sound/effect). If the last session didn't end
  with SUSPEND or QUIT, the title screen shows where it stopped with a "Copy crash report" button,
  and safe graphics turn on (no glow/MSAA). Ask Guillaume for that report instead of guessing. Add `Diag.once()`
  breadcrumbs to new features.
- No looping `AudioStreamWAV` (`loop_mode`): the Android build crashed when the stage song first
  hit its loop point. Songs restart from the player's `finished` signal instead.
- Android uses the Compatibility (OpenGL ES) renderer: on Guillaume's Pixel (PowerVR GPU) the
  Vulkan Mobile renderer hitched each time a new kind of object appeared and then crashed. An
  `override.cfg` renderer switch was ignored there, so it is set in `project.godot`.
- `_warm_up()` in `main.gd` draws every model and material once behind the title screen; add any
  new model or material to it so its first appearance in a run doesn't hitch.
- The game fills any screen (stretch aspect `expand`). Wider than 16:9, `xm` in `main.gd` is the
  extra stage width visible on each side: spawn and culling positions must include it.
- `tools/soak.gd` plays in real time with simulated touches and no invincibility; use it to look
  for crashes: `godot --path . --script tools/soak.gd -- 40`.

- UI is built in code: use `set_anchors_and_offsets_preset()`; plain `set_anchors_preset()`
  keeps the old (zero) size.
- Simulated touches in headless tests must go through `root.push_input(event, true)`; headless
  window coordinates don't match the 1280x720 canvas.
- Game logic runs in stage units (224 x 126, y down) at a fixed 60 ticks per second; `X()` /
  `Y()` in `scripts/main.gd` map them to 3D.
- GDScript can't infer types from Dictionary fields: write `var k: float = d.x * 2`, not `:=`.
