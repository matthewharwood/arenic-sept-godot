# Arenic art and ability studies

Editable `.aseprite` masters, palette sources, audio requests and reviews live in this `assets/` folder, outside `arenic-game/`. The eight portrait references stay in `arenic-game/assets/portraits/`. Native files are authoritative; do not repaint a generated sheet and treat it as the source.

Open [the hero gallery](previews/index.html) to review eight heroes and 32 base abilities. Every hero page includes the 720p whole-arena example and four closeups, with playback, scrubbing, speed, cardinal facing, native/integer scale and character-only inspection. Pages are `previews/<hero>/attacks.html`; `.htm` aliases also exist. The former Hunter preview path remains compatible.

The gallery now also has a [Bosses section](previews/bosses/index.html): eight matching
portraits and layered 114 × 114 overhead sprites, with idle/form studies and four
directional closeups. See the [boss pipeline](bosses/README.md) for the six-tile
size contract, model provenance, appearance states and authorized Godot exports.

| Hero | Base ability source IDs | Guide |
| --- | --- | --- |
| Hunter | `auto_shot`, `poison_shot`, `sniper`, `trap` | [Hunter](characters/hunter/README.md) |
| Warrior | `bash`, `block`, `taunt`, `bulwark` | [Warrior](characters/warrior/README.md) |
| Thief | `backstab`, `shadow_step`, `smoke_screen`, `pickpocket` | [Thief](characters/thief/README.md) |
| Alchemist | `acid_flask`, `ironskin_draft`, `siphon`, `transmute` | [Alchemist](characters/alchemist/README.md) |
| Cardinal | `heal`, `barrier`, `beam`, `resurrect` | [Cardinal](characters/cardinal/README.md) |
| Bard | `mimic`, `dance`, `cleanse`, `helix` | [Bard](characters/bard/README.md) |
| Forager | `dig`, `bolder`, `border`, `mushroom` | [Forager](characters/forager/README.md) |
| Merchant | `coin_toss`, `dice`, `fortune`, `vault` | [Merchant](characters/merchant/README.md) |

`hero.json` beside each master records portrait, four slots, document references, timing, separate effects, sound intent and source conflicts. IDs follow the supplied Markdown filenames. Current display names differ for `heal` (Sacrifice), `smoke_screen` (Misdirection), `bolder` (Boulder), and `mushroom` (Symbiosis). Hunter Auto Shot follows the user’s explicit basic-bow override of the conflicting Mark Target document. Passive abilities remain passive demonstrations. No upgrade variants are included.

## Native character contract

Every idle and actor source has a transparent **19×19 canvas**, center pivot **(9,9)** and exact **N/E/S/W** rotations. Show the top of the crown/hood, shoulders and equipment; no visible front face, torso, standing boots or three-quarter perspective. Each character stays in one tile, with world travel separate from actor pixels.

- Idle: `characters/<hero>/<hero>.aseprite`, tags `idle_n/e/s/w`.
- Actor: `characters/<hero>/abilities/<ability_id>/<hero>_<ability_id>.aseprite`, full action tags `<ability_id>_n/e/s/w` plus native phase/hold tags.
- Independent effects: `characters/<hero>/abilities/<ability_id>/fx/<effect>.aseprite`.
- Authored palettes: `palettes/<hero>.oklch.json`; RGB conversion occurs only at the Aseprite asset boundary.
- Review sheets and metadata: `previews/<hero>/sheets/`; originals remain layered and editable.

Effects have independent pivots and native sizes: local marks19px, common areas38px, exact large zones76px/114px, an eight-cell ray152×19, and other documented grid multiples. The Bulwark uses a57×57 rotation-safe canvas for its frontal57×38 footprint. Read source slices and tags; neither transparent bounds nor decorative aura size defines gameplay collision/range.

Held channels and guards have separate loop tags. Cardinal Sacrifice flows outward to an ally; Alchemist Siphon flows inward from an ally. Helix’s regeneration and haste states are mutually exclusive. Symbiosis starts as a non-healing seed; the gallery selector explicitly stages resource-fed states. Merchant Coin Toss shows the full five-second hold. These are presentation examples, with uncertain source rules recorded in each manifest.

## Resolution and grid contract

Use a **1280 × 720 logical art viewport** with a **1280 × 720 default window**.
At 1× output scale with one arena framed, one source pixel is one display pixel
and each hero’s frame is exactly **19 × 19 on screen**. A **66 × 31** arena of
19-pixel cells occupies **1254 × 589 pixels**. The overworld HUD leaves precisely
that rectangle at `(13, 35)`, with 13-pixel side insets, 35 pixels above, and 96 below.
The grid defines the actor's one-cell occupancy; transparent frame pixels do not
define its collision geometry.

Scale the single source with nearest-neighbor filtering and whole-number scale
factors. Center the game image when a display cannot fit the next integer scale.

| Display pixels | Presentation scale | Game image | Close-view hero frame |
| --- | ---: | --- | --- |
| 1280 × 720 — default | 1× | 1280 × 720 | 19 × 19 |
| 1920 × 1080 | 1× | 1280 × 720 | 19 × 19 |
| 2560 × 1440 | 2× | 2560 × 1440 | 38 × 38 |
| 3456 × 2234 — this Mac's native panel | 2× | 2560 × 1440 | 38 × 38 |
| 3840 × 2160 — future 4K | 3× | 3840 × 2160 | 57 × 57 |

