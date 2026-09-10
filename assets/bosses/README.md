# Boss appearance studies

Eight bosses were developed from the supplied child drawings and spoken brief. The
portraits match the existing heroes' ink contours, jewel colors, gold fittings and
white backgrounds. Native overhead sprites are redrawn in Aseprite from those
portraits; they are not resized portrait cutouts.

| Boss | Identity retained from the brief | Appearance states |
| --- | --- | --- |
| Hunter | One bow-bearing creature folding between five expressive forms | Cycle, quiet, sorrow, startled, wrath, elation |
| Warrior | Armored warrior with squared crest, sword and crescent boomerang | Idle |
| Cardinal | The storm cloud itself, with lightning and a folded funnel | Idle |
| Forager | Burrowing scorpion with digging pincers and segmented tail | Idle |
| Bard | Large, frightening barking dog with a resonant bell collar | Idle |
| Alchemist | Viscous gel that changes between bomb, skull and potion | Cycle, bomb, skull, potion |
| Merchant | Wealthy pilot in a compact saucer with purchased mechanical gadgets | Idle |
| Thief | Ninja with sword, bow and changing outfits; interpreted as a raven | Cycle, obsidian, crimson, indigo |

Names for the Hunter's forms and Thief's outfits are organizational interpretations.
They specify appearance only. No boss attacks, sounds, stats, targeting, damage,
collision shapes or arena assignments are defined in this pass.

## Size and source contract

- Every native master is **114 × 114 RGBA pixels**, with a `frame` slice covering
  the whole canvas and a **(57,57)** pivot. This is six 19-pixel tiles, matching
  the existing HTML arena's 57-pixel-radius boss reference at 1280 × 720.
- All eight use that same canvas and nominal circular size guide. Actual
  silhouettes differ; the circle is not a gameplay collision definition.
- Art is strict overhead orthographic. Cardinal directions are exact 90-degree
  rotations of authored pixels. Layers retain independently editable anatomy,
  cloth, equipment and accents. Palettes are authored in OKLCH and converted
  only at the Aseprite color boundary.
- `<state>_n`, `_e`, `_s`, `_w` identify native sequences. `idle_*` always exists;
  for Hunter, Alchemist and Thief it aliases the complete `cycle_*` range.
- Keep frame regions untrimmed and sampling nearest-neighbor. Native 1× means
  114 display pixels for a boss and 19 for a hero. Integer display scaling is
  independent of the Mac's resolution; do not re-author art for each monitor.
- `boss.json` is the appearance manifest. The saved `.aseprite` file is the
  pixel/timing authority. Authoring Lua is an editable construction aid; do not
  rerun it over manual Aseprite changes without deliberately reconciling them.

## Portrait provenance

Original drawings are preserved in `references/`; `thief.jpg` uses the canonical
spelling of the supplied `theif.jpg`. Selected images are in `portraits/` and
copied to `arenic-game/assets/portraits/bosses/` for Godot.

Generation used the **built-in image generation tool** with one request per
portrait. The requested model was **GPT-Image-2.5 Sunburst**, but the callable tool
does not expose a model selector or verified model identity. These images must
not be represented as verified Sunburst output. Exact prompts are preserved in
`portraits/prompts.json`; `portraits/provenance.json` records selected output
paths. Existing Warrior and Alchemist hero portraits supplied style references.

## Rebuild and handoff

From the repository root, with the Aseprite executable available:

```sh
python3 assets/pipeline/build-character-previews.py --aseprite aseprite
python3 assets/pipeline/build-boss-previews.py --aseprite aseprite
```

The first command maintains hero studies; the second reads saved boss masters
and rebuilds the Bosses gallery. Both preserve the Heroes / Bosses entry points.
Open `assets/previews/index.html` or serve `assets/previews/` locally. Boss pages
are `bosses/<id>/attacks.html` for naming continuity; they show idle/form studies,
the whole arena, and four directional closeups. Hero pages also allow selecting
any boss as the arena reference. These remain animation specifications.

This task explicitly authorizes boss game assets and data. To regenerate them:

```sh
python3 assets/pipeline/build-boss-previews.py --aseprite aseprite --export-game
```

Runtime outputs are `arenic-game/assets/bosses/<id>/<id>.png`, `.json`, and
`<id>_frames.tres`. Sheets use at most 16 columns, 114-pixel untrimmed regions,
native durations, tags and slice metadata. SpriteFrames speed is 1000 and each
frame's duration is its native milliseconds, preserving timing exactly.
Godot resources live in `arenic-game/data/bosses/`, parallel to `data/classes/`.
Apply nearest filtering when a scene instantiates these assets. The existing
Godot arena orb/scene is unchanged; this pass prepares resources and HTML review.

The earlier preview-only restriction continues to apply to hero game exports.
Boss export permission does not authorize exporting the hero roster.
