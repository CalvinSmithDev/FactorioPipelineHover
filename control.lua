local Network = require("scripts.network")
local Overlay = require("scripts.overlay")

local function clear_player(player_index)
  local overlays = storage.pipeline_hover
  if overlays then
    Overlay.clear(overlays[player_index])
    overlays[player_index] = nil
  end
end

local function refresh_player(player_index)
  clear_player(player_index)
  local player = game.get_player(player_index)
  if not player or not player.valid or not player.connected
    or not player.game_view_settings.show_entity_info then return end

  local preferences = settings.get_player_settings(player)
  if not preferences["pipeline-hover-enabled"].value then return end

  local selected = player.selected
  if not Network.is_candidate(selected) then return end

  local limit = preferences["pipeline-hover-max-nodes"].value
  local network = Network.collect(selected, limit)
  if #network.nodes == 0 then return end
  storage.pipeline_hover = storage.pipeline_hover or {}
  storage.pipeline_hover[player_index] = Overlay.draw(player, selected, network, {
    limit = limit,
    icons = preferences["pipeline-hover-show-icons"].value,
    contents = preferences["pipeline-hover-show-contents"].value,
  })
end

local function refresh_event(event)
  refresh_player(event.player_index)
end

local function reset()
  rendering.clear(script.mod_name)
  storage.pipeline_hover = {}
end

script.on_init(reset)
script.on_configuration_changed(reset)
script.on_event({
  defines.events.on_selected_entity_changed,
  defines.events.on_player_toggled_alt_mode,
  defines.events.on_player_joined_game,
  defines.events.on_player_changed_surface,
  defines.events.on_player_controller_changed,
}, refresh_event)

script.on_event({defines.events.on_player_left_game, defines.events.on_player_removed}, function(event)
  clear_player(event.player_index)
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.player_index and string.sub(event.setting, 1, 15) == "pipeline-hover-" then
    refresh_player(event.player_index)
  end
end)

-- Only visit connected players and the hovered network. No surface scans and
-- no per-tick handler. Refresh also catches fluids changing, rotation, recipes,
-- construction, destruction, and script-driven changes while the cursor rests.
script.on_nth_tick(30, function()
  for _, player in pairs(game.connected_players) do
    refresh_player(player.index)
  end
end)
