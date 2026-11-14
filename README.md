# Star Breaker

**[▶ Play in the browser](https://guillaumefont.github.io/star-breaker/)** · **[⬇ Download the Android APK](https://guillaumefont.github.io/star-breaker/star-breaker.apk)**

<sub>Latest build of `main`, updated on every merge.</sub>

An original low poly 3D horizontal side-scrolling shooter, built with **Godot 4.7**.
Fly through four worlds, each with its own enemies, tunnels, gates and boss, to the heart of a
dying star.

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
| Fire (tap: heavy shot, hold: rapid fire) | Z | A | **Fire** zone (bottom right): tap, or hold for rapid fire |
| Charge beam | X or C (hold, release) | B, X | Hold the **Charge** zone (middle right), release to fire |
| Pod launch / recall | Space | Y, RB | Tap the **Pod** zone (top right) |
| Pause | Esc / Enter | Start | Pause button, Android back |
| Mute | M | | Speaker button |

There are no visible touch buttons. The right side is one stack, bottom up: Fire, Charge, Pod. A faint map of the zones shows for the first 8 seconds of a run.

## Game

- **Weapons:** one Fire button (a tap shoots a heavy shot, holding it streams rapid fire) and a charge beam with three levels that pierces
  everything in its path.
- **Pod:** collect a **P** carrier drop to get the pod. It docks to the front or back of the
  ship (whichever side it touches), blocks bullets, rams enemies, and fires with you. Launch it
  across the screen and recall it at will.
- **Items:** **P** pod, **L** laser (twin, then spread), **S** speed.
- **Campaign:** four worlds played in a row, each ending with a boss, then the ending. Item
  carriers drop P, L and S in every world.

  | World | Terrain | Enemies | Boss |
  | --- | --- | --- | --- |
  | 1 · The Hollow Moon | crystal cave, then a winding tunnel with fixed and sliding gates | spore drifters, cave turrets, hoppers, shell beasts | **Bloom Mother:** break four petals and the tentacle, then shoot the eye while it is open |
  | 2 · Frost Rift | low icy ceiling, two tunnels with sliding gates and ice walls to shoot through | crystal darts that stop, aim and lunge, falling icicles, spinning flakes, ice hulks | **Prism Warden:** two prisms fire aimed streams and shield the core; then the core spins spirals |
  | 3 · Iron Foundry | long tunnels with wall pistons, furnace shutters that open and close, walls | drone squadrons, floor crawlers, gun emplacements | **Furnace Titan:** the furnace hatch opens on a cycle; destroy the two cannons to keep it open longer |
  | 4 · Star Core | molten caves and the narrowest tunnels, every kind of gate | embers that arc up from below, homing seekers, gold sentinels, plus creatures from the earlier worlds | **Star Heart:** eight orbiting nodes shield it; then it chases you with spirals and seekers |

- **Gates and walls:** gates are solid pillars with one opening (fixed, sliding up and down, or
  shutters that open and close); breakable walls block the corridor until you shoot through.
  Rock, gates and walls destroy the ship.
- **Game over:** after world 1, *Continue* restarts the world you reached with the score reset.
- Extra ship at 20,000 points, then every 30,000.

## Project layout

| Path | What it holds |
| --- | --- |
| `scenes/main.tscn` | Root scene (everything else is built in code) |
| `scripts/main.gd` | Game loop: fixed 60 Hz logic on a 224 x 126 playfield, enemies, gates, bosses, scoring, world flow |
| `scripts/worlds.gd` | The four worlds: palettes, terrain (caves and tunnels), level scripts, boss and song per world |
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
