# Browser validation

The release gate runs 16 headless and 5 software-rendered Godot checks, followed
by 28 Chromium browser tests: 17 documentation/gallery cases, 6 game/display/music
cases, 3 combat cases and 2 SFX cases. Test inventory is distinct from a completed run; use
the retained CI results for pass/fail evidence.

The September 10, 2026 local native run passed all 21 checks, including 182 SFX
and 281 combat-model assertions. Both focused Chromium SFX cases passed in
22.4 seconds: decoded SFX peak 0.2271, at most three active voices, music retained
and silence after channel release. The other 26 cases passed in 3.6 minutes,
completing 28/28 Chromium cases against fresh production and private probe
exports. This evidence does not imply subjective listening approval.

Use Node 22+ and the exact dependency lockfile. Install browsers with
`npx playwright install --with-deps chromium` in Linux CI. Firefox is an explicit
additional lane: install it and set `ARENIC_WEB_FIREFOX=1`; a Chromium pass is not
a claim about Firefox, Safari, mobile browsers, or hardware performance.

The build prepares a clean production export and a separate QA export. To add
the test autoload to a **fresh isolated project**, run:

```sh
node tests/web/prepare-probe.mjs --source /path/to/clean-project --destination .tmp/web-probe-project
```

The caller owns the pinned Godot import/export commands and removal of editor
addons from its clean snapshot. Export this probe project into a private
`__probe__/` directory. Production `play/` must contain no `__ci__` scripts,
`WebCIProbe` autoload, or `ARENIC_CI` protocol. Never publish the QA root.

Arrange `.tmp/site-qa/` with the real site root, `play/` production game, and
`__probe__/` test game, then run:

```sh
ARENIC_WEB_ROOT=.tmp/site-qa npm run test:web
```

The local server exposes only `/arenic-sept-godot/` by default, matching a
repository GitHub Pages deployment. This intentionally catches incorrect
root-relative asset links. `ARENIC_WEB_BASE_PATH` changes that prefix;
`ARENIC_WEB_BASE_URL` uses an already-running server and disables the managed
server. Both game URL overrides are relative to this base by default:
`ARENIC_GAME_URL=play/`, `ARENIC_PROBE_URL=__probe__/`. Port defaults to 4174 and
can be set with `ARENIC_WEB_PORT`.

The clean game test waits for browser-rendered title, class screen, and world
HUD pixels before sending dependent pointer/key input. It uses no production
test hook or fixed scene-loading delay. A browser-only passive AnalyserNode
branch observes audio output connections. It preserves the
original audio connections and does not call `resume()` or bypass autoplay.
Nonzero output samples establish browser mixing, not subjective sound quality.

The isolated autoload emits `ARENIC_CI` JSON. It reports real control geometry,
scene identity, chosen class, hero tile, camera, music and combat state at 10 Hz. Tests
click projected positions and press physical keys; they do not emit button
signals or mutate gameplay state to pass navigation checks. F8 runs bounded
music API checks because the shipping game has no seek/pause UI. F9 reads the
actual framebuffer once; texture size alone is not accepted as render evidence.
Combat readback is passive: nine arena/target totals, actual HUD phase/fill,
remaining cooldown and activity, held-channel state, active effects, animation
availability and ability-button geometry. Infinite channel duration is encoded
as `null` plus `is_channeling`; no combat test changes model state or clocks.

Coverage includes all eight card identities and portraits, a non-default hero
spawn/move, all nine arena hotkeys, bracket navigation, zoom controls, DPR1/2,
4:3 letterboxing, resizing and pointer alignment. The mixer probe checks actual
PCM for the hum and nine MP3 tracks, explicit seeking across every loop end,
independent pause/offset, a two-voice crossfade, request coalescing and left/right
listener balance. Broad tolerances allow real browser mixer scheduling; these
are correctness checks, not a 60 fps benchmark or sample-perfect seam test.

`combat.spec.mjs` uses real title/class choices and Tab, Space, movement and
bracket keys. Hunter covers target/arena/HUD agreement, cooldown and echo
rejection, and independent arena progress. Cardinal covers one-second channel
hits, release, and movement cancellation. Merchant moves five tiles into range,
completes all 20 Fortune hits, and checks both Phase 2 readback and rendered
pixels of the retained completed-layer foundation. The probe verifies all eight
starter actor sets and the 14 effect resources' used animation tags.

`sfx.spec.mjs` uses real movement, blocked collision and Space input to exercise
movement cues, projectile cast/impact and a held channel. Passive readback checks
all 22 cue resources, decoded SFX bus samples, the 12-voice ceiling and silence
after channel release and return to overview. Music remains on its separate bus;
these checks establish browser playback and lifecycle behavior, not listening approval.

Software WebGL runners get a 300-second per-game-test budget; rendered scene
readiness is bounded at 60 seconds and the mixer report at 240 seconds. The
audio and combat tests use a 640×360 viewport to limit unrelated GPU work. Separate
1280×720, DPR2, letterbox and resize tests retain their full framebuffer checks.
Loop checks observe playing audio wrapping near zero within 2.5 advancing game
seconds, with an independent 20-second wall cap; game clocks intentionally follow
Godot's clamped frame delta. Combat waits observe the actual physics clock or
active-cast state; Fortune's full-duration completion has an independent
180-second wall-clock bound. PCM and loop assertions are unchanged by these waits.

Upload `playwright-report/` and `test-results/` on failure. They contain console
JSON, screenshots, video/trace on failure, and mixer results. Browser runtime
errors, Godot script/shader errors and failed resource requests fail the tests.

A Chromium `ERR_ABORTED` for `.pck` or `.wasm` is accepted only after startup
and an audit of the exact reader Godot used proves HTTP 200, the exact expected
byte count, and end-of-stream. Unencoded responses must match Content-Length.
For explicit gzip or Brotli responses, Fetch yields decoded bytes, so the size
must match that exact asset URL in the exported `GODOT_CONFIG.fileSizes` map.
Unknown encodings or undeclared compressed assets cannot use this exception.
All other failed requests remain failures. The audit observes existing reads;
it does not retry or duplicate downloads.
