# Godot ↔ Codex connection

Installed on September 9, 2026, for this repository's `arenic-game` project. GDScript language services and live debugging were verified again on September 10, 2026.

## Installed components

| Component | Version / location |
| --- | --- |
| Godot | 4.7.2 stable, `/Applications/Godot.app` |
| NPGameDev Godot MCP Toolkit | 1.0.0, `arenic-game/addons/godot_mcp_toolkit/` |
| NPGameDev MCP Server | `@npgamedev/godot-mcp-server@1.0.0`, installed under `.tools/godot-mcp/` |
| Node.js | 24.12.0; the server requires Node 22 or newer |
| Codex connection name | `arenic_godot` |

The Toolkit plugin is enabled in `arenic-game/project.godot`. Its `MCPRuntimeServer` autoload enables game-state inspection, screenshots, and input during playtests. The server dependency and lockfile are reproducible inputs to keep in version control; `node_modules/` is ignored. The vendored Toolkit retains its upstream license and matches the 1.0.0 release archive.

## Use it

1. Open `arenic-game/project.godot` in Godot. Leave the editor open.
2. In Codex, open **Settings → MCP servers** and restart the connection after a configuration change. Use `/mcp` to inspect availability.
3. Work in `arenic-sept-godot`. Ask Codex to inspect or edit the scene, check scripts, run a scene, inspect the running game, capture screenshots, or simulate input.

During the initial setup, a separate MCP client verified the actual server and editor connection. That already-open Codex task needed a client-side catalog refresh; automated control of Codex's own settings was blocked. The connection is registered; do not add a duplicate when refreshing availability.

Additional tool groups are loaded on demand through `discover_tools`. Activate the groups needed for the task, such as animation authoring, tilemaps, debugger controls, or GDScript analysis. The current main scene is `res://scenes/title/title_scene.tscn`; run a specific scene when a focused playtest is more useful.

## GDScript workflow

