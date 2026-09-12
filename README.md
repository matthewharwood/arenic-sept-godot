# Arenic

[Play in the browser](https://matthewharwood.github.io/arenic-sept-godot/) ·
[Heroes](https://matthewharwood.github.io/arenic-sept-godot/docs/) ·
[Bosses](https://matthewharwood.github.io/arenic-sept-godot/docs/bosses/) ·
[Attacks & abilities](https://matthewharwood.github.io/arenic-sept-godot/docs/attacks.html)

A Godot 4.7.2 game with eight selectable heroes and nine connected arenas.
The current project supports arena exploration, one chosen hero, tile movement,
eight starter abilities, and independent damage phases in all nine arenas.
Bosses and the Guild House training construct remain immortal. Camera
transitions, native-resolution rendering, and spatial V3 music are integrated.
The field guide includes 32 ability studies; the other 24 abilities and their
sound effects remain separate from the playable implementation.

Use a desktop keyboard and mouse. Click **Start** to unlock browser audio.
Press **P** to toggle the overworld, **[ / ]** to cycle arenas, and **Tab**
to focus your hero. Arrow keys move a selected hero one tile per press.
In its focused arena, press **Space** or click the ability button to cast;
hold for Cardinal’s Sacrifice and release to stop. Arena shortcuts: **L G S / F W T / A M B**, in map order.

Open `arenic-game/project.godot` in Godot for native development. Editable art
and galleries live in `assets/`; the Bevy repositories are reference material.

- [Web builds, deployment and regression checks](docs/github-pages.md)
- [Godot Doctor authored-data preflight](docs/godot-doctor.md)
- [Starter combat and damage phases](docs/combat.md)
- [Battle sequences](docs/encounters.md)
- [Recording and ghosts](docs/recording.md)
- [The guild](docs/guild.md)
- [Arena music](docs/arena-music.md)
- [Overworld and controls](docs/overworld.md)
- [Display density](docs/display-rendering.md)
- [Art pipeline](assets/README.md)

The [main-game HUD](docs/hud.md) documents the roster, hero vitals, fixed ability slots, arena map, and controls.