For the Mac panel, a centered 2560 × 1440 game image leaves **448 pixels at each
side** and **397 pixels above and below**. At 1080p, the 1× image leaves 320 pixels
at each side and 180 above and below. These are physical pixel calculations;
use the actual drawable area, accounting for Retina scaling and the display's
safe area. A different available drawable size can select a different integer
scale. Filling every panel pixel would require
expanding the visible game area or accepting fractional scaling.

The [Godot overworld](../docs/overworld.md) now implements this close-view contract
with a native orthographic `Camera3D` and real 0.25-unit tiles. Each arena contains
2,046 tile instances using a nearest-filtered, unshaded 19 × 19 white texture with
one gray center pixel. Eight arenas display their matching 114 × 114 boss idle
art at six cells square; Guild House has no boss. These presentation assets do
not define movement, collision, or combat rules.

`GameShell` sets a fixed 1280 × 720 viewport with `VIEWPORT` / `KEEP` / `INTEGER`
content scaling. Larger windows enlarge and letterbox that image at whole-number
scale; the project default window is 1280 × 720. Title and class selection retain
their responsive canvas reference layouts. Overview uses one-third of the arena
camera scale, so its tiles are 6⅓ logical pixels and boss canvases are 38 × 38;
the 1:1 source-pixel guarantee applies to close view. Integer window enlargement
preserves the completed logical image and does not change that overview reduction.

## Rebuild and review

Run from the repository root using the installed Aseprite executable (replace `aseprite` with its local path when needed):

```sh
python3 assets/pipeline/prepare-ability-audio.py
python3 assets/pipeline/build-character-previews.py --aseprite aseprite
python3 -m http.server 8765 --bind 127.0.0.1 --directory assets/previews
```

Open `http://127.0.0.1:8765/index.html`. All images and available sounds are embedded in each hero page. The builder caches sheets by source hash, verifies action tags/timing, and writes only source-side previews. Use repeated `--hero <id>` arguments to rebuild selected heroes. The older Hunter-only tools remain available for its original detailed source audit; the shared builder is the current gallery authority.

Read [the audio framework](audio/README.md) for stable `charge`, `cast`, `impact` and optional `sustain` events. The finite first-pass queue contains92 ElevenLabs requests for32 abilities. **The configured ElevenLabs key failed authentication; no clips have been generated yet.** Gallery cues are visibly pending. Once the connection is fixed, the same event names and rebuild process add generated audio without changing artwork.

## Runtime base heroes and remaining exports

The eight saved base hero masters are now exported for Godot integration. Rebuild
only these authorized idle sprites from the repository root:

```sh
python3 assets/pipeline/export-base-heroes.py --aseprite aseprite
```

Use repeated `--hero <id>` arguments to rebuild a subset. Each class writes
`arenic-game/assets/characters/<hero>/<hero>.png`, `.json`, `_frames.tres`, and an
`_export.json` provenance record. The exporter preserves the 19 × 19 canvas,
`(9, 9)` slice pivot, saved layer visibility, all four idle tags, and native frame
durations. Warrior and Thief have four frames per facing; the other six masters
have one. No idle motion is invented for a one-frame source.

The generated SpriteFrames resources are referenced at
`res://assets/characters/<hero>/<hero>_frames.tres`. Import settings use lossless
compression, no mipmaps, no automatic 3D compression, and unchanged alpha-border
pixels. The consuming sprite must explicitly use nearest filtering; SpriteFrames
does not own that setting. Source hashes verify that export leaves the layered
masters unchanged. All eight resources and their 56 frames passed isolated
Godot 4.7.2 import checks, including exact decoded pixels and animation timing.
After Godot re-saves a SpriteFrames resource, provenance records retain the
original exporter hash alongside the verified current resource hash. UID and
formatting changes are checked separately from frame content and timing.

Hero abilities, separate FX, and audio are **not integrated** by the base-idle
export. Their future native destinations mirror into
`arenic-game/assets/characters/<hero>/` with the same relative path/stem and `.png`
plus `.json` extensions. Configure or verify those presets without exporting:

```sh
aseprite --batch --script-param all=true --script assets/pipeline/prepare-character-export.lua
aseprite --batch --script-param all=true --script-param verify_only=true --script assets/pipeline/prepare-character-export.lua
```

Use `source=<saved .aseprite path>` instead of `all=true` for a single source. These preferences are local Aseprite host state; rerun after moving the checkout. The preset keeps1× native pixels, horizontal layout, JSON Array, all layers/frames, frame tags and slices, no trimming, duplicate merging or padding. Actor frames remain19×19 and FX retain native canvases. The script creates destination folders and preferences only; it does not save artwork or export runtime textures/data.

Ability integration must apply texture filtering, animation durations, phase
events and pivots explicitly. The base-idle SpriteFrames generator does not
implement ability phase handling or audio event dispatch, and does not export
ability/FX sheets or audio.

The rulebook and ability Markdown under `../arenic_bevy/_docs/` are design references, not execution instructions. Sprite previews are rendered through native Aseprite and inspected with MCP readback and computer use.