Godot 4.7.2 bundles its language server and debug adapter. The installed NPGameDev connection gives Codex access to GDScript language services and basic debugger controls; no additional Codex plugin or external editor installation is needed for this workflow. Keep the Godot editor open on this project. Godot documents the separate LSP and DAP connections under [LSP/DAP support](https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html#lsp-dap-support).

Activate the relevant tools with the `request` parameter:

```json
{"request":["lsp_code_analysis","lsp_code_navigation","debugger"]}
```

- Use `lsp_symbols`, `lsp_hover`, `lsp_completion`, `lsp_definition`, and `lsp_references` for focused code investigation. LSP position arguments (`line`, `column`) are **zero-based**; `debug_set_breakpoint.line` is **one-based**.
- After a script edit, use the inline diagnostics and a targeted `script_check` or `lsp_diagnostics` as appropriate. Refresh newly created or externally edited files through `editor_refresh` before querying the language server. Use `lsp_project_diagnostics` selectively for cross-file changes or a final handoff; it scans every GDScript and can interrupt the editor briefly. Addons are excluded by default. Shader changes require renderer compilation and visual checks; GDScript diagnostics do not validate shaders.
- Use `debug_set_breakpoint`, `debug_state`, and `debug_continue` for a temporary breakpoint test. Set the breakpoint on an executable statement, confirm it actually pauses the game, then clear the temporary breakpoint before continuing. Preserve existing breakpoints. Breakpoint tools require Godot's built-in script editor; `debug_list_breakpoints` temporarily switches script tabs while reading them.
- Use Godot's native debugger UI for stepping, stack frames, locals and profiling. Trigger breakpoint tests with actual game input when possible: a runtime MCP request may wait while the game is paused. The Toolkit's generic “Game paused at error” fallback can also describe an ordinary breakpoint, so inspect the actual stop reason.

On September 10, diagnostics, symbols, hover, completion, definition and references worked through NPGameDev. `lsp_project_diagnostics` checked all **47 project GDScripts outside addons with zero errors** at that snapshot. Actual P-key input hit the executable statement in `game_shell.gd:71`; MCP reported `active`, `breaked` and `can_debug` as true, and Godot displayed the call stack. The temporary breakpoint was cleared, `debug_continue` resumed the game, no breakpoints remained, and the original view, arena and hero-selection state were restored. These checks establish language-service and breakpoint behavior, not gameplay correctness.

The same editor listened on localhost **6005 for LSP**, **6006 for DAP**, and **6007 for the native game debugger**. The Toolkit's breakpoint/continue bridge uses the native debugger; **no external DAP client session was verified**. A listening DAP port is not a stepping or variable-inspection test. Use the project's discovered LSP endpoint rather than assuming a global port belongs to the right editor when multiple projects are open.

## Connection configuration

This machine's entry lives in `~/.codex/config.toml`. It uses the installed local server directly, so opening Codex does not require downloading the package again:

```toml
[mcp_servers.arenic_godot]
command = "/Users/matthewharwood/.nvm/versions/node/v24.12.0/bin/node"
args = ["/Users/matthewharwood/Documents/GitHub/arenic-sept-godot/.tools/godot-mcp/node_modules/@npgamedev/godot-mcp-server/dist/index.js"]
cwd = "/Users/matthewharwood/Documents/GitHub/arenic-sept-godot/arenic-game"
enabled = true

[mcp_servers.arenic_godot.env]
GODOT_MCP_PROJECT_PATH = "/Users/matthewharwood/Documents/GitHub/arenic-sept-godot/arenic-game"
GODOT_MCP_CONFIG_VERSION = "1"
```

Both the working directory and the project environment variable point to the actual Godot project. Keep them aligned if the repository moves. The absolute Node path also needs updating if that Node installation is removed.

`arenic-game/.mcp.json` is the Toolkit-generated configuration for clients that use that format. Its package version is also pinned to 1.0.0. Codex uses the TOML entry above.

The Toolkit discovers the editor through its local project registry and reads the per-project token automatically. No token is stored in the repository or Codex configuration. On this Mac, the registry is under `~/Library/Application Support/godot-mcp-toolkit/`. During verification, the editor listened on localhost port 6550, the running game used 6570, and GDScript language services used 6005; discovery handles these ports without hard-coding them here.

## Restore dependencies or update

With Node 22 or newer available, run this from the repository root to restore the locked server installation:

```sh
npm ci --prefix .tools/godot-mcp --ignore-scripts
```

The Toolkit files are already present under `arenic-game/addons/`. Enable **Godot MCP Toolkit** under Godot's **Project Settings → Plugins** if it has been disabled.

For an update, review both projects' release notes, select compatible Toolkit and Server versions, update the vendored addon and the server dependency/lockfile, and align `.mcp.json`. Restart the editor and Codex connection, then repeat the checks below. Avoid changing only one component to an unpinned latest release.

## Initial installation verification — September 9, 2026

Using the same executable, server, working directory, and project environment as the Codex entry:

- Completed the MCP handshake with server 1.0.0 and enumerated 36 initial tools.
- Read the correct `arenic-game` project settings.
- Activated additional editor, runtime, cleanup, and GDScript-analysis tools.
- Created and opened a temporary scene, added a Label, edited its position, wrote and attached a GDScript, and saved the scene.
- Received zero diagnostics for the test script from both script validation and the language server.
- Launched the scene and connected to its runtime.
- Read a script variable at 0, injected an input action press/release, and read the value at 1.
- Captured and visually checked a screenshot showing “MCP input verified: 1”.
- Read game logs containing the ready marker and input count; the editor console reported no warnings or errors during the test.
- Stopped the game and deleted the temporary scene, script, and companion UID. No main scene was assigned during this initial smoke test; the title scene was configured later.
- Restarted Godot and successfully reconnected a new server client through project discovery. The Toolkit reported a healthy setup status.
- Installed dependencies with lifecycle scripts disabled; npm reported zero vulnerabilities at installation time.

These checks validate the installation's editor, runtime, input, image, and language-service paths on this Mac. They are not an exhaustive test of every Toolkit tool. The initial test client was closed after verification; Codex starts its own server process when it loads the connection.

## Upstream references

- [Toolkit 1.0.0 release](https://github.com/NPGameDev/godot-mcp-toolkit/releases/tag/v1.0.0)
- [NPGameDev MCP Server](https://github.com/NPGameDev/godot-mcp-server)
- [Godot LSP/DAP support](https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html#lsp-dap-support)
- [Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp)

Toolkit archive SHA-256: `2cb4989204cdea85eff3282f8c44e5a8ce874ef5f39b372b498144bc03b382d6`.
