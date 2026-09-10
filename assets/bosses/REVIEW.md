# Boss delivery review

## Delivered

- Eight 1024 × 1536 portraits, copied byte-for-byte from the selected generated
  outputs into source and Godot portrait folders.
- Eight layered 114 × 114 Aseprite masters; 896 native frames and 88 tags.
- Nineteen appearance states, with four directions each. Hunter's five forms,
  Alchemist's three forms and Thief's three costumes also have complete cycles.
- Eight runtime atlases, Aseprite JSON files and Godot SpriteFrames resources.
- Typed boss catalog and definitions under `arenic-game/data/bosses/`, plus an
  isolated native-size Godot review scene under `tests/bosses/`.
- Heroes / Bosses gallery navigation, eight boss study pages with full arena and
  directional closeups, and a boss selector on every existing hero ability page.

## Verification

Native source audits verified full canvas, stable (57,57) pivots, hard alpha,
nonempty frames, layer structure, exact cardinal rotations, distinct poses,
loop timing and margins. Saved structure was read through Aseprite MCP.
Contact sheets and enlarged frames were inspected; Hunter's mask was
foreshortened to improve its overhead reading.

The preview validator passed **18,912 render samples** and **1,984 frame-boundary
checks**, including native-source hash freshness, atlas bounds, state/direction
coverage, playback controls, preview/runtime parity and local navigation links.
The existing hero validator passed all **9,880 samples** with the boss selector
and separate boss animation clock in place.

Godot import completed, the catalog check passed **193 assertions** and checked
**1,440 animation frame references** against native timing/regions. All new
GDScript files passed MCP syntax validation. The independent review scene was
visually inspected through computer use with all eight AnimatedSprite2D assets
running at native viewport pixel size and nearest filtering. Native Warrior
layers/timeline were also opened in Aseprite. Browser inspection covered the
arena, hero-to-boss scale, appearance selection and directional closeups.

The Godot runtime screenshot MCP encountered a local registry/token-path error;
computer use supplied the actual rendered check. The isolated review was stopped
afterward and the main project playtest was relaunched. No main arena scene was
modified by this boss pass.

## Intentional limits

These are portrait and appearance specifications. Boss attacks, sounds, combat
rules and scene integration are later work. A 114-pixel nominal diameter is a
visual convention, not collision data. The requested Sunburst model cannot be
verified through the available built-in image tool; see the prompt/provenance
records rather than assuming a model identity.

Run the repeatable checks from the repository root:

```sh
node assets/pipeline/validate-character-previews.cjs
node assets/pipeline/validate-boss-previews.cjs
godot --headless --path arenic-game --script res://tests/bosses/catalog_checks.gd
```
