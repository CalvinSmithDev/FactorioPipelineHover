# Pipeline Hover Visualizer

Bring back pipeline visualization on mouse-over. With **alt mode enabled**, hover
over a pipe, underground pipe, storage tank, pump, or fluid machine to see its
connected pipelines and what they contain. No clicking, tool selection, or extra
hotkey is needed. Move the cursor away or turn alt mode off to clear the overlay.

Built for **Factorio 2.1.22 or newer in the 2.1 series**, including **Space Age**.
Space Age is optional; the mod also works with the base game. Factorio 2.0 is not
targeted because it already has the original hover visualization.

## What you see

- Connected pipelines colored by their actual fluid, with fluid icons along the route.
- Dashed lines for connected underground pipes (and modded linked connections).
- Fluid name, total pipeline amount/capacity, and temperature above the hovered entity.
- Gray highlights and an empty label for pipelines with no fluid.
- Separate highlights for each attached pipeline on a pump or machine with multiple fluids.

The overlay is personal to each player. It uses the actual fluid-storage
connections and segment IDs, so it does not accidentally connect adjacent pipes,
cross a pump, or join a machine's independent inputs and outputs. It works on the
surface being viewed, including remote view and space platforms. Ghosts are not
part of a live pipeline. Standalone machine buffers and fluid wagons are not
pipelines; a pump or machine needs an attached pipeline to highlight.

This mod draws its own overlay using the runtime rendering API. It does not
toggle the game's persistent pipeline checkboxes or change fluid simulation.

## Install

1. Copy `dist/pipeline-hover_1.0.0.zip` into your Factorio `mods` folder. Leave it zipped.
   - Windows: `%APPDATA%\Factorio\mods`
   - Linux: `~/.factorio/mods`
   - macOS: `~/Library/Application Support/factorio/mods`
2. Enable **Pipeline Hover Visualizer** in the game's Mods menu and restart when prompted.
3. Load a save, enable alt mode (normally **Alt**), and hover over a pipeline.

It can be added to existing saves. For multiplayer, install the same mod version
on the server and participating clients.

## Settings and performance

Under **Settings → Mod settings → Per player**, you can disable the overlay,
hide icons or contents labels, and change the traversal limit (default 1,500
fluid storages, maximum 10,000).

Hover and alt-mode events update immediately. While hovering, the network and
contents refresh every 30 ticks (half a second at 60 UPS), including after pipes
are built, mined, rotated, or destroyed. Only connected players and the hovered
networks are visited; there are no whole-surface scans or per-tick handlers.

Very large networks are highlighted up to the configured limit, with an explicit
notice when the drawing is incomplete. Amounts and capacities still describe the
whole fluid segment. Higher limits increase rendering and traversal work.

## Development

Build the distributable with Python 3:

```sh
python3 tools/build.py
```

The ZIP contains the mod files under the required `pipeline-hover_1.0.0/` folder.
Development tools and tests are excluded.

Run the engine integration checks against a local Factorio installation:

```sh
python3 tools/test_engine.py /path/to/factorio
```

The runner uses isolated mod, save, and configuration directories under
`.test-output/`. It checks real pipe networks, underground pairs, pump boundaries,
machine connections, cycles, traversal limits, render creation/cleanup, and
save/reload with rendering expiry. It supports Windows executables from WSL.
The test installation must include Space Age.

Event/lifecycle tests use Lua 5.2 through the optional Python `lupa` package:

```sh
python3 -m pip install lupa
python3 tools/test_control.py
```

These check hover events, stationary fluid changes, alt-mode toggling, per-player
settings and rendering isolation, destroyed selections, disconnect/rejoin, and
configuration changes. A graphical in-game hover check is still recommended for
visual appearance; automated engine checks run headlessly.

API references: [fluid connections](https://lua-api.factorio.com/latest/classes/LuaEntity.html#get_fluid_box_pipe_connections),
[fluid segments](https://lua-api.factorio.com/latest/classes/LuaEntity.html#get_fluid_segment_id),
[per-player rendering](https://lua-api.factorio.com/latest/classes/LuaRendering.html),
and [alt-mode events](https://lua-api.factorio.com/latest/events.html#on_player_toggled_alt_mode).
Factorio's [2.1.7 release notes](https://forums.factorio.com/viewtopic.php?t=134095)
document the removal of automatic pipeline visualization on hover.

License: MIT.
