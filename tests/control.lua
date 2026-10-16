-- Host-side event/lifecycle regression tests, using the actual mod modules.
local handlers, ticks = {}, {}
local init, configuration_changed
storage = {}
defines = {events = {}}
for index, name in ipairs({
  "on_selected_entity_changed", "on_player_toggled_alt_mode", "on_player_joined_game",
  "on_player_changed_surface", "on_player_controller_changed", "on_player_left_game",
  "on_player_removed", "on_runtime_mod_setting_changed",
}) do defines.events[name] = index end

script = {
  mod_name = "pipeline-hover",
  on_init = function(handler) init = handler end,
  on_configuration_changed = function(handler) configuration_changed = handler end,
  on_nth_tick = function(interval, handler) ticks[interval] = handler end,
  on_event = function(events, handler)
    if type(events) ~= "table" then events = {events} end
    for _, event in ipairs(events) do handlers[event] = handler end
  end,
}

local objects = {}
rendering = {clear = function()
  for _, object in ipairs(objects) do object.valid = false end
end}
for _, kind in ipairs({"draw_line", "draw_circle", "draw_sprite", "draw_text"}) do
  rendering[kind] = function(parameters)
    assert(#parameters.players == 1, "every render must target exactly one player")
    assert(parameters.only_in_alt_mode, "every render must require alt mode")
    local object = {valid = true, parameters = parameters, kind = kind}
    object.destroy = function() object.valid = false end
    objects[#objects + 1] = object
    return object
  end
end
prototypes = {fluid = {water = {
  visualization_color = {r = 0, g = 0.3, b = 0.8}, localised_name = {"fluid-name.water"},
}}}

local fluid = {name = "water", amount = 25, temperature = 15}
local pipe = {
  valid = true, type = "pipe", fluids_count = 1, unit_number = 42,
  surface = {index = 1}, position = {x = 0, y = 0},
  has_fluid_segment = function() return true end,
  get_fluid_segment_id = function() return 1 end,
  get_fluid_box_pipe_connections = function() return {} end,
  get_fluid_segment_fluid = function() return fluid end,
  get_fluid_segment_capacity = function() return 100 end,
}
local players, preferences = {}, {}
for i = 1, 2 do
  players[i] = {index = i, valid = true, connected = true, selected = pipe,
    game_view_settings = {show_entity_info = true}}
  preferences[i] = {
    ["pipeline-hover-enabled"] = {value = true},
    ["pipeline-hover-show-icons"] = {value = true},
    ["pipeline-hover-show-contents"] = {value = true},
    ["pipeline-hover-max-nodes"] = {value = 100},
  }
end
game = {get_player = function(index) return players[index] end, connected_players = players}
settings = {get_player_settings = function(player) return preferences[player.index] end}

require("control")
local function emit(name, player_index, setting)
  handlers[defines.events[name]]({player_index = player_index, setting = setting})
end
local function active(index)
  local count = 0
  for _, object in ipairs(objects) do
    if object.valid and object.parameters.players[1] == index then count = count + 1 end
  end
  return count
end

init()
emit("on_selected_entity_changed", 1)
assert(active(1) == 3, "hover creates a node, fluid icon and contents label")
assert(active(2) == 0, "other player cannot see the first player's hover")
emit("on_selected_entity_changed", 2)
assert(active(2) == 3, "second player has an independent overlay")
players[1].game_view_settings.show_entity_info = false
emit("on_player_toggled_alt_mode", 1)
assert(active(1) == 0 and active(2) == 3, "alt-off clears only that player's overlay")
players[1].game_view_settings.show_entity_info = true
emit("on_player_toggled_alt_mode", 1)
assert(active(1) == 3, "alt-on works without moving the cursor")

players[1].selected = nil
emit("on_selected_entity_changed", 1)
assert(active(1) == 0, "moving away clears the overlay immediately")
players[1].selected = pipe
emit("on_selected_entity_changed", 1)
fluid = nil
ticks[30]()
assert(active(1) == 2, "stationary hover updates when pipeline becomes empty")
assert(objects[#objects].parameters.text[1] == "pipeline-hover.empty", "empty content label")

preferences[1]["pipeline-hover-enabled"].value = false
emit("on_runtime_mod_setting_changed", 1, "pipeline-hover-enabled")
assert(active(1) == 0 and active(2) == 2, "per-player disable is isolated")
preferences[1]["pipeline-hover-enabled"].value = true
emit("on_runtime_mod_setting_changed", 1, "pipeline-hover-enabled")
assert(active(1) == 2, "setting re-enable refreshes immediately")
preferences[1]["pipeline-hover-show-contents"].value = false
emit("on_runtime_mod_setting_changed", 1, "pipeline-hover-show-contents")
assert(active(1) == 1, "contents setting applied")

pipe.valid = false
ticks[30]()
assert(active(1) == 0 and active(2) == 0, "destroyed selection is safe")
pipe.valid = true
emit("on_selected_entity_changed", 1)
emit("on_player_left_game", 1)
assert(active(1) == 0, "disconnect clears renderings")
emit("on_player_joined_game", 1)
assert(active(1) == 1, "rejoin refreshes")
emit("on_player_removed", 1)
assert(active(1) == 0, "removed player cleared")

players[1].selected = nil
emit("on_player_changed_surface", 1)
assert(active(1) == 0, "surface change without selection is safe")
players[1].selected = pipe
emit("on_selected_entity_changed", 1)
configuration_changed()
assert(active(1) == 0 and next(storage.pipeline_hover) == nil, "configuration reset clears state")
ticks[30]()
assert(active(1) == 1, "overlay rebuilt after configuration changes")
print("PIPELINE_HOVER_CONTROL_TESTS_PASSED")
