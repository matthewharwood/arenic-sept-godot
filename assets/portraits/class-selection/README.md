# Class-selection portrait provenance

The approved **v2 portraits are the active game art** for all eight classes. They were generated with the built-in `image_gen` tool using the previous portraits as identity and style references. The original v1 portraits were based on user-provided screenshots. UI text and generation prompts do not define gameplay rules.

| Class | Character | Active v2 runtime image |
| --- | --- | --- |
| Hunter | Dean | [hunter.png](../../../arenic-game/assets/portraits/hunter.png) |
| Bard | Marcus | [bard.png](../../../arenic-game/assets/portraits/bard.png) |
| Merchant | Calvin | [merchant.png](../../../arenic-game/assets/portraits/merchant.png) |
| Warrior | King | [warrior.png](../../../arenic-game/assets/portraits/warrior.png) |
| Cardinal | Pius | [cardinal.png](../../../arenic-game/assets/portraits/cardinal.png) |
| Alchemist | Giuseppe | [alchemist.png](../../../arenic-game/assets/portraits/alchemist.png) |
| Forager | Daisy | [forager.png](../../../arenic-game/assets/portraits/forager.png) |
| Thief | Ginger | [thief.png](../../../arenic-game/assets/portraits/thief.png) |

The v2 sources remain in [regeneration-v2/](regeneration-v2/), and the runtime paths above contain the approved replacements. Previous v1 originals are archived under [regeneration-v2/before/](regeneration-v2/before/). The [interactive comparison](regeneration-v2/compare.html) and [eight-hero table](regeneration-v2/COMPARISON.md) compare those archived originals with active v2 art.

[active-portraits.json](active-portraits.json) is the current authority for active runtime files, selected sources, archived previous paths, hashes, and activation time.

Both sets use 1024 × 1536 RGB PNGs with near-white backgrounds rather than native alpha. Generated image pixels are preserved; selecting v2 changes which source PNGs occupy the runtime paths.

Godot's [portrait cutout shader](../../../arenic-game/scripts/character_creation/portrait_cutout.gdshader) removes the white backing during rendering. Per-class `AtlasTexture` resources, such as [hunter_atlas.tres](../../../arenic-game/assets/portraits/hunter_atlas.tres), crop the displayed region to normalize framing without changing the source PNG. Runtime rendering is responsible for cutout appearance; file verification alone does not establish visual quality.

[generation-manifest.json](generation-manifest.json) is the **historical v1 record**: it retains all eight original hashes, generated source paths, and exact prompt histories, including the unsuccessful transparency requests and subsequent white-background edits. Its recorded runtime paths describe the original generation; use the archived `before/` files for those original pixels. Embedded batch records retain historical machine-local paths, which may not exist on another machine.

The active v2 prompt histories and source records are grouped in [Hunter, Bard, Merchant](regeneration-v2/batch-hbm.json), [Warrior, Cardinal, Alchemist](regeneration-v2/batch-wca.json), and [Forager, Thief](regeneration-v2/batch-ft.json). [verification.json](regeneration-v2/verification.json) records v2 dimensions, hashes, and browser comparison checks before activation; its original-unchanged fields describe that earlier comparison stage.

The optional Sunburst backdrop is confined to the comparison page. It is not baked into the PNGs or connected to the game. This portrait collection does not change Aseprite sources or the Hunter preview-only sprite pipeline. The built-in generator does not expose its model identifier, so the v2 label denotes this approved art revision, not a verified model upgrade.
