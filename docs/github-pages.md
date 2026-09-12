# Browser release and GitHub Pages

The public entry point is <https://matthewharwood.github.io/arenic-sept-godot/>.
`site/` owns the landing page. The build publishes the game at `play/`, eight
hero studies at `docs/`, eight boss studies at `docs/bosses/`, and an index of
32 attacks and abilities at `docs/attacks.html`. All links are relative so the
site works beneath a repository path.

## Release gate

`.github/workflows/pages.yml` runs for pull requests and changes to `main`.
It calls the reusable native validation workflow and independently builds and
tests the website. Deployment requires both jobs to pass. PRs never deploy.

1. Install official Godot **4.7.2**, verified against pinned SHA-512 checksums.
2. Run the Godot Doctor authored-data preflight before installing browser dependencies.
3. Run 16 headless and 5 software-rendered Godot checks; the headless lane also
   runs Godot Doctor before its gameplay checks.
4. Export a clean Web release and a separate, disposable instrumented release.
5. Package the landing page and galleries; deduplicate existing preview images
   without changing their pixels or animation data.
6. Run 28 Chromium browser tests under `/arenic-sept-godot/`.
7. Upload **only** the clean site and deploy it through GitHub Pages.
8. Confirm the public build manifest matches the deployed commit, then exercise
   public title/class clicks, arena navigation, actual audio output and catalog links.

The checks cover the current implemented contracts. They cannot guarantee
untested future features or every browser/hardware combination. A failed build
does not replace the last deployed site; a post-deployment failure marks the
release red and retains evidence for diagnosis. Revert a bad release through a
reviewed PR and let the same workflow republish it.

The September 10, 2026 local native run passed all 16 headless and 5 rendered
checks, including 182 SFX and 281 combat-model assertions. All 28 Chromium cases
also passed against fresh production and private probe exports: the two SFX
cases completed in 22.4 seconds and the other 26 in 3.6 minutes. SFX checks
confirmed decoded audio and clean channel-release silence. These are local
validation results, not a deployment record.

## Browser contracts

The Web preset uses the single-threaded Compatibility renderer. It needs WebGL 2
and avoids cross-origin isolation headers, which standard GitHub Pages cannot
configure. Native rendering settings are preserved. Music and procedural hum
explicitly use streamed playback so Godot's mixer handles spatial audio and
crossfades. Browser audio begins only after a real user gesture.

The complete automated lane is Chromium. A local Firefox production smoke test
also passed title/class selection, arena input and nonzero WebAudio output.
Safari and mobile gameplay have not been certified; the landing page itself is
tested at desktop and mobile widths. The game currently requires a keyboard.

The private probe exercises all nine decoded music streams and their loop
boundaries, independent pause/seek/resume, the bounded two-voice pool, interrupted
crossfades, panning and hum. Real pointer/keyboard tests cover eight class cards,
Guild House spawn, hero selection and tile movement, all arena keys, bracket
navigation, zoom, resizing, letterboxing and DPR 1/2 framebuffer coverage.
The three combat cases use the real title/class flow and controls: Hunter verifies
cooldown/repeat rejection and independent arena totals; Cardinal verifies held
channel damage and cancellation; Merchant moves into range and completes all
20 Fortune ticks, checking the visible completed-phase foundation. Passive
readback also verifies all eight starter actor sets and their used effect tags.
Two SFX cases exercise actual movement and blocked-step sounds, projectile
cast/impact, held-channel playback and release cleanup. They read decoded SFX
bus samples separately from music and enforce the bounded voice pool.
The clean production test uses a passive browser audio tap and never bypasses
autoplay. Gallery tests exercise every hero ability and boss appearance.

Software-rendered CI is a correctness lane, not a frame-rate benchmark. Game
tests have a five-minute bound, including full-density screenshot and browser
cleanup work. The clean production smoke test, audio and combat cases run at
640 × 360 to avoid unrelated pixel work; the separate input and framebuffer cases still exercise 1280 × 720,
Retina density and resizing. Loop waits observe advancing game time and retain
a real-time deadline. Fortune completion follows actual simulation progress with
a separate 180-second wall-clock bound. CI stops on its first failure and uploads diagnostics;
every test must pass in a green release.

`tests/web/probe.gd` is added only to a disposable project copy. Its autoload,
test shortcuts and readback are absent from production. The export also removes
the editor MCP bridge and audits the PCK for development resource paths.
No test or editor server is published. QA uses a separate `__probe__/` directory
that is never uploaded to Pages.

## Local build and test

Install Node 24, Python 3, Godot 4.7.2 and its matching Web export templates.
Use fresh empty export directories; the exporter refuses to overwrite an
existing export. It never modifies the open editor project or its imports.

```sh
python3 scripts/ci/test-godot.py --godot /path/to/godot --suite doctor
npm ci
npx playwright install chromium
python3 scripts/build-web.py --godot /path/to/godot --output .tmp/web-production
python3 scripts/build-web.py --godot /path/to/godot --output .tmp/web-probe --probe tests/web/prepare-probe.mjs
python3 scripts/build-site.py --game .tmp/web-production --output .tmp/site
cp -a .tmp/site .tmp/site-qa
cp -a .tmp/web-probe .tmp/site-qa/__probe__
ARENIC_WEB_ROOT=.tmp/site-qa npm run test:web
```

On macOS the installed Godot binary is normally
`/Applications/Godot.app/Contents/MacOS/Godot`.
Linux CI uses `scripts/ci/install-godot.py --templates`. Download caches are
checksum-verified; generated imports and release artifacts are rebuilt.
Tests start a local server beneath the repository URL prefix automatically.
Keep one run per results directory; concurrent runs need distinct Playwright
output and report paths.

To test an already served site, set `ARENIC_WEB_BASE_URL` to its trailing-slash
URL. For a clean public site, select only production/catalog tests because the
private probe deliberately does not exist there:

```sh
ARENIC_WEB_BASE_URL=https://matthewharwood.github.io/arenic-sept-godot/ npm run test:web -- --grep 'clean production|landing, complete catalog'
```

Failures retain browser screenshots, logs and traces for 14 days in Actions.
Engine upgrade, export-preset or audio changes must pass this full release gate.
See [Godot Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
and [GitHub Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
