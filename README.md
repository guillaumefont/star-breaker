# Star Breaker

**[▶ Play in the browser](https://guillaumefont.github.io/star-breaker/)** · **[⬇ Download the Android APK](https://guillaumefont.github.io/star-breaker/star-breaker.apk)**

<sub>Latest build of `main`, updated on every merge.</sub>

An original low poly 3D horizontal side-scrolling shooter, built with **Godot 4.7**.
The moon is blooming: fly into the crystal cavern of *The Hollow Moon* and cut the Bloom Mother back.

Every model, sound and song is generated from code (no imported meshes or audio files), and all
names, art and levels are original.

## Play

- **Browser:** every push to `main` is published on GitHub Pages
  (`https://guillaumefont.github.io/star-breaker/`), with the Android APK next to it
  (`star-breaker.apk`). Each pull request gets its own preview under `/pr/<number>/`, linked in a
  comment on the PR.
- **Godot:** open `project.godot` in Godot 4.7 and press Play.

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | Arrows / WASD | Left stick, D-pad | Left half: floating stick that appears under your thumb and follows it |
| Fire (tap: heavy shot, hold: rapid fire) | Z | A | **Fire** zone (bottom right, right column): tap, or hold for rapid fire |
| Charge beam | X or C (hold, release) | B, X | Hold the **Charge** zone (bottom right, left column), release to fire |
| Pod launch / recall | Space | Y, RB | Tap the **Pod** strip (top right) |
| Pause | Esc / Enter | Start | Pause button, Android back |
| Mute | M | | Speaker button |

There are no visible touch buttons: a faint map of the zones shows for the first 8 seconds of a run.

## Game

- **Weapons:** one Fire button (a tap shoots a heavy shot, holding it streams rapid fire) and a charge beam with three levels that pierces
  everything in its path.
- **Pod:** collect a **P** carrier drop to get the pod. It docks to the front or back of the
  ship (whichever side it touches), blocks bullets, rams enemies, and fires with you. Launch it
  across the screen and recall it at will.
- **Items:** **P** pod, **L** laser (twin, then spread), **S** speed.
- **Enemies:** spore drifters, cave turrets, hoppers, item carriers, armoured shell beasts.
- **Boss, Bloom Mother:** destroy its four petals and its tentacle, then shoot the eye while it
  is open. Clearing the stage loops it with faster, tougher enemies.
- Extra ship at 20,000 points, then every 30,000.

## Project layout

| Path | What it holds |
| --- | --- |
| `scenes/main.tscn` | Root scene (everything else is built in code) |
| `scripts/main.gd` | Game loop: fixed 60 Hz logic on a 224 x 126 playfield, stage script, enemies, boss, scoring |
| `scripts/models.gd` | Materials and low poly models |
| `scripts/geo.gd` | Flat-shaded mesh builders (polyhedra, prisms, cones, terrain) |
| `scripts/hud.gd` | Glass HUD, banners, title / pause / game over menus |
| `scripts/touch.gd` | Floating stick and invisible touch zones |
| `scripts/audio.gd` | Chiptune synth: sound effects and songs rendered at start-up |
| `shaders/` | Sky gradient, gradient text, rounded progress bars |
| `tests/` | Headless tests run in CI |
| `AGENTS.md` | Notes and rules for coding agents |
| `tools/` | Icon generator, screenshot script |

## Tests

```sh
godot --headless --path . --import
godot --headless --path . --script tests/play_test.gd    # full run: stage, pod, beam, boss, loop, game over
godot --headless --path . --script tests/touch_test.gd   # floating stick and touch zones
godot --headless --path . --script tests/audio_test.gd   # songs build on the main thread, all sound effects exist
godot --headless --path . --script tests/screen_test.gd  # crash report, safe graphics, wide and narrow screens
```

Screenshots (needs a display, e.g. `xvfb-run`):

```sh
godot --path . --rendering-method gl_compatibility --script tools/screenshots.gd -- /tmp/shots
```

## CI and builds

- `.github/workflows/test.yml` runs the headless tests on every pull request and on `main`.
- `.github/workflows/build.yml` exports Web and Android (release template, arm64) for `main` and
  every pull request, uploads the APK as a run artifact, and publishes both to the `gh-pages`
  branch; `pages.yml` deploys that branch. A closed PR's preview is deleted.
- Every APK is signed with the fixed test keystore in `.github/android/debug.keystore` (or the
  `ANDROID_DEBUG_KEYSTORE_BASE64` secret), so a new build installs over the previous one.
  `versionCode` is `100 + run number`, so it always goes up.
- One-time setup: **Settings > Pages > Source = GitHub Actions**.

## Licences

Code: see `LICENSE`. Rubik font (`assets/fonts/`) by the Rubik Project Authors, SIL Open Font
License 1.1 (`assets/fonts/OFL.txt`).
