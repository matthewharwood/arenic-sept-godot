# Display density and native rendering

Current transition coverage and native performance are documented in [overworld-atmosphere.md](overworld-atmosphere.md). Earlier native benchmark files below predate the correction to the screen-copy rectangle and copied only part of the intended region. Use [overworld-native-benchmark.json](overworld-native-benchmark.json) for the corrected cost.

1280 × 720 is the game's layout size, not its hardware resolution. At a 2560 × 1440 window, the full scene renders into a 2560 × 1440 target while camera, movement, hit-testing, and HUD layout retain their 1280 × 720 coordinates. Text is rasterized at the output density; pixel sprites retain their authored textures and nearest filtering. No system monitor resolution is changed.

## Startup and resizing

[`ArenicDisplayPolicy`](../arenic-game/scripts/app/display_policy.gd), registered as `DisplayPolicy`, sizes standalone desktop windows once at startup. It requests a 1280 × 720-point window multiplied by display scale, then fits it inside 90% of the usable screen and centers it. The 16:9 dimensions are whole multiples of 16 × 9. It leaves subsequent user resizing alone. Smaller screens clamp to their usable area.

The macOS adapter uses `DisplayServer.screen_get_max_scale()` because Godot 4.7.2 uses that coordinate scale for Cocoa window geometry and screen bounds, including mixed-density monitor arrangements. It does not multiply already-scaled screen bounds again. Other platforms use `screen_get_scale()` where implemented, with 1× as the fallback; only macOS was visually validated in this pass. See the [exact engine implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/macos/display_server_macos.mm) and [DisplayServer API](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-screen-get-max-scale).

Headless runs, script-driven tests, embedded previews, explicit resolution/fullscreen/maximized launches, and non-windowed modes retain their own geometry. HiDPI remains enabled. Fullscreen and window resizing use the actual render target automatically; they never change the monitor's resolution.

`apply_game_layout()` selects Canvas Items, Keep aspect, and fractional stretch. Keep aspect adds letterbox/pillarbox space when needed. Unlike the former Viewport/integer setup, fonts and effects are not enlarged from a finished 720p image, and ordinary intermediate window sizes do not leave oversized borders. At exact 2× density, a 19-unit tile is 38 output pixels. Fractional scales necessarily distribute source pixels over unequal physical widths; they preserve nearest filtering rather than inventing artwork detail. [Godot's resolution and HiDPI guidance](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)

Camera projection/picking remains logical: Godot applies the canvas stretch internally. Multiplying mouse positions or world-label coordinates by Retina density would apply the conversion twice. The fog shader instead uses actual `SCREEN_PIXEL_SIZE` for half-texel copy bounds and logical viewport dimensions for a visually consistent blur radius. The same bounded nine taps are used at every size.

## Godot editor preview

The embedded Game view has its own window sizing policy, independent of the game's standalone launch. For native-size playtesting, choose **Game Window Options → Embedded Window Sizing → Stretch to Fit**, then enlarge or maximize its window. The project-local editor preference is `game_view/embed_size_mode=2` in `.godot/editor/project_metadata.cfg`; this machine's preference was updated and the project reloaded. This generated editor file is intentionally not committed. A fresh checkout may need the same menu choice.

An embedded preview at 1280 × 720 still has only that many output pixels even on a Retina monitor. Enlarging the container while keeping Fixed sizing does not change that. Stretch to Fit lets the game render to the actual container dimensions. Standalone launch sizing does not override the editor's explicit `--wid`/`--resolution` controls.

## Validation

Godot 4.7.2 / macOS / Apple M4 Max / Metal Forward+:

- Real standalone startup reported a 2560 × 1440 window on the 2× Retina display, centered inside the usable 3456 × 2158 region.
- **78 display assertions** passed: 1280 × 720, 1920 × 1080, 2560 × 1440, and a 1600 × 1200 window with a 1600 × 900 letterboxed render target; fixed logical layout, camera/picking round trips, real GUI input through both coordinate paths, density-aware fitting, and identical HUD pixels with fog off/on.
- The prior ten suites also passed, including 418 transition assertions and 2,244 presentation assertions.
- Actual editor Play was verified through mouse clicks on title Start and class Start, then the overworld, with the embedded preview enlarged to 3436 × 2009 and Stretch to Fit enabled. The larger preview filled its window; the scene continued to use its original layout and controls.
- At actual **2560 × 1440**, the transition benchmark measured 643 intervals with **p95 10.271 ms**, **p99 11.052 ms**, and **maximum 17.746 ms**. One interval exceeded 16.67 ms; none exceeded 20 ms. Observed FPS was 119–120. The first animated frame was 7.950 ms with no new pipeline compilations. This short local sample does not establish performance on other hardware. [Full sample](display-retina-benchmark.json)
- A second sample matching the enlarged preview used an actual **3436 × 1932** content framebuffer: 644 motion intervals, **p95 9.980 ms**, **p99 11.660 ms**, **maximum 18.170 ms**, with one interval above 16.67 ms and none above 20 ms. Observed FPS was 118–121. The larger letterboxed window was rounded to 3436 × 2008 by the platform. [Large-window sample](display-large-benchmark.json)

Framebuffer checks use an actual `get_image()` after `frame_post_draw`, outside performance sampling. In this engine version, root `ViewportTexture.get_size()` applies an additional stretch factor and can overstate physical render size; it is not sufficient proof of resolution. [Godot 4.7.2 viewport texture source](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/viewport.cpp#L142-L190)

Run from the repository root, with other game instances stopped:

```sh
godot --path arenic-game --script res://tests/display/display_checks.gd
godot --path arenic-game --script res://tests/themes/transition_benchmark.gd -- --render-size=2560x1440
```

The benchmark defaults to 1280 × 720 for comparisons and accepts an explicit render size. It records both the actual framebuffer and logical dimensions, so a 720p measurement cannot be mistaken for a Retina measurement.
