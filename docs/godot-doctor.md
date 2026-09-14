# Godot Doctor authored-data preflight

[Godot Doctor](https://github.com/codevogel/godot_doctor) is an editor and
headless validator for Godot scenes and resources. Arenic vendors the
GDScript-only portion of release **2.2.0**, pinned to upstream tag commit
`6ded179ae47098fe6bf0f31e83f05aeb94e93584`, at
`arenic-game/addons/godot_doctor/`. Its MIT license and attribution stay with
the vendor directory.

The plugin is enabled in the native editor. It provides immediate feedback when
an authored resource is opened or saved, and the same checks run as a bounded
headless preflight in CI.

## Scope

The suite at `arenic-game/data/validation/arenic_authored_content.tres`
discovers scripted resources below `res://data`. Project resources with an
explicit Doctor hook reuse their existing `validation_errors()` logic through
`ArenicDoctorConditions`. That covers the contracts already owned by class,
world, boss, theme, music, and sound-profile data instead of creating a second,
plugin-specific ruleset.

Class abilities expose the same pure `enemy_dot_error()` contract used when
combat accepts a cast. Enemy DOT duration is finite and between 0 and 120 seconds;
zero disables it, while a positive duration requires Cleanse and must round to
at least one 60 Hz tick. The interval stays between 0.05 and 10 seconds and damage
between 1 and 100, including while disabled so later Inspector enablement is safe.
Validation preserves authored seconds; accepted stacks freeze their rounded
integer timing in the combat model. The class catalog includes the owning class
and ability in any reported error.

Generic default validation is deliberately off. It treats every exported object
and string as mandatory, which is wrong for Arenic's reusable scene templates,
runtime-assigned fields, optional ability sound phases, and Guild House's
intentional lack of a boss. Add a domain rule when a new invariant matters; do
not turn an optional field into a fake requirement to silence a generic check.

Each resource script that supplies a Doctor hook must be `@tool`. Any nested
resource whose methods are called by that hook must also be `@tool`, otherwise
Godot creates a placeholder during editor validation. Keep validation pure and
bounded: validate data only, and never touch the scene tree, playback, clocks,
randomness, networking, or mutate files. A bounded, declared read of source
metadata is acceptable when it is part of the resource contract.

## Run it locally

Use the disposable CI runner rather than pointing a headless editor at an open
development project. It removes the MCP autoload, enables only Godot Doctor,
imports a temporary copy, and keeps logs in `.tmp/ci-logs/`.

```sh
python3 scripts/ci/test-godot.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --suite doctor
```

`--suite headless` and `--suite all` run the same preflight before their
gameplay checks. The plugin has a five-second editor-readiness fallback and a
45-second watchdog. The runner's wall-clock timeout is the final backstop.

## Release integration

The Pages build runs `--suite doctor` immediately after installing Godot, before
downloading browser dependencies or exporting the Web game. The native headless
validation lane also runs it, so a data-contract failure is visible before its
longer test list.

The production Web exporter makes a separate project copy, removes the
editor-only validation-suite resource, and clears the whole `[editor_plugins]`
list, not only the MCP entry. It also removes the MCP autoload and audits the
PCK for development paths. Godot Doctor is editor-only and must never ship in a
browser release.

Doctor confirms authored-data invariants. It does not certify gameplay flow,
rendering, shader output, browser behavior, decoded audio, frame rate, or visual
quality; retain the existing native and Chromium gates for those concerns.

## Update policy

Upgrade only from a reviewed upstream release. Preserve the GDScript-only
vendor layout and the license, update the pinned version and commit in this
document and `AGENTS.md`, then run the local macOS `--suite doctor` command and
let Linux CI verify the same headless path. Automatic update checks are disabled
in the project settings so editor startup and CI stay reproducible.
