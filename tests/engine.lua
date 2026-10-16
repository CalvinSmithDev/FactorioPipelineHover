-- Executed as a separate test mod, never included in the release ZIP.
local Network = require("__pipeline-hover__/scripts/network")
local Overlay = require("__pipeline-hover__/scripts/overlay")

local function check(value, message)
  if not value then error("Pipeline Hover test failed: " .. message) end
end

script.on_init(function()
  local surface = game.create_surface("pipeline-hover-tests", {
    width = 128, height = 128, autoplace_controls = {},
    autoplace_settings = {entity = {treat_missing_as_default = false}},
  })
  surface.request_to_generate_chunks({0, 0}, 2)
  surface.force_generate_chunk_requests()
  for _, entity in pairs(surface.find_entities()) do entity.destroy() end
  local tiles = {}
  for x = -50, 50 do
    for y = -50, 50 do tiles[#tiles + 1] = {name = "landfill", position = {x, y}} end
  end
  surface.set_tiles(tiles)

  local function create(name, x, y, direction)
    return assert(surface.create_entity({
      name = name, position = {x, y}, direction = direction, force = "player",
    }), "Could not create " .. name)
  end

  local a = create("pipe", 0.5, 0.5)
  local b = create("pipe", 1.5, 0.5)
  local c = create("pipe", 2.5, 0.5)
  create("pipe", 4.5, 0.5) -- Disconnected: must not be drawn.
  local network = Network.collect(a, 100)
  check(#network.nodes == 3, "exact connected pipe count")
  check(#network.edges == 2, "each connection appears once")
  check(#network.segments == 1, "one pipeline")
  check(not network.truncated, "small network complete")

  a.set_fluid_segment_fluid(1, {name = "water", amount = 50, temperature = 25})
  local contents = a.get_fluid_segment_fluid(1)
  check(contents and contents.name == "water", "test network contains water")

  -- The headless create path has no player yet. An empty players array renders
  -- globally in this isolated test only; production always supplies player.index.
  local state = Overlay.draw({}, a, network, {icons = true, contents = true, limit = 100})
  check(#state.objects > 5, "engine creates lines, icons and contents text")
  for _, object in ipairs(state.objects) do
    check(object.valid, "render object valid")
    check(object.only_in_alt_mode, "rendering restricted to alt mode")
  end
  Overlay.clear(state)
  for _, object in ipairs(state.objects) do check(not object.valid, "overlay cleared") end
  Overlay.clear(state) -- Idempotent even if objects expired/destroyed.

  local limited = Network.collect(a, 2)
  check(#limited.nodes == 2 and limited.truncated, "large-network cap is explicit")
  state = Overlay.draw({}, a, limited, {icons = false, contents = false, limit = 2})
  check(state.objects[#state.objects].type == "text", "truncation notice without contents")
  Overlay.clear(state)

  b.destroy()
  check(#Network.collect(a, 100).nodes == 1, "mined pipe splits network")
  a.clear_fluid_segment_fluid(1)
  state = Overlay.draw({}, a, Network.collect(a, 100), {icons = true, contents = true, limit = 100})
  check(state.objects[#state.objects].text[1] == "pipeline-hover.empty", "empty label")
  Overlay.clear(state)

  local ghost = surface.create_entity({name = "entity-ghost", inner_name = "pipe", position = {8.5, 0.5}, force = "player"})
  check(not Network.is_candidate(ghost), "ghost ignored")
  check(not Network.is_candidate(nil), "nil selection ignored")
  check(not Network.is_candidate(b), "destroyed selection ignored")
  check(not Network.is_candidate(create("wooden-chest", 10.5, 0.5)), "non-fluid entity ignored")

  local u1 = create("pipe-to-ground", 0.5, 10.5, defines.direction.west)
  local u2 = create("pipe-to-ground", 5.5, 10.5, defines.direction.east)
  local underground = Network.collect(u1, 100)
  check(#underground.nodes == 2, "underground pair connected")
  check(#underground.edges == 1 and underground.edges[1].underground, "underground link dashed")

  local pump = create("pump", 0.5, 20, defines.direction.north)
  local upstream = create("pipe", 0.5, 21.5)
  local downstream = create("pipe", 0.5, 18.5)
  local inlet = Network.collect(upstream, 100)
  local outlet = Network.collect(downstream, 100)
  check(#inlet.nodes == 1 and #outlet.nodes == 1, "neither pipeline crosses the pump buffer")
  check(#inlet.edges == 1 and #outlet.edges == 1, "each pipeline draws up to its pump port")
  check(inlet.segments[1].id ~= outlet.segments[1].id, "pump sides are separate segments")
  check(#Network.collect(pump, 100).segments == 2, "hovering pump shows both sides")

  local machine = create("chemical-plant", 20.5, 20.5, defines.direction.north)
  machine.set_recipe("sulfuric-acid")
  for index = 1, machine.fluids_count do
    for _, connection in ipairs(machine.get_fluid_box_pipe_connections(index) or {}) do
      create("pipe", connection.target_position.x, connection.target_position.y)
    end
  end
  local machine_network = Network.collect(machine, 100)
  check(#machine_network.segments >= 2, "recipe fluid storages stay separate")
  check(#machine_network.edges == #machine_network.nodes, "only actual machine ports are connected")
  state = Overlay.draw({}, machine, machine_network, {icons = true, contents = true, limit = 100})
  Overlay.clear(state)

  -- A loop exercises visited-node handling with real LuaEntity references.
  local loop
  for x = 30, 32 do
    for y = 0, 2 do
      if x ~= 31 or y ~= 1 then loop = create("pipe", x + 0.5, y + 0.5) end
    end
  end
  local cycle = Network.collect(loop, 100)
  check(#cycle.nodes == 8 and #cycle.edges == 8, "cycles terminate without duplicate nodes/edges")
  check(not cycle.truncated, "cycle not falsely truncated")

  -- Leave engine rendering objects in storage to exercise save/reload and TTL.
  storage.saved_overlay = Overlay.draw({}, loop, cycle, {icons = true, contents = true, limit = 100})
  storage.started_tick = game.tick

  log("PIPELINE_HOVER_ENGINE_TESTS_PASSED")
end)

script.on_nth_tick(1, function()
  if not storage.saved_overlay then return end
  local elapsed = game.tick - storage.started_tick
  if elapsed == 1 then
    for _, object in ipairs(storage.saved_overlay.objects) do
      check(object.valid, "render objects survive save/reload")
    end
  elseif elapsed == 40 then
    for _, object in ipairs(storage.saved_overlay.objects) do
      check(not object.valid, "stale render objects expire")
    end
    Overlay.clear(storage.saved_overlay)
    storage.saved_overlay = nil
    log("PIPELINE_HOVER_RELOAD_TESTS_PASSED")
  end
end)
