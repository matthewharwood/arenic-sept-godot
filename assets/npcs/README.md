# NPC character booklet

NPCs belong in `assets/npcs/<id>/`, alongside their editable master, portrait
reference, palette, source previews, and `npc.json` manifest. The shared
[character booklet](../previews/index.html) links Heroes, Bosses, and
[NPCs](../previews/npcs/index.html).

[The Keeper](../previews/npcs/keeper/index.html) is the opening Guild House
caretaker: pale, ageless, patient, and quietly mysterious. The manifest's
`dialogue_portrait` selects the transparent half-body illustration presented
against the booklet's dark background. The original full-body `portrait`
remains the costume and silhouette reference, available in a closed reference
disclosure below the main illustration. Both source images are retained.

The [dialogue portrait provenance](keeper/dialogue-portrait-provenance.json)
records that ImageGen produced an opaque illustration; its checkerboard was
part of the image. Native Aseprite cleanup supplied the final transparent alpha.
The generated image and editable `dialogue-portrait.aseprite` are retained beside
the final PNG; the booklet copies that finished PNG without altering the art.

The original standing overhead master remains a 19 × 19 reference with pivot
(9,9), matching a single hero tile. Its idle and beckon studies retain their
saved durations and four cardinal directions. The manifest's top-level
`source`, `canvas`, `pivot` and `sprite_preview` keep that contract for the
existing booklet and standing-art exporter.

`current_pose` and `current_world_sprite` explicitly identify the
[seated Keeper](keeper/seated/README.md) used by Guild House: a 38 × 38 canvas
with pivot (19,19), a repeating south idle and a one-shot south beckon. The
current reference includes its separate source, runtime SpriteFrames resource,
native preview and motion review. Portraits and opening dialogue are unchanged.

The four opening lines in [the manifest](keeper/npc.json) explain the R countdown,
recorded movement and attacks, Commit, and repeated echoes forming patterns.
They target approximately 15 seconds of guided introduction, with at least
2.75 seconds per line and further progress controlled by the player. The modal
label and dialogue must stay aligned when either is changed.
The game uses the typed [NPC definition](../../arenic-game/data/npcs/keeper.tres)
and [intro resource](../../arenic-game/data/intro/guild_introduction.tres), both
referenced by the manifest.

Future identity and spider-form notes are design spoilers in the manifest and a
closed, explicitly labeled booklet disclosure. They do not belong in the
player's opening dialogue. The source plot supplies themes and relationships;
its older arena names and punishment ideas do not override the current game.

Rebuild saved portrait and sprite previews without changing native art:

```sh
python3 assets/pipeline/build-npc-previews.py
```

The builder requires the saved portraits and sprite sheet/metadata, validates
the one-tile frame and tag contract, writes `assets/previews/npcs/`, and refreshes
the three shared booklet indexes. The existing Pages publisher packages the
NPC pages and content-hashed images alongside all eight heroes and eight bosses.
