# Notes for coding agents

Star Breaker is an original low poly 3D side-scrolling shooter in Godot 4.7, in the genre of
R-Type II but with all-original content: never use R-Type names, art, enemies or levels.
Guillaume wants a modern mobile-game look (glass HUD, bloom, Rubik font), not retro.

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
godot --headless --path . --script tests/play_test.gd    # full run: weapons, pod, enemies, boss, loop, game over
godot --headless --path . --script tests/touch_test.gd   # floating stick and invisible touch zones
```

Screenshots (needs a display, e.g. `xvfb-run -a`):
`godot --path . --rendering-method gl_compatibility --script tools/screenshots.gd -- /tmp/shots`

## Gotchas

- UI is built in code: use `set_anchors_and_offsets_preset()`; plain `set_anchors_preset()`
  keeps the old (zero) size.
- Simulated touches in headless tests must go through `root.push_input(event, true)`; headless
  window coordinates don't match the 1280x720 canvas.
- Game logic runs in stage units (224 x 126, y down) at a fixed 60 ticks per second; `X()` /
  `Y()` in `scripts/main.gd` map them to 3D.
- GDScript can't infer types from Dictionary fields: write `var k: float = d.x * 2`, not `:=`.
